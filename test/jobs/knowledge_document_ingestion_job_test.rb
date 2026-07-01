require "test_helper"

class KnowledgeDocumentIngestionJobTest < ActiveJob::TestCase
  test "processes a knowledge document asynchronously" do
    document = KnowledgeDocument.create!(
      title: "Manual Warranty Policy",
      source_type: "manual",
      source_identifier: "manual/warranty",
      category: "returns",
      body: "Warranty claims require order context.",
      status: "draft"
    )

    assert_enqueued_with(job: KnowledgeDocumentIngestionJob, args: [ document ]) do
      document.ingest_later
    end

    perform_enqueued_jobs

    assert_equal "active", document.reload.status
    assert_equal "Warranty claims require order context.", document.extracted_text
  end
end
