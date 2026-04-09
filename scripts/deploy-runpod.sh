#!/bin/bash
set -euo pipefail

# ===== Configuration =====
POD_NAME="${POD_NAME:-runpod-vllm-gemma}"
TEMPLATE_NAME="${TEMPLATE_NAME:-runpod-vllm-gemma}"
IMAGE="${IMAGE:-vllm/vllm-openai:gemma4}"
CONTAINER_DISK="${CONTAINER_DISK:-50}"
MIN_VRAM="${MIN_VRAM:-48}"
MAX_PRICE="${MAX_PRICE:-0.80}"

# vLLM settings
MODEL_NAME="${MODEL_NAME:-google/gemma-4-31B-it}"
MAX_MODEL_LENGTH="${MAX_MODEL_LENGTH:-auto}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
DTYPE="${DTYPE:-auto}"
QUANTIZATION="${QUANTIZATION:-fp8}"
VLLM_API_KEY="${VLLM_API_KEY:-}"

# ===== Preflight =====
if ! command -v runpodctl &> /dev/null; then
  echo "Error: runpodctl is not installed" >&2
  exit 1
fi

RUNPOD_API_KEY=$(python3 -c "
try:
    import tomllib
except ImportError:
    import tomli as tomllib
with open('$HOME/.runpod/config.toml', 'rb') as f:
    print(tomllib.load(f)['apikey'])
" 2>/dev/null || true)

if [ -z "${RUNPOD_API_KEY}" ]; then
  echo "Error: RunPod API key not found in ~/.runpod/config.toml" >&2
  exit 1
fi

if [ -z "${VLLM_API_KEY}" ]; then
  VLLM_API_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  echo "==> Generated API key: ${VLLM_API_KEY}"
fi

# ===== Query GPU availability and pricing =====
echo "==> Querying GPU availability (VRAM >= ${MIN_VRAM}GB, price < \$${MAX_PRICE}/hr)..."
GPU_CANDIDATES=$(curl -s "https://api.runpod.io/graphql?api_key=${RUNPOD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ gpuTypes { id displayName memoryInGb securePrice communityPrice } }"}' \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
gpus = data['data']['gpuTypes']
min_vram = ${MIN_VRAM}
max_price = ${MAX_PRICE}
candidates = []
for g in gpus:
    mem = g['memoryInGb']
    if mem < min_vram:
        continue
    # Community first (cheaper), then Secure
    cp = g.get('communityPrice')
    sp = g.get('securePrice')
    if cp and cp < max_price:
        candidates.append((cp, 'COMMUNITY', g['id'], mem, g['displayName']))
    if sp and sp < max_price:
        candidates.append((sp, 'SECURE', g['id'], mem, g['displayName']))
candidates.sort(key=lambda x: x[0])
for price, cloud, gpu_id, mem, name in candidates:
    print(f'{gpu_id}|{cloud}|{price}|{mem}|{name}')
")

if [ -z "${GPU_CANDIDATES}" ]; then
  echo "Error: no GPU found matching criteria" >&2
  exit 1
fi

echo "   Candidates (cheapest first):"
echo "${GPU_CANDIDATES}" | while IFS='|' read -r gpu_id cloud price mem name; do
  printf "   %-45s %4sGB  \$%s/hr  %s\n" "${gpu_id}" "${mem}" "${price}" "${cloud}"
done

# ===== Build vLLM command args =====
# TODO: thinking 有効化は vllm/vllm-openai:gemma4 イメージ更新後に再検討
#   vllm-project/vllm#39027 (マージ済み) で Gemma4 reasoning/tool calling が修正された
#   新イメージでは以下に切り替える:
#     --default-chat-template-kwargs '{"enable_thinking": true}'
#     --chat-template examples/tool_chat_template_gemma4.jinja
#   関連: vllm-project/vllm#38855, block/goose#6192
VLLM_CMD="${MODEL_NAME},--served-model-name,${MODEL_NAME},gpt-4o-mini,--max-model-len,${MAX_MODEL_LENGTH},--gpu-memory-utilization,${GPU_MEMORY_UTILIZATION},--dtype,${DTYPE},--quantization,${QUANTIZATION},--api-key,${VLLM_API_KEY},--enable-auto-tool-choice,--tool-call-parser,gemma4,--reasoning-parser,gemma4,--host,0.0.0.0,--port,8000"

# ===== Create Template =====
echo "==> Creating template: ${TEMPLATE_NAME}"
TEMPLATE_RESULT=$(runpodctl template create \
  --name "${TEMPLATE_NAME}" \
  --image "${IMAGE}" \
  --container-disk-in-gb "${CONTAINER_DISK}" \
  --ports "8000/http" \
  --docker-start-cmd "${VLLM_CMD}" \
  2>&1)

echo "${TEMPLATE_RESULT}"
TEMPLATE_ID=$(echo "${TEMPLATE_RESULT}" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)

if [ -z "${TEMPLATE_ID}" ]; then
  echo "Error: failed to extract template ID" >&2
  exit 1
fi
echo "==> Template created: ${TEMPLATE_ID}"

# ===== Create Pod (try candidates in price order) =====
POD_ID=""
USED_GPU=""
USED_CLOUD=""
USED_PRICE=""

while IFS='|' read -r gpu_id cloud price mem name; do
  echo "==> Trying: ${name} (${mem}GB, \$${price}/hr, ${cloud})"
  POD_RESULT=$(runpodctl pod create \
    --template-id "${TEMPLATE_ID}" \
    --gpu-id "${gpu_id}" \
    --name "${POD_NAME}" \
    --cloud-type "${cloud}" \
    2>&1) || true

  POD_ID=$(echo "${POD_RESULT}" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)

  if [ -n "${POD_ID}" ]; then
    USED_GPU="${name}"
    USED_CLOUD="${cloud}"
    USED_PRICE="${price}"
    break
  fi
  echo "    Not available, trying next..."
done <<< "${GPU_CANDIDATES}"

if [ -z "${POD_ID}" ]; then
  echo "Error: no GPU available. All candidates exhausted." >&2
  echo "  Cleanup template: runpodctl template delete ${TEMPLATE_ID}" >&2
  exit 1
fi

BASE_URL="https://${POD_ID}-8000.proxy.runpod.net"
POLL_INTERVAL="${POLL_INTERVAL:-15}"
POLL_TIMEOUT="${POLL_TIMEOUT:-900}"

echo ""
echo "==> Waiting for vLLM to become ready (timeout: ${POLL_TIMEOUT}s)..."
echo "    Polling ${BASE_URL}/v1/models every ${POLL_INTERVAL}s"

ELAPSED=0
while [ "${ELAPSED}" -lt "${POLL_TIMEOUT}" ]; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -H "Authorization: Bearer ${VLLM_API_KEY}" \
    "${BASE_URL}/v1/models" 2>/dev/null || echo "000")

  if [ "${HTTP_CODE}" = "200" ]; then
    echo ""
    echo "==> vLLM is ready! (${ELAPSED}s elapsed)"
    break
  fi

  printf "\r    [%3ds] HTTP %s — waiting..." "${ELAPSED}" "${HTTP_CODE}"
  sleep "${POLL_INTERVAL}"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

