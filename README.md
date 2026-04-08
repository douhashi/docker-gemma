# docker-gemma

Docker で Gemma4 モデルを動かすためのリポジトリ。

## 構成

| 環境 | フレームワーク | モデル | GPU |
|---|---|---|---|
| ローカル | Ollama | gemma4:e4b (GGUF) | RTX 3060 (12GB) |
| RunPod Serverless | vLLM (公式イメージ) | gemma-4-26B-A4B AWQ 4bit | 24GB+ |

## ローカル (Ollama + E4B)

```bash
docker compose up -d
docker exec ollama ollama pull gemma4:e4b
curl http://localhost:11434/api/generate -d '{"model":"gemma4:e4b","prompt":"Hello"}'
```

## RunPod Serverless (vLLM + 26B AWQ)

公式 `runpod/worker-vllm` イメージを使用。モデルは初回起動時にダウンロードされる。

### デプロイ

```bash
scripts/deploy-runpod.sh
```

`runpodctl` でテンプレートとエンドポイントを一括作成する。

| 変数 | デフォルト |
|---|---|
| `IMAGE` | `runpod/worker-vllm:stable-cuda12.1.0` |
| `GPU_ID` | `NVIDIA RTX A5000` |
| `WORKERS_MIN` / `WORKERS_MAX` | `0` / `1` |
| `CONTAINER_DISK` | `40` |
| `MODEL_NAME` | `cyankiwi/gemma-4-26B-A4B-it-AWQ-4bit` |

### Goose 接続

```yaml
provider:
  type: openai
  api_key: "<RunPod API Key>"
  base_url: "https://api.runpod.ai/v2/<endpoint_id>/openai/v1"
  model: "cyankiwi/gemma-4-26B-A4B-it-AWQ-4bit"
```
