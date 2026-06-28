module SupportBot
  class ToneGuardrail
    DISALLOWED_FIRST_PERSON_PATTERNS = [
      /\bI\s+can\b/i,
      /\bI\s+will\b/i,
      /\bI\s+found\b/i,
      /\bI\s+am\b/i,
      /\bI\s+have\b/i,
      /\bI\s+need\b/i,
      /\bI(?:'m|'ll|'ve|'d)\b/i
    ].freeze

    def self.instructions
      [
        "Use 'we' instead of first-person singular language.",
        "Do not use first-person singular phrasing such as 'I can', 'I will', 'I found', 'I'm', or 'I've'.",
        "Keep replies concise: 1-3 short sentences, action-oriented, and clear about limitations.",
        "Use calm customer-facing support language."
      ]
    end

    def self.violation_reason(text)
      return if text.blank?

      return "Bot response used disallowed first-person singular phrasing." if DISALLOWED_FIRST_PERSON_PATTERNS.any? { |pattern| text.match?(pattern) }

      nil
    end
  end
end
