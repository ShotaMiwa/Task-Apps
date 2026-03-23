# タスク成長型SNS PvPアプリ システム設計書

**バージョン:** 1.3.0　　**作成日:** 2026年3月

## 更新履歴

| バージョン | 内容 |
|---|---|
| v1.3.0 | 勝率同率時の昇格・降格タイブレーカーを追加 |
| v1.2.0 | 第2回レビュー指摘事項を反映 |
| v1.1.0 | レビュー指摘事項を反映 |
| v1.0.0 | 初版作成 |

---

## 1. 概要

本ドキュメントはタスク成長型SNS PvPアプリのシステム設計書である。仕様書をもとにシステム構成・処理フロー・ファイル構成・エラーハンドリング方針を定義する。

---

## 2. 技術スタック

| レイヤー | 技術 | 備考 |
|---|---|---|
| フロントエンド | Expo (React Native) | iOS / Android |
| バックエンド | Node.js + Express | REST API |
| データベース | PostgreSQL 16 | Docker コンテナ |
| バッチ処理 | node-cron | デイリーバトル |
| 認証 | JWT (Bearer Token) | アクセス1h / リフレッシュ30d |
| インフラ（本番） | 自宅PC + Cloudflare Tunnel | Docker Compose |
| 開発環境 | Docker (DB のみ) + ローカル API | nodemon で自動再起動 |

---

## 3. システム構成

### 3.1 開発環境

| コンポーネント | 場所 | 起動方法 |
|---|---|---|
| PostgreSQL | Docker コンテナ | `docker compose up db -d` |
| Express API | ローカル (WSL2) | `npm run dev` |
| Expo | ローカル (各自の PC) | `expo start` |

### 3.2 本番環境

| コンポーネント | 場所 | 起動方法 |
|---|---|---|
| PostgreSQL | Docker コンテナ (自宅 PC) | `docker compose up` |
| Express API | Docker コンテナ (自宅 PC) | `docker compose up` |
| Cloudflare Tunnel | 自宅 PC | `cloudflared tunnel run` |
| Expo | ユーザーのスマートフォン | Expo Go / スタンドアロンビルド |

---

## 4. ファイル構成

### 4.1 バックエンド (`apps/api/src/`)

| ファイル | 役割 |
|---|---|
| `index.js` | サーバー起動・ルート登録 |
| `models/db.js` | PostgreSQL 接続プール管理 |
| `middleware/auth.js` | JWT 認証ミドルウェア |
| `routes/auth.js` | 認証エンドポイント定義 |
| `routes/avatar.js` | アバターエンドポイント定義 |
| `routes/tasks.js` | タスクエンドポイント定義 |
| `routes/timecircle.js` | タイムサークルエンドポイント定義 |
| `routes/timeline.js` | タイムラインエンドポイント定義 |
| `routes/league.js` | リーグ・バトルエンドポイント定義 |
| `controllers/auth.js` | 認証ビジネスロジック |
| `controllers/avatar.js` | アバタービジネスロジック |
| `controllers/tasks.js` | タスクビジネスロジック |
| `controllers/timecircle.js` | タイムサークルビジネスロジック |
| `controllers/timeline.js` | タイムラインビジネスロジック |
| `controllers/league.js` | リーグ・バトルビジネスロジック |
| `batch/dailyBattle.js` | デイリーバトルバッチ処理 (node-cron) |

### 4.2 フロントエンド (`apps/mobile/`)

フロントエンド (Expo) のファイル構成は別途定義する。バックエンド API の実装完了後に作成予定。

---

## 5. API 設計

### 5.1 共通仕様

| 項目 | 内容 |
|---|---|
| ベース URL | `https://api.example.com` |
| API バージョンプレフィックス | `/v1`（各エンドポイントに含む） |
| 形式 | REST / JSON |
| 認証 | `Authorization: Bearer {アクセストークン}` |
| 日時形式 | ISO 8601（例: `2025-04-01T09:00:00Z`） |

### 5.2 エンドポイント一覧

