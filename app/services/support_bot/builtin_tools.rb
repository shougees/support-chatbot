module SupportBot
  # The default set of tools exposed to the LLM. Safe, read-only tools execute
  # during the tool loop; one sensitive proposal tool is generated per
  # {SupportAction::ACTION_TYPES} entry so the model can *propose* (never
  # perform) a refund, return, replacement, credit, cancellation, or operator
  # review.
  module BuiltinTools
    module_function

    def all
      [ search_knowledge_base, lookup_order_status, *action_proposals ]
    end

    def action_proposals
      SupportAction::ACTION_TYPES.map { |action_type| propose_action(action_type) }
    end

    # Safe: runs the existing keyword retriever and feeds grounded snippets
    # back to the model.
    def search_knowledge_base
      Tool.new(
        name: "search_knowledge_base",
        description: "Search internal support policy and knowledge documents for grounding before answering policy questions.",
        parameters: {
          "type" => "object",
          "properties" => {
            "query" => { "type" => "string", "description" => "Keywords describing the policy or topic to look up." }
          },
          "required" => [ "query" ]
        }
      ) do |arguments, _context|
        matches = KnowledgeDocumentKeywordRetriever.call(question: arguments["query"].to_s)

        if matches.empty?
          "No matching knowledge documents were found."
        else
          matches.map do |match|
            document = match.document
            text = (document.body.presence || document.extracted_text.to_s).to_s.truncate(400)
            "[#{document.id}] #{document.title}: #{text}"
          end.join("\n")
        end
      end
    end

    # Safe: read-only order status lookup. There is no real fulfillment
    # integration in this environment, so the tool is honest about that rather
    # than fabricating a status — it never claims a real-world action or an
    # unverifiable fact. Replace the body when a real order system exists.
    def lookup_order_status
      Tool.new(
        name: "lookup_order_status",
        description: "Look up the current status of an order by its reference. Read-only; no real order system is connected yet.",
        parameters: {
          "type" => "object",
          "properties" => {
            "order_reference" => { "type" => "string", "description" => "The customer's order number or reference." }
          },
          "required" => [ "order_reference" ]
        }
      ) do |arguments, _context|
        reference = arguments["order_reference"].to_s.strip
        if reference.empty?
          "No order reference was provided; ask the customer for their order number."
        else
          "No live order system is connected in this environment, so the status of order " \
            "#{reference} cannot be verified here. Do not state a delivery status as confirmed; " \
            "offer to escalate to a human operator when the customer needs a guaranteed status."
        end
      end
    end

    # Sensitive: proposes a structured action for operator review. Not executed.
    def propose_action(action_type)
      Tool.new(
        name: "propose_#{action_type}",
        description: "Propose a #{action_type.tr('_', ' ')} for operator review. This does NOT perform the action.",
        sensitive: true,
        action_type: action_type,
        parameters: {
          "type" => "object",
          "properties" => {
            "reason" => { "type" => "string", "description" => "Why this action is appropriate for the customer's request." },
            "order_reference" => { "type" => "string", "description" => "The order number this action applies to, if known." }
          },
          "required" => [ "reason" ]
        }
      )
    end
  end
end
