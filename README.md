# Support Chatbot

Initial Ruby on Rails application scaffolded with:

- Rails 8
- SQLite
- Hotwire (Turbo + Stimulus)
- Action Cable
- Solid Cache, Solid Queue, and Solid Cable

## Dev Container setup

The dev container installs Ruby and Node with mise, plus the GitHub CLI and Codex CLI. It uses SQLite only; no MySQL or Redis service is required.

1. Reopen the repository in a Dev Container.
2. Let the `postCreateCommand` run `mise trust && mise install && bin/setup --skip-server`.
3. Start the app:

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

5. Start the app:

   ```bash
   bin/rails server
   ```

6. Open http://localhost:3000

## OpenAI provider setup

Development and test use the fake chatbot provider by default so the app can run without OpenAI credentials.

To try the OpenAI provider locally, set:

```bash
cp .env.example .env
```

Then edit `.env`:

```bash
SUPPORT_BOT_PROVIDER=openai
OPENAI_API_KEY=your-api-key
```

Restart `bin/rails server` after changing `.env`.

`OPENAI_API_KEY` can also be stored in Rails credentials under `openai.api_key`.

## Demo flow

- Customer view: create a conversation from `/`, then send messages at `/conversations/:public_id`.
- Operator view: open `/operator/conversations/:public_id` to inspect draft responses, approve a bot draft, send an edited draft, reject a draft with a replacement, or send a direct support reply. After seeding, `/operator/conversations/demo-review-conversation` includes a pending draft.
- Customer-facing replies use the public `support` role while internal bot/operator authorship and review provenance remain stored on messages, drafts, and reviews.

## Run tests

```bash
bin/rails test
```
