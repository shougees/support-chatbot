module Operator
  class ResponseDraftsController < ApplicationController
    before_action :set_response_draft

    def approve
      @response_draft.publish_approved!(operator_user: current_operator_user)
      redirect_to operator_conversation_path(@response_draft.conversation.public_id), notice: "Draft approved and published."
    rescue ActiveRecord::RecordInvalid => error
      redirect_with_publication_error(error)
    end

    def publish_edit
      @response_draft.publish_edited!(operator_user: current_operator_user, body: response_draft_params[:body])
      redirect_to operator_conversation_path(@response_draft.conversation.public_id), notice: "Edited draft published."
    rescue ActiveRecord::RecordInvalid => error
      redirect_with_publication_error(error)
    end

    def replace
      @response_draft.publish_replacement!(operator_user: current_operator_user, body: response_draft_params[:body])
      redirect_to operator_conversation_path(@response_draft.conversation.public_id), notice: "Replacement reply sent."
    rescue ActiveRecord::RecordInvalid => error
      redirect_with_publication_error(error)
    end

    private

    def set_response_draft
      @response_draft = ResponseDraft.find(params[:id])
    end

    def response_draft_params
      params.require(:response_draft).permit(:body)
    end

    def redirect_with_publication_error(error)
      redirect_to operator_conversation_path(@response_draft.conversation.public_id), alert: error.record.errors.full_messages.to_sentence
    end
  end
end
