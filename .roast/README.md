# Roast workflows

Offline/local [Roast](https://github.com/Shopify/roast) workflows used to
generate, validate, and emit artifacts that support the Rails support
chatbot.

These workflows are **not part of the Rails runtime request path**. They are
designed to be run locally by developers or in CI to produce reviewable
artifacts under `.roast/out/`.

## Layout

```
.roast/
├── workflows/
│   └── build_response_units.rb       # Roast workflow definition
├── schemas/
│   └── response_unit_candidate.schema.json
├── lib/
│   ├── response_unit_gate.rb         # Deterministic validator
│   └── response_unit_emitter.rb      # Artifact writer
└── out/                              # Generated artifacts (gitignored)
```

## `build_response_units`

Generates pluggable chatbot response unit *candidates* (clarifying questions,
upload requests, escalations) and emits them as:

- `.roast/out/response_unit_candidates.json`
- `.roast/out/response_unit_candidates.md`

It does **not** wire candidates into the runtime chatbot. A follow-up issue
will add the Rails `ResponseUnitRegistry` and YAML loader.

### Run with the Roast runner

Requires the `roast-ai` gem (already in the `Gemfile`) and an OpenAI API key
configured for Roast:

```sh
bundle exec roast run .roast/workflows/build_response_units.rb
```

### Run offline (no LLM)

The workflow file is also runnable as a plain Ruby script with `--offline`.
This skips the `agent` and `chat` steps and feeds a bundled set of seed
candidates through the deterministic gate + emitter:

```sh
ruby .roast/workflows/build_response_units.rb --offline
```

This is useful for smoke-testing the schema, the gate rules, and the emitter
output without any network access or API credentials.

### Validation rules

`Roast::ResponseUnits::ResponseUnitGate` enforces, among other things:

- The candidate matches `schemas/response_unit_candidate.schema.json`.
- Ids match `<type>.<slug>` and are unique within a run.
- `type` is one of `clarifying_question`, `upload_request`, `escalation`.
- The `response_contract` fully covers the existing bot response contract
  (answer text, confidence, category, source references, upload request,
  escalation recommendation, escalation reason).
- Type-specific alignment:
  - `upload_request` ⇒ `upload_requested=true` and a concrete `upload_type`.
  - `escalation` ⇒ `escalation_recommended=true` and an `escalation_reason`.
  - `clarifying_question` ⇒ a question in `answer_text`, no upload request,
    no escalation.
- `answer_text` uses the "we" voice and contains no placeholder text.

The gate is covered by `test/roast/response_unit_gate_test.rb` and can be
run as part of `bin/rails test`.
