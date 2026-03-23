# Task-Apps

タスク成長型SNS PvPアプリ

## 技術スタック

| レイヤー | 技術 |
|---|---|
| モバイル | Expo (React Native) |
| API | Node.js + Express |
| DB | PostgreSQL 16 |
| インフラ | Docker / Cloudflare Tunnel |

## ディレクトリ構成

```
Task-Apps/
├── apps/
│   ├── api/        # Express API
│   └── mobile/     # Expo アプリ
├── db/
│   └── init.sql    # DB初期化スキーマ
├── docker-compose.yml
├── .env.example
└── README.md
```

---

## セットアップ手順

### 共通（WSL2 / Windows どちらも）

#### 1. 前提ソフトのインストール

**WSL2 (Ubuntu) の場合**
```bash
# Docker Engine
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# ↑ 反映のため一度ターミナルを再起動
```

**Windows ネイティブの場合**
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) をインストール
- [Git for Windows](https://git-scm.com/) をインストール

---

#### 2. リポジトリをクローン

```bash
git clone https://github.com/ShotaMiwa/Task-Apps.git
cd Task-Apps
```

#### 3. 環境変数ファイルを作成

```bash
cp .env.example .env
```

`.env` を開いてパスワード等を設定する。

```env
POSTGRES_USER=taskapp
POSTGRES_PASSWORD=（任意のパスワード）
POSTGRES_DB=taskapp_db
PORT=3000
JWT_SECRET=（長いランダム文字列）
JWT_REFRESH_SECRET=（長いランダム文字列）
```

> ⚠️ `.env` は `.gitignore` に含まれているのでコミットされません。2人それぞれが手元で作成してください。

#### 4. 起動

```bash
docker compose up --build
```

以下が表示されれば成功：
```
task_app_api  | API server running on port 3000
```

#### 5. 動作確認

```bash
curl http://localhost:3000/health
# => {"status":"ok","timestamp":"..."}
```

---

## よく使うコマンド

```bash
# 起動（バックグラウンド）
docker compose up -d

# 停止
docker compose down

# DBだけ再作成（スキーマ変更時）
docker compose down -v
docker compose up --build

# APIのログ確認
docker compose logs -f api

# DBに直接接続
docker compose exec db psql -U taskapp -d taskapp_db
```

---

## 開発フロー（ブランチ運用）

```
main          # 本番相当・直接pushしない
└── develop   # 開発統合ブランチ
    ├── feature/auth      # 機能ブランチ例
    └── feature/tasks
```

1. `develop` から `feature/xxx` ブランチを切る
2. 実装 → PR → レビュー → `develop` にマージ
3. リリース時に `develop` → `main`
