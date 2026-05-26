module Ai
  class RubyLlmClient
    SYSTEM_PROMPT = <<~PROMPT.squish
      You are a careful personal finance assistant for this expense tracker.
      Return all monetary amounts in dollars using a $ prefix, never in cents.
      Base conclusions on the supplied records and tool results. Say when the available data does not support an answer.
    PROMPT

    def initialize(feature:, model: nil, tools: [])
      @feature = feature
      @model = model.presence || Ai::Controls.model_for(feature)
      @tools = tools
    end

    def ask(prompt, schema: nil, on_event: nil, &)
      chat = RubyLLM.chat(model: model).with_instructions(SYSTEM_PROMPT)
      chat.with_tools(*tools) if tools.any?
      chat.with_schema(schema) if schema.present?
      wire_callbacks(chat, on_event) if on_event.present?

      response = chat.ask(prompt, &)
      Ai::Controls.record(feature:, model:, response:)
      response
    rescue StandardError => error
      Rails.logger.warn("RubyLLM #{feature} request failed: #{error.class}: #{error.message}")
      Ai::Controls.record(feature:, model:, successful: false, error:)
      raise
    end

    private

    attr_reader :feature, :model, :tools

    def wire_callbacks(chat, on_event)
      current_tool_call = nil

      chat.before_tool_call do |tool_call|
        current_tool_call = tool_call
        on_event.call(type: "tool_call", tool_call:)
      end

      chat.after_tool_result do |result|
        on_event.call(type: "tool_result", tool_call: current_tool_call, result:)
      end
    end
  end
end
