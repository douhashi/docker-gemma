#!/bin/bash
set -euo pipefail

PREFIX="${PREFIX:-runpod-vllm-gemma}"

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

echo ""
echo "==> Listing templates matching '${PREFIX}'..."
TEMPLATES=$(runpodctl template list 2>&1)
MATCHED_TEMPLATES=$(echo "${TEMPLATES}" | python3 -c "
import json, sys
templates = json.load(sys.stdin)
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

echo "${TEMPLATES}" | python3 -c "
import json, sys
templates = json.load(sys.stdin)
for t in templates:
    if '${PREFIX}' in t.get('name','').lower():
        print(t['id'])
" 2>/dev/null | while read -r tpl_id; do
  echo "==> Deleting template: ${tpl_id}"
  runpodctl template delete "${tpl_id}" 2>&1 | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"   deleted: {d.get('deleted',False)}\")" 2>/dev/null || true
done

echo ""
echo "Done."
