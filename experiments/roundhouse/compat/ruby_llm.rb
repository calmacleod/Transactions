# The declarative Tool surface used by the app. Keep the metadata rather
# than discarding the class-body calls during native boot.
module RubyLLM
  class Parameter
    attr_reader :name, :type, :description, :required

    def initialize(name, type: 'string', description: nil, required: true)
      @name = name
      @type = type
      @description = description
      @required = required
    end
  end

  class Tool
    def self.description(text = nil)
      @description = text if text
      @description
    end

    def self.parameter(name, type: 'string', description: nil, required: true)
      declared_parameters[name] = Parameter.new(name, type: type, description: description, required: required)
    end

    def self.declared_parameters
      @declared_parameters ||= {}
    end
  end
end

module RubyLLM
  class Configuration
    attr_reader :default_model
    def initialize
      @default_model = ENV.fetch('RUBYLLM_MODEL', 'gpt-5-nano')
    end
  end

  class Model
    def initialize(pricing: {})
      @pricing = pricing
    end

    def price(kind)
      column = case kind
      when :input then 'input_per_million'
      when :output then 'output_per_million'
      when :cache_read then 'cache_read_input_per_million'
      when :cache_write then 'cache_write_input_per_million'
      else raise ArgumentError, "Unknown price kind: #{kind}"
      end
      text = @pricing['text_tokens'] || @pricing[:text_tokens] || {}
      standard = text['standard'] || text[:standard] || {}
      standard[column] || standard[column.to_sym]
    end
  end

  class RegistryModel
    def initialize(row)
      @row = row
    end
    def id
      @row['id']
    end
    def provider
      @row['provider']
    end
    def name
      @row['name']
    end
    def family
      @row['family']
    end
    def created_at
      @row['created_at']
    end
    def context_window
      @row['context_window']
    end
    def max_output_tokens
      @row['max_output_tokens']
    end
    def knowledge_cutoff
      value = @row['knowledge_cutoff']
      return nil if value.nil?
      value.to_s.length == 7 ? value.to_s + '-01' : value
    end
    def modalities
      @row['modalities'] || {}
    end
    def capabilities
      @row['capabilities'] || []
    end
    def pricing
      @row['pricing'] || {}
    end
    def metadata
      @row['metadata'] || {}
    end
  end

  class Registry
    def initialize
      @rows = []
    end
    def load_from_json
      @rows = JSON.parse(File.read('config/ruby_llm_models.json'))
      self
    end
    def map
      @rows.map { |row| yield RegistryModel.new(row) }
    end
  end

  CONFIGURATION = Configuration.new
  REGISTRY = Registry.new
  def self.config
    CONFIGURATION
  end
  def self.models
    REGISTRY
  end
end

# Native transport for the text, JSON Schema and tool calls this app uses.
# Provider requests have finite timeouts and a bounded tool-call loop. The
# provider keys remain in the environment; no transaction data is logged.
require 'net/http'

