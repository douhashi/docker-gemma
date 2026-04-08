# runpod-vllm-gemma

Docker で Gemma4 モデルを動かすためのリポジトリ。

## 前提条件

### ローカル実行

- [Docker](https://docs.docker.com/get-docker/) + Docker Compose
- NVIDIA GPU + [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

### RunPod デプロイ

- [RunPod](https://www.runpod.io/) アカウント
- [runpodctl](https://github.com/runpod/runpodctl) — `runpodctl doctor` で API キー設定済みであること

### Goose 接続

- [Goose](https://github.com/block/goose) (codename-goose)

## 構成

| 環境 | フレームワーク | モデル | GPU |
|---|---|---|---|
| ローカル | Ollama | gemma4:e4b (GGUF) | RTX 3060 (12GB) |
| RunPod Pod | vLLM (公式イメージ) | gemma-4-26B-A4B AWQ 4bit | A5000 (24GB) |

## ローカル (Ollama + E4B)

```bash
docker compose up -d
docker exec ollama ollama pull gemma4:e4b
curl http://localhost:11434/api/generate -d '{"model":"gemma4:e4b","prompt":"Hello"}'
```

## RunPod Pod (vLLM + 26B AWQ)

公式 `vllm/vllm-openai:gemma4` イメージを使用。`--api-key` で認証を設定。

### デプロイ

```bash
VLLM_API_KEY=your-secret-key ./scripts/deploy-runpod.sh
```

`runpodctl` でテンプレートと Pod を一括作成。完了時に接続情報が出力される。

| 変数 | デフォルト |
|---|---|
| `IMAGE` | `vllm/vllm-openai:gemma4` |
| `GPU_IDS` | `NVIDIA RTX A5000,NVIDIA RTX A6000,NVIDIA A40` |
| `CLOUD_TYPE` | `COMMUNITY` |
| `CONTAINER_DISK` | `50` |
| `MODEL_NAME` | `cyankiwi/gemma-4-26B-A4B-it-AWQ-4bit` |
| `VLLM_API_KEY` | (必須) |

### Goose 接続

```yaml
provider:
  type: openai
  api_key: "your-secret-key"
  base_url: "https://<pod-id>-8000.proxy.runpod.net/v1"
  model: "cyankiwi/gemma-4-26B-A4B-it-AWQ-4bit"
```

### ライフサイクル管理

```bash
runpodctl pod stop <pod-id>    # 一時停止（課金停止）
runpodctl pod start <pod-id>   # 再開
runpodctl pod delete <pod-id>  # 完全削除
```

Pod は常時課金されるため、使わないときは `stop` で課金を止めてください。
