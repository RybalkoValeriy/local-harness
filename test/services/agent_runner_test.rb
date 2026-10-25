require "test_helper"
require "tmpdir"

class AgentRunnerTest < ActiveSupport::TestCase
  test "continues beyond former step tool and context byte budgets" do
    conversation = Conversation.create!
    client = Object.new
    requests = []
    client.define_singleton_method(:complete) do |messages:, tools:, &block|
      requests << Marshal.load(Marshal.dump(messages))
      if requests.length <= 14
        { "role" => "assistant", "content" => "", "tool_calls" => [ { "id" => "call_#{requests.length}", "function" => { "name" => "list_files", "arguments" => "{}" } } ] }
      else
        { "role" => "assistant", "content" => "Complete", "tool_calls" => [] }
      end
    end
    tools = Object.new
    tools.define_singleton_method(:call) { |name, arguments| { content: "x" * 2000 } }
    events = []
    AgentRunner.new(conversation, client: client, tools: tools).run("Do the whole task") { |type, data| events << [ type, data ] }
    assert_equal 15, requests.length
    assert_equal 14, conversation.messages.where(role: "tool").count
    assert conversation.messages.where(role: "tool").all? { |message| JSON.parse(message.content)["content"] == "x" * 2000 }
    assert_equal({ number: 15 }, events.select { |type, _| type == "step" }.last.last)
    assert_equal "done", events.last.first

    # A subsequent prompt keeps the complete successful turn even above 18KB.
    AgentRunner.new(conversation, client: client, tools: tools).run("Continue") { }
    assert_equal 14, requests.last.count { |message| message["role"] == "tool" }
    assert requests.last.to_json.bytesize > 28_000
  end

  class FakeClient
    attr_reader :requests
    def initialize
      @requests = []
    end
    def complete(messages:, tools:)
      @requests << Marshal.load(Marshal.dump(messages))
      if @requests.length == 1
        { "role" => "assistant", "content" => "", "tool_calls" => [ { "id" => "call_1", "type" => "function", "function" => { "name" => "read_file", "arguments" => '{"path":"README.md"}' } } ] }
      else
        yield "token", { text: "This is a local agent workspace." }
        { "role" => "assistant", "content" => "This is a local agent workspace.", "tool_calls" => [] }
      end
    end
  end
  test "executes a tool, feeds its result back, and saves the conversation" do
    conversation = Conversation.create!
    client = FakeClient.new
    events = []
    AgentRunner.new(conversation, client: client).run("Read README.md") { |type, data| events << [ type, data ] }
    assert_equal %w[user assistant tool assistant], conversation.messages.pluck(:role)
    assert_equal "tool", client.requests.last.last["role"]
    assert_includes client.requests.last.last["content"], "My first local agent"
    assert_equal "done", events.last.first
  end
  test "empty prompts never reach the model" do
    assert_raises(ArgumentError) { AgentRunner.new(Conversation.create!).run(" ") { } }
  end

  test "model file changes are executed and persisted in the selected project" do
    Dir.mktmpdir do |directory|
      project = ProjectRegistration.call(name: "Writable project", path: directory, mode: "existing")
      conversation = project.conversations.create!
      client = Object.new
      responses = [
        { "role" => "assistant", "content" => "", "tool_calls" => [ { "id" => "write_1", "function" => { "name" => "create_file", "arguments" => { path: "notes/plan.md", content: "Initial plan" }.to_json } } ] },
        { "role" => "assistant", "content" => "", "tool_calls" => [ { "id" => "edit_1", "function" => { "name" => "edit_file", "arguments" => { path: "notes/plan.md", old_text: "Initial", new_text: "Updated" }.to_json } } ] },
        { "role" => "assistant", "content" => "Created and updated the plan.", "tool_calls" => [] }
      ]
      client.define_singleton_method(:complete) { |messages:, tools:, &block| responses.shift }
      events = []
      AgentRunner.new(conversation, client: client).run("Create and update a plan") { |type, data| events << [ type, data ] }
      assert_equal "Updated plan", File.read(File.join(directory, "notes/plan.md"))
      assert_equal %w[create_file edit_file], conversation.messages.where(role: "tool").map { |message| message.metadata["name"] }
      assert_equal %w[created edited], conversation.messages.where(role: "tool").map { |message| JSON.parse(message.content)["action"] }
      assert_equal "done", events.last.first
    end
  end

  test "tool results use the conversation project without leaking another project" do
    Dir.mktmpdir do |parent|
      projects = %w[AAA BBB].map do |name|
        directory = File.join(parent, name)
        Dir.mkdir(directory)
        File.write(File.join(directory, "README.md"), "Only #{name}")
        ProjectRegistration.call(name: name, path: directory, mode: "existing")
      end
      projects.each do |project|
        client = FakeClient.new
        AgentRunner.new(project.conversations.create!, client: client).run("Read README.md") { }
        assert_includes client.requests.last.last.fetch("content"), "Only #{project.name}"
        assert_not_includes client.requests.last.last.fetch("content"), "Only #{project == projects.first ? 'BBB' : 'AAA'}"
      end
    end
  end
end
