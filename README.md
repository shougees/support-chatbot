# Support Chatbot

Support Chatbot is a Ruby on Rails personal project for learning how to build an AI-assisted customer support system for a hypothetical ecommerce company.

The app models a support experience where customers always chat with a unified support assistant, while automation, retrieval, background jobs, and behind-the-scenes human review decide how each answer should be produced. The goal is to resolve eligible customer issues in chat while staying grounded in policy and escalating or routing to review when confidence is low or the situation is high-risk.

## Why This Exists

This project is meant to make the technical pieces of an AI support product concrete:

- how conversations, messages, drafts, reviews, actions, uploads, and traces fit together,
- how RAG retrieves policy/context before a model answers,
- how an LLM provider can be swapped without rewriting the product flow,
- how background jobs keep bot responses asynchronous,
- how operators can review low-confidence or sensitive decisions,
- how agent behavior can be audited through decision traces.

The product scenario is fictional. Sample support policies, seed data, and demo content should be original, public, or user-provided. Do not add private company data, real customer data, or copied internal support policies.

## Current Capabilities

- Customer conversation flow with public conversation IDs.
- Realtime customer and operator message updates with Hotwire and Action Cable.
- Background bot response jobs through Solid Queue.
- Keyword-only RAG over active knowledge documents.
- OpenAI-compatible LLM layer with fake, OpenAI, Fireworks AI, and generic compatible provider modes.
- Structured bot responses with confidence, category, source references, upload requests, and action proposals.
- Human review queue for low-confidence, failed, or sensitive responses.
- Operator view for transcript review, draft approval, edited replies, rejection with replacement, and direct support replies.
- Agent decision traces for auditability and future analysis.

This app does not perform real-world ecommerce actions yet. Refunds, returns, replacements, cancellations, credits, and human-review actions are stored as structured proposals for application-side validation and review.

## Tech Stack

- Rails 8
- SQLite
- Hotwire: Turbo and Stimulus
- Action Cable
- Solid Queue, Solid Cache, and Solid Cable
- Tailwind CSS
- Active Storage
- Ruby managed with mise or rbenv

## Architecture Overview

```text
Customer message
  -> MessagesController
  -> Conversation message persistence
  -> BotResponseJob
  -> BotOrchestrator
       -> KnowledgeDocumentKeywordRetriever
       -> SupportBot::ProviderFactory
       -> SupportBot::LlmProvider or SupportBot::FakeProvider
       -> PromptBuilder + ToolRegistry + StructuredResponseParser
       -> ResponseDraft
       -> Message or ResponseReview
       -> SupportAction proposals
       -> AgentDecisionTrace
  -> Customer and operator views update through Turbo streams
```

The core flow lives in `BotOrchestrator`. It gathers retrieved knowledge, calls the configured provider, parses the structured response, persists the draft, and decides whether the answer can be published directly or needs operator review.

`ProviderFactory` chooses the provider from environment configuration and bot-agent settings. Local development defaults to the fake provider so the app can run without paid API calls.

## RAG

RAG is part of the MVP. The first implementation uses database-backed keyword retrieval through `KnowledgeDocumentKeywordRetriever`.

Knowledge documents represent policy and support content. The bot should answer from current active documents when possible, and retrieved sources are persisted as retrieval results so answers can be inspected later.

The retrieval interface is intentionally simple so embeddings, vector search, URL ingestion, Reddit/public-source ingestion, or richer ranking can be added later without changing the overall bot orchestration flow.

## Knowledge Ingestion

Manual knowledge document ingestion is supported through a background job. Manual documents can be processed into extracted text, marked active, and then used by retrieval.

Upload, URL, and Reddit source types are represented in the data model but are intentionally disabled until their processing rules are implemented. Public web and Reddit ingestion must respect terms of service, API rules, robots rules, rate limits, attribution needs, and privacy expectations. Do not ingest private data, personal data, copied internal policy, or content that the project does not have permission to use.

## Human Review And Agent Behavior

Customers see one support conversation. They should not need to know whether a reply came directly from automation, was approved by an operator, was edited by an operator, or was written directly by support.

Internally, low-confidence responses, provider failures, sensitive action proposals, and policy-risk cases can create response reviews for operators. Operators can inspect the transcript, retrieved sources, draft response, proposed actions, and decision trace before sending a customer-visible reply.

Agent decision traces capture the bot path for each handled customer message, including provider, model, confidence, outcome, retrieved documents, proposed actions, review status, and fallback details.

## Dynamic Uploads

