# General Support Chatbot - Product Requirements Document

## 1. Overview

Build a personal Ruby on Rails chatbot application for general support use cases. The app should help users ask questions, receive AI-assisted answers grounded in retrieved context, optionally provide files or images when the conversation calls for it, and escalate unresolved or high-risk conversations.

This project is intended to deepen hands-on technical understanding of chatbot systems: conversation UX, RAG architecture, content ingestion, LLM integration, multimodal inputs, background jobs, guardrails, feedback loops, and operational analytics.

The project must be independent from Amazon systems, data, policies, internal designs, screenshots, prompts, metrics, workflows, or proprietary terminology. Sample scenarios and content must be original, public, or explicitly user-provided.

## 2. Goals

- Create a working Rails-based support chatbot MVP that can be adapted to multiple domains.
- Build the full stack personally: backend, frontend, database, background jobs, AI integration, retrieval, ingestion, and deployment.
- Make RAG a core requirement from the first version.
- Keep knowledge sources flexible: manually entered documents, uploaded documents, seeded examples, website content, and later public-source connectors such as Reddit.
- Use OpenAI as the first LLM provider behind a service abstraction.
- Let the chatbot dynamically request file or image uploads inside the conversation when they are useful.
- Publish the project on GitHub with clear documentation and issue tracking.

## 3. Non-Goals

- Do not use proprietary Amazon data, workflows, policy text, screenshots, metrics, or internal terminology.
- Do not build for a single specialized support domain.
- Do not build a production-grade contact center platform in the MVP.
- Do not prioritize operator/admin UX polish in the first version.
- Do not support voice, SMS, WhatsApp, or mobile-native clients in the first release.
- Do not scrape websites in ways that violate terms of service, robots rules, copyright, privacy expectations, or rate limits.

## 4. Target Users

### Primary User: Support Seeker

A person who needs help with a question, issue, or decision in a particular support domain. The domain should be configurable through the knowledge sources and system prompt rather than hard-coded into the application.

### Secondary User: Builder / Operator

The developer or owner of the app who configures knowledge sources, reviews conversations, checks escalations, and improves chatbot quality over time.

## 5. MVP User Problems

- Users need fast, conversational answers without navigating static help content.
- Users often ask short, ambiguous questions that need clarification.
- Some issues are unsafe, unsupported, or high-impact and should be escalated or handled carefully.
- The chatbot needs to answer from retrievable context, not only from general model knowledge.
- The builder may not have a pre-existing knowledge base and needs flexible ways to add or ingest context.
- Some support scenarios require an image or file, but upload controls should appear only when the conversation needs them.

## 6. MVP Scope

### Chat Experience

- Start a new support conversation.
- Send and receive chat messages.
- See a typing/loading state while the bot response is processed.
- Ask follow-up questions in the same conversation.
- Receive clarifying questions when the request is ambiguous.
- Receive a dynamic upload prompt when the bot determines that an image or file would help.
- Upload an image or file only after that conversational prompt appears.
- See escalation messaging for unsupported, unsafe, or low-confidence situations.
- Rate a bot answer as helpful or not helpful.

### AI Answering

- Use OpenAI as the first LLM provider through a service abstraction.
- Generate responses from conversation history and retrieved context.
- Use background jobs from the beginning for bot response generation.
- Refuse or escalate questions outside the configured support domain.
- Use a structured response contract that includes answer text, confidence, category, source references, upload request, escalation recommendation, and escalation reason.

### RAG and Knowledge Sources

- Store normalized knowledge documents in the application database.
- Support manual knowledge entries from the beginning.
- Support a seeded example knowledge set that is original and generic.
- Support keyword-only retrieval first, with interfaces designed for embeddings/vector search later.
- Track source documents used by each answer.
- Design ingestion around flexible source types: manual text, uploaded files, URLs, and future public-source connectors.
- Treat Reddit ingestion as a future connector that should use approved APIs or compliant public access patterns, with clear source attribution and rate limiting.

### File and Image Uploads

- Do not show file upload as a permanent default chat control in the MVP.
- Allow the bot to ask the user for a file or image as part of the conversation.
- When the bot asks for an upload, render an upload control in the thread.
- Store uploaded files through Rails Active Storage.
- Associate uploads with the relevant conversation and message.
- For images, send the image to the OpenAI model only when the provider and selected model support image input.
- For non-image files, extract text where practical and add it as conversation-specific context.

### Escalation

- Create an escalation record from a conversation.
- Capture reason, status, summary, and conversation link.
- Allow basic status updates.
- Keep escalation UX simple in the MVP.

### Minimal Operator Tools

- Provide basic screens or console-friendly workflows to inspect conversations, source documents, feedback, and escalations.
- Provide basic management for knowledge documents.
- Do not invest heavily in operator/admin UX polish until the chatbot and RAG loop are working.

