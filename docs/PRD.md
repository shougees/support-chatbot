# Ecommerce Support Chatbot - Product Requirements Document

## 1. Overview

Build a personal Ruby on Rails chatbot application for a hypothetical ecommerce company. The app should help customers resolve order-support issues through chat, receive AI-assisted answers grounded in retrieved context and policy, optionally provide files or images when the conversation calls for it, complete eligible support actions, and route difficult or low-confidence decisions to human support behind the scenes.

This project is intended to deepen hands-on technical understanding of chatbot systems: conversation UX, RAG architecture, content ingestion, LLM integration, multimodal inputs, background jobs, guardrails, feedback loops, and operational analytics.

The product scenario is fictional. Sample scenarios, policies, and content must be original, public, or explicitly user-provided.

## 2. Goals

- Create a working Rails-based ecommerce support chatbot MVP.
- Build the full stack personally: backend, frontend, database, background jobs, AI integration, retrieval, ingestion, and deployment.
- Make RAG a core requirement from the first version.
- Keep knowledge sources flexible: manually entered documents, uploaded documents, seeded examples, website content, and later public-source connectors such as Reddit.
- Use OpenAI as the first LLM provider behind a service abstraction.
- Let the chatbot dynamically request file or image uploads inside the conversation when they are useful.
- Support eligible, policy-compliant customer actions such as refunds, returns, replacements, credits, or cancellation flows through structured application workflows.
- Keep the customer experience chatbot-facing even when a human support agent helps behind the scenes.
- Route low-confidence chatbot decisions to human review using a configurable confidence threshold. The default threshold is 70%.
- Maximize self-serve efficacy without hiding, delaying, or discouraging legitimate human review.
- Publish the project on GitHub with clear documentation and issue tracking.

## 3. Non-Goals

- Do not use private company data, copied support policies, real customer PII, or proprietary workflows.
- Do not build a generic chatbot with no ecommerce support focus.
- Do not build a production-grade contact center platform in the MVP.
- Do not prioritize operator/admin UX polish in the first version.
- Do not support voice, SMS, WhatsApp, or mobile-native clients in the first release.
- Do not scrape websites in ways that violate terms of service, robots rules, copyright, privacy expectations, or rate limits.

## 4. Target Users

### Primary User: Customer

A customer who needs help with an ecommerce order or account issue, such as delivery status, missing items, damaged items, returns, refunds, account questions, or related support concerns.

### Human Support Agent

A support operator who reviews difficult questions and decisions behind the scenes when automation cannot confidently resolve the issue. The customer remains in the chatbot conversation and does not need to know whether a human helped with the decision.

### Builder / Operator Team

Product managers, developers, scientists, QA analysts, business intelligence engineers, and program managers who develop, manage, evaluate, and improve the chat support experience.

## 5. MVP User Problems

- Customers need fast, conversational answers without navigating static help content.
- Customers often ask short, ambiguous questions that need clarification.
- Some issues are unsafe, unsupported, low-confidence, or high-impact and should be routed to human review.
- Customers may ask for an agent or human support, but the customer-facing experience should remain a chatbot conversation.
- The chatbot needs to answer from retrievable context, not only from general model knowledge.
- Policy can change over time, and chatbot answers need to reflect the latest active policy.
- Some customer situations are complicated enough that the chatbot cannot confidently decide whether to approve an action, such as a refund.
- The builder may not have a polished pre-existing knowledge base and needs flexible ways to add or ingest context.
- Some support scenarios require an image or file, but upload controls should appear only when the conversation needs them.

## 6. MVP Scope

### Chat Experience

- Start a new ecommerce support conversation.
- Send and receive chat messages.
- See a typing/loading state while the bot response is processed.
- Ask follow-up questions in the same conversation.
- Receive clarifying questions when the request is ambiguous.
- Receive a dynamic upload prompt when the bot determines that an image or file would help.
- Upload an image or file only after that conversational prompt appears.
- Continue interacting with the chatbot even when a human support agent is helping behind the scenes.
- Receive a final chatbot response once low-confidence or human-reviewed decisions are resolved.
- Rate a bot answer as helpful or not helpful.

### AI Answering

- Use OpenAI as the first LLM provider through a service abstraction.
- Generate responses from conversation history and retrieved context.
- Use background jobs from the beginning for bot response generation.
- Refuse or route questions outside the configured support domain to human review when needed.
- Assign a confidence score to each response or proposed decision.
- Route responses or decisions below the configurable confidence threshold to human review before the chatbot responds with a final decision.
- Use a structured response contract that includes answer text, confidence, category, source references, upload request, proposed action, human review recommendation, and review reason.

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

### Human Review

