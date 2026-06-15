# Support Chatbot

Initial Ruby on Rails application scaffolded with:

- Rails 8
- SQLite
- Hotwire (Turbo + Stimulus)
- Action Cable
- Solid Cache, Solid Queue, and Solid Cable

## Local setup

1. Install Ruby 3.3.8 and Bundler.
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

## Demo flow

- Customer view: create a conversation from `/`, then send messages at `/conversations/:public_id`.
- Operator view: open `/operator/conversations/:public_id` to inspect draft responses, approve a bot draft, send an edited draft, reject a draft with a replacement, or send a direct support reply. After seeding, `/operator/conversations/demo-review-conversation` includes a pending draft.
- Customer-facing replies use the public `support` role while internal bot/operator authorship and review provenance remain stored on messages, drafts, and reviews.

## Run tests

```bash
bin/rails test
```
