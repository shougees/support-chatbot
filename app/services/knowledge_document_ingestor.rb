class KnowledgeDocumentIngestor
  Result = Struct.new(:document, :success, :error_message, keyword_init: true) do
    def success?
      success
    end
  end

  DISABLED_SOURCE_MESSAGES = {
    "upload" => "Upload ingestion is not implemented yet.",
    "url" => "URL ingestion is not implemented yet.",
    "reddit" => "Reddit ingestion is not implemented yet."
  }.freeze

  def self.call(document)
    new(document).call
  end

  def initialize(document)
    @document = document
  end

  def call
    document.with_lock do
      return mark_failed!("Manual source body is blank.") if document.source_type == "manual" && document.body.to_s.strip.blank?

      mark_processing!

      case document.source_type
      when "manual"
        ingest_manual!
      when *DISABLED_SOURCE_MESSAGES.keys
        mark_failed!(DISABLED_SOURCE_MESSAGES.fetch(document.source_type), disabled: true)
      else
        mark_failed!("Unsupported source type: #{document.source_type}")
      end
    end
  rescue StandardError => error
    mark_failed!(error.message, error_class: error.class.name)
  end

  private

  attr_reader :document

  def ingest_manual!
    extracted_text = document.body.to_s.strip
    return mark_failed!("Manual source body is blank.") if extracted_text.blank?

    document.update!(
      extracted_text: extracted_text,
      status: "active",
      metadata: metadata_with(
        ingestion: {
          status: "completed",
          source_type: document.source_type,
          completed_at: Time.current.iso8601
        }
      ).to_json
    )

    Result.new(document: document, success: true)
  end

  def mark_processing!
    document.update!(
      status: "processing",
      metadata: metadata_with(
        ingestion: {
          status: "processing",
          source_type: document.source_type,
          started_at: Time.current.iso8601
        }
      ).to_json
    )
  end

  def mark_failed!(message, disabled: false, error_class: nil)
    document.reload unless document.persisted? && document.has_changes_to_save?
    document.update!(
      status: "failed",
      metadata: metadata_with(
        ingestion: {
          status: "failed",
          source_type: document.source_type,
          failed_at: Time.current.iso8601,
          error: message,
          error_class: error_class,
          disabled: disabled
        }.compact
      ).to_json
    )

    Result.new(document: document, success: false, error_message: message)
  end

  def metadata_with(attributes)
    document.metadata_hash.deep_merge(attributes.deep_stringify_keys)
  end
end
