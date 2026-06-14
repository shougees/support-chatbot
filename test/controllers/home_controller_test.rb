require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get root page" do
    get root_url
    assert_response :success
    assert_match "Support Chatbot", @response.body
    assert_match "Start support conversation", @response.body
  end
end
