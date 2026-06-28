# Support Chatbot

Initial Ruby on Rails application scaffolded with:

- Rails 8
- SQLite
- Hotwire (Turbo + Stimulus)
- Action Cable
- Solid Cache, Solid Queue, and Solid Cable

## Dev Container setup

The dev container installs Ruby, Node, GitHub CLI, and Codex CLI with mise. It uses SQLite only; no MySQL or Redis service is required.

1. Reopen the repository in a Dev Container.
2. Run setup the first time, or after dependencies change:

   ```bash
   bin/setup --skip-server
   ```

3. Start the app when needed:

   ```bash
   bin/dev
   ```

4. Open http://localhost:3000

## Local setup

1. Install mise, then install project tools:

   ```bash
   mise trust
   mise install
   gem install bundler -v 4.0.13
   ```

2. Install dependencies:

   ```bash
   bundle install
   ```

3. Prepare the database:

   ```bash
   bin/rails db:prepare
   ```

4. Load demo operator and bot records:

   ```bash
   bin/rails db:seed
   ```

   Seeds create a demo operator, a bot agent, a demo review conversation, and original ecommerce support policy documents for local retrieval testing.

5. Start the app:

   ```bash
   bin/rails server
   ```

6. Open http://localhost:3000

## LLM provider setup

Development and test use the fake chatbot provider by default so the app can run without LLM credentials.

To try the OpenAI provider locally, set:

```bash
cp .env.example .env
```

Then edit `.env`:

```bash
SUPPORT_BOT_PROVIDER=openai
OPENAI_API_KEY=your-api-key
```

To try an OpenAI-compatible provider such as Fireworks AI, set:

```bash
SUPPORT_BOT_PROVIDER=fireworks
FIREWORKS_API_KEY=your-fireworks-api-key
```

The `fireworks` provider defaults to `https://api.fireworks.ai/inference/v1` and the `accounts/fireworks/models/kimi-k2p6` model. Override them with `FIREWORKS_BASE_URL` and `FIREWORKS_MODEL`.

To use a different OpenAI-compatible provider, set:

```bash
SUPPORT_BOT_PROVIDER=openai_compatible
LLM_API_KEY=your-api-key
LLM_BASE_URL=https://your-provider.example/v1
LLM_MODEL=your-model-name
```

Restart `bin/rails server` after changing `.env`.

`OPENAI_API_KEY` can also be stored in Rails credentials under `openai.api_key`.
`FIREWORKS_API_KEY` can also be stored in Rails credentials under `fireworks.api_key`.
`LLM_API_KEY` can also be stored in Rails credentials under `llm.api_key`.

## Demo flow

- Customer view: create a conversation from `/`, then send messages at `/conversations/:public_id`.
- Operator view: open `/operator/conversations/:public_id` to inspect draft responses, approve a bot draft, send an edited draft, reject a draft with a replacement, or send a direct support reply. After seeding, `/operator/conversations/demo-review-conversation` includes a pending draft.
- Customer-facing replies use the public `support` role while internal bot/operator authorship and review provenance remain stored on messages, drafts, and reviews.

## Run tests

```bash
bin/rails test
```
