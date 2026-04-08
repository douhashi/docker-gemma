#!/bin/bash
set -euo pipefail

# ===== Configuration =====
TEMPLATE_NAME="${TEMPLATE_NAME:-docker-gemma-vllm}"
ENDPOINT_NAME="${ENDPOINT_NAME:-docker-gemma}"
IMAGE="${IMAGE:-ghcr.io/douhashi/docker-gemma:latest}"
GPU_ID="${GPU_ID:-NVIDIA RTX A5000}"
WORKERS_MIN="${WORKERS_MIN:-0}"
WORKERS_MAX="${WORKERS_MAX:-1}"
CONTAINER_DISK="${CONTAINER_DISK:-40}"
VOLUME_DISK="${VOLUME_DISK:-0}"

# vLLM environment variables
MODEL_NAME="${MODEL_NAME:-cyankiwi/gemma-4-26B-A4B-it-AWQ-4bit}"
QUANTIZATION="${QUANTIZATION:-awq}"
MAX_MODEL_LENGTH="${MAX_MODEL_LENGTH:-8192}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
DTYPE="${DTYPE:-float16}"

ENV_JSON=$(cat <<ENVEOF
{
  "MODEL_NAME": "${MODEL_NAME}",
  "QUANTIZATION": "${QUANTIZATION}",
  "MAX_MODEL_LENGTH": "${MAX_MODEL_LENGTH}",
  "GPU_MEMORY_UTILIZATION": "${GPU_MEMORY_UTILIZATION}",
  "DTYPE": "${DTYPE}"
}
ENVEOF
)

# ===== Preflight =====
if ! command -v runpodctl &> /dev/null; then
  echo "Error: runpodctl is not installed" >&2
  exit 1
fi

echo "==> Creating template: ${TEMPLATE_NAME}"
TEMPLATE_RESULT=$(runpodctl template create \
  --name "${TEMPLATE_NAME}" \
  --image "${IMAGE}" \
  --serverless \
  --container-disk-in-gb "${CONTAINER_DISK}" \
  --volume-in-gb "${VOLUME_DISK}" \
  --env "${ENV_JSON}" \
  2>&1)

echo "${TEMPLATE_RESULT}"
TEMPLATE_ID=$(echo "${TEMPLATE_RESULT}" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)

if [ -z "${TEMPLATE_ID}" ]; then
  echo "Error: failed to extract template ID" >&2
  exit 1
fi
echo "==> Template created: ${TEMPLATE_ID}"

echo "==> Creating endpoint: ${ENDPOINT_NAME}"
ENDPOINT_RESULT=$(runpodctl serverless create \
  --name "${ENDPOINT_NAME}" \
  --template-id "${TEMPLATE_ID}" \
  --gpu-id "${GPU_ID}" \
  --workers-min "${WORKERS_MIN}" \
  --workers-max "${WORKERS_MAX}" \
  2>&1)

echo "${ENDPOINT_RESULT}"
ENDPOINT_ID=$(echo "${ENDPOINT_RESULT}" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)

if [ -z "${ENDPOINT_ID}" ]; then
  echo "Error: failed to extract endpoint ID" >&2
  exit 1
fi

echo ""
echo "=============================="
echo "Deployment complete!"
echo "=============================="
echo "Endpoint ID : ${ENDPOINT_ID}"
echo "Template ID : ${TEMPLATE_ID}"
echo "GPU         : ${GPU_ID}"
echo "Model       : ${MODEL_NAME}"
echo ""
echo "OpenAI-compatible API:"
echo "  https://api.runpod.ai/v2/${ENDPOINT_ID}/openai/v1"
echo ""
echo "Goose config:"
echo "  provider:"
echo "    type: openai"
echo "    api_key: <RunPod API Key>"
echo "    base_url: https://api.runpod.ai/v2/${ENDPOINT_ID}/openai/v1"
echo "    model: ${MODEL_NAME}"
