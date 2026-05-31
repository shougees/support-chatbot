# GitHub Issue Backlog

This file contains GitHub-ready issues for the first version of the general support chatbot. Suggested labels are included so the backlog can become a GitHub project board later.

## Milestone 1: Project Foundation

### Issue 1: Initialize Rails Application

**Labels:** `setup`, `rails`, `mvp`

Create the initial Ruby on Rails application and commit the baseline project structure.

**Acceptance Criteria**

- Rails app is created with PostgreSQL.
- App boots locally.
- Default route renders a basic home or chat entry page.
- README includes local setup instructions.
- Secrets and local environment files are excluded from Git.

---

### Issue 2: Add Core Data Models

**Labels:** `backend`, `database`, `mvp`

Create the initial database schema for conversations, messages, knowledge documents, retrieval results, bot responses, uploads, escalations, feedback, and operator users.

**Acceptance Criteria**

- Models and migrations exist for the core entities.
- Basic model associations are defined.
- Model validations cover required fields.
- Schema supports message ordering and conversation status.
- Model tests cover associations and validations.

---

### Issue 3: Add Seed Knowledge Documents

**Labels:** `content`, `knowledge-base`, `mvp`

Create original sample support documents for generic support scenarios.

**Acceptance Criteria**

- Seed file creates at least 12 active knowledge documents.
- Documents cover a generic demo domain that is not tied to any real company or specialized support workflow.
- Content is generic and does not use proprietary company language.
- Running seeds is documented in README.

---

### Issue 4: Create Basic Application Layout

**Labels:** `frontend`, `ui`, `mvp`

Create a clean responsive layout for the support chat and minimal operator areas.

**Acceptance Criteria**

- App has a consistent header/navigation pattern.
- Chat page works at mobile and desktop widths.
- Operator pages use a simple functional layout.
- Empty, loading, and error states are visually handled.

## Milestone 2: Chat MVP

### Issue 5: Build Conversation Start Flow

**Labels:** `frontend`, `backend`, `chat`, `mvp`

Allow a user to start a new support conversation.

**Acceptance Criteria**

- User can create a new conversation from the landing route.
- Conversation receives a unique public URL.
- User is redirected to the conversation chat screen.
- Conversation status starts as open.

---

### Issue 6: Implement Message Creation

**Labels:** `backend`, `chat`, `mvp`

Allow users to submit chat messages and persist them in order.

**Acceptance Criteria**

- Chat form creates a user message.
- Messages appear in chronological order.
- Blank messages are rejected.
- Conversation page updates after message submission.
- Request specs cover successful and invalid submissions.

---

### Issue 7: Build Chat UI

**Labels:** `frontend`, `chat`, `mvp`

Create the user-facing chat interface.

**Acceptance Criteria**

- Messages have visually distinct user and assistant styling.
- Chat input remains easy to use on mobile widths.
- Loading state appears while waiting for a bot response.
- Escalation state can be shown in the conversation.
- UI avoids exposing implementation details to the user.

---

### Issue 8: Add Bot Orchestration Service

**Labels:** `backend`, `ai`, `chat`, `mvp`

Create a service object that coordinates retrieval, OpenAI provider calls, response parsing, message persistence, upload requests, and escalation.

**Acceptance Criteria**

- Service accepts a conversation and latest user message.
- Service retrieves relevant knowledge documents.
- Service calls the OpenAI provider abstraction.
- Service saves an assistant message.
- Service records bot response metadata.
- Unit tests cover success, fallback, upload request, and escalation paths.

---

### Issue 9: Add Background Bot Response Jobs

**Labels:** `backend`, `jobs`, `chat`, `mvp`

Run bot response generation in a background job from the beginning.

**Acceptance Criteria**

- User message creation enqueues a bot response job.
- Chat UI shows a pending state while the job is running.
- Job calls the bot orchestration service.
- Failed jobs create or expose a friendly fallback state.
- Tests cover enqueueing and job success/failure behavior.

## Milestone 3: RAG and Source Ingestion

### Issue 10: Add OpenAI Provider Interface

**Labels:** `backend`, `ai`, `architecture`, `mvp`

Add an internal interface for OpenAI responses so model usage stays isolated and providers can be swapped later.

**Acceptance Criteria**

