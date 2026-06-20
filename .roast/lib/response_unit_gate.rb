# frozen_string_literal: true

require "json"
require "set"

module Roast
  module ResponseUnits
    # Deterministic validator/gate for response unit candidates.
    #
    # The gate is intentionally pure Ruby with no dependency on the Rails
    # runtime or the Roast workflow engine so it can be exercised from
    # `bin/rails test` and from inside the Roast workflow with identical
    # semantics.
    #
    # Each candidate is validated against the JSON schema at
    # `.roast/schemas/response_unit_candidate.schema.json`. The validation
    # performed here is a lightweight, dependency-free subset that enforces
    # the structural rules the workflow cares about. Additional heuristics
    # (vague summaries, missing evidence, contract/type mismatches) are
    # applied on top to reject low-signal LLM output.
    class ResponseUnitGate
      ALLOWED_TYPES = %w[clarifying_question upload_request escalation].freeze
      ALLOWED_UPLOAD_TYPES = ["image", "document", "any", nil].freeze
      ID_PATTERN = /\A[a-z0-9_]+\.[a-z0-9_]+\z/.freeze
      VAGUE_TERMS = ["tbd", "todo", "n/a", "lorem ipsum", "placeholder", "fill in"].freeze

      Result = Struct.new(:accepted, :rejected, keyword_init: true) do
        def accepted_count
          accepted.length
        end

        def rejected_count
          rejected.length
        end
      end

      def self.call(candidates)
        new(candidates).call
      end

      def initialize(candidates)
        @candidates = Array(candidates)
      end

      def call
        accepted = []
        rejected = []
        seen_ids = Set.new

        @candidates.each_with_index do |candidate, index|
          reasons = validate(candidate)

          if reasons.empty?
            id = candidate["id"]
            if seen_ids.include?(id)
              rejected << reject_record(candidate, index, ["duplicate id '#{id}'"])
            else
              seen_ids << id
              accepted << candidate
            end
          else
            rejected << reject_record(candidate, index, reasons)
          end
        end

        Result.new(accepted: accepted, rejected: rejected)
      end

      private

      def reject_record(candidate, index, reasons)
        {
          "index" => index,
          "id" => candidate.is_a?(Hash) ? candidate["id"] : nil,
          "reasons" => reasons
        }
      end

      def validate(candidate)
        reasons = []
        unless candidate.is_a?(Hash)
          return ["candidate is not an object"]
        end

        validate_required_fields(candidate, reasons)
        validate_id(candidate, reasons)
        validate_type(candidate, reasons)
        validate_priority(candidate, reasons)
        validate_version(candidate, reasons)
        validate_summary(candidate, reasons)
        validate_trigger(candidate, reasons)
        validate_guardrails(candidate, reasons)
        validate_acceptance_criteria(candidate, reasons)
        validate_response_contract(candidate, reasons)
        validate_type_contract_alignment(candidate, reasons)

        reasons
      end

      def validate_required_fields(candidate, reasons)
        %w[id version type priority summary trigger response_contract guardrails acceptance_criteria].each do |field|
          reasons << "missing required field '#{field}'" unless candidate.key?(field)
        end
      end

      def validate_id(candidate, reasons)
        id = candidate["id"]
        return if id.nil?

        reasons << "id must match '<type>.<slug>' pattern" unless id.is_a?(String) && id.match?(ID_PATTERN)
      end

      def validate_type(candidate, reasons)
        type = candidate["type"]
        return if type.nil?

        reasons << "type '#{type}' is not in #{ALLOWED_TYPES.inspect}" unless ALLOWED_TYPES.include?(type)
      end

      def validate_priority(candidate, reasons)
        priority = candidate["priority"]
        return if priority.nil?

        unless priority.is_a?(Integer) && priority.between?(0, 100)
          reasons << "priority must be an integer in 0..100"
        end
      end

      def validate_version(candidate, reasons)
        version = candidate["version"]
        return if version.nil?

        reasons << "version must be an integer >= 1" unless version.is_a?(Integer) && version >= 1
      end

      def validate_summary(candidate, reasons)
        summary = candidate["summary"]
        return if summary.nil?

        unless summary.is_a?(String) && summary.strip.length >= 10
          reasons << "summary must be a string of at least 10 characters"
        end

        if summary.is_a?(String) && contains_vague_term?(summary)
          reasons << "summary contains placeholder/vague text"
        end
      end

      def validate_trigger(candidate, reasons)
        trigger = candidate["trigger"]
        return if trigger.nil?

        unless trigger.is_a?(Hash) && !trigger.empty?
          reasons << "trigger must be a non-empty object"
        end
      end

      def validate_guardrails(candidate, reasons)
        guardrails = candidate["guardrails"]
        return if guardrails.nil?

        unless guardrails.is_a?(Array) && !guardrails.empty? &&
            guardrails.all? { |g| g.is_a?(String) && g.strip.length >= 5 }
          reasons << "guardrails must be a non-empty array of short strings"
        end
      end

      def validate_acceptance_criteria(candidate, reasons)
        criteria = candidate["acceptance_criteria"]
        return if criteria.nil?

        unless criteria.is_a?(Array) && !criteria.empty? &&
            criteria.all? { |c| c.is_a?(String) && c.strip.length >= 5 }
          reasons << "acceptance_criteria must be a non-empty array of short strings"
        end
      end

      def validate_response_contract(candidate, reasons)
        contract = candidate["response_contract"]
        return if contract.nil?

        unless contract.is_a?(Hash)
          reasons << "response_contract must be an object"
          return
        end

        required = %w[answer_text confidence category source_references upload_requested upload_type escalation_recommended escalation_reason]
        required.each do |field|
          reasons << "response_contract missing '#{field}'" unless contract.key?(field)
        end

        answer = contract["answer_text"]
        if answer.is_a?(String)
          reasons << "response_contract.answer_text is empty" if answer.strip.empty?
          reasons << "response_contract.answer_text contains placeholder text" if contains_vague_term?(answer)
          reasons << "response_contract.answer_text uses first-person singular voice; use 'we' instead" if first_person_singular?(answer)
        elsif !answer.nil?
          reasons << "response_contract.answer_text must be a string"
        end

        confidence = contract["confidence"]
        unless confidence.is_a?(Numeric) && confidence >= 0 && confidence <= 1
          reasons << "response_contract.confidence must be a number in 0.0..1.0"
        end

        category = contract["category"]
        unless category.is_a?(String) && !category.strip.empty?
          reasons << "response_contract.category must be a non-empty string"
        end

        sources = contract["source_references"]
        unless sources.is_a?(Array) && sources.all? { |s| s.is_a?(String) }
          reasons << "response_contract.source_references must be an array of strings"
        end

        unless [true, false].include?(contract["upload_requested"])
          reasons << "response_contract.upload_requested must be a boolean"
        end

        unless ALLOWED_UPLOAD_TYPES.include?(contract["upload_type"])
          reasons << "response_contract.upload_type must be one of image|document|any|null"
        end

        unless [true, false].include?(contract["escalation_recommended"])
          reasons << "response_contract.escalation_recommended must be a boolean"
        end

        reason = contract["escalation_reason"]
        unless reason.nil? || (reason.is_a?(String) && !reason.strip.empty?)
          reasons << "response_contract.escalation_reason must be null or a non-empty string"
        end
      end

      def validate_type_contract_alignment(candidate, reasons)
        type = candidate["type"]
        contract = candidate["response_contract"]
        return unless contract.is_a?(Hash) && ALLOWED_TYPES.include?(type)

        case type
        when "upload_request"
          if contract["upload_requested"] == false
            reasons << "upload_request unit must set response_contract.upload_requested=true"
          end
          if contract["upload_type"].nil?
            reasons << "upload_request unit must set response_contract.upload_type"
          end
        when "escalation"
          if contract["escalation_recommended"] == false
            reasons << "escalation unit must set response_contract.escalation_recommended=true"
          end
          if contract["escalation_reason"].nil? || contract["escalation_reason"].to_s.strip.empty?
            reasons << "escalation unit must set response_contract.escalation_reason"
          end
        when "clarifying_question"
          if contract["upload_requested"] == true
            reasons << "clarifying_question unit must not request uploads"
          end
          if contract["escalation_recommended"] == true
            reasons << "clarifying_question unit must not recommend escalation"
          end
          unless contract["answer_text"].is_a?(String) && contract["answer_text"].include?("?")
            reasons << "clarifying_question unit answer_text must contain a question"
          end
        end
      end

      def contains_vague_term?(text)
        downcased = text.to_s.downcase
        VAGUE_TERMS.any? { |term| downcased.include?(term) }
      end

      def first_person_singular?(text)
        # Look for whole-word first-person singular pronouns that are flagged
        # by the project's voice guardrails. "we" / "our" are allowed.
        text.match?(/\b(I|I'm|I'll|I've|I'd|me|my|mine|myself)\b/)
      end
    end
  end
end
