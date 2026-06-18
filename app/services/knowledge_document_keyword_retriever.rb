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
    end.sort_by { |result| -result.score }.first(limit)
  end

  private

  attr_reader :question, :limit, :scope

  def keyword_score(document)
    terms.count { |term| document_text(document).include?(term) }
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
    %w[title category body extracted_text]
  end

  def term_matches
    @term_matches ||= {}
  end

  def document_text(document)
    [
      document.title,
      document.category,
      document.body,
      document.extracted_text
    ].compact.join(" ").downcase
  end

  def terms
    @terms ||= question.downcase.scan(/[a-z0-9]+/).reject { |term| term.length < 4 }.uniq
  end
end
