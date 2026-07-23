# BYOK Sample Vector DB

Sample BYOK (Bring Your Own Knowledge) vector database for the AI Rolling Demo.

Source docs live in `docs/` — the vector DB is generated at build time using [rag-content](https://github.com/lightspeed-core/rag-content) and is not checked into git.

## Prerequisites

1. Clone [rag-content](https://github.com/lightspeed-core/rag-content)
2. Set up a virtualenv: `cd rag-content && uv venv && uv pip install -e .`

## Adding documents

Place your source documents in `docs/`. Supported formats: `.md`, `.txt`, `.pdf`, `.html`.

For Google Docs: **File > Download > Markdown (.md)**, then place the exported file in `docs/`.

## Build the vector DB and container image

```bash
RAG_CONTENT_REPO=/path/to/rag-content \
BYOK_IMAGE=quay.io/<org>/byok-sample:latest \
./build-vector-db.sh
```

This will:
1. Download the embedding model (if not already present)
2. Process all docs in `docs/` into a FAISS vector DB
3. Build and push the container image
4. Print the `vector_store_id` to update in `lightspeed-stack.yaml`

To generate the vector DB only (no container build), omit `BYOK_IMAGE`:

```bash
RAG_CONTENT_REPO=/path/to/rag-content ./build-vector-db.sh
```

To use a different docs directory:

```bash
RAG_CONTENT_REPO=/path/to/rag-content ./build-vector-db.sh /path/to/your/docs
```

## Configuration

After building, update `lightspeed-stack.yaml` with the vector store ID printed by the script:

- **Embedding model:** `sentence-transformers/all-mpnet-base-v2` (dimension 768)
- **DB path in container:** `/byok/vector_db/custom_docs/faiss_store.db`
