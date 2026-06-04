---
annotations_creators:
- machine-generated
- expert-generated
language_creators:
- machine-generated
- found
language:
- en
license: mit
multilinguality:
- monolingual
size_categories:
- 10K<n<100K
source_datasets:
- original
task_categories:
- question-answering
- text-generation
- other
task_ids:
- dialogue-modeling
- open-domain-qa
pretty_name: E-commerce Chatbot Training Data
tags:
- ecommerce
- chatbot
- tool-use
- customer-support
- retail
- conversational-ai
---

# E-commerce Chatbot Training Data

A curated, multi-source dataset for training and evaluating e-commerce conversational AI systems. It covers a broad range of customer intents — from product discovery and order management to returns, tool-augmented responses, and RAG-grounded Q&A — across 16+ product domains.

## Dataset Summary

| Split | Records |
|-------|---------|
| Train | 35,213  |
| Test  | 8,818   |
| **Total** | **44,031** |

The train/test split uses **prompt-group-level stratified sampling** on `source × response_type × intent × difficulty` to guarantee identical distributions across both splits with zero prompt contamination between train and test.

---

## Sources

| Source | Records | Response Types | Domains | Intents |
|--------|---------|----------------|---------|---------|
| `synthetic_api_generated` | 3,933 | text, tool_call, mixed | 12 | 19 |
| `asos_ecom_dataset` | 2,000 | text | fashion | similarity_search |
| `bitext_customer_support` | 5,000 | tool_call, mixed | general | 6 |
| `bitext_retail_ecom` | 4,998 | text, tool_call | general | multiple |
| `amazon_reviews_2023_*` | 23,100 | text | 16 | 4 |
| `amazon_meta_2023_*` | 5,000 | text | 9 | 4 |

---

## Schema

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique record ID (e.g. `ecomm_a1b2c3`) |
| `source` | string | Origin dataset/pipeline |
| `group` | string | Response group: `A` (tool_call), `B` (text), `C` (mixed) |
| `difficulty` | int | Task difficulty: `1` (easy) to `3` (hard) |
| `system` | string | System prompt given to the assistant |
| `history` | string (JSON) | Prior conversation turns `[{"role": ..., "content": ...}]` |
| `prompt` | string | Current user message |
| `context` | string (JSON) | Retrieved docs, user profile, cart/order state |
| `tools` | string (JSON) | Available tool/function definitions |
| `response_type` | string | `text`, `tool_call`, or `mixed` |
| `response` | string | Ground-truth assistant response |
| `language` | string | ISO language code (e.g. `en`) |
| `locale` | string | Locale (e.g. `en-US`) |
| `annotator` | string | Annotation source (e.g. `gemini_synthetic`, `bitext`, `amazon_user`) |
| `quality_score` | float | Annotation quality score (0–1) |
| `domain` | string | Product domain (e.g. `electronics`, `fashion`, `grocery_food`) |
| `intent_category` | string | High-level intent category (e.g. `product_discovery`, `order_management`) |
| `intent` | string | Fine-grained intent (19 values, e.g. `order_status`, `return_refund`) |
| `sub_intent` | string | Further sub-intent (e.g. `track_delivery`, `refund_timeline`) |
| `capability` | string | Model capability tag (where applicable) |
| `test_tier` | string | Evaluation tier tag (where applicable) |

---

## Intents

The dataset covers 19 intents across 7 high-level categories:

| Category | Intents |
|----------|---------|
| Product Discovery | `product_search`, `product_detail_qa`, `product_comparison`, `similarity_search`, `bundle_suggestions`, `gift_recommendation`, `personalized_recommendations` |
| Order Management | `order_status`, `order_cancellation`, `reorder_assistance` |
| Returns & Exchanges | `return_refund`, `exchange_request` |
| Cart & Checkout | `cart_management`, `payment_issues` |
| Customer Support | `complaint_handling`, `human_handoff`, `faq_answering` |
| Account | `account_management` |
| Inventory | `stock_availability` |

---

## Product Domains

`appliances`, `beauty`, `books_media`, `electronics`, `fashion`, `gaming`, `garden_outdoor`, `grocery_food`, `home_kitchen`, `industrial`, `pet_supplies`, `sports_outdoors`, `automotive`, `baby`, `health`, `office`, `toys_games`

---

## Usage

```python
from datasets import load_dataset

ds = load_dataset("V1rtucious/ecom-chatbot-train-data")

train = ds["train"]
test  = ds["test"]

# Filter by response type
tool_call_examples = train.filter(lambda x: x["response_type"] == "tool_call")

# Filter by intent
order_queries = train.filter(lambda x: x["intent"] == "order_status")
```

---

## Split Methodology

Both splits were produced using **prompt-group-level stratified sampling** to ensure zero contamination, maximum variance, and minimum bias:

- **Stratification key:** `source | response_type | intent | difficulty`
- **Splitting unit:** unique `(source, prompt)` groups — all records sharing a prompt are assigned atomically to one split
- **40,949 prompt groups** across 44,031 records; 3,082 records share a prompt with at least one other record
- **Fallback cascade** for rare strata (< 5 groups): drops `difficulty`, then drops to `source` only
- **113 unique strata** | **Random seed:** 42 (reproducible)
- **Prompt contamination between splits: 0** (verified post-split)

Distribution drift between train and test is < 0.35% across all key columns.

---

## License

This dataset is released under the **MIT License**. Individual source data may carry additional terms from their original providers (Amazon, ASOS, Bitext).
