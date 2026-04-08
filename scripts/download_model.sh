#!/bin/bash
set -e

MODEL_ID="${1:-cyankiwi/gemma-4-26B-A4B-it-AWQ-4bit}"
LOCAL_DIR="${2:-./models/$(basename "$MODEL_ID")}"

echo "Downloading model: $MODEL_ID"
echo "Destination: $LOCAL_DIR"

pip install --quiet huggingface_hub

huggingface-cli download "$MODEL_ID" \
  --local-dir "$LOCAL_DIR" \
  --local-dir-use-symlinks False

echo "Done: $LOCAL_DIR"