- Create a human review record when the chatbot confidence score is below the configured threshold or when policy requires review.
- Default the human review threshold to 70%, and make it configurable.
- Capture reason, status, summary, key decision needed, confidence score, and conversation link.
- Keep the customer-facing conversation in the chatbot thread while review happens behind the scenes.
- Do not expose whether a human support agent helped unless a future product decision explicitly changes that.

### Support Actions

- Represent customer-impacting actions as structured application workflows, not free-form model behavior.
- Support initial action types such as refund, return, replacement, credit, cancellation, or human-review request.
- Validate proposed actions against policy, customer/order context, and action eligibility before execution.
- Record action decisions and outcomes for auditability.
- Route complicated or low-confidence action decisions, such as whether to issue a refund, to human review.

### Human Support Workspace

- Provide a separate service/product surface for human support agents.
- Let human support agents view the chatbot/customer transcript.
- Surface the key decision needed, such as approve refund, deny refund, request more information, or route for further review.
- Provide accept and deny controls for decisions that the chatbot can consume.
- Allow a human support agent to send a message into the customer conversation when needed. The customer sees the message as part of the same chatbot/support thread, not as a separate visible transfer to an agent.
- Provide basic screens or console-friendly workflows to inspect conversations, source documents, feedback, human reviews, and support actions.
- Provide basic management for knowledge documents.
- Do not invest heavily in operator/admin UX polish until the chatbot, RAG loop, and human-review loop are working.

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

### Customer

- As a customer, I want to ask an order-support question in plain language so that I can get help quickly.
- As a customer, I want the bot to use available order/support context so that I do not need to explain everything from scratch.
- As a customer, I want the bot to ask a clarifying question when my issue is unclear so that I get a relevant answer.
- As a customer, I want the bot to ask for an image or file only when it would help solve my issue.
- As a customer, I want to upload an image or file in the conversation when the bot requests it.
- As a customer, I want eligible actions such as refunds or returns to be handled in chat when policy allows it.
- As a customer, I want the chatbot to resolve my issue even when the decision is complicated.
- As a customer, I want to stay in one chatbot conversation even if a human support agent helps behind the scenes.
- As a customer, I want to rate whether an answer helped me so that the product can improve.

### Builder / Operator

- As the builder, I want a clean Rails architecture so that I can understand each chatbot subsystem.
- As the builder, I want a provider abstraction for OpenAI calls so that I can change model providers later.
- As the builder, I want flexible source ingestion so that I can experiment without already owning a polished knowledge base.
- As the builder, I want tests and seeded demo data so that the project remains easy to evolve.
- As a human support agent, I want to review the chatbot/customer transcript and key decision needed so that I can quickly approve or deny difficult cases.
- As an operator, I want to review conversations, source usage, actions, and human reviews so that I can understand where the bot succeeds or fails.

## 9. Functional Requirements

### Conversation Management

- The system must create conversations with a unique public identifier.
- The system must persist all user, assistant, and system messages.
- The system must preserve message order.
- The system must allow users to resume a conversation by URL.
- The system must associate uploaded files with the relevant conversation and message.

### Background Bot Response Generation

- The system must enqueue a background job after each user message that requires a bot response.
- The job must coordinate retrieval, OpenAI provider calls, response parsing, message persistence, upload prompts, human review, and support actions.
- The UI must show a pending state while the job is running.
- The system must handle failed jobs with a friendly fallback message and useful logs.

### Bot Response Generation

- The system must call a chatbot orchestration service from the background job.
- The service must retrieve relevant knowledge documents before generating an answer.
- The service must include recent conversation history in the OpenAI request.
- The service must save assistant responses to the conversation.
- The service must support structured proposed actions, such as refund, return, replacement, credit, cancellation, or human-review request.
- The service must assign and persist confidence scores.
- The service must route responses or proposed decisions below the configured confidence threshold to human review.
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

### Human Review

- The system must create a human review when the chatbot confidence score is below the configured threshold. The default threshold is 70%.
- The confidence threshold must be configurable without code changes.
- The system must create a human review when the bot identifies safety, emergency, legal, payment-critical, account-critical, privacy-sensitive, fraud, identity, chargeback, policy-conflict, or unsupported issues.
- The customer must remain in the chatbot conversation while human review happens behind the scenes.
- The system must not require a customer action phrase, such as "agent" or "human", to trigger human review.
- Customer requests for an agent may be considered conversational context, but routing to human review is determined by confidence, policy, risk, and decision eligibility.
- The system must allow basic human review status updates.
- The system must show human review state in operator-facing views.
- The system must not disclose whether a human agent helped unless a future product decision explicitly changes that behavior.

### Human Support Workspace

