require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  test "the import map serves the compiled TypeScript application" do
    get root_path
    imports = JSON.parse(css_select('script[type="importmap"]').first.text).fetch("imports")
    get imports.fetch("application")
    assert_response :success
    assert_includes response.body, "chat_controller.ts"
    assert_includes response.body, 'application.register("chat",'
  end

  test "home renders and a new conversation can be created" do
    get root_path
    assert_response :success
    assert_select "h1", "Your projects"
    assert_difference("Conversation.count", 1) { post conversations_path }
    assert_response :see_other
    follow_redirect!
    assert_response :success
    assert_select "textarea#prompt"
  end
end
