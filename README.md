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

4. Start the app:

   ```bash
   bin/rails server
   ```

5. Open http://localhost:3000

## Run tests

```bash
bin/rails test
```
