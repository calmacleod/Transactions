module Ai
  class InsightGenerator
    MAX_INSIGHTS = 6

    def initialize(model: Ai::Controls.model_for(:insights), user: Current.user)
      @model = model
      @user = user
    end

    def call(start_date: 4.months.ago.to_date.beginning_of_month, end_date: Date.current)
      transactions = transaction_scope.includes(:category).between(start_date, end_date)
      analysis = Insights::Analysis.new(transactions:, start_date:, end_date:, user:).call
      findings = selected_findings(analysis)

      Insight.transaction do
        insight_scope.destroy_all
        findings.map { |finding| persist_finding(finding, analysis:, start_date:, end_date:) }
      end
    end

    private

    attr_reader :model, :user

    def selected_findings(analysis)
      candidates = analysis[:findings]
      return candidates.first(MAX_INSIGHTS) if candidates.empty? || !Ai::Controls.enabled?(:insights)

      edits = llm_edits(analysis)
      return candidates.first(MAX_INSIGHTS) if edits.blank?

      candidates_by_key = candidates.index_by { |finding| finding[:key] }
      selected = edits.filter_map do |edit|
        candidate = candidates_by_key.delete(edit[:finding_key])
        next unless candidate

        candidate.merge(
          title: edit[:title].presence || candidate[:title],
          body: edit[:body].presence || candidate[:body],
          action: edit[:action].presence || candidate[:action],
          generation_source: "ai"
        )
      end
      selected.concat(candidates_by_key.values)
      selected.first(MAX_INSIGHTS)
    end

    def llm_edits(analysis)
      response = Ai::RubyLlmClient.new(feature: :insights, model:).ask(<<~PROMPT, schema: ExpenseInsightsSchema)
        You are editing precomputed personal-finance findings. Select and rank up to #{MAX_INSIGHTS} findings that are most useful for a user deciding what to review or change.

        Rules:
        - Use only the exact finding_key values supplied below. Never invent a finding, number, merchant, category, or transaction.
        - Preserve the meaning of each metric and comparison.
        - Prefer changes from a baseline, emerging budget risk, unusual behavior, recurring commitments, and data-quality issues over obvious totals.
        - Make the title decision-oriented, the body explain why the comparison matters, and the action specific.
        - Do not provide generic financial advice or mention AI/model limitations.

        Analysis period: #{JSON.pretty_generate(analysis[:period])}
        Overview: #{JSON.pretty_generate(analysis[:overview])}
        Candidate findings: #{JSON.pretty_generate(llm_findings(analysis[:findings]))}
      PROMPT

      response.content.fetch("insights").map do |insight|
        insight.symbolize_keys.slice(:finding_key, :title, :body, :action)
      end
    rescue StandardError => error
      Rails.logger.warn("RubyLLM insight editing failed: #{error.class}: #{error.message}")
      nil
    end

    def llm_findings(findings)
      findings.map do |finding|
        finding.slice(:key, :kind, :title, :body, :action, :severity, :metric, :score)
      end
    end

    def persist_finding(finding, analysis:, start_date:, end_date:)
      transaction_ids = Array(finding[:transaction_ids]).map(&:to_i) & analysis[:transaction_ids]
      insight = Insight.create!(
        title: finding.fetch(:title),
        body: finding.fetch(:body),
        action: finding.fetch(:action),
        kind: finding.fetch(:kind),
        metric: finding.fetch(:metric),
        severity: finding.fetch(:severity, "info"),
        starts_on: start_date,
        ends_on: end_date,
        generation_source: finding.fetch(:generation_source, "automatic"),
        payload: {
          key: finding.fetch(:key),
          score: finding.fetch(:score),
          filters: finding.fetch(:filters, {}),
          overview: analysis[:overview]
        },
        user:
      )
      insight.expense_transaction_ids = transaction_ids
      insight
    end

    def transaction_scope
      user&.expense_transactions || ExpenseTransaction.all
    end

    def insight_scope
      user&.insights || Insight.all
    end
  end
end
