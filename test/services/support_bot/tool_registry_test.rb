require "test_helper"

module SupportBot
  class ToolRegistryTest < ActiveSupport::TestCase
    test "default registry exposes safe and sensitive tools" do
      registry = ToolRegistry.default

      assert registry.fetch("search_knowledge_base")
      assert_not registry.fetch("search_knowledge_base").sensitive?
      assert registry.fetch("lookup_order_status")
      assert_not registry.fetch("lookup_order_status").sensitive?
    end

    test "registers one sensitive proposal tool per support action type" do
      registry = ToolRegistry.default

      SupportAction::ACTION_TYPES.each do |action_type|
        tool = registry.fetch("propose_#{action_type}")
        assert tool, "missing propose_#{action_type}"
        assert tool.sensitive?
        assert_equal action_type, tool.action_type
      end
    end

    test "schemas are OpenAI-compatible function definitions" do
      schema = ToolRegistry.default.fetch("search_knowledge_base").to_schema

      assert_equal "function", schema[:type]
      assert_equal "search_knowledge_base", schema.dig(:function, :name)
      assert_equal "object", schema.dig(:function, :parameters, "type")
      assert_includes schema.dig(:function, :parameters, "required"), "query"
    end

    test "safe tools execute and feed grounded results back" do
      result = ToolRegistry.default.fetch("search_knowledge_base").execute({ "query" => "refund" }, nil)

      assert_match "Refund Policy", result
    end

    test "sensitive tools refuse execution" do
      tool = ToolRegistry.default.fetch("propose_refund")

      assert_raises(RuntimeError) { tool.execute({ "reason" => "x" }, nil) }
    end

    test "none registry is empty and advertises no schemas" do
      registry = ToolRegistry.none

      assert registry.empty?
      assert_empty registry.schemas
    end
  end
end