### GitHub-Ready Project Hygiene

- README with setup steps, environment variables, architecture overview, and demo flow.
- Issue backlog managed in GitHub.
- Basic test coverage for models, services, jobs, and core request flows.

## 7. Future Scope

- Embeddings-based vector search.
- Reddit connector using approved API access and configurable subreddit/topic ingestion.
- Additional web connectors and scheduled refresh jobs.
- Streaming responses.
- Multi-channel support.
- Rich response cards and guided flows.
- Review queue for low-confidence answers.
- A/B testing prompts and retrieval strategies.
- Evaluation set for regression testing bot quality.
- Production observability dashboards.
- More polished operator/admin experience.

## 8. Key User Stories

### Support Seeker

- As a user, I want to ask a support question in plain language so that I can get help quickly.
- As a user, I want the bot to ask a clarifying question when my issue is unclear so that I get a relevant answer.
- As a user, I want the bot to ask for an image or file only when it would help solve my issue.
- As a user, I want to upload an image or file in the conversation when the bot requests it.
- As a user, I want to know when the bot cannot help so that I can escalate the issue.
- As a user, I want to rate whether an answer helped me so that the product can improve.

### Builder / Operator

- As the builder, I want a clean Rails architecture so that I can understand each chatbot subsystem.
- As the builder, I want a provider abstraction for OpenAI calls so that I can change model providers later.
- As the builder, I want flexible source ingestion so that I can experiment without already owning a polished knowledge base.
- As the builder, I want tests and seeded demo data so that the project remains easy to evolve.
- As an operator, I want to review conversations and source usage so that I can understand where the bot succeeds or fails.

## 9. Functional Requirements

### Conversation Management

- The system must create conversations with a unique public identifier.
- The system must persist all user, assistant, and system messages.
- The system must preserve message order.
- The system must allow users to resume a conversation by URL.
- The system must associate uploaded files with the relevant conversation and message.

### Background Bot Response Generation

- The system must enqueue a background job after each user message that requires a bot response.
- The job must coordinate retrieval, OpenAI provider calls, response parsing, message persistence, upload prompts, and escalation.
- The UI must show a pending state while the job is running.
- The system must handle failed jobs with a friendly fallback message and useful logs.

### Bot Response Generation

- The system must call a chatbot orchestration service from the background job.
- The service must retrieve relevant knowledge documents before generating an answer.
- The service must include recent conversation history in the OpenAI request.
- The service must save assistant responses to the conversation.
- The service must mark a response as escalated when escalation is recommended.
- The service must mark a response as requesting an upload when the model determines that a file or image is needed.

### RAG Retrieval

- The MVP must use keyword-only retrieval first.
- The retrieval service must search normalized knowledge documents.
- The retrieval layer must be isolated so embeddings and vector search can be added later.
- Retrieved source documents must be tracked with the assistant response when practical.
- Retrieval must exclude disabled, draft, archived, or failed-ingestion documents.

### Knowledge Ingestion

- The system must support manual creation of knowledge documents.
- The system should support uploaded text-like files when practical.
- The system should support URL-based ingestion after the manual MVP is working.
- The ingestion model must track source type, source URL or filename, status, extracted text, and metadata.
- Ingestion jobs must run in the background.
- Public web or Reddit ingestion must include compliance checks before implementation.

### Dynamic Upload Request

- The bot response contract must support an upload request field.
- Upload requests must specify accepted type: image, document, or either.
- The chat UI must render an upload affordance only when the latest assistant response requests it.
- The upload control must attach the uploaded file to the conversation.
- Uploaded images can be passed to OpenAI for multimodal analysis when supported.
- Uploaded documents should be text-extracted or stored for future extraction when unsupported.

### Escalation

- The system must create an escalation when the bot identifies safety, emergency, legal, account-critical, payment-critical, privacy-sensitive, or unsupported issues.
- The system must allow basic escalation status updates.
- The system must show escalation state in the conversation view.

### Feedback

- The system must let users rate assistant messages.
- The system must optionally capture a short free-text feedback note.
- The system must expose feedback for later review.

### Authentication

- The application must support simple local authentication for operator-only routes.
- Operator passwords must not be stored in plain text.
- Public chat routes should not require authentication for the MVP unless abuse becomes a concern.

## 10. Non-Functional Requirements

- The application should be easy to run locally.
- The app should use background jobs from the beginning.
- The MVP should be deployable to a common Rails-friendly host.
- Secrets must be stored in environment variables or Rails credentials, never committed.
- AI failures should degrade gracefully with a friendly fallback message.
- The app should avoid storing sensitive personal data in sample flows.
- The chat UI should be responsive enough for mobile-width usage.
- Core services and jobs should have automated tests.
- Source ingestion must be rate-limited and respectful of external source constraints.

## 11. Proposed Technical Stack

