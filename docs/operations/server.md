# サーバー運用

## ローカル環境 (Ollama + E4B)

### Docker 構成

- Ollama コンテナで Gemma4 E4B モデルを GPU 推論
- RTX 3060 (12GB VRAM) で動作確認済み

### 起動手順

```bash
docker compose up -d
docker exec ollama ollama pull gemma4:e4b
```

### 動作確認

```bash
curl http://localhost:11434/api/generate \
  -d '{"model":"gemma4:e4b","prompt":"Hello"}'
```

## RunPod Serverless (vLLM + 26B AWQ)

### Docker 構成

- vLLM 公式 worker イメージベース
- Gemma4 26B A4B AWQ 4bit モデルをイメージにプリロード
- OpenAI 互換 API を RunPod が自動提供

### デプロイ手順

1. Docker イメージをビルド & プッシュ
   ```bash
   docker build -t ghcr.io/douhashi/docker-gemma:latest .
   docker push ghcr.io/douhashi/docker-gemma:latest
   ```
2. RunPod Console → Serverless → New Endpoint
3. 以下を設定:
   - Image: `ghcr.io/douhashi/docker-gemma:latest`
   - GPU: 24GB (A5000 / RTX 4090)
   - Disk: 30GB
   - Workers: min 0 / max 1

### API エンドポイント

```
https://api.runpod.ai/v2/<endpoint_id>/openai/v1/chat/completions
```

認証ヘッダー: `Authorization: Bearer <RunPod API Key>`

### リソース要件

| 項目 | ローカル | RunPod |
|---|---|---|
| GPU | RTX 3060 (12GB) | 24GB+ (A5000/4090) |
| モデルサイズ | ~9.6GB (E4B GGUF) | ~14GB (26B AWQ 4bit) |
| ストレージ | Docker Volume | イメージ内プリロード |
