require "test_helper"

class OperatorKnowledgeDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_operator
  end

  test "operator can list knowledge documents" do
    get operator_knowledge_documents_url

    assert_response :success
    assert_select "h1", text: "Knowledge documents"
    assert_select "td", text: /Refund Policy/
    assert_select "span", text: "Active"
    assert_select "a[href='#{edit_operator_knowledge_document_path(knowledge_documents(:refund_policy))}']", text: "Edit"
  end

  test "operator can create an active knowledge document available for retrieval" do
    assert_difference("KnowledgeDocument.count", 1) do
      post operator_knowledge_documents_url, params: {
        knowledge_document: {
          title: "Damaged Item Policy",
          category: "damaged items",
          body: "Customers can request a replacement when an item arrives cracked.",
          source_type: "manual",
          source_identifier: "policy/damaged-items",
          status: "active"
        }
      }
    end

    document = KnowledgeDocument.order(:created_at).last

    assert_redirected_to operator_knowledge_documents_url
    assert_includes KnowledgeDocumentKeywordRetriever.call(question: "My item arrived cracked").map(&:document), document
  end

  test "operator can edit and archive a knowledge document" do
    document = knowledge_documents(:refund_policy)

    patch operator_knowledge_document_url(document), params: {
      knowledge_document: {
        title: "Archived Refund Policy",
        category: document.category,
        body: document.body,
        source_type: document.source_type,
        source_identifier: document.source_identifier,
        status: "archived"
      }
    }

    assert_redirected_to operator_knowledge_documents_url
    assert_equal "Archived Refund Policy", document.reload.title
    assert_equal "archived", document.status
    assert_not_includes KnowledgeDocumentKeywordRetriever.call(question: "refund missing order").map(&:document), document
  end

  test "operator sees clear validation errors" do
    assert_no_difference("KnowledgeDocument.count") do
      post operator_knowledge_documents_url, params: {
        knowledge_document: {
          title: "",
          category: "returns",
          body: "",
          source_type: "manual",
          status: "draft"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "p", text: "Please fix the following:"
    assert_select "li", text: "Title can't be blank"
    assert_select "li", text: "body or extracted text must be present"
  end

  test "knowledge document management requires operator authentication" do
    delete operator_session_url

    get operator_knowledge_documents_url

    assert_redirected_to operator_sign_in_url
    assert_equal "Sign in to use the operator workspace.", flash[:alert]
  end
end
