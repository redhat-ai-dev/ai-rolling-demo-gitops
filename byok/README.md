# BYOK Sample Vector DB

Sample BYOK (Bring Your Own Knowledge) vector database for the AI Rolling Demo.

Contains internal RHDH team docs (Feature Exploration Process, Engineering Workflow, Onboarding), built into a FAISS vector DB using [rag-content](https://github.com/lightspeed-core/rag-content) tooling.

## Pre-built vector store

- **Vector store ID:** `vs_727b6321-1ff4-47bf-a76b-1cc12426c954`
- **Embedding model:** `sentence-transformers/all-mpnet-base-v2` (dimension 768)
- **DB path in container:** `/byok/vector_db/custom_docs/faiss_store.db`

## Build the container image

```bash
cd byok/
podman build -t quay.io/rh-ee-rkichann/byok-sample:latest -f Containerfile .
podman push quay.io/rh-ee-rkichann/byok-sample:latest
```

## Rebuild the vector DB

Requires the [rag-content](https://github.com/lightspeed-core/rag-content) repo and an embeddings model.

```bash
cd /path/to/rag-content
.venv/bin/python /path/to/byok/custom_processor.py \
  --folder /path/to/byok/docs \
  --output /path/to/byok/vector_db/custom_docs \
  --index v1 \
  --vector-store-type llamastack-faiss \
  --model-dir /path/to/embeddings_model \
  --model-name sentence-transformers/all-mpnet-base-v2 \
  --chunk 512 --overlap 128
```
