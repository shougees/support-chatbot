module Operator
  class ApplicationController < ::ApplicationController
    before_action :require_operator_user
    helper_method :current_operator_user

    private

    def current_operator_user
      @current_operator_user ||= OperatorUser.order(:email).first
    end

    def require_operator_user
      return if current_operator_user.present?

      redirect_to root_path, alert: "Create an operator user before using the operator workspace."
    end
  end
end
