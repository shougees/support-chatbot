class KnowledgeDocumentKeywordRetriever
  DEFAULT_LIMIT = 3

  Result = Struct.new(:document, :score, keyword_init: true)

  def self.call(question:, limit: nil)
    new(question:, limit: limit || default_limit).call
  end

  def self.default_limit
    ENV.fetch("KNOWLEDGE_RETRIEVAL_LIMIT", DEFAULT_LIMIT).to_i
  end

  def initialize(question:, limit:, scope: KnowledgeDocument.retrievable)
    @question = question.to_s
    @limit = [ limit.to_i, 0 ].max
    @scope = scope
  end

  def call
    return [] if limit.zero? || terms.empty?

    matching_scope.filter_map do |document|
      score = keyword_score(document)
      Result.new(document:, score:) if score.positive?
    end.sort_by { |result| [ -result.score, result.document.id ] }.first(limit)
  end

  private

  attr_reader :question, :limit, :scope

  def keyword_score(document)
    terms.sum do |term|
      score = 0
      score += 3 if text_for(document.title).include?(term)
      score += 3 if text_for(document.category).include?(term)
      score += 2 if metadata_tags(document).any? { |tag| tag.include?(term) }
      score += 1 if text_for(document.body).include?(term)
      score += 1 if text_for(document.extracted_text).include?(term)
      score
    end
  end

  def matching_scope
    conditions = terms.each_with_index.map do |term, index|
      placeholder = :"term_#{index}"
      term_matches[placeholder] = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"

      searchable_columns.map do |column|
        "LOWER(COALESCE(#{column}, '')) LIKE :#{placeholder}"
      end.join(" OR ")
    end

    scope.where(conditions.map { |condition| "(#{condition})" }.join(" OR "), term_matches)
  end

  def searchable_columns
    %w[title category body extracted_text metadata]
  end

  def term_matches
    @term_matches ||= {}
  end

  def document_text(document)
    [
      document.title,
      document.category,
      document.body,
      document.extracted_text,
      metadata_tags(document).join(" ")
    ].compact.join(" ").downcase
  end

  def terms
    @terms ||= (base_terms + intent_terms).uniq
  end

  def base_terms
    question.downcase.scan(/[a-z0-9]+/).reject { |term| term.length < 4 }
  end

  def intent_terms
    normalized_question = question.downcase
    terms = []
    terms.concat(%w[delivery tracking package missing delayed]) if delivery_intent?(normalized_question)
    terms
  end

  def delivery_intent?(normalized_question)
    normalized_question.match?(/\b(where|track|tracking|status|shipped|shipment|package|delivery|late|delayed|missing)\b/) &&
      normalized_question.match?(/\b(order|package|delivery|shipment|tracking)\b/)
  end

  def metadata_tags(document)
    metadata = JSON.parse(document.metadata.presence || "{}")
    Array(metadata["tags"]).map { |tag| tag.to_s.downcase }
  rescue JSON::ParserError
    []
  end

  def text_for(value)
    value.to_s.downcase
  end
end
