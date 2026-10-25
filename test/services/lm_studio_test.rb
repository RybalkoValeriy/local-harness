require "test_helper"
require "socket"

class LmStudioTest < ActiveSupport::TestCase
  # Exercise the actual RubyLLM HTTP/SSE implementation against a local fixture.
  def with_server(packets, status: 200)
    server = TCPServer.new("127.0.0.1", 0)
    previous_url = ENV["LM_STUDIO_URL"]
    ENV["LM_STUDIO_URL"] = "http://127.0.0.1:#{server.addr[1]}/v1"
    requests = Queue.new
    worker = Thread.new do
      socket = server.accept
      headers = +""
      headers << socket.read(1) until headers.end_with?("\r\n\r\n")
      body = socket.read(headers[/Content-Length: (\d+)/i, 1].to_i)
      requests << JSON.parse(body)
      stream = packets.map { |p| "data: #{p.to_json}\n\n" }.join + "data: [DONE]\n\n"
      socket.write("HTTP/1.1 #{status} Fixture\r\nContent-Type: text/event-stream\r\nContent-Length: #{stream.bytesize}\r\nConnection: close\r\n\r\n")
      stream.bytes.each_slice(7) { |bytes| socket.write(bytes.pack("C*")) }
    ensure
      socket&.close
    end
    yield requests
    worker.value
  ensure
    ENV["LM_STUDIO_URL"] = previous_url
    server&.close
    worker&.kill
    worker&.join
  end

  test "streams text reasoning and fragmented tool calls through RubyLLM" do
    packets = [
      { choices: [ { delta: { reasoning_content: "Inspecting", content: "Reading", tool_calls: [ { index: 0, id: "call_1", function: { name: "read_file", arguments: '{"pa' } } ] } } ] },
      { choices: [ { delta: { tool_calls: [ { index: 0, function: { arguments: 'th":"README.md"}' } } ] } } ] },
      { choices: [ { delta: {}, finish_reason: "tool_calls" } ] }
    ]
    with_server(packets) do |requests|
      events = []
      result = LmStudio.new.complete(messages: [ { "role" => "system", "content" => "Local only" }, { "role" => "user", "content" => "Read the file" } ], tools: WorkspaceTools.definitions) { |*event| events << event }
      assert_equal({ "path" => "README.md" }, JSON.parse(result["tool_calls"].first["function"]["arguments"]))
      assert_equal "call_1", result["tool_calls"].first["id"]
      assert_equal "Inspecting", result["reasoning_content"]
      assert_includes events, [ "token", { text: "Reading" } ]
      assert_includes events, [ "reasoning", { text: "Inspecting" } ]
      request = requests.pop
      assert_equal LmStudio.model, request["model"]
      assert_equal "system", request["messages"].first["role"]
      assert_equal 4096, request["max_tokens"]
      assert_equal 20, request["top_k"]
      assert_equal WorkspaceTools.definitions.as_json, request["tools"]
    end
  end

  test "replays persisted assistant calls and tool results" do
    packets = [ { choices: [ { delta: { content: "Done" }, finish_reason: "stop" } ] } ]
    with_server(packets) do |requests|
      messages = [
        { "role" => "user", "content" => "Read it" },
        { "role" => "assistant", "content" => "", "reasoning_content" => "Inspect", "tool_calls" => [ { "id" => "call_1", "function" => { "name" => "read_file", "arguments" => '{"path":"README.md"}' } } ] },
        { "role" => "tool", "tool_call_id" => "call_1", "content" => "File contents" }
      ]
      assert_equal "Done", LmStudio.new.complete(messages: messages)["content"]
      request = requests.pop
      assert_equal "call_1", request["messages"][1]["tool_calls"][0]["id"]
      assert_equal "call_1", request["messages"][2]["tool_call_id"]
      assert_equal "File contents", request["messages"][2]["content"]
    end
  end

  test "incomplete response is never accepted as successful" do
    with_server([ { choices: [ { delta: { content: "Partial" } } ] } ]) do
      assert_raises(LmStudio::Error) { LmStudio.new.complete(messages: []) }
    end
  end

  test "output truncation raises an actionable error" do
    with_server([ { choices: [ { delta: { content: "Partial" }, finish_reason: "length" } ] } ]) do
      error = assert_raises(LmStudio::Error) { LmStudio.new.complete(messages: []) }
      assert_match "output limit", error.message
    end
  end

  test "provider errors retain the application error boundary" do
    with_server([], status: 500) do
      assert_raises(LmStudio::Error) { LmStudio.new.complete(messages: []) }
    end
  end
end
