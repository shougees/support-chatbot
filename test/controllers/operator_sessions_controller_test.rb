require "test_helper"

class OperatorSessionsControllerTest < ActionDispatch::IntegrationTest
  test "operator can sign in" do
    operator = operator_users(:alice)

    post operator_session_url, params: {
      operator_session: {
        email: operator.email.upcase,
        password: "password"
      }
    }

    assert_redirected_to root_url
    assert_equal "Signed in as operator.", flash[:notice]

    get operator_conversation_url(conversations(:open_conversation).public_id)

    assert_response :success
  end

  test "operator cannot sign in with invalid password" do
    post operator_session_url, params: {
      operator_session: {
        email: operator_users(:alice).email,
        password: "wrong"
      }
    }

    assert_response :unprocessable_entity
    assert_equal "Email or password is invalid.", flash[:alert]
  end

  test "operator can sign out" do
    sign_in_operator

    delete operator_session_url

    assert_redirected_to root_url
    assert_equal "Signed out.", flash[:notice]

    get operator_conversation_url(conversations(:open_conversation).public_id)

    assert_redirected_to operator_sign_in_url
  end

  test "sign in page redirects when no local operator exists" do
    without_operator_users do
      get operator_sign_in_url
    end

    assert_redirected_to root_url
    assert_equal "Create an operator user before using the operator workspace.", flash[:alert]
  end

  private

  def without_operator_users
    ResponseReview.update_all(operator_user_id: nil)
    Escalation.update_all(operator_user_id: nil)
    OperatorUser.delete_all
    yield
  end
end