if [ "${ELAPSED}" -ge "${POLL_TIMEOUT}" ]; then
  echo ""
  echo "Warning: timed out after ${POLL_TIMEOUT}s. The pod may still be loading." >&2
  echo "  Check manually: curl -H 'Authorization: Bearer ${VLLM_API_KEY}' ${BASE_URL}/v1/models" >&2
fi

# ===== Update Goose config =====
GOOSE_CONFIG="${HOME}/.config/goose/config.yaml"
if [ -f "${GOOSE_CONFIG}" ]; then
  sed -i "s|OPENAI_HOST:.*|OPENAI_HOST: ${BASE_URL}|" "${GOOSE_CONFIG}"
  echo "==> Updated ${GOOSE_CONFIG} (OPENAI_HOST: ${BASE_URL})"
else
  mkdir -p "$(dirname "${GOOSE_CONFIG}")"
  cat > "${GOOSE_CONFIG}" <<GOOSE_EOF
GOOSE_PROVIDER: openai
GOOSE_MODEL: ${MODEL_NAME}
OPENAI_HOST: ${BASE_URL}
GOOSE_MODE: auto
GOOSE_TELEMETRY_ENABLED: true
extensions:
  developer:
    enabled: true
    type: platform
    name: developer
    description: Write and edit files, and execute shell commands
    display_name: Developer
    bundled: true
    available_tools: []
GOOSE_EOF
  echo "==> Created ${GOOSE_CONFIG}"
fi

echo ""
echo "=============================="
echo "Deployment complete!"
echo "=============================="
echo "Pod ID  : ${POD_ID}"
echo "GPU     : ${USED_GPU} (${USED_CLOUD}, \$${USED_PRICE}/hr)"
echo "Model   : ${MODEL_NAME}"
echo "API Key : ${VLLM_API_KEY}"
echo "API URL : ${BASE_URL}/v1"
echo ""
echo "Goose config:"
echo "  provider:"
echo "    type: openai"
echo "    api_key: ${VLLM_API_KEY}"
echo "    base_url: ${BASE_URL}/v1"
echo "    model: ${MODEL_NAME}"
echo ""
echo "Goose launch:"
echo "  OPENAI_HOST=${BASE_URL} OPENAI_API_KEY=${VLLM_API_KEY} goose session"
echo ""
echo "Claude Code launch:"
echo "  CLAUDE_CODE_USE_VERTEX=0 \\"
echo "  ANTHROPIC_BASE_URL=${BASE_URL} \\"
echo "  ANTHROPIC_DEFAULT_OPUS_MODEL=${MODEL_NAME} \\"
echo "  ANTHROPIC_DEFAULT_SONNET_MODEL=${MODEL_NAME} \\"
echo "  ANTHROPIC_DEFAULT_HAIKU_MODEL=${MODEL_NAME} \\"
echo "  ANTHROPIC_AUTH_TOKEN=${VLLM_API_KEY} \\"
echo "  claude --model sonnet"
echo ""
echo "Lifecycle:"
echo "  runpodctl pod stop ${POD_ID}    # pause (stop billing)"
echo "  runpodctl pod start ${POD_ID}   # resume"
echo "  runpodctl pod delete ${POD_ID}  # destroy permanently"
