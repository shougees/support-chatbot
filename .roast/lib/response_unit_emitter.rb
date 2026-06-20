# frozen_string_literal: true

require "json"
require "fileutils"
require "time"

module Roast
  module ResponseUnits
    # Writes accepted/rejected response unit candidates to the
    # `.roast/out/` artifact directory as JSON and a human-readable
    # Markdown report.
    class ResponseUnitEmitter
      DEFAULT_OUTPUT_DIR = File.expand_path("../out", __dir__)

      def self.call(result, output_dir: DEFAULT_OUTPUT_DIR, now: Time.now.utc)
        new(result, output_dir: output_dir, now: now).call
      end

      def initialize(result, output_dir: DEFAULT_OUTPUT_DIR, now: Time.now.utc)
        @result = result
        @output_dir = output_dir
        @now = now
      end

      def call
        FileUtils.mkdir_p(@output_dir)

        json_path = File.join(@output_dir, "response_unit_candidates.json")
        md_path = File.join(@output_dir, "response_unit_candidates.md")

        File.write(json_path, JSON.pretty_generate(json_payload))
        File.write(md_path, markdown_report)

        { json: json_path, markdown: md_path }
      end

      private

      def json_payload
        {
          "generated_at" => @now.iso8601,
          "accepted_count" => @result.accepted_count,
          "rejected_count" => @result.rejected_count,
          "accepted" => @result.accepted,
          "rejected" => @result.rejected
        }
      end

      def markdown_report
        lines = []
        lines << "# Response unit candidates"
        lines << ""
        lines << "_Generated at #{@now.iso8601} by `.roast/workflows/build_response_units.rb`._"
        lines << ""
        lines << "- Accepted: #{@result.accepted_count}"
        lines << "- Rejected: #{@result.rejected_count}"
        lines << ""
        lines << "## Accepted"
        lines << ""

        if @result.accepted.empty?
          lines << "_No candidates were accepted in this run._"
        else
          @result.accepted.each do |candidate|
            lines.concat(accepted_section(candidate))
          end
        end

        lines << ""
        lines << "## Rejected"
        lines << ""

        if @result.rejected.empty?
          lines << "_No candidates were rejected in this run._"
        else
          @result.rejected.each do |entry|
            lines.concat(rejected_section(entry))
          end
        end

        lines.join("\n") + "\n"
      end

      def accepted_section(candidate)
        contract = candidate["response_contract"] || {}
        section = []
        section << "### #{candidate["id"]} (v#{candidate["version"]})"
        section << ""
        section << "- Type: `#{candidate["type"]}`"
        section << "- Priority: #{candidate["priority"]}"
        section << "- Summary: #{candidate["summary"]}"
        section << "- Confidence: #{contract["confidence"]}"
        section << "- Upload requested: #{contract["upload_requested"]} (#{contract["upload_type"] || "n/a"})"
        section << "- Escalation recommended: #{contract["escalation_recommended"]}"
        if contract["escalation_reason"]
          section << "- Escalation reason: #{contract["escalation_reason"]}"
        end
        section << ""
        section << "**Answer text**"
        section << ""
        section << "> #{contract["answer_text"]}"
        section << ""
        section << "**Guardrails**"
        section << ""
        Array(candidate["guardrails"]).each { |g| section << "- #{g}" }
        section << ""
        section << "**Acceptance criteria**"
        section << ""
        Array(candidate["acceptance_criteria"]).each { |c| section << "- #{c}" }
        section << ""
        section
      end

      def rejected_section(entry)
        section = []
        label = entry["id"] || "candidate #{entry["index"]}"
        section << "### #{label}"
        section << ""
        Array(entry["reasons"]).each { |r| section << "- #{r}" }
        section << ""
        section
      end
    end
  end
end
