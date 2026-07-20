require "test_helper"

class OperatorAnalyticsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_operator
  end

  test "operator can view support analytics" do
    get operator_analytics_url

    assert_response :success
    assert_select "h1", text: "Support analytics"
    assert_select "dt", text: "Total conversations"
    assert_select "dd", text: Conversation.count.to_s
    assert_select "dt", text: "Escalated conversations"
    assert_select "dt", text: "Escalation rate"
    assert_select "dt", text: "Helpfulness rate"
    assert_select "h2", text: "Top detected categories"
    assert_select "h2", text: "Needs attention"
    assert_select "a[href='#{operator_conversation_path(conversations(:open_conversation).public_id)}']"
  end

  test "analytics requires operator authentication" do
    delete operator_session_url

    get operator_analytics_url

    assert_redirected_to operator_sign_in_url
  end
end
