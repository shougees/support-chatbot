# Support Chatbot

Initial Ruby on Rails application scaffolded with:

- Rails 8
- SQLite
- Hotwire (Turbo + Stimulus)
- Action Cable
- Solid Cache, Solid Queue, and Solid Cable

## Local setup

1. Install Ruby 3.2+ and Bundler.
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
