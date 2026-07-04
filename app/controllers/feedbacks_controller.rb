class FeedbacksController < ApplicationController
  before_action :set_conversation
  before_action :set_message

  def create
    feedback = @message.feedbacks.first_or_initialize
    feedback.assign_attributes(feedback_params)

    if feedback.save
      redirect_to conversation_path(@conversation.public_id), notice: "Thanks for the feedback."
    else
      redirect_to conversation_path(@conversation.public_id), alert: feedback.errors.full_messages.to_sentence
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find_by!(public_id: params[:conversation_public_id])
  end

  def set_message
    @message = @conversation.messages.support_messages.find(params[:message_id])
  end

  def feedback_params
    params.require(:feedback).permit(:rating, :note)
  end
end
