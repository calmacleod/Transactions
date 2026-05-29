module TransactionClassification
  class FastPass
    CATEGORY_RULES = Ai::TransactionClassifier::CATEGORY_RULES
    BATCH_SIZE = 500
    LOCAL_RULE_REASON = "Matched local merchant rules during fast classification pass."
    UNCATEGORIZED_REASON = "No local merchant rule matched during fast classification pass."
    PAYMENT_REASON = "Credit card payment; excluded from expense totals."
    CREDIT_REASON = "Credit or refund; excluded from expense totals."

    Result = Data.define(:category_name, :confidence, :reason)

    def initialize(run:, batch_size: BATCH_SIZE)
      @run = run
      @batch_size = batch_size
    end

    def call(scope)
      run.start!(total: scope.count)
      return run.complete! if run.total_count.zero?

      scope.select(:id, :description, :direction).find_in_batches(batch_size:) do |transactions|
        run.reload
        return run.cancel! if run.cancel_requested?

        results_by_id = transactions.index_with { |transaction| classify(transaction) }
        categories_by_name = ensure_categories(results_by_id.values.map(&:category_name).uniq)
        apply_results(results_by_id, categories_by_name)
        record_progress(results_by_id)
      end

      run.reload.cancel_requested? ? run.cancel! : run.complete!
    rescue StandardError => error
      run.fail!(error)
      raise
    end

    private

    attr_reader :run, :batch_size

    def ensure_categories(names)
      names.each_with_object({}) do |name, categories|
        categories[name] = category_scope.find_or_create_by!(name:) do |category|
          category.color = CategoryColor.pick(name)
        end
      end
    end

    def classify(transaction)
      return credit_classification(transaction) unless transaction.direction == "debit"

      category_name = CATEGORY_RULES.find { |_name, pattern| transaction.description.match?(pattern) }&.first

      if category_name
        Result.new(category_name:, confidence: 0.65, reason: LOCAL_RULE_REASON)
      else
        Result.new(category_name: "Uncategorized", confidence: 0.25, reason: UNCATEGORIZED_REASON)
      end
    end

    def credit_classification(transaction)
      if transaction.description.match?(/payment thank you|paiemen t merci|payment/i)
        Result.new(category_name: "Payments", confidence: 1.0, reason: PAYMENT_REASON)
      else
        Result.new(category_name: "Refunds & Credits", confidence: 0.8, reason: CREDIT_REASON)
      end
    end

    def apply_results(results_by_id, categories_by_name)
      classified_at = Time.current

      results_by_id.group_by { |_id, result| result }.each do |result, pairs|
        ExpenseTransaction.where(id: pairs.map(&:first)).update_all(
          category_id: categories_by_name.fetch(result.category_name).id,
          classification_confidence: result.confidence,
          classification_reason: result.reason,
          classified_at:,
          updated_at: classified_at
        )
      end
    end

    def record_progress(results_by_id)
      run.record_batch!(
        processed: results_by_id.size,
        classified: results_by_id.size,
        rule_based: results_by_id.size,
        ai: 0,
        failed: 0
      )
    end

    def category_scope
      run.user&.categories || Category.all
    end
  end
end
