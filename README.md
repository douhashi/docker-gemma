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
docker build -t ghcr.io/douhashi/docker-gemma:latest .
docker push ghcr.io/douhashi/docker-gemma:latest
```

または GitHub Actions の `workflow_dispatch` で手動実行。

### デプロイ

RunPod Console → Serverless → New Endpoint で以下を設定:

| 項目 | 値 |
|---|---|
| Image | `ghcr.io/douhashi/docker-gemma:latest` |
| GPU | 24GB (A5000 / RTX 4090) |
| Disk | 30GB |
| Workers | min 0 / max 1 |

### Goose 接続

```yaml
provider:
  type: openai
  api_key: "<RunPod API Key>"
  base_url: "https://api.runpod.ai/v2/<endpoint_id>/openai/v1"
  model: "cyankiwi/gemma-4-26B-A4B-it-AWQ-4bit"
```
