module Operator
  class EscalationsController < ApplicationController
    before_action :set_escalation

    def update
      @escalation.update_status!(
        status: escalation_params[:status],
        operator_user: current_operator_user
      )

      redirect_to operator_conversation_path(@escalation.conversation.public_id), notice: "Escalation updated."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to operator_conversation_path(@escalation.conversation.public_id), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def set_escalation
      @escalation = Escalation.find(params[:id])
    end

    def escalation_params
      params.require(:escalation).permit(:status)
    end
  end
end
