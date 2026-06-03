# AGENTS.md

Guidance for Codex and other coding agents working on this repository.

## What This Project Is

This is a personal Ruby on Rails project for learning how to build and improve an AI-assisted chat support system.

The product scenario is a hypothetical ecommerce company. The initial support use case should focus on customer-facing order support, including delivery status, missing items, damaged items, returns, refunds, account questions, and handoff to a human support agent.

This project must remain fictional and independent. Use original sample content or clearly public/user-provided sources.

Primary product docs:

- `docs/PRD.md`: product requirements and architectural direction.
- `docs/ISSUES.md`: original GitHub issue backlog.
- `docs/design/`: UX reference notes and images.

## Product Actors

The support experience has multiple actors:

- Customer: the primary user asking for help.
- Chatbot: the automated support assistant.
- Human support agent: the operator who takes over when automation cannot or should not resolve the issue.
- Product manager: defines support experiences, success metrics, and improvement priorities.
- Developer: builds and maintains the application.
- Scientist / ML practitioner: improves retrieval, model behavior, evaluation, and quality loops.
- QA analyst: validates flows, regressions, policy compliance, and edge cases.
- Business intelligence engineer: analyzes support outcomes, defects, escalation rates, and operational metrics.
- Program manager: owns policy/process updates and rollout coordination.

When making product or technical choices, consider how these actors would use, operate, evaluate, or improve the system.

## Product Goals

- Provide tailored solutions to customer queries.
- Solve customer issues in an easy, low-effort manner.
- Use available context so customers do not need to explain everything from scratch.
- Combine chatbot automation and human agent support in one coherent chat support experience.
- Make chatbot answers policy-compliant and grounded in current support policy.
- Keep the chatbot flexible so it can be improved iteratively through new policies, better retrieval, prompt changes, evaluations, and user feedback.
- Reflect policy updates made by the program team without requiring hard-coded answer changes.
- Support permissioned actions, such as issuing refunds or processing returns, when the system has enough context and policy allows it.
- Maximize self-serve resolution so the chatbot can solve as many eligible issues as possible without human escalation.

## Success Metrics

The key success metric is self-serve efficacy: the percentage of support sessions where the customer goes through support and does not get escalated to a human agent.

Agents should consider how product and engineering changes affect:

- self-serve efficacy,
- escalation rate,
- repeat contact rate,
- customer effort,
- policy compliance,
- containment quality, meaning the issue was actually resolved rather than merely deflected,
- action success rate for supported workflows such as refunds or returns.

## Product Principles

- Start from the customer problem, not the technology.
- Prefer resolving the issue in chat when it is safe and policy-compliant.
- Use retrieved context and known order/support state before asking the customer for more information.
- Ask concise clarifying questions only when needed.
- Aim for chatbot resolution first when the issue is eligible, safe, and policy-compliant.
- Escalate to a human support agent when the chatbot cannot help, confidence is low, policy requires human review, or the issue is high-risk.
- If a customer asks directly for an agent, human, or representative, the bot should make one concise attempt to resolve the issue before handoff.
- High-risk issues should bypass the one-more-attempt rule and escalate immediately.
- The bot should use "we" instead of first-person singular phrasing like "I can", "I will", or "I found".
- File/image upload should appear conversationally only when the bot asks for it, not as a permanent default chat control.

## Policy And Action Boundaries

Policy compliance is a core product requirement.

- Chatbot answers should be grounded in the latest active policy/support documents.
- Underlying policy should be represented as data or retrievable content, not scattered as hard-coded strings.
- Program-team policy updates should flow into chatbot behavior through knowledge ingestion, retrieval, configuration, or explicit rule updates.
- Any customer-impacting action, such as refunding, replacing, canceling, crediting, or processing a return, must be permissioned, auditable, and reversible where practical.
- The model should not directly execute sensitive actions from free-form text. It should propose structured actions that application code validates against policy and user/context state.
- When policy is missing, ambiguous, or conflicting, escalate or ask for review rather than inventing a rule.
- Do not claim the app can perform real-world account, payment, delivery, refund, or return actions unless that integration actually exists.

## Chat Support Experience

Chat support includes both chatbot and human agents.