- Ruby on Rails 8 or current stable Rails version.
- PostgreSQL for application data.
- Active Storage for file and image uploads.
- Hotwire/Turbo for chat updates and pending states.
- Tailwind CSS or Rails-native styling approach selected at setup time.
- Solid Queue or Active Job for background bot response and ingestion jobs.
- OpenAI provider behind an internal Ruby service interface.
- Keyword retrieval first using PostgreSQL-backed search.
- Optional future: pgvector for embeddings-based retrieval.

## 12. Deployment Target

Deployment target means the hosting environment where the Rails app, database, background worker, file storage, and environment variables will run after local development.

Recommended first target: Render.

Render is a good early choice because it can host a Rails web service, PostgreSQL database, background worker, environment variables, and simple deploys from GitHub without much infrastructure setup.

Alternatives:

- Fly.io: strong Rails support and more control, but slightly more operational complexity.
- Heroku: very simple developer experience, but may be more expensive for always-on hobby apps.
- Railway: fast to start, good for prototypes, but production conventions may need more care later.
- AWS: valuable to learn, but unnecessary complexity for the first personal MVP.

The PRD assumes Render for initial deployment documentation unless a different target is chosen later.

## 13. Core Data Model

### Conversation

- public_id
- status
- category
- escalated_at
- resolved_at
- timestamps

### Message

- conversation_id
- role: user, assistant, system
- body
- metadata
- timestamps

### KnowledgeDocument

- title
- source_type: manual, upload, url, reddit
- source_identifier
- category
- body
- extracted_text
- status: draft, processing, active, failed, archived
- metadata
- timestamps

### RetrievalResult

- message_id
- knowledge_document_id
- score
- rank
- metadata
- timestamps

### BotResponse

- message_id
- confidence
- category
- escalation_recommended
- escalation_reason
- upload_requested
- upload_type: image, document, either
- raw_provider_response
- timestamps

### Upload

- conversation_id
- message_id
- active_storage_attachment
- file_type
- processing_status
- extracted_text
- metadata
- timestamps

### Escalation

- conversation_id
- status: open, in_review, resolved, closed
- reason
- summary
- timestamps

### Feedback

- message_id
- rating: helpful, not_helpful
- note
- timestamps

### OperatorUser

- email
- password_digest or authentication-provider fields
- timestamps

## 14. Bot Behavior Principles

- Be concise and action-oriented.
- Ask a clarifying question when needed.
- Ground answers in retrieved context.
- State when retrieved context is insufficient.
- Ask for a file or image only when it materially helps the answer.
- Avoid pretending to perform real-world actions.
- Escalate safety, emergency, legal, payment-critical, account-critical, privacy-sensitive, or unsupported issues.
- Clearly state limitations.
- Never claim access to real accounts, private systems, payments, personal records, or internal tools.

## 15. Example Supported Domains

The app should be domain-flexible. Example domains for testing:

- Product troubleshooting.
- Local service support.
- Marketplace seller support.
- Creator or community support.
- Travel planning support.
- Hobby research support using public sources.
- Policy or FAQ assistant for a small website.

## 16. Success Metrics

- MVP can handle at least 20 seeded generic support scenarios.
- RAG retrieval is used for all normal bot answers.
- At least 80% of seeded simple questions receive an answer grounded in retrieved context.
- Escalation is triggered for all seeded safety, legal, privacy-sensitive, and account-critical scenarios.
- Dynamic upload request appears only when the bot asks for an image or file.
- Chat flow works on desktop and mobile widths.
- Builder can add or update knowledge documents without code changes.
- README allows a new developer to run the app locally.

## 17. Milestones

### Milestone 1: Project Foundation

Create Rails app, data models, background job setup, basic UI shell, README, and seeded generic support content.

### Milestone 2: Chat MVP

Implement conversation creation, message persistence, background bot orchestration, and visible assistant responses.

### Milestone 3: RAG and Source Ingestion

Add keyword retrieval, knowledge document management, source tracking, structured AI responses, and ingestion foundations.

### Milestone 4: Dynamic Uploads and Escalation

Add conversational upload requests, Active Storage uploads, image/document handling, feedback, and escalation records.

### Milestone 5: Polish and Publish

Add tests, lightweight analytics, documentation, deployment notes for Render, and GitHub issue/project hygiene.

## 18. Decisions

- First LLM provider: OpenAI.
- First bot processing mode: background jobs from the beginning.
- First authentication approach: simple local authentication for operator-only routes.
- First deployment target for docs: Render.
- First retrieval method: keyword-only retrieval over normalized knowledge documents.

## 19. Open Questions

- Which exact OpenAI model should be the default at implementation time?
- Which file types should be supported first beyond common image formats?
- Should URL ingestion ship in the MVP or immediately after manual knowledge document support?
- What first demo domain should be used for seeded content?
