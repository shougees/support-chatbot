class MessagesController < ApplicationController
  def create
    @conversation = Conversation.find_by!(public_id: params[:conversation_public_id])
    @conversation.publish_customer_message!(body: message_params[:body])

    redirect_to conversation_path(@conversation.public_id)
  rescue ActiveRecord::RecordInvalid => error
    @message = error.record
    @messages = @conversation.customer_visible_messages
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render "conversations/show", status: :unprocessable_entity
  end

  private

  def message_params
    params.require(:message).permit(:body)
  end
end
