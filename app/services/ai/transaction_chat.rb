module Ai
  class TransactionChat
    def initialize(model: Ai::Controls.model_for(:chat))
      @model = model
    end

    def call(question:, transactions:, filters: {}, chat: nil)
      return disabled_response unless Ai::Controls.enabled?(:chat)

      prompt = prompt_for(question:, transactions:, filters:, chat:)
      response = Ai::RubyLlmClient.new(feature: :chat, model:, tools: chat_tools).ask(prompt)

      record_chat_messages(chat, question, response) if chat.present?
      { answer: response.content.to_s, source: "ai", chat_id: chat&.id, messages: chat_messages(chat) }
    rescue StandardError => error
      Rails.logger.warn("RubyLLM transaction chat failed: #{error.class}: #{error.message}")
      { answer: "I could not complete the AI chat request. Check the AI controls page for provider and request-limit status.", source: "automatic" }
    end

    def respond_to_chat(chat:, assistant_message:)
      question = chat.messages.where(role: "user").where(created_at: ..assistant_message.created_at).ordered.last&.content.to_s
      transactions = chat.expense_transactions.includes(:category, :subcategories)
      prompt = prompt_for(question:, transactions:, filters: chat.context_filters, chat:)
      tool_message = nil

      response = Ai::RubyLlmClient.new(feature: :chat, model:, tools: chat_tools).ask(
        prompt,
        on_event: lambda { |event|
          tool_message = handle_tool_event(chat, assistant_message, tool_message, event)
        }
      )

      content = response.content.to_s
      assistant_message.update!(
        status: "complete",
        content:,
        metadata: assistant_message.metadata.merge("referenced_transaction_ids" => referenced_transaction_ids(content)),
        input_tokens: Ai::Controls.token_count(response, :input_tokens),
        output_tokens: Ai::Controls.token_count(response, :output_tokens),
        estimated_cost_microdollars: Ai::Controls.estimated_cost_microdollars(model, response, Ai::Controls.token_count(response, :input_tokens), Ai::Controls.token_count(response, :output_tokens))
      )
      chat.update!(model:, updated_at: Time.current)
      AiChatChannel.broadcast_message_update(chat, assistant_message)
    rescue StandardError => error
      Rails.logger.warn("RubyLLM async transaction chat failed for chat #{chat.id}: #{error.class}: #{error.message}")
      assistant_message.update!(
        status: "failed",
        content: "I could not complete the AI chat request. Check the AI controls page for provider and request-limit status.",
        metadata: assistant_message.metadata.merge("error" => error.message)
      )
      AiChatChannel.broadcast_message_update(chat, assistant_message)
    end

    private

    attr_reader :model

    def disabled_response
      { answer: "AI chat is disabled, over the monthly request limit, or no provider key is configured.", source: "automatic" }
    end

    def prompt_for(question:, transactions:, filters:, chat:)
      payload = summary_payload(transactions)

      <<~PROMPT
        Answer the user's question using the attached transaction context first.
        You may use tools to search other transactions, budgets, or spending summaries when the user asks broader follow-up questions.
        Format the answer as concise Markdown with short headings, bullets, or tables when useful.
        When you mention a specific transaction, cite it inline with the exact token [[transaction:ID]], using the transaction id from the context or tool result.
        Always keep money amounts in dollars with a $ symbol.

        Filters: #{JSON.pretty_generate(filters)}
        Attached transaction context: #{JSON.pretty_generate(payload)}
        Conversation history: #{JSON.pretty_generate(chat_history(chat))}
        Question: #{question}
      PROMPT
    end

    def summary_payload(transactions)
      records = transactions.limit(500).to_a
      expenses = records.select(&:expense?)

      {
        transaction_count: records.size,
        expense_total_dollars: money(expenses.sum(&:amount_cents)),
        credit_total_dollars: money(records.reject(&:expense?).sum(&:amount_cents)),
        date_range: {
          start: records.map(&:occurred_on).min,
          end: records.map(&:occurred_on).max
        },
        category_totals: expenses.group_by { |transaction| transaction.category&.name || "Uncategorized" }
                                 .transform_values { |items| money(items.sum(&:amount_cents)) },
        subcategory_totals: subcategory_totals(expenses),
        merchants: expenses.group_by { |transaction| normalized_merchant(transaction.description) }
                          .transform_values { |items| { count: items.size, dollars: money(items.sum(&:amount_cents)) } }
                          .sort_by { |_merchant, item| -item[:dollars].to_d }
                          .first(25)
                          .to_h,
        sample_transactions: records.first(50).map do |transaction|
          Ai::TransactionPayload.record(transaction)
        end
      }
    end

    def normalized_merchant(description)
      description.split(/\s{2,}| #|\*/).first.to_s.downcase.squish
    end

    def subcategory_totals(transactions)
      totals = Hash.new(0)

      transactions.each do |transaction|
        subcategories = transaction.subcategories.to_a
        if subcategories.any?
          subcategories.each { |subcategory| totals[subcategory.name] += transaction.amount_cents }
        else
          totals["None"] += transaction.amount_cents
        end
      end

      totals.transform_values { |cents| money(cents) }
    end

    def money(cents)
      Ai::TransactionPayload.dollars(cents)
    end

    def chat_tools
      [
        Ai::Tools::SearchTransactionsTool.new,
        Ai::Tools::BudgetSummaryTool.new,
        Ai::Tools::SpendingSummaryTool.new
      ]
    end

    def chat_history(chat)
      return [] if chat.blank?

      chat.messages.ordered.last(12).map { |message| { role: message.role, content: message.content } }
    end

    def record_chat_messages(chat, question, response)
      chat.messages.create!(role: "user", content: question)
      chat.messages.create!(
        role: "assistant",
        content: response.content.to_s,
        metadata: { referenced_transaction_ids: referenced_transaction_ids(response.content.to_s) },
        model:,
        input_tokens: Ai::Controls.token_count(response, :input_tokens),
        output_tokens: Ai::Controls.token_count(response, :output_tokens),
        estimated_cost_microdollars: Ai::Controls.estimated_cost_microdollars(model, response, Ai::Controls.token_count(response, :input_tokens), Ai::Controls.token_count(response, :output_tokens))
      )
      chat.update!(model:, updated_at: Time.current)
    end

    def chat_messages(chat)
      return [] if chat.blank?

      chat.messages.ordered.map { |message| AiChatChannel.message_payload(message) }
    end

    def handle_tool_event(chat, assistant_message, tool_message, event)
      case event.fetch(:type)
      when "tool_call"
        tool_call = event.fetch(:tool_call)
        message = chat.messages.create!(
          role: "tool",
          content: "Calling #{tool_call.name.humanize}",
          status: "thinking",
          metadata: {
            assistant_message_id: assistant_message.id,
            kind: "tool_call",
            tool_call_id: tool_call.id,
            name: tool_call.name,
            arguments: tool_call.arguments
          }
        )
        AiChatChannel.broadcast_tool_call(chat, assistant_message, tool_call)
        AiChatChannel.broadcast_message(chat, message)
        message
      when "tool_result"
        result = event.fetch(:result)
        message = tool_message || chat.messages.create!(
          role: "tool",
          content: "Tool returned",
          status: "thinking",
          metadata: { assistant_message_id: assistant_message.id, kind: "tool_result" }
        )
        message.update!(
          status: "complete",
          content: "#{message.metadata["name"].presence&.humanize || "Tool"} returned",
          metadata: message.metadata.merge("result" => normalize_tool_result(result))
        )
        AiChatChannel.broadcast_tool_result(chat, assistant_message, normalize_tool_result(result))
        AiChatChannel.broadcast_message_update(chat, message)
        nil
      else
        tool_message
      end
    end

    def normalize_tool_result(result)
      case result
      when Hash, Array, String, Numeric, TrueClass, FalseClass, NilClass
        result
      else
        result.as_json
      end
    end

    def referenced_transaction_ids(content)
      content.to_s.scan(/\[\[transaction:(\d+)\]\]/i).flatten.map(&:to_i).uniq
    end
  end
end