- The system must provide a separate operator-facing surface for human support agents.
- Human support agents must be able to view the chatbot/customer transcript.
- Human support agents must be able to see the key decision needed and the context behind that decision.
- The workspace must provide accept and deny controls for supported decisions.
- Human decisions must be saved in a structured format that the chatbot orchestration service can consume.
- Human support agents must be able to send a message into the customer conversation when needed.
- Customer-facing human-assisted messages must appear inside the same chatbot/support thread.

### Support Action Handling

- The system must distinguish model-suggested actions from application-approved actions.
- The system must validate proposed actions against retrieved policy and available customer/order context.
- The system must avoid executing customer-impacting actions when required context is missing.
- The system must create an auditable record for proposed, approved, denied, and completed actions.
- The system must request human review when policy is ambiguous, action eligibility cannot be determined, or confidence is below the configured threshold.

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
- SQLite for initial application data.
- Active Storage for file and image uploads.
- Hotwire/Turbo for chat updates and pending states.
- Tailwind CSS or Rails-native styling approach selected at setup time.
- Solid Queue or Active Job for background bot response and ingestion jobs.
- OpenAI provider behind an internal Ruby service interface.
- Keyword retrieval first using SQLite-backed search.
- Optional future: SQLite vector extension or external vector store for embeddings-based retrieval.

## 12. Deployment Target

Deployment target means the hosting environment where the Rails app, database, background worker, file storage, and environment variables will run after local development.

Recommended first target: Render.

Render is a good early choice because it can host a Rails web service, background worker, environment variables, persistent storage options, and simple deploys from GitHub without much infrastructure setup.

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
- human_review_requested_at
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
- proposed_action_type
- proposed_action_payload
- human_review_recommended
- human_review_reason
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

### HumanReview

- conversation_id
- message_id
- status: open, in_review, accepted, denied, resolved, closed
- reason
- summary
- confidence
- key_decision
- decision_payload
- agent_response
- timestamps

### SupportAction

- conversation_id
- message_id
- action_type: refund, return, replacement, credit, cancellation, human_review
- status: proposed, approved, denied, completed, failed, requires_review
- policy_reference_ids
- eligibility_reason
- metadata
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
- Request behind-the-scenes human review for safety, emergency, legal, payment-critical, account-critical, privacy-sensitive, fraud, identity, chargeback, policy-conflict, unsupported, or low-confidence issues.
- Do not make customer-visible promises that a human is or is not involved.
- Use human decisions as structured input to the chatbot response when review is completed.
- Use "we" instead of "I" when speaking as the chatbot or support system.
- Avoid first-person singular phrasing such as "I can," "I will," or "I found."
- Clearly state limitations.
- Never claim access to real accounts, private systems, payments, personal records, or internal tools.

## 15. Example Supported Ecommerce Scenarios

Example scenarios for testing:

- Order delivery status.
- Missing item.
- Damaged item.
- Late delivery.
- Return eligibility.
- Refund eligibility.
- Replacement request.
- Account access question.
- Policy clarification.
- Behind-the-scenes human review for a complicated refund decision.

## 16. Success Metrics

- MVP can handle at least 20 seeded ecommerce support scenarios.
- RAG retrieval is used for all normal bot answers.
- At least 80% of seeded simple questions receive an answer grounded in retrieved context.
- Self-serve efficacy is tracked as the primary success metric.
- Self-serve success only counts when the issue is plausibly resolved, policy-compliant, and not merely deflected.
- Self-serve efficacy must not be optimized by hiding, delaying, or discouraging legitimate human review.
- Human review is triggered for all seeded safety, emergency, legal, payment-critical, account-critical, privacy-sensitive, fraud, identity, chargeback, policy-conflict, and sub-70% confidence scenarios.
- Human review threshold defaults to 70% and can be configured.
- Dynamic upload request appears only when the bot asks for an image or file.
- Chat flow works on desktop and mobile widths.
- Builder can add or update knowledge documents without code changes.
- README allows a new developer to run the app locally.

## 17. Milestones

### Milestone 1: Project Foundation

Create Rails app, data models, background job setup, basic UI shell, README, and seeded ecommerce support content.

### Milestone 2: Chat MVP

Implement conversation creation, message persistence, background bot orchestration, and visible assistant responses.

### Milestone 3: RAG and Source Ingestion

Add keyword retrieval, knowledge document management, source tracking, structured AI responses, and ingestion foundations.

### Milestone 4: Dynamic Uploads and Human Review

Add conversational upload requests, Active Storage uploads, image/document handling, feedback, human review records, and human decision consumption.

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
- Which seeded ecommerce policy/action scenarios should be prioritized first?