The chatbot can request an upload as part of a structured response, for example when a damaged item needs a photo. Upload controls should appear in the conversation only when the bot asks for them, not as a permanent default chat control.

Uploads are modeled so they can be associated with conversations and messages. The current product direction is to use uploaded images or files as support context, not to expose a general-purpose file-upload interface at all times.

## Local Setup

Install project tools with mise:

```bash
mise trust
mise install
gem install bundler -v 4.0.13
```

Install dependencies:

```bash
bundle install
```

Prepare the database:

```bash
bin/rails db:prepare
bin/rails db:seed
```

Start the app:

```bash
bin/rails server -p 3000
```

Open:

- Customer app: http://localhost:3000
- Demo operator review: http://localhost:3000/operator/conversations/demo-review-conversation

Seed data creates a local operator user for development:

```text
Email: operator@example.test
Password: password
```

To create another local operator user:

```bash
bin/rails runner 'OperatorUser.create!(email: "another-operator@example.test", password: "password")'
```

If port 3000 is already in use, start Rails on another port:

```bash
bin/rails server -p 3001
```

## Dev Container Setup

The dev container installs Ruby, Node, GitHub CLI, and Codex CLI with mise. It uses SQLite only; no MySQL or Redis service is required.

```bash
bin/setup --skip-server
bin/dev
```

Open http://localhost:3000.

## Environment Variables

Copy the example file before using real providers:

```bash
cp .env.example .env
```

Development and test use the fake provider by default.

| Variable | Required When | Purpose |
| --- | --- | --- |
| `SUPPORT_BOT_PROVIDER` | Optional | Provider mode: `fake`, `openai`, `fireworks`, or `openai_compatible`. |
| `OPENAI_API_KEY` | `SUPPORT_BOT_PROVIDER=openai` | API key for OpenAI. |
| `OPENAI_BASE_URL` | Optional for OpenAI | Override for the OpenAI-compatible base URL. |
| `FIREWORKS_API_KEY` | `SUPPORT_BOT_PROVIDER=fireworks` | API key for Fireworks AI. |
| `FIREWORKS_BASE_URL` | Optional for Fireworks | Defaults to `https://api.fireworks.ai/inference/v1`. |
| `FIREWORKS_MODEL` | Optional for Fireworks | Defaults to `accounts/fireworks/models/kimi-k2p6`. |
| `LLM_API_KEY` | `SUPPORT_BOT_PROVIDER=openai_compatible` | API key for another OpenAI-compatible provider. |
| `LLM_BASE_URL` | `SUPPORT_BOT_PROVIDER=openai_compatible` | Base URL for another OpenAI-compatible provider. |
| `LLM_MODEL` | `SUPPORT_BOT_PROVIDER=openai_compatible` | Model name for another OpenAI-compatible provider. |

API keys can also be stored in Rails credentials under `openai.api_key`, `fireworks.api_key`, or `llm.api_key`.

Restart Rails after changing `.env`.

## Demo Flows

Start with the fake provider if you want predictable local behavior without API cost:

```bash
SUPPORT_BOT_PROVIDER=fake bin/rails server -p 3000
```

Try these flows:

- Create a customer conversation from `/` and send a basic message.
- Ask about a return or damaged item to see policy-backed support behavior.
- Ask for an upload-worthy case, such as a damaged item photo, to see the bot request upload context.
- Use `/operator/conversations/:public_id` to inspect the same conversation from the operator side.
- Use `/operator/conversations/demo-review-conversation` after seeding to approve, edit, reject, or replace a pending draft.
- Try a low-confidence or risky request to see the response routed to review instead of being published directly.

## Running Checks

Run the full Rails test suite:

```bash
bin/rails test
```

Run style checks:

```bash
bin/rubocop
```

Run security checks when changing sensitive behavior:

```bash
bin/brakeman
```

## Deployment

Render is the intended first deployment target for this project. The app is designed for a simple Rails deployment with SQLite and Rails' Solid adapters rather than separate Redis or job services at the beginning.

Deployment notes are tracked as project documentation work. Before using a real deployment, configure provider API keys through environment variables or Rails credentials, keep secrets out of Git, and verify how persistent storage will be handled for SQLite, uploaded files, Action Cable, and background jobs.

## Project Docs

- Product requirements: `docs/PRD.md`
- Data model: `docs/DATA_MODEL.md`
- Original issue backlog: `docs/ISSUES.md`
- LLM response layer: `docs/llm_response_layer.md`
- Design notes: `docs/design/notes.md`
- GitHub issue import notes: `github/issues/README.md`
