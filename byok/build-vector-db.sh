#!/usr/bin/env bash
#
# Builds a BYOK FAISS vector DB from source documents and optionally
# builds + pushes a container image.
#
# Supported input formats: .md, .txt, .pdf, .html
# For Google Docs: File > Download > Markdown (.md), then place in docs/
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCS_DIR="${1:-$SCRIPT_DIR/docs}"
OUTPUT_DIR="$SCRIPT_DIR/vector_db/custom_docs"
EMBEDDINGS_DIR="$SCRIPT_DIR/embeddings_model"
MODEL_NAME="sentence-transformers/all-mpnet-base-v2"
CHUNK_SIZE=512
CHUNK_OVERLAP=128
RAG_CONTENT_REPO="${RAG_CONTENT_REPO:-}"
BYOK_IMAGE="${BYOK_IMAGE:-}"
CONTAINER_ENGINE="${CONTAINER_ENGINE:-podman}"

if [ -z "$RAG_CONTENT_REPO" ]; then
  echo "Error: RAG_CONTENT_REPO must be set to the path of your local rag-content clone."
  echo ""
  echo "Usage:"
  echo "  RAG_CONTENT_REPO=/path/to/rag-content BYOK_IMAGE=quay.io/<org>/byok-sample:latest ./build-vector-db.sh [docs_dir]"
  echo ""
  echo "  docs_dir    Directory containing source documents (default: ./docs)"
  echo ""
  echo "Environment variables:"
  echo "  RAG_CONTENT_REPO   (required) Path to local rag-content clone"
  echo "  BYOK_IMAGE         (optional) Container image tag — if set, builds and pushes the image"
  echo "  CONTAINER_ENGINE   (optional) podman or docker (default: podman)"
  echo ""
  echo "Prerequisites:"
  echo "  1. Clone https://github.com/lightspeed-core/rag-content"
  echo "  2. Set up a virtualenv: cd rag-content && uv venv && uv pip install -e ."
  echo "  3. For Google Docs: export as Markdown via File > Download > Markdown (.md)"
  exit 1
fi

if [ ! -d "$RAG_CONTENT_REPO" ]; then
  echo "Error: RAG_CONTENT_REPO directory not found: $RAG_CONTENT_REPO"
  exit 1
fi

if [ ! -d "$DOCS_DIR" ]; then
  echo "Error: docs directory not found: $DOCS_DIR"
  exit 1
fi

# Download embedding model if not present
if [ ! -d "$EMBEDDINGS_DIR" ]; then
  echo "Downloading embedding model to $EMBEDDINGS_DIR..."
  mkdir -p "$EMBEDDINGS_DIR"
  (cd "$RAG_CONTENT_REPO" && uv run python ./scripts/download_embeddings_model.py \
    -l "$EMBEDDINGS_DIR" \
    -r "$MODEL_NAME")
fi

# Build vector DB
echo "Building vector DB from $DOCS_DIR..."
mkdir -p "$OUTPUT_DIR"

(cd "$RAG_CONTENT_REPO" && uv run python "$SCRIPT_DIR/custom_processor.py" \
  --folder "$DOCS_DIR" \
  --output "$OUTPUT_DIR" \
  --index v1 \
  --vector-store-type llamastack-faiss \
  --model-dir "$EMBEDDINGS_DIR" \
  --model-name "$MODEL_NAME" \
  --chunk "$CHUNK_SIZE" \
  --overlap "$CHUNK_OVERLAP")

echo ""
echo "Vector DB built at: $OUTPUT_DIR"

if [ -f "$OUTPUT_DIR/llama-stack.yaml" ]; then
  VECTOR_STORE_ID=$(grep "vector_store_id:" "$OUTPUT_DIR/llama-stack.yaml" | awk '{print $2}')
  echo "Vector store ID: $VECTOR_STORE_ID"
  echo "Update this ID in lightspeed-stack.yaml under byok_rag.vector_db_id"
fi

# Build and push container image if BYOK_IMAGE is set
if [ -n "$BYOK_IMAGE" ]; then
  echo ""
  echo "Building container image: $BYOK_IMAGE"
  $CONTAINER_ENGINE build -t "$BYOK_IMAGE" -f "$SCRIPT_DIR/Containerfile" "$SCRIPT_DIR"

  echo "Pushing $BYOK_IMAGE..."
  $CONTAINER_ENGINE push "$BYOK_IMAGE"

  echo "Image pushed: $BYOK_IMAGE"
fi
