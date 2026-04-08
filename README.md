# runpod-vllm-gemma

Docker で Gemma4 モデルを動かすためのリポジトリ。

## 前提条件

### RunPod デプロイ

- [RunPod](https://www.runpod.io/) アカウント
- [runpodctl](https://github.com/runpod/runpodctl) — `runpodctl doctor` で API キー設定済みであること

### ローカル実行

- [Docker](https://docs.docker.com/get-docker/) + Docker Compose
- NVIDIA GPU + [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

### Goose 接続

- [Goose](https://github.com/block/goose) (codename-goose)

## 構成

| 環境 | フレームワーク | モデル | GPU |
|---|---|---|---|
| ローカル | Ollama | gemma4:e4b (GGUF) | RTX 3060 (12GB) |
| RunPod Pod | vLLM (公式イメージ) | gemma-4-26B-A4B AWQ 4bit | A5000 (24GB) |

## Getting Started (RunPod + vLLM)

公式 `vllm/vllm-openai:gemma4` イメージを使用。`--api-key` で認証を設定。

### デプロイ

```bash
./scripts/deploy-runpod.sh
```

`runpodctl` でテンプレートと Pod を一括作成。モデルのダウンロードと vLLM の起動完了まで自動で待機し、完了時に接続情報が出力される。

| 変数 | デフォルト |
|---|---|
| `IMAGE` | `vllm/vllm-openai:gemma4` |
| `MIN_VRAM` | `24` |
| `MAX_PRICE` | `0.80` |
| `CONTAINER_DISK` | `50` |
| `MODEL_NAME` | `cyankiwi/gemma-4-26B-A4B-it-AWQ-4bit` |
| `VLLM_API_KEY` | 未設定時は自動生成 |
| `POLL_INTERVAL` | `15` (秒) |
| `POLL_TIMEOUT` | `900` (秒) |

### Goose 接続

```yaml
provider:
  type: openai
  api_key: "your-secret-key"
  base_url: "https://<pod-id>-8000.proxy.runpod.net/v1"
  model: "cyankiwi/gemma-4-26B-A4B-it-AWQ-4bit"
```

### クリーンアップ

```bash
./scripts/cleanup-runpod.sh
```

`runpod-vllm-gemma` に一致する Pod とテンプレートを一覧表示し、確認後に一括削除する。`PREFIX` 環境変数でマッチ対象を変更可能。

### ライフサイクル管理

```bash
runpodctl pod stop <pod-id>    # 一時停止（課金停止）
runpodctl pod start <pod-id>   # 再開
runpodctl pod delete <pod-id>  # 完全削除
```

Pod は常時課金されるため、使わないときは `stop` で課金を止めてください。

## ローカル (Ollama + E4B)

```bash
docker compose up -d
docker exec ollama ollama pull gemma4:e4b
curl http://localhost:11434/api/generate -d '{"model":"gemma4:e4b","prompt":"Hello"}'
```
