# 開発ガイドライン

## 前提条件

- Docker / Docker Compose がインストール済みであること
- GPU 利用時は NVIDIA Container Toolkit が設定済みであること

## 開発フロー

1. リポジトリをクローン
2. Docker イメージをビルド
3. コンテナを起動して動作確認
4. 変更を加えてテスト
5. PR を作成

## ブランチ戦略

- `main`: 安定版
- feature ブランチで開発し、PR 経由でマージ
