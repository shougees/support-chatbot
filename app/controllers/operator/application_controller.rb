module Operator
  class ApplicationController < ::ApplicationController
    before_action :require_operator_user
    helper_method :current_operator_user

    private

    def current_operator_user
      @current_operator_user ||= OperatorUser.find_by(id: session[:operator_user_id])
    end

    def require_operator_user
      return if current_operator_user.present?

      if OperatorUser.exists?
        redirect_to operator_sign_in_path, alert: "Sign in to use the operator workspace."
      else
        redirect_to root_path, alert: "Create an operator user before using the operator workspace."
      end
    end
  end
end