| メソッド | エンドポイント | 説明 | 認証 |
|---|---|---|---|
| POST | `/v1/auth/register` | ユーザー登録 | 不要 |
| POST | `/v1/auth/login` | ログイン・JWT 発行 | 不要 |
| POST | `/v1/auth/refresh` | アクセストークン再発行 ※リフレッシュトークン必須 | 不要 |
| POST | `/v1/auth/logout` | ログアウト・リフレッシュトークン削除 | 必要 |
| POST | `/v1/avatar` | キャラクター作成 | 必要 |
| GET | `/v1/avatar` | 自分のキャラクター取得 | 必要 |
| GET | `/v1/avatar/:user_id` | 他ユーザーのキャラクター取得 | 必要 |
| POST | `/v1/tasks/start` | タイマー開始 | 必要 |
| PATCH | `/v1/tasks/:id/end` | タイマー終了・タスク完了 | 必要 |
| GET | `/v1/tasks` | 自分のタスク一覧 | 必要 |
| DELETE | `/v1/tasks/:id` | タスク削除 | 必要 |
| GET | `/v1/timecircle` | 今日のタイムサークル | 必要 |
| GET | `/v1/timecircle/:user_id` | 他ユーザーのタイムサークル | 必要 |
| GET | `/v1/timeline` | タイムライン取得 | 必要 |
| GET | `/v1/league` | リーグ・ランキング取得 | 必要 |
| GET | `/v1/battles` | 直近バトル結果 | 必要 |

---

## 6. 主要処理フロー

### 6.1 認証フロー

| ステップ | 処理 |
|---|---|
| 1 | クライアントが email / password を `POST /v1/auth/login` に送信 |
| 2 | サーバーが DB から email でユーザーを検索 |
| 3 | bcrypt でパスワードを検証 |
| 4 | JWT アクセストークン (1h) とリフレッシュトークン (30d) を生成 |
| 5 | リフレッシュトークンを `refresh_tokens` テーブルに保存 |
| 6 | クライアントにトークンを返却 |
| 7 | 以降のリクエストは `Authorization: Bearer {token}` を付与 |
| 8 | アクセストークン期限切れ時は `POST /v1/auth/refresh` で再発行 |
| 9 | ログアウト時は `POST /v1/auth/logout` を呼び `refresh_tokens` テーブルから該当レコードを削除 |

### 6.2 タスク記録フロー

| ステップ | 処理 |
|---|---|
| 1 | `POST /v1/tasks/start` でタスク名・カテゴリ・公開設定を送信 |
| 2 | アバターが存在しない場合は `404 NOT_FOUND` を返す（message: "アバターが作成されていません"） |
| 3 | サーバーが `start_time` を記録し `in_progress` 状態で保存 |
| 4 | 未完了タスクが既に存在する場合は `409 CONFLICT` を返す（message: "進行中のタスクがあります。先に終了してください"） |
| 5 | `PATCH /v1/tasks/:id/end` で `end_time` を送信 |
| 6 | `duration_minutes = (end_time - start_time)` を自動計算 |
| 7 | `exp = duration_minutes × 10` を計算 |
| 8 | カテゴリの `ratio × exp` でステータス増加量を計算 |
| 9 | キャラクタータイプの補正倍率を適用 |
| 10 | `avatars` テーブルのステータスを更新 |
| 11 | `league_memberships` の `last_task_at` を更新 |

### 6.3 デイリーバトルフロー

| 時刻 | ステップ | 処理 |
|---|---|---|
| 00:00 | 1 | アクティブユーザー（3日以内にタスクあり）を取得 |
| 00:00 | 2 | リーグごとにユーザーをリストアップ |
| 00:00 | 3 | リーグ内ユーザーが2人未満の場合はそのリーグのバトルをスキップ |
| 00:00 | 4 | リーグ内ユーザーをランダムにシャッフルしてペアを組む（奇数の場合は1人バイ） |
| 00:00 | 5 | 各ペアで5回バトルを実施 |
| 00:00 | 6 | `base_power = INT×1.1 + STR×1.0 + FOC×1.2 + SPI×1.0` を計算 |
| 00:00 | 7 | `random_range = floor(base_power × 0.1)` のランダム幅を加算した power で1戦ごとに勝敗を決定 |
| 00:00 | 8 | 両者の power が完全に同値の場合はランダムで勝者を決定 |
| 00:00 | 9 | 5回中3勝以上した方をペアの勝者とする |
| 00:00 | 10 | `is_published = false` のまま `battles` テーブルに保存（非公開） |
| 06:00 | 11 | `is_published = true` に更新 |
| 06:00 | 12 | `league_memberships` の `wins` / `losses` / `match_count` を更新 |
| 06:00 | 13 | 昇格: 勝率（`wins / match_count`）上位 `floor(リーグ人数 × 0.2)` 人を上位リーグへ（S リーグは昇格なし）。同率の場合は総戦闘力（`base_power`）で判断 |
| 06:00 | 14 | 降格: 勝率（`wins / match_count`）下位 `floor(リーグ人数 × 0.2)` 人を下位リーグへ（C リーグは降格なし）。同率の場合は総戦闘力（`base_power`）で判断 |

### 6.4 マッチング詳細

