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

## RunPod Pod (vLLM + 26B AWQ)

### Docker 構成

- vLLM 公式イメージ (`vllm/vllm-openai:gemma4`) を使用
- Gemma4 26B A4B AWQ 4bit モデルを起動時にダウンロード
- OpenAI 互換 API をポート 8000 で提供
- `--api-key` で認証を設定

### デプロイ手順

```bash
VLLM_API_KEY=your-secret-key ./scripts/deploy-runpod.sh
```

テンプレート作成 → Pod 作成が自動で行われ、完了時に接続情報が出力される。

### API エンドポイント

```
https://<pod-id>-8000.proxy.runpod.net/v1/chat/completions
```

認証ヘッダー: `Authorization: Bearer <VLLM_API_KEY>`

### ライフサイクル管理

| コマンド | 動作 |
|---|---|
| `runpodctl pod stop <pod-id>` | 一時停止（課金停止、状態保持） |
| `runpodctl pod start <pod-id>` | 再開 |
| `runpodctl pod delete <pod-id>` | 完全削除 |

### リソース要件

| 項目 | ローカル | RunPod |
|---|---|---|
| GPU | RTX 3060 (12GB) | A5000 (24GB) |
| モデルサイズ | ~9.6GB (E4B GGUF) | ~14GB (26B AWQ 4bit) |
| ストレージ | Docker Volume | コンテナディスク 50GB |

### コストに関する注意

Pod は常時課金されます。使用しないときは必ず `runpodctl pod stop` で停止してください。