- The chatbot should handle common, policy-backed questions and actions.
- Human agents should handle exceptions, ambiguous cases, high-risk issues, repeated failures, or explicit handoff after one bot retry.
- Handoff should preserve conversation history and context so the customer does not need to repeat the issue.
- The product should make it possible to analyze which contacts were resolved by the bot, escalated to humans, or reopened later.
- Customer-facing language should be concise, calm, and action-oriented.

## Design Direction

- The experience should feel trustworthy, simple, and support-oriented.
- Mobile-width chat should be treated as a first-class experience.
- Avoid enterprise-heavy admin polish early; operator tools should be functional and clear.
- Use `docs/design/notes.md` for design intent.
- Do not copy third-party product UI directly.

## Technical Direction

- Rails 8 application.
- SQLite for the initial database.
- Hotwire: Turbo and Stimulus.
- Action Cable.
- Solid Queue, Solid Cache, and Solid Cable.
- Tailwind CSS.
- OpenAI as the first LLM provider, behind an internal service abstraction.
- RAG is an MVP requirement.
- Keyword-only retrieval first, with interfaces that can later support embeddings/vector search.
- Background jobs from the beginning for bot responses, ingestion, and slow actions.

## Engineering Preferences

- Prefer standard Rails conventions over custom architecture.
- Keep controllers thin and move non-trivial behavior into models, jobs, policies, or service objects.
- Use Rails generators when helpful, but review generated files carefully.
- Use Active Record associations and validations rather than ad hoc data handling.
- Use Active Job/Solid Queue for asynchronous bot-response and ingestion work.
- Use Active Storage for uploaded files/images.
- Keep secrets in environment variables or Rails credentials. Never commit secrets.
- Prefer small, reversible changes that map to one GitHub issue.

## GitHub Issue Workflow

When asked to tackle a GitHub issue:

1. Fetch/read the issue from GitHub first when tooling is available.
2. Inspect the current code before changing files.
3. Create or suggest a branch named like `issue-4-basic-layout`.
4. Implement the smallest clean change that satisfies the issue acceptance criteria.
5. Add or update focused tests for the changed behavior.
6. Run relevant checks.
7. Summarize changed files, tests run, and any remaining risks.
8. Do not push or open a PR unless the user explicitly asks.

If GitHub tooling is unavailable, use `docs/ISSUES.md` as a fallback, but note that GitHub may contain newer issue edits.

## Testing And Verification

Before finishing a coding task, run the most relevant checks available:

- `bin/rails test` for test coverage.
- `bin/rubocop` for style when Ruby files change.
- `bin/brakeman` for security-sensitive changes when practical.
- `bin/ci` before larger PR-ready changes.

For chatbot behavior, prefer adding examples, fixtures, or tests that cover:

- policy compliance,
- human handoff,
- one-more-attempt behavior,
- "we" voice,
- low-confidence fallback,
- action eligibility and denial cases.

If a check cannot run because dependencies or local services are missing, say so clearly and include the command attempted.

## Documentation

Update docs when behavior, setup, architecture, or product scope changes:

- Product changes: `docs/PRD.md`.
- Backlog/import details: `docs/ISSUES.md` or `github/issues/README.md`.
- Developer setup: `README.md`.
- Design references: `docs/design/notes.md`.

Keep documentation concise and practical.

## Local Development

Common commands:

```sh
bundle install
bin/rails db:prepare
bin/rails server
bin/rails test
```

The project may be worked on from a Mac mini over SSH/tmux. Avoid assuming files exist only on one local machine; GitHub should remain the source of truth.

## Data And Legal Boundaries

- Do not add real user PII, private company data, internal company material, or copied support policies.
- Use original sample content or clearly public/user-provided sources.
- For public web or Reddit ingestion, respect terms of service, API rules, robots rules, attribution needs, privacy expectations, and rate limits.
- Do not copy competitor or reference product UI. Convert observations into original design patterns.

## Commit Guidance

- Keep commits focused around a single issue or coherent change.
- Use descriptive commit messages, for example `Add core conversation models`.
- Do not rewrite history or reset user changes unless explicitly asked.
- Check `git status` before and after edits.
