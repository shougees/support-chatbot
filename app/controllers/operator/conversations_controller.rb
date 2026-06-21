module Operator
  class ConversationsController < ApplicationController
    def show
      @conversation = Conversation.find_by!(public_id: params[:public_id])
      @direct_message = Message.new
    end
  end
end