| ケース | 挙動 |
|---|---|
| リーグ内が1人 | バトルスキップ（不戦勝なし） |
| リーグ内が2人以上 | ランダムシャッフル後にペアを組む |
| 奇数人数でペアが余る | 余った1人はバイ（その日のバトルなし・勝敗カウントなし・`match_count` も増えない） |
| 1戦で power が同値 | ランダムで勝者を決定 |
| 昇格・降格の基準 | 勝率（`wins / match_count`）で判断。バイの日は `match_count` に含まれないため勝率に影響しない |

---

## 7. EXP・ステータス計算仕様

### 7.1 EXP 計算

```
exp = duration_minutes × 10
```

### 7.2 ステータス分配（カテゴリ別）

| カテゴリ | INT | STR | FOC | SPI |
|---|---|---|---|---|
| 学習 | 40% | 5% | 40% | 15% |
| 運動 | 5% | 60% | 20% | 15% |
| 瞑想・休養 | 5% | 10% | 15% | 70% |
| 創作 | 35% | 5% | 45% | 15% |
| 家事・生活 | 10% | 40% | 15% | 35% |
| 仕事 | 35% | 10% | 45% | 10% |
| その他 | 30% | 20% | 30% | 20% |

### 7.3 キャラクタータイプ補正

| ステータス | 研究者 | 戦士 | 修行僧 |
|---|---|---|---|
| INT | ×1.4 | ×0.8 | ×1.0 |
| STR | ×0.8 | ×1.5 | ×0.9 |
| FOC | ×1.2 | ×1.0 | ×1.2 |
| SPI | ×1.0 | ×1.1 | ×1.3 |

### 7.4 レベル計算

```
level = floor( sqrt(total_exp / 100) )
```

---

## 8. エラーハンドリング方針

| HTTP ステータス | code | 説明 |
|---|---|---|
| 400 | `VALIDATION_ERROR` | リクエストの形式不正・必須項目欠如 |
| 401 | `UNAUTHORIZED` | 認証失敗・トークン期限切れ・無効 |
| 403 | `FORBIDDEN` | アクセス権限なし |
| 404 | `NOT_FOUND` | リソースが存在しない |
| 409 | `CONFLICT` | 重複登録（アバター作成済み・タスク進行中） |
| 500 | `INTERNAL_ERROR` | サーバー内部エラー |

### 8.1 エラーレスポンス共通形式

```json
{ "error": { "code": "UNAUTHORIZED", "message": "認証トークンが無効です" } }
```

### 8.2 方針

- 全ての controller は try-catch で囲み、500 エラーを必ずログ出力する
- クライアントには詳細なスタックトレースを返さない
- DB の一意制約違反 (`err.code === "23505"`) は 409 として返す
- JWT 検証失敗 (`JsonWebTokenError` / `TokenExpiredError`) は 401 として返す
- 409 CONFLICT のメッセージはユーザーが次に取るべき行動を明示する

---

## 9. ブランチ運用ルール

| ブランチ | 用途 | マージ先 |
|---|---|---|
| `main` | 本番相当・直接 push 禁止 | - |
| `develop` | 開発統合ブランチ | `main` |
| `feature/xxx` | 機能ごとの作業ブランチ | `develop` |
| `fix/xxx` | バグ修正ブランチ | `develop` |

### 9.1 開発フロー

- `develop` から `feature/xxx` ブランチを切る
- 実装・動作確認後に PR を出す
- レビューしてもらってから `develop` にマージ
- 直接 `main` / `develop` へ push しない

---

## 10. コーディング規約

### 10.1 命名規則

| 対象 | スタイル | 例 |
|---|---|---|
| 変数・関数 | camelCase | `taskName`, `getUserById` |
| 定数 | UPPER_SNAKE_CASE | `JWT_SECRET` |
| ファイル名 | camelCase | `auth.js`, `dailyBattle.js` |
| DB カラム | snake_case | `task_name`, `start_time` |
| 環境変数 | UPPER_SNAKE_CASE | `DATABASE_URL` |

### 10.2 コード規約

- インデントはスペース 2 つ
- 文字列はシングルクォート (`'`) を使う
- セミコロンは必ずつける
- async/await を使い Promise チェーンは使わない
- controller は必ず try-catch で囲む
- `console.log` はデバッグ用のみ。本番コードには残さない

### 10.3 コミットメッセージ規約

| プレフィックス | 用途 | 例 |
|---|---|---|
| `feat` | 新機能追加 | `feat: 認証 API 実装` |
| `fix` | バグ修正 | `fix: ログイン時のエラー修正` |
| `chore` | 設定・環境変更 | `chore: Docker 設定追加` |
| `docs` | ドキュメント更新 | `docs: 設計書追加` |
| `refactor` | リファクタリング | `refactor: controller 整理` |
