# LLM response layer (`app/services/support_bot/`)

The runtime LLM-response subsystem. One pluggable provider, one transport, one
response contract, and a tool registry. This is the place to iterate on bot
behavior. (The offline `.roast/` workflows are a separate, non-runtime concern.)

## Flow

```
BotOrchestrator
  → ProviderFactory.build(bot_agent:)        # picks fake | LlmProvider
    → LlmProvider#call(ProviderRequest)
        PromptBuilder.messages                # system instructions + user prompt
        loop (≤ MAX_TOOL_ITERATIONS):
          HttpClient#post_json → chat/completions
          tool_calls?  → safe tool  → execute, feed result back, loop
                       → sensitive  → stop, propose action for review
          final text   → StructuredResponseParser → ProviderResponse
  → persists ResponseDraft (+ proposed SupportActions) and routes to review
```

## Pieces

| File | Responsibility |
| --- | --- |
| `response_contract.rb` | **Single source of truth** for the structured reply shape (fields, model instructions). Consumed by the prompt builder and the parser. Upload-type values are anchored to `ResponseDraft::UPLOAD_TYPES` so the contract and the DB column never drift. |
| `prompt_builder.rb` | Builds system instructions + initial chat messages (the shared guidance lives here once). |
| `http_client.rb` | One Net::HTTP JSON POST transport for any OpenAI-compatible endpoint. |
| `provider_config.rb` | Resolves `{api_key, base_url, model}` for the `openai` / `openai_compatible` profiles from ENV, credentials, and the bot agent. |
| `llm_provider.rb` | The one provider. Chat-completions wire format + bounded tool loop + structured parsing. |
| `tool.rb` / `tool_registry.rb` / `builtin_tools.rb` | Tool definitions and the registry the model sees. |
| `structured_response_parser.rb` | Validates model JSON against the contract → `ProviderResponse`. |
| `fake_provider.rb` | Deterministic, network-free provider used in dev/test. |

## Tool calling

Two kinds of tools, matching the PRD action boundaries:

- **Safe (read-only)** — e.g. `search_knowledge_base`. Executed in the loop;
  results are fed back to the model. Add more by registering `Tool`s.
- **Sensitive** — `propose_<action>` per `SupportAction::ACTION_TYPES`
  (refund, return, replacement, credit, cancellation, operator_review). Never
  executed. When the model calls one, the provider stops and returns a
  review-required response carrying the proposed action; `BotOrchestrator`
  persists it as a `proposed` `SupportAction` and routes to operator review.

The model proposes; application code and operators decide eligibility.

## Extending

- New response field → edit `ResponseContract` (instructions + required keys)
  and the parser validation.
- New tool → add a `Tool` to `BuiltinTools.all` (or build a custom
  `ToolRegistry` and inject it into `LlmProvider`).
- New provider endpoint → add a profile to `ProviderConfig`; the provider and
  transport stay the same as long as it is OpenAI-compatible.
