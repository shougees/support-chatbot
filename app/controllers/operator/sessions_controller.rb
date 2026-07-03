module Operator
  class SessionsController < ::ApplicationController
    def new
      return if OperatorUser.exists?

      redirect_to root_path, alert: "Create an operator user before using the operator workspace."
    end

    def create
      operator_user = OperatorUser.find_by(email: session_params[:email].to_s.downcase)

      if operator_user&.authenticate(session_params[:password])
        session[:operator_user_id] = operator_user.id
        redirect_to root_path, notice: "Signed in as operator."
      else
        flash.now[:alert] = "Email or password is invalid."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      session.delete(:operator_user_id)
      redirect_to root_path, notice: "Signed out."
    end

    private

    def session_params
      params.require(:operator_session).permit(:email, :password)
    end
  end
end
