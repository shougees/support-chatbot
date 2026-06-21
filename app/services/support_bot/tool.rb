module SupportBot
  # A single callable tool/function the LLM may invoke.
  #
  # Two flavours, matching the PRD action boundaries:
  #
  # * Safe tools (`sensitive: false`) run in-process during the tool-calling
  #   loop and feed their result back to the model (e.g. searching the
  #   knowledge base). They must be read-only.
  # * Sensitive tools (`sensitive: true`) are NEVER executed. When the model
  #   calls one, the provider stops and surfaces it as a *proposed* structured
  #   action (mapped to a {SupportAction}) for application/operator review.
  class Tool
    attr_reader :name, :description, :parameters, :action_type

    def initialize(name:, description:, parameters: nil, sensitive: false, action_type: nil, &executor)
      @name = name.to_s
      @description = description
      @parameters = parameters || { "type" => "object", "properties" => {} }
      @sensitive = sensitive
      @action_type = action_type
      @executor = executor
    end

    def sensitive?
      @sensitive
    end

    # Runs a safe tool. Raises for sensitive tools, which must be proposed,
    # not executed.
    def execute(arguments, context)
      raise "Sensitive tool #{name} must be proposed, not executed" if sensitive?
      return "" unless @executor

      @executor.call(arguments || {}, context).to_s
    end

    # OpenAI-compatible function-tool schema.
    def to_schema
      {
        type: "function",
        function: {
          name: name,
          description: description,
          parameters: parameters
        }
      }
    end
  end
end