- Provider interface has a clear request and response contract.
- First implementation can use a fake provider in development/test.
- OpenAI credentials are read from environment or Rails credentials.
- Provider errors return a controlled failure object.
- Tests do not require live network calls.

---

### Issue 11: Implement Keyword RAG Retrieval

**Labels:** `backend`, `knowledge-base`, `search`, `mvp`

Implement the required first-pass RAG retrieval service using database-backed keyword search.

**Acceptance Criteria**

- Retrieval accepts a user question and returns relevant active knowledge documents.
- Archived, draft, failed, and processing documents are excluded.
- Results are capped to a configurable number.
- Service is isolated behind a clear interface.
- Tests cover matching, no-match, and status filtering.

---

### Issue 12: Add Structured Bot Response Parsing

**Labels:** `backend`, `ai`, `mvp`

Parse model responses into structured fields the application can trust.

**Acceptance Criteria**

- Bot response includes answer text, confidence, category, escalation flag, escalation reason, source references, upload request flag, and requested upload type.
- Invalid or incomplete provider responses trigger a fallback message.
- Low-confidence responses can recommend escalation.
- Bot can request image, document, or either upload type.
- Parsing behavior is covered by tests.

---

### Issue 13: Track Source Documents

**Labels:** `backend`, `knowledge-base`, `analytics`

Track which knowledge documents were used for each assistant response.

**Acceptance Criteria**

- Retrieval results store source document IDs, scores, and ranks.
- Operator conversation view can show source document titles.
- Missing or deleted source documents do not break conversation rendering.
- Tests cover source persistence.

---

### Issue 14: Add Knowledge Document Management

**Labels:** `operator`, `knowledge-base`, `frontend`, `mvp`

Allow the builder/operator to create, edit, activate, archive, and view knowledge documents.

**Acceptance Criteria**

- Operator can list knowledge documents.
- Operator can create and edit title, category, body, source type, and status.
- Active documents are available for retrieval.
- Draft, processing, failed, and archived documents are not used in bot answers.
- Form validation errors are clear.

---

### Issue 15: Add Ingestion Model and Background Job Foundation

**Labels:** `backend`, `knowledge-base`, `jobs`, `mvp`

Create the foundation for flexible knowledge ingestion from manual text, uploads, URLs, and future public-source connectors.

**Acceptance Criteria**

- Knowledge document stores source type, source identifier, extracted text, status, and metadata.
- Ingestion jobs can process a document asynchronously.
- Manual text ingestion works in the MVP.
- URL and Reddit source types are represented but can remain disabled until implemented.
- README documents compliance expectations for public web and Reddit ingestion.

## Milestone 4: Dynamic Uploads and Escalation

### Issue 16: Add Dynamic Upload Request UI

**Labels:** `frontend`, `uploads`, `chat`, `mvp`

Show file or image upload controls only when the assistant asks for an upload in the conversation.

**Acceptance Criteria**

- Chat UI does not show upload as a default always-on control.
- Assistant response can render an upload request in the thread.
- Upload request specifies image, document, or either.
- Upload control attaches the file to the relevant conversation.
- UI handles upload success and failure states.

---

### Issue 17: Add Active Storage Upload Handling

**Labels:** `backend`, `uploads`, `mvp`

Persist uploaded files and associate them with conversations and messages.

**Acceptance Criteria**

- Active Storage is configured.
- Upload model or equivalent association exists.
- Uploaded files are associated with conversation and message context.
- Basic image file validation is implemented.
- Unsupported file types are rejected with clear errors.
- Tests cover successful and invalid uploads.

---

### Issue 18: Add Escalation Workflow

**Labels:** `backend`, `operator`, `support-ops`, `mvp`

Create escalation records when the bot cannot safely or confidently resolve an issue.

**Acceptance Criteria**

- Escalation can be created from bot orchestration.
- Escalation has status, reason, summary, and conversation link.
- Conversation reflects escalation state.
- Operator can update escalation status.
- Tests cover escalation creation and updates.

---

### Issue 19: Add Feedback on Bot Answers

**Labels:** `frontend`, `backend`, `analytics`, `mvp`

Allow users to rate assistant responses.

**Acceptance Criteria**

- User can mark an assistant response as helpful or not helpful.
- User can optionally provide a short note.
- Feedback is associated with the assistant message.
- Duplicate feedback for the same message is handled gracefully.
- Operator can see feedback in conversation details.

