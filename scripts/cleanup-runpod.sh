#!/bin/bash
set -euo pipefail

# --all: delete all matching resources, not just the current user's
ALL=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --all) ALL=true; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
done

if [ "$ALL" = true ]; then
  PREFIX="${PREFIX:-runpod-vllm-gemma}"
  echo "Mode: all resources matching '${PREFIX}'"
else
  DEPLOY_USER="${DEPLOY_USER:-$(whoami)}"
  PREFIX="${PREFIX:-runpod-vllm-gemma-${DEPLOY_USER}}"
  echo "Mode: current user only (${DEPLOY_USER}). Use --all for all users."
fi

# ===== Resolve RunPod API key =====
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

# ===== List matching pods =====
echo "==> Listing pods matching '${PREFIX}'..."
PODS=$(runpodctl pod list 2>&1)
MATCHED_PODS=$(echo "${PODS}" | python3 -c "
import json, sys
pods = json.load(sys.stdin)
matched = [p for p in pods if '${PREFIX}' in p.get('name','').lower()]
if not matched:
    print('NONE')
else:
    for p in matched:
        print(f\"   {p['id']}  {p.get('name','?'):30s}  {p.get('desiredStatus','?')}\")
" 2>/dev/null || echo "NONE")

echo "${MATCHED_PODS}"

# ===== List matching templates (via GraphQL — runpodctl only returns public ones) =====
echo ""
echo "==> Listing templates matching '${PREFIX}'..."
TEMPLATES=$(curl -s "https://api.runpod.io/graphql?api_key=${RUNPOD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ myself { podTemplates { id name imageName } } }"}')

MATCHED_TEMPLATES=$(echo "${TEMPLATES}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
templates = data['data']['myself']['podTemplates']
matched = [t for t in templates if '${PREFIX}' in t.get('name','').lower()]
if not matched:
    print('NONE')
else:
    for t in matched:
        print(f\"   {t['id']}  {t.get('name','?'):30s}  {t.get('imageName','?')}\")
" 2>/dev/null || echo "NONE")

echo "${MATCHED_TEMPLATES}"

if [[ "${MATCHED_PODS}" == "NONE" && "${MATCHED_TEMPLATES}" == "NONE" ]]; then
  echo ""
  echo "Nothing to clean up."
  exit 0
fi

echo ""
read -p "Delete these resources? [y/N] " CONFIRM
if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

# ===== Delete matching pods =====
echo ""
echo "${PODS}" | python3 -c "
import json, sys
pods = json.load(sys.stdin)
for p in pods:
    if '${PREFIX}' in p.get('name','').lower():
        print(p['id'])
" 2>/dev/null | while read -r pod_id; do
  echo "==> Deleting pod: ${pod_id}"
  runpodctl pod delete "${pod_id}" 2>&1 | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"   deleted: {d.get('deleted',False)}\")" 2>/dev/null || true
done

# ===== Delete matching templates (via GraphQL mutation — templateName takes the name, not ID) =====
echo "${TEMPLATES}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
templates = data['data']['myself']['podTemplates']
for t in templates:
    if '${PREFIX}' in t.get('name','').lower():
        print(t['name'])
" 2>/dev/null | while read -r tpl_name; do
  echo "==> Deleting template: ${tpl_name}"
  RESULT=$(curl -s "https://api.runpod.io/graphql?api_key=${RUNPOD_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"query\":\"mutation { deleteTemplate(templateName: \\\"${tpl_name}\\\") }\"}")
  if echo "${RESULT}" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'errors' not in d else 1)" 2>/dev/null; then
    echo "   deleted"
  else
    echo "   failed: ${RESULT}" >&2
  fi
done

echo ""
echo "Done."
