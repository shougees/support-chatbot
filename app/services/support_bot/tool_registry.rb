module SupportBot
  # Holds the tools available to the LLM for a given request and renders them
  # as OpenAI-compatible function schemas. The registry is the extension point
  # for the "response plugin": register more {Tool}s here (or build a custom
  # registry) without touching the provider.
  class ToolRegistry
    def self.default
      new(BuiltinTools.all)
    end

    def self.none
      new([])
    end

    def initialize(tools = [])
      @tools = {}
      Array(tools).each { |tool| register(tool) }
    end

    def register(tool)
      @tools[tool.name] = tool
      self
    end

    def fetch(name)
      @tools[name.to_s]
    end

    def tools
      @tools.values
    end

    def empty?
      @tools.empty?
    end

    def schemas
      tools.map(&:to_schema)
    end
  end
end
