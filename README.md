# docker-gemma

Docker で Gemma4 モデルを動かすためのリポジトリ。

## 構成

| 環境 | フレームワーク | モデル | GPU |
|---|---|---|---|
| ローカル | Ollama | gemma4:e4b (GGUF) | RTX 3060 (12GB) |
| RunPod Serverless | vLLM | gemma-4-26B-A4B AWQ 4bit | 24GB+ |

## ローカル (Ollama + E4B)

```bash
docker compose up -d
docker exec ollama ollama pull gemma4:e4b
curl http://localhost:11434/api/generate -d '{"model":"gemma4:e4b","prompt":"Hello"}'
```

## RunPod Serverless (vLLM + 26B AWQ)

### ビルド & プッシュ

```bash
scripts/build-and-push.sh
```

環境変数で上書き可能:

| 変数 | デフォルト |
|---|---|
| `REGISTRY` | `ghcr.io` |
| `IMAGE_NAME` | `douhashi/docker-gemma` |
| `TAG` | `latest` |

または GitHub Actions の `workflow_dispatch` で手動実行。

### デプロイ

```bash
scripts/deploy-runpod.sh
```

`runpodctl` が必要。テンプレートとエンドポイントを一括作成する。

| 変数 | デフォルト |
|---|---|
| `TEMPLATE_NAME` | `docker-gemma-vllm` |
| `ENDPOINT_NAME` | `docker-gemma` |
| `IMAGE` | `ghcr.io/douhashi/docker-gemma:latest` |
| `GPU_ID` | `NVIDIA RTX A5000` |
| `WORKERS_MIN` / `WORKERS_MAX` | `0` / `1` |
| `CONTAINER_DISK` | `40` |
| `MODEL_NAME` | `cyankiwi/gemma-4-26B-A4B-it-AWQ-4bit` |
| `QUANTIZATION` | `awq` |
| `MAX_MODEL_LENGTH` | `8192` |
| `GPU_MEMORY_UTILIZATION` | `0.90` |
| `DTYPE` | `float16` |

### モデルダウンロード

HuggingFace からモデルをローカルにダウンロードする:

```bash
scripts/download_model.sh [MODEL_ID] [LOCAL_DIR]
```

デフォルトは `cyankiwi/gemma-4-26B-A4B-it-AWQ-4bit` → `./models/` 配下に保存。

### Goose 接続

```yaml
provider:
  type: openai
  api_key: "<RunPod API Key>"
  base_url: "https://api.runpod.ai/v2/<endpoint_id>/openai/v1"
  model: "cyankiwi/gemma-4-26B-A4B-it-AWQ-4bit"
```
