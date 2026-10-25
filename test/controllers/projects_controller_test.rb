require "test_helper"
require "tmpdir"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "registers a project and scopes its conversations" do
    Dir.mktmpdir do |directory|
      post projects_path, params: { project: { name: "AAA", path: directory, mode: "existing" } }
      project = Project.find_by!(path: File.realpath(directory))
      assert_redirected_to project_path(project)
      follow_redirect!
      assert_select "section.workspace-strip", text: /AAA/
      post project_conversations_path(project)
      conversation = project.conversations.sole
      assert_redirected_to project_conversation_path(project, conversation)
      follow_redirect!
      assert_select "textarea#prompt"
      other = Project.legacy_workspace
      get project_conversation_path(other, conversation)
      assert_response :not_found
      post run_project_conversation_path(other, conversation), params: { prompt: "hello" }
      assert_response :not_found
    end
  end

  test "invalid paths render actionable errors and unavailable projects remain visible" do
    post projects_path, params: { project: { name: "Incomplete form" } }
    assert_response :unprocessable_entity
    post projects_path, params: { project: { name: "Bad", path: "relative", mode: "existing" } }
    assert_response :unprocessable_entity
    assert_select '[role="alert"]', text: /absolute/
    assert_select '#existing_path[value="relative"]'
    assert_select "#new_path" do |inputs|
      assert_nil inputs.first["value"]
    end
    project = Project.create!(name: "Unavailable", path: "/missing-project-path")
    get project_path(project)
    assert_response :success
    assert_select '[role="alert"]', text: /unavailable/
  end

  test "legacy conversation URLs redirect to their project without losing messages" do
    conversation = Conversation.create!
    conversation.messages.create!(role: "user", content: "saved message")
    get conversation_path(conversation)
    assert_redirected_to project_conversation_path(conversation.project, conversation)
    follow_redirect!
    assert_select ".message-content", text: "saved message"
  end
end