---

### Issue 20: Build Minimal Operator Conversation Review

**Labels:** `operator`, `frontend`, `support-ops`, `mvp`

Create minimal operator screens for reviewing conversations, messages, feedback, source documents, uploads, and bot metadata.

**Acceptance Criteria**

- Operator can list conversations.
- Operator can filter or visually identify escalated conversations.
- Operator can open a conversation detail page.
- Detail page shows messages, feedback, source documents, confidence, uploads, and escalation status.

---

### Issue 21: Add Basic Operator Authentication

**Labels:** `operator`, `security`, `mvp`

Protect operator screens behind simple local authentication.

**Acceptance Criteria**

- Operator routes require sign-in.
- Operator user can sign in and sign out.
- Passwords are not stored in plain text.
- README documents how to create a local operator user.
- Request specs cover protected routes.

## Milestone 5: Polish and Publish

### Issue 22: Add Lightweight Analytics Dashboard

**Labels:** `operator`, `analytics`, `frontend`

Create a basic dashboard for conversation and bot-performance metrics.

**Acceptance Criteria**

- Dashboard shows total conversations.
- Dashboard shows escalation count and escalation rate.
- Dashboard shows helpfulness rate.
- Dashboard shows top detected categories.
- Dashboard shows recent unresolved or low-confidence conversations.
- Dashboard stays lightweight and functional rather than polished operator UX.

---

### Issue 23: Add Error Handling and Fallback States

**Labels:** `backend`, `frontend`, `quality`

Make AI, retrieval, and form failures graceful for users and visible for debugging.

**Acceptance Criteria**

- AI provider failures return a friendly assistant fallback message.
- Retrieval no-match cases are handled clearly.
- Background job failures are visible and recoverable.
- Server-side validation errors appear in the UI.
- Errors are logged with useful context.
- Tests cover major failure paths.

---

### Issue 24: Add Automated Test Coverage

**Labels:** `testing`, `quality`, `mvp`

Add focused test coverage for the core product flows.

**Acceptance Criteria**

- Model tests cover validations and associations.
- Job tests cover bot response and ingestion jobs.
- Service tests cover bot orchestration, retrieval, parsing, upload requests, and escalation.
- Request/system tests cover conversation creation, message creation, dynamic uploads, feedback, and operator protection.
- Test suite can run locally from README instructions.

---

### Issue 25: Write Project README

**Labels:** `docs`, `github`, `mvp`

Create a polished README for GitHub.

**Acceptance Criteria**

- README explains what the project is and why it exists.
- README includes local setup steps.
- README documents required environment variables.
- README includes demo user flows.
- README includes architecture overview.
- README explains RAG, background jobs, OpenAI setup, dynamic uploads, and deployment target.
- README clearly states that sample content is original, public, or user-provided.

---

### Issue 26: Prepare GitHub Repository

**Labels:** `github`, `setup`, `release`

Prepare the project for public GitHub tracking.

**Acceptance Criteria**

- Repository is initialized.
- `.gitignore` excludes credentials, logs, local databases, and temporary files.
- Issues from this backlog are created in GitHub.
- Milestones are created in GitHub.
- Labels are created or normalized.
- Initial commit is pushed to GitHub.

---

### Issue 27: Add Render Deployment Notes

**Labels:** `docs`, `deployment`

Document how the app can be deployed to Render as the first recommended deployment target.

**Acceptance Criteria**

- Render deployment target is explained in plain language.
- Required environment variables are listed.
- Database setup steps are documented.
- Background worker setup is documented.
- File storage considerations are documented.
- Known limitations are documented.
- README links to deployment notes.

## Suggested Labels

- `ai`
- `analytics`
- `architecture`
- `backend`
- `chat`
- `content`
- `database`
- `deployment`
- `docs`
- `frontend`
- `github`
- `knowledge-base`
- `jobs`
- `mvp`
- `operator`
- `quality`
- `rails`
- `release`
- `search`
- `security`
- `setup`
- `support-ops`
- `testing`
- `ui`
- `uploads`

## Suggested Milestones

- Project Foundation
- Chat MVP
- RAG and Source Ingestion
- Dynamic Uploads and Escalation
- Polish and Publish
