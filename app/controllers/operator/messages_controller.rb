module Operator
  class MessagesController < ApplicationController
    def create
      @conversation = Conversation.find_by!(public_id: params[:conversation_public_id])
      @conversation.publish_support_message!(
        body: message_params[:body],
        origin: "operator_direct",
        author: current_operator_user,
        published_by: current_operator_user
      )

      redirect_to operator_conversation_path(@conversation.public_id), notice: "Support reply sent."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to operator_conversation_path(@conversation.public_id), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def message_params
      params.require(:message).permit(:body)
    end
  end
end
