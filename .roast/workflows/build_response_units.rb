# frozen_string_literal: true

# Roast workflow: build_response_units
#
# Offline/local workflow that turns PRD requirements, repository observations,
# and (optional) agent feedback into structured response unit candidates for
# the Rails support chatbot.
#
# This workflow is *not* part of the Rails runtime request path. It only emits
# local artifacts under `.roast/out/` for human and follow-up review.
#
# Workflow shape (see issue #67):
#
#   ruby(:load_context)
#     Load PRD, backlog docs, existing response unit files, and optional
#     sample transcripts.
#
#   agent(:inspect_response_flow)
#     Inspect the Rails app and identify response generation extension points.
#     Read-only. Returns observations with evidence.
#
#   chat(:taskify_feedback)
#     Convert observations into strict-JSON response unit candidates.
#
#   ruby(:gate_units)
#     Validate candidate JSON against the schema and project heuristics.
#
#   ruby(:emit)
#     Write `.roast/out/response_unit_candidates.json` and `.md`.
#
# Run locally with:
#
#   bundle exec roast run .roast/workflows/build_response_units.rb
#
# Or, to exercise just the deterministic gate + emitter against the bundled
# seed candidates (no LLM calls required):
#
#   ruby .roast/workflows/build_response_units.rb --offline

require "json"
require "pathname"
require "fileutils"

ROAST_ROOT = Pathname.new(File.expand_path("..", __dir__))

require_relative "../lib/response_unit_gate"
require_relative "../lib/response_unit_emitter"

module BuildResponseUnits
  module_function

  PROJECT_ROOT = ROAST_ROOT.parent
  SCHEMA_PATH = ROAST_ROOT.join("schemas/response_unit_candidate.schema.json")
  CONTEXT_PATHS = [
    PROJECT_ROOT.join("docs/PRD.md"),
    PROJECT_ROOT.join("docs/ISSUES.md")
  ].freeze

  # Seed candidates used in `--offline` mode. They double as a concrete
  # contract example for the LLM-backed steps and as deterministic input the
  # gate/emitter can be exercised against without network access.
  SEED_CANDIDATES = [
    {
      "id" => "clarifying_question.ambiguous_order_reference",
      "version" => 1,
      "type" => "clarifying_question",
      "priority" => 70,
      "summary" => "Ask for an order number when the customer references an order without identifying it.",
      "trigger" => {
        "category" => "order_lookup",
        "missing_context" => ["order_number"]
      },
      "response_contract" => {
        "answer_text" => "Could you share the order number so we can look up the right order?",
        "confidence" => 0.7,
        "category" => "order_lookup",
        "source_references" => [],
        "upload_requested" => false,
        "upload_type" => nil,
        "escalation_recommended" => false,
        "escalation_reason" => nil
      },
      "guardrails" => [
        "Ask for at most one missing detail at a time.",
        "Do not claim access to private account data before the customer confirms it.",
        "Use 'we' instead of first-person singular phrasing."
      ],
      "acceptance_criteria" => [
        "Unit produces a single concise question.",
        "Unit does not request uploads.",
        "Unit does not recommend escalation."
      ],
      "evidence" => [
        "docs/PRD.md: bot should ask concise clarifying questions only when needed."
      ]
    },
    {
      "id" => "upload_request.photo_needed",
      "version" => 1,
      "type" => "upload_request",
      "priority" => 80,
      "summary" => "Ask for a photo when visual evidence is materially useful (damaged/missing items).",
      "trigger" => {
        "category" => "damaged_item",
        "requires_visual_evidence" => true
      },
      "response_contract" => {
        "answer_text" => "A photo would help us understand the issue. Please upload a clear image of the problem area.",
        "confidence" => 0.72,
        "category" => "damaged_item",
        "source_references" => [],
        "upload_requested" => true,
        "upload_type" => "image",
        "escalation_recommended" => false,
        "escalation_reason" => nil
      },
      "guardrails" => [
        "Do not request uploads unless they materially help.",
        "Do not claim access to private account data.",
        "Use 'we' instead of first-person singular phrasing."
      ],
      "acceptance_criteria" => [
        "Unit sets upload_requested=true and upload_type=image.",
        "Unit does not recommend escalation by itself.",
        "Unit is covered by tests in the follow-up registry issue."
      ],
      "evidence" => [
        "app/services/bot_orchestrator.rb: existing upload_output already maps to upload_requested/upload_type.",
        "docs/PRD.md: dynamic upload requests when materially useful."
      ]
    },
    {
      "id" => "escalation.high_risk_or_agent_request",
      "version" => 1,
      "type" => "escalation",
      "priority" => 95,
      "summary" => "Escalate high-risk requests or explicit agent/human requests to operator review.",
      "trigger" => {
        "category" => "operator_review",
        "matches_any" => ["agent", "human", "representative", "legal", "fraud", "chargeback", "identity", "emergency"]
      },
      "response_contract" => {
        "answer_text" => "We need a support operator to review this before we can reply.",
        "confidence" => 0.6,
        "category" => "operator_review",
        "source_references" => [],
        "upload_requested" => false,
        "upload_type" => nil,
        "escalation_recommended" => true,
        "escalation_reason" => "High-risk or explicit operator-request context detected."
      },
      "guardrails" => [
        "Never bypass escalation for high-risk safety, legal, payment, or identity cases.",
        "Preserve full conversation context for the operator handoff.",
        "Use 'we' instead of first-person singular phrasing."
      ],
      "acceptance_criteria" => [
        "Unit sets escalation_recommended=true and a non-empty escalation_reason.",
        "Unit does not request uploads.",
        "Unit triggers before lower-priority units in the registry."
      ],
      "evidence" => [
        "app/services/bot_orchestrator.rb: StubProvider already detects high-risk keywords.",
        "docs/PRD.md: high-risk issues bypass the one-more-attempt rule."
      ]
    }
  ].freeze

  def load_context
    {
      schema: JSON.parse(SCHEMA_PATH.read),
      docs: CONTEXT_PATHS.each_with_object({}) do |path, memo|
        memo[path.relative_path_from(PROJECT_ROOT).to_s] = path.exist? ? path.read : ""
      end
    }
  end

  def gate(candidates)
    Roast::ResponseUnits::ResponseUnitGate.call(candidates)
  end

  def emit(result)
    Roast::ResponseUnits::ResponseUnitEmitter.call(result)
  end

  # Deterministic, no-LLM run. Useful for CI, smoke tests, and as a fallback
  # when the Roast runner / OpenAI credentials are not available locally.
  def run_offline
    load_context
    result = gate(SEED_CANDIDATES.map { |c| deep_dup(c) })
    paths = emit(result)
    puts "Wrote #{paths[:json]}"
    puts "Wrote #{paths[:markdown]}"
    puts "Accepted: #{result.accepted_count}, Rejected: #{result.rejected_count}"
    result
  end

  def deep_dup(value)
    JSON.parse(JSON.generate(value))
  end
