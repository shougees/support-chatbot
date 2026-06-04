# Research Data

This directory contains external sample data used for project research and future seed-data preparation.

## Full Ecom Chatbot Dataset

- Local directory: `full-ecom-chatbot-dataset/`
- Source URL: https://huggingface.co/datasets/rescommons/Full-Ecom-Chatbot-Dataset
- Source dataset ID: `rescommons/Full-Ecom-Chatbot-Dataset`
- License: MIT, per Hugging Face metadata and dataset card
- Preferred local sample: `full-ecom-chatbot-dataset/synthetic-api-generated-sample.json`
- Downloaded sample records: 100
- Selected source subset: `synthetic_api_generated`
- Source card snapshot: `full-ecom-chatbot-dataset/README.source.md`
- API metadata snapshot: `full-ecom-chatbot-dataset/metadata.json`
- Dataset-server first-row snapshot: `full-ecom-chatbot-dataset/train-first-rows.json`

Use `synthetic-api-generated-sample.json` for issue #3 seed-data preparation. The full dataset card notes that individual upstream sources may carry additional provider terms, so the synthetic subset is preferred for this project.

The sample covers these intent categories: account, cart/checkout, customer support, general information, order management, product discovery, and returns/exchanges.
