# frozen_string_literal: true

require "test_helper"

require Rails.root.join(".roast/lib/response_unit_gate").to_s
require Rails.root.join(".roast/lib/response_unit_emitter").to_s

class ResponseUnitGateTest < ActiveSupport::TestCase
  def valid_clarifying_candidate
    {
      "id" => "clarifying_question.ambiguous_order_reference",
      "version" => 1,
      "type" => "clarifying_question",
      "priority" => 70,
      "summary" => "Ask for the order number when the customer references an order without identifying it.",
      "trigger" => { "category" => "order_lookup" },
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
      "guardrails" => [ "Use 'we' instead of first-person singular phrasing." ],
      "acceptance_criteria" => [ "Unit produces a single concise question." ]
    }
  end

  def valid_upload_candidate
    valid_clarifying_candidate.merge(
      "id" => "upload_request.photo_needed",
      "type" => "upload_request",
      "summary" => "Ask for a photo when visual evidence is materially useful.",
      "response_contract" => {
        "answer_text" => "A photo would help us understand the issue. Please upload a clear image.",
        "confidence" => 0.72,
        "category" => "damaged_item",
        "source_references" => [],
        "upload_requested" => true,
        "upload_type" => "image",
        "escalation_recommended" => false,
        "escalation_reason" => nil
      }
    )
  end

  def valid_escalation_candidate
    valid_clarifying_candidate.merge(
      "id" => "escalation.high_risk",
      "type" => "escalation",
      "summary" => "Escalate high-risk customer requests to operator review.",
      "response_contract" => {
        "answer_text" => "We need a support operator to review this before we can reply.",
        "confidence" => 0.6,
        "category" => "operator_review",
        "source_references" => [],
        "upload_requested" => false,
        "upload_type" => nil,
        "escalation_recommended" => true,
        "escalation_reason" => "High-risk request detected."
      }
    )
  end

  test "accepts valid candidates of every supported type" do
    result = Roast::ResponseUnits::ResponseUnitGate.call(
      [ valid_clarifying_candidate, valid_upload_candidate, valid_escalation_candidate ]
    )

    assert_equal 3, result.accepted_count
    assert_equal 0, result.rejected_count
  end

  test "rejects candidates that are missing required fields" do
    bad = valid_clarifying_candidate.except("guardrails")

    result = Roast::ResponseUnits::ResponseUnitGate.call([ bad ])

    assert_equal 0, result.accepted_count
    assert_equal 1, result.rejected_count
    assert_includes result.rejected.first["reasons"], "missing required field 'guardrails'"
  end

  test "rejects ids that do not match the type.slug pattern" do
    bad = valid_clarifying_candidate.merge("id" => "BadId")

    result = Roast::ResponseUnits::ResponseUnitGate.call([ bad ])

    assert_equal 1, result.rejected_count
    assert_includes result.rejected.first["reasons"], "id must match '<type>.<slug>' pattern"
  end

  test "rejects unknown response unit types" do
    bad = valid_clarifying_candidate.merge("type" => "smalltalk")

    result = Roast::ResponseUnits::ResponseUnitGate.call([ bad ])

    assert_equal 1, result.rejected_count
    assert(result.rejected.first["reasons"].any? { |r| r.include?("type 'smalltalk'") })
  end

  test "rejects upload_request units that do not actually request uploads" do
    bad = valid_upload_candidate
    bad["response_contract"]["upload_requested"] = false
    bad["response_contract"]["upload_type"] = nil

    result = Roast::ResponseUnits::ResponseUnitGate.call([ bad ])

    reasons = result.rejected.first["reasons"]
    assert_includes reasons, "upload_request unit must set response_contract.upload_requested=true"
    assert_includes reasons, "upload_request unit must set response_contract.upload_type"
  end

  test "rejects escalation units missing escalation reason" do
    bad = valid_escalation_candidate
    bad["response_contract"]["escalation_reason"] = nil

    result = Roast::ResponseUnits::ResponseUnitGate.call([ bad ])

    assert_includes result.rejected.first["reasons"], "escalation unit must set response_contract.escalation_reason"
  end

  test "rejects clarifying_question units without a question in answer_text" do
    bad = valid_clarifying_candidate
    bad["response_contract"]["answer_text"] = "Please share the order number."

    result = Roast::ResponseUnits::ResponseUnitGate.call([ bad ])

    assert_includes result.rejected.first["reasons"], "clarifying_question unit answer_text must contain a question"
  end

  test "rejects answer text that uses first-person singular voice" do
    bad = valid_clarifying_candidate
    bad["response_contract"]["answer_text"] = "Can I get your order number?"

    result = Roast::ResponseUnits::ResponseUnitGate.call([ bad ])

    assert_includes result.rejected.first["reasons"],
      "response_contract.answer_text uses first-person singular voice; use 'we' instead"
  end

  test "rejects placeholder text in summary" do
    bad = valid_clarifying_candidate.merge("summary" => "TODO: write summary later.")

    result = Roast::ResponseUnits::ResponseUnitGate.call([ bad ])

    assert_includes result.rejected.first["reasons"], "summary contains placeholder/vague text"
  end

  test "rejects duplicate ids within a single run" do
    result = Roast::ResponseUnits::ResponseUnitGate.call(
      [ valid_upload_candidate, valid_upload_candidate ]
    )

    assert_equal 1, result.accepted_count
    assert_equal 1, result.rejected_count
    assert(result.rejected.first["reasons"].any? { |r| r.include?("duplicate id") })
  end

  test "emits json and markdown artifacts under the configured output dir" do
    Dir.mktmpdir do |dir|
      result = Roast::ResponseUnits::ResponseUnitGate.call([ valid_upload_candidate ])
      paths = Roast::ResponseUnits::ResponseUnitEmitter.call(result, output_dir: dir)

      assert File.exist?(paths[:json])
      assert File.exist?(paths[:markdown])

      payload = JSON.parse(File.read(paths[:json]))
      assert_equal 1, payload["accepted_count"]
      assert_equal 0, payload["rejected_count"]
      assert_equal "upload_request.photo_needed", payload["accepted"].first["id"]

      markdown = File.read(paths[:markdown])
      assert_includes markdown, "# Response unit candidates"
      assert_includes markdown, "upload_request.photo_needed"
    end
  end
end