module RubyLLM
  class NativeTokens
    attr_reader :input, :output
    def initialize(input, output)
      @input = input
      @output = output
    end
  end

  class NativeResponse
    attr_reader :content, :tokens
    def initialize(content, input, output)
      @content = content
      @tokens = NativeTokens.new(input, output)
    end
    def parsed
      JSON.parse(content)
    end
  end

  class NativeToolCall
    attr_reader :id, :name, :arguments
    def initialize(id, name, arguments)
      @id = id
      @name = name
      @arguments = arguments
    end
  end

  module NativeTransport
    def self.request(url, headers, payload = nil)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 10
      http.read_timeout = 60
      request = payload.nil? ? Net::HTTP::Get.new(uri.request_uri) : Net::HTTP::Post.new(uri.request_uri)
      headers.each { |key, value| request[key] = value }
      request['Accept'] = 'application/json'
      request['Accept-Encoding'] = 'identity'
      unless payload.nil?
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(payload)
      end
      response = http.request(request)
      raise "Provider HTTP #{response.code}" unless response.code.to_i.between?(200, 299)
      raise 'Provider response exceeds 4 MiB' if response.body.bytesize > 4 * 1024 * 1024
      JSON.parse(response.body)
    end
  end

  class NativeChat
    def initialize(model, provider)
      @model = model
      @provider = provider
      @instructions = ''
      @tools = []
      @schema = nil
      @before = nil
      @after = nil
    end
    def with_instructions(text)
      @instructions = text
      self
    end
    def with_tools(*tools)
      @tools = tools
      self
    end
    def with_schema(schema)
      @schema = schema.json_schema
      self
    end
    def before_tool_call(&block)
      @before = block
      self
    end
    def after_tool_result(&block)
      @after = block
      self
    end

    def tool_definitions
      definitions = JSON.parse(File.read('config/native_tools.json'))
      @tools.map { |tool| definitions.fetch(tool.name) }
    end

    def execute_tool(call)
      tool = @tools.find { |candidate| candidate.name == call.name }
      raise 'Provider requested an unregistered tool' unless tool
      @before.call(call) if @before
      args = call.arguments
      # These methods are emitted with the positional ABI by Roundhouse.
      result = case call.name
      when 'search_transactions' then Ai::Tools::SearchTransactionsTool.new.execute(args)
      when 'budget_summary' then Ai::Tools::BudgetSummaryTool.new.execute(month: args['month'])
      when 'spending_summary' then Ai::Tools::SpendingSummaryTool.new.execute(start_date: args['start_date'], end_date: args['end_date'])
      else raise 'Unknown native tool'
      end
      @after.call(result) if @after
      JSON.generate(NativeInertia.resolve(result))
    end

    def ask(prompt, &block)
      result = case @provider
      when 'openai' then ask_openai(prompt)
      when 'anthropic' then ask_anthropic(prompt)
      when 'gemini' then ask_gemini(prompt)
      else raise ArgumentError, 'Unsupported native provider: ' + @provider
      end
      block.call(result) if block
      result
    end

    def ask_openai(prompt)
      input = [{ 'role' => 'user', 'content' => prompt }]
      endpoint = ENV.fetch('OPENAI_API_BASE', 'https://api.openai.com/v1').delete_suffix('/') + '/responses'
      headers = { 'Authorization' => 'Bearer ' + ENV.fetch('OPENAI_API_KEY') }
      incoming = 0
      outgoing = 0
      8.times do
        payload = { 'model' => @model, 'instructions' => @instructions, 'input' => input }
        payload['tools'] = tool_definitions.map { |tool| tool.merge('type' => 'function') } unless @tools.empty?
        payload['text'] = { 'format' => { 'type' => 'json_schema', 'name' => 'transactions_output', 'schema' => @schema, 'strict' => true } } if @schema
        response = NativeTransport.request(endpoint, headers, payload)
        usage = response['usage'] || {}
        incoming += usage.fetch('input_tokens', 0).to_i
        outgoing += usage.fetch('output_tokens', 0).to_i
        output = response.fetch('output')
        calls = output.select { |item| item['type'] == 'function_call' }
        if calls.empty?
          text = output.select { |item| item['type'] == 'message' }.flat_map { |item| item.fetch('content', []) }
            .select { |item| item['type'] == 'output_text' }.map { |item| item.fetch('text') }.join
          raise 'Provider returned no text' if text.empty?
          return NativeResponse.new(text, incoming, outgoing)
        end
        input.concat(output)
        calls.each do |item|
          call = NativeToolCall.new(item.fetch('call_id'), item.fetch('name'), JSON.parse(item.fetch('arguments')))
          input << { 'type' => 'function_call_output', 'call_id' => call.id, 'output' => execute_tool(call) }
        end
      end
      raise 'Provider tool-call limit exceeded'
    end

    def ask_anthropic(prompt)
      messages = [{ 'role' => 'user', 'content' => prompt }]
      endpoint = ENV.fetch('ANTHROPIC_API_BASE', 'https://api.anthropic.com/v1').delete_suffix('/') + '/messages'
      headers = { 'x-api-key' => ENV.fetch('ANTHROPIC_API_KEY'), 'anthropic-version' => '2023-06-01' }
      incoming = 0
      outgoing = 0
      8.times do
        payload = { 'model' => @model, 'system' => @instructions, 'max_tokens' => 4096, 'messages' => messages }
        payload['tools'] = tool_definitions.map { |tool| { 'name' => tool['name'], 'description' => tool['description'], 'input_schema' => tool['parameters'] } } unless @tools.empty?
        payload['output_config'] = { 'format' => { 'type' => 'json_schema', 'schema' => @schema } } if @schema
        response = NativeTransport.request(endpoint, headers, payload)
        usage = response['usage'] || {}
        incoming += usage.fetch('input_tokens', 0).to_i
        outgoing += usage.fetch('output_tokens', 0).to_i
        content = response.fetch('content')
        calls = content.select { |item| item['type'] == 'tool_use' }
        if calls.empty?
          text = content.select { |item| item['type'] == 'text' }.map { |item| item.fetch('text') }.join
          raise 'Provider returned no text' if text.empty?
          return NativeResponse.new(text, incoming, outgoing)
        end
        messages << { 'role' => 'assistant', 'content' => content }
        results = calls.map do |item|
          call = NativeToolCall.new(item.fetch('id'), item.fetch('name'), item.fetch('input'))
          { 'type' => 'tool_result', 'tool_use_id' => call.id, 'content' => execute_tool(call) }
        end
        messages << { 'role' => 'user', 'content' => results }
      end
      raise 'Provider tool-call limit exceeded'
    end

    def ask_gemini(prompt)
      contents = [{ 'role' => 'user', 'parts' => [{ 'text' => prompt }] }]
      endpoint = ENV.fetch('GEMINI_API_BASE', 'https://generativelanguage.googleapis.com/v1beta').delete_suffix('/') + '/models/' + @model + ':generateContent'
      headers = { 'x-goog-api-key' => ENV.fetch('GEMINI_API_KEY') }
      incoming = 0
      outgoing = 0
      8.times do
        payload = { 'contents' => contents, 'systemInstruction' => { 'parts' => [{ 'text' => @instructions }] } }
        payload['tools'] = [{ 'functionDeclarations' => tool_definitions }] unless @tools.empty?
        payload['generationConfig'] = { 'responseMimeType' => 'application/json', 'responseJsonSchema' => @schema } if @schema
        response = NativeTransport.request(endpoint, headers, payload)
        usage = response['usageMetadata'] || {}
        incoming += usage.fetch('promptTokenCount', 0).to_i
        outgoing += usage.fetch('candidatesTokenCount', 0).to_i
        content = response.fetch('candidates')[0].fetch('content')
        parts = content.fetch('parts')
        calls = parts.select { |part| part.key?('functionCall') }
        if calls.empty?
          text = parts.select { |part| part.key?('text') && !part['thought'] }.map { |part| part.fetch('text') }.join
          raise 'Provider returned no text' if text.empty?
          return NativeResponse.new(text, incoming, outgoing)
        end
        contents << content
        results = calls.map do |part|
          item = part.fetch('functionCall')
          call = NativeToolCall.new(item.fetch('id', SecureRandom.uuid), item.fetch('name'), item.fetch('args'))
          { 'functionResponse' => { 'name' => call.name, 'response' => JSON.parse(execute_tool(call)) } }
        end
        contents << { 'role' => 'user', 'parts' => results }
      end
      raise 'Provider tool-call limit exceeded'
    end
  end

  def self.chat(model:, provider:)
    NativeChat.new(model, provider)
  end

  class Registry
    def refresh
      rows = NativeTransport.request('https://rubyllm.com/models.json', {})
      raise 'Invalid model registry response' unless rows.is_a?(Array)
      File.write('config/ruby_llm_models.json', JSON.generate(rows))
      @rows = rows
      self
    end
  end
end
