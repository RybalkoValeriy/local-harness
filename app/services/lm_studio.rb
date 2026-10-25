require "net/http"
require "json"

# RubyLLM owns inference transport; AgentRunner owns project tool execution.
class LmStudio
  class Error < StandardError; end

  def self.model
    ENV.fetch("LM_STUDIO_MODEL", "qwen/qwen3.5-9b")
  end

  def self.base_url
    ENV.fetch("LM_STUDIO_URL", "http://127.0.0.1:1234/v1").delete_suffix("/")
  end

  def models
    req = Net::HTTP::Get.new(URI("#{self.class.base_url}/models"))
    req["Authorization"] = "Bearer #{ENV['LM_STUDIO_API_KEY']}" if ENV["LM_STUDIO_API_KEY"].present?
    response = Net::HTTP.start(req.uri.host, req.uri.port, use_ssl: req.uri.scheme == "https", open_timeout: 5, read_timeout: 10) { |http| http.request(req) }
    raise Error, "LM Studio returned HTTP #{response.code}. Check its server." unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body).fetch("data").map { |m| m.fetch("id") }
  rescue JSON::ParserError, KeyError => e
    raise Error, "LM Studio returned an invalid model list: #{e.message}"
  rescue IOError, SystemCallError, Timeout::Error, SocketError => e
    raise Error, "Cannot reach LM Studio at #{self.class.base_url}. Keep its server running. (#{e.class})"
  end

  def complete(messages:, tools: [], &on_event)
    chat = build_chat(tools: tools)
    messages.each { |message| chat.add_message(import_message(message)) }
    result = chat.generate do |chunk|
      on_event&.call("token", { text: chunk.content }) if chunk.content.present?
      on_event&.call("reasoning", { text: chunk.thinking.text }) if chunk.thinking&.text.present?
    end
    raise Error, "The model response was interrupted. Please retry." unless result.finish_reason
    raise Error, "The model reached its 4,096-token output limit. Try a smaller task." if result.finish_reason == :max_tokens
    raise Error, "The model could not complete this response (#{result.finish_reason})." unless %i[stop tool_calls].include?(result.finish_reason)
    {
      "role" => "assistant", "content" => result.content.to_s,
      "reasoning_content" => result.thinking&.text.to_s,
      "tool_calls" => (result.tool_calls || {}).values.map do |call|
        { "id" => call.id, "type" => "function", "function" => { "name" => call.name, "arguments" => JSON.generate(call.arguments) } }
      end
    }
  rescue RubyLLM::Error, Faraday::Error, JSON::ParserError => e
    raise Error, "LM Studio request failed (#{e.class.name}). Check the server/model and retry."
  end

  private

  def build_chat(tools:)
    # Per-request configuration avoids global endpoint/credential mutation.
    context = RubyLLM.context do |config|
      config.openai_api_base = self.class.base_url
      config.openai_api_key = ENV["LM_STUDIO_API_KEY"].presence || "lm-studio"
      config.openai_use_system_role = true
      config.request_timeout = 180
      config.max_retries = 0
    end
    context.chat(model: self.class.model, provider: :openai, protocol: :chat_completions, assume_model_exists: true)
      .with_temperature(0.6)
      .with_provider_options(top_p: 0.95, top_k: 20, min_p: 0.0, presence_penalty: 0.0, repeat_penalty: 1.0, max_tokens: 4096, tools: tools)
  end

  def import_message(message)
    attributes = { role: message.fetch("role"), content: message.fetch("content", "") }
    attributes[:tool_call_id] = message["tool_call_id"] if message["tool_call_id"]
    attributes[:thinking] = message["reasoning_content"] if message["reasoning_content"].present?
    if message["tool_calls"].present?
      attributes[:tool_calls] = message["tool_calls"].to_h do |call|
        function = call.fetch("function")
        [ call.fetch("id"), RubyLLM::ToolCall.new(id: call.fetch("id"), name: function.fetch("name"), arguments: JSON.parse(function.fetch("arguments"))) ]
      end
    end
    attributes
  end
end