end

# Roast DSL definition. Guarded so the file is also runnable as a plain Ruby
# script (`ruby .roast/workflows/build_response_units.rb --offline`) without
# requiring the `roast-ai` gem to be loaded.
begin
  require "roast"

  Roast.workflow "build_response_units" do
    description "Generate, validate, and emit pluggable chatbot response unit candidates."

    ruby :load_context do
      BuildResponseUnits.load_context
    end

    agent :inspect_response_flow do
      tools :read_file, :grep, :list_files
      instructions <<~PROMPT
        You are a read-only repository inspector for a Rails support chatbot.

        Inspect the Rails app under `app/` (especially `app/services/`,
        `app/models/`, and any existing `app/services/support_bot/`),
        the docs under `docs/`, and any seed/fixture data under `db/` or
        `test/fixtures/`.

        Identify concrete extension points where a pluggable response unit
        could plug into the existing bot response flow. For each observation:

        - Cite the file path and a short evidence snippet.
        - Classify the candidate behavior as one of: clarifying_question,
          upload_request, escalation.
        - Note any policy or guardrail in `docs/PRD.md` that applies.

        Do not modify any files. Do not perform backlog management. Do not
        create runtime behavior. Return a JSON array of observations.
      PROMPT
    end

    chat :taskify_feedback do
      schema "../schemas/response_unit_candidate.schema.json"
      instructions <<~PROMPT
        Convert the agent observations into an array of response unit
        candidates that conform exactly to the JSON schema referenced above.

        Rules:
        - Use ids of the form '<type>.<slug>' with snake_case.
        - Only use types: clarifying_question, upload_request, escalation.
        - upload_request units MUST set upload_requested=true and a non-null
          upload_type.
        - escalation units MUST set escalation_recommended=true and a
          non-empty escalation_reason.
        - clarifying_question units MUST contain a single concise question in
          answer_text and MUST NOT request uploads or recommend escalation.
        - Use 'we' voice. Avoid first-person singular ('I', 'my', 'me').
        - Do not invent policy. If unsure, omit the candidate.

        Return strict JSON only.
      PROMPT
    end

    ruby :gate_units do |candidates|
      BuildResponseUnits.gate(candidates)
    end

    ruby :emit do |result|
      BuildResponseUnits.emit(result)
    end
  end
rescue LoadError
  # roast-ai is optional at script-evaluation time. The deterministic
  # `--offline` mode below covers local validation without it.
end

if $PROGRAM_NAME == __FILE__
  if ARGV.include?("--offline")
    BuildResponseUnits.run_offline
  else
    warn "Use `bundle exec roast run .roast/workflows/build_response_units.rb` to run via Roast,"
    warn "or `ruby .roast/workflows/build_response_units.rb --offline` for the deterministic local run."
    exit 1
  end
end
