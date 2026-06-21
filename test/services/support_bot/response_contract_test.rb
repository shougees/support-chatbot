require "test_helper"

module SupportBot
  class ResponseContractTest < ActiveSupport::TestCase
    test "instructions describe every required field" do
      assert_match "Return only valid JSON", ResponseContract.instructions

      ResponseContract::REQUIRED_KEYS.each do |key|
        assert_match key, ResponseContract.instructions
      end
    end

    test "the parser shares the single contract definition" do
      assert_same ResponseContract::REQUIRED_KEYS, StructuredResponseParser::REQUIRED_KEYS
      assert_same ResponseContract::UPLOAD_TYPES, StructuredResponseParser::UPLOAD_TYPES
    end
  end
end
