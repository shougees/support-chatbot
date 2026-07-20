class UploadsController < ApplicationController
  before_action :set_upload_request

  def create
    file = upload_params[:file]
    upload = @conversation.uploads.build(
      message: @request_message,
      file_type: file_type_for(file),
      processing_status: "pending"
    )
    upload.file.attach(file) if file.present?

    if file.blank?
      redirect_to conversation_path(@conversation.public_id), alert: "Choose a file to upload."
    elsif upload.save
      redirect_to conversation_path(@conversation.public_id), notice: "Upload received."
    else
      redirect_to conversation_path(@conversation.public_id), alert: upload.errors.full_messages.to_sentence
    end
  end

  private

  def set_upload_request
    @conversation = Conversation.find_by!(public_id: params[:conversation_public_id])
    @request_message = @conversation.messages.support_messages.find(params[:message_id])
    @response_draft = @request_message.response_draft
    latest_support_message = @conversation.messages.support_messages.chronological.last

    raise ActiveRecord::RecordNotFound unless @response_draft&.upload_requested? && @request_message == latest_support_message
  end

  def upload_params
    params.fetch(:upload, {}).permit(:file)
  end

  def file_type_for(file)
    return @response_draft.upload_type unless @response_draft.upload_type == "either"
    return "other" if file.blank?

    Upload::IMAGE_CONTENT_TYPES.include?(file.content_type) ? "image" : "document"
  end
end
