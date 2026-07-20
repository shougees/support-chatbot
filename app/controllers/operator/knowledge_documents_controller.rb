module Operator
  class KnowledgeDocumentsController < ApplicationController
    before_action :set_knowledge_document, only: [ :edit, :update ]

    def index
      @knowledge_documents = KnowledgeDocument.order(updated_at: :desc, title: :asc)
    end

    def new
      @knowledge_document = KnowledgeDocument.new
    end

    def create
      @knowledge_document = KnowledgeDocument.new(knowledge_document_params)

      if @knowledge_document.save
        redirect_to operator_knowledge_documents_path, notice: "Knowledge document created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @knowledge_document.update(knowledge_document_params)
        redirect_to operator_knowledge_documents_path, notice: "Knowledge document updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_knowledge_document
      @knowledge_document = KnowledgeDocument.find(params[:id])
    end

    def knowledge_document_params
      params.require(:knowledge_document).permit(
        :title,
        :category,
        :body,
        :source_type,
        :source_identifier,
        :status
      )
    end
  end
end
