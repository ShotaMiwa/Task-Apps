# タスク成長型SNS PvPアプリ システム設計書

**バージョン:** 1.7.0　　**作成日:** 2026年3月

## 更新履歴

| バージョン | 内容 |
|---|---|
| v1.7.0 | レビュー指摘反映（バトルフロー順序修正・battle_executions トランザクション明記・タスク終了の403定義・タイムゾーン明記・in_progress タスク扱い明記・勝率ゼロ除算対策・タイムサークル日付定義・battled_at 定義・タイムライン category 追加・GET /v1/league レスポンス修正） |
| v1.6.0 | バッチ冪等性の設計を修正（battle_executions テーブルに分離・battles テーブルの誤ったUNIQUE INDEX・processed カラムを削除） |
| v1.5.0 | 放置EXP上限・バッチ冪等性・トランザクション設計・インデックス定義・トークンハッシュ化・エラーコード細分化 |
| v1.4.0 | end_time をサーバー記録方式に変更・フォロー機能追加（DB・ファイル構成・処理フロー） |
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
| `routes/follows.js` | フォローエンドポイント定義 |
| `controllers/auth.js` | 認証ビジネスロジック |
| `controllers/avatar.js` | アバタービジネスロジック |
| `controllers/tasks.js` | タスクビジネスロジック |
| `controllers/timecircle.js` | タイムサークルビジネスロジック |
| `controllers/timeline.js` | タイムラインビジネスロジック |
| `controllers/league.js` | リーグ・バトルビジネスロジック |
| `controllers/follows.js` | フォロービジネスロジック |
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
| POST | `/v1/follows/:user_id` | フォローする | 必要 |
| DELETE | `/v1/follows/:user_id` | フォロー解除する | 必要 |
| GET | `/v1/follows/following` | 自分のフォロー一覧 | 必要 |
| GET | `/v1/follows/followers` | 自分のフォロワー一覧 | 必要 |

---

## 6. 主要処理フロー

### 6.1 認証フロー

| ステップ | 処理 |
|---|---|
| 1 | クライアントが email / password を `POST /v1/auth/login` に送信 |
| 2 | サーバーが DB から email でユーザーを検索 |
| 3 | bcrypt でパスワードを検証 |
| 4 | JWT アクセストークン (1h) とリフレッシュトークン (30d) を生成 |
| 5 | リフレッシュトークンを `bcrypt` でハッシュ化して `refresh_tokens` テーブルに保存 |
| 6 | クライアントにトークンを返却（生のトークンはこの1回のみ返す） |
| 7 | 以降のリクエストは `Authorization: Bearer {token}` を付与 |
| 8 | アクセストークン期限切れ時は `POST /v1/auth/refresh` で再発行。受け取ったリフレッシュトークンを `bcrypt.compare` でDB内ハッシュと照合 |
| 9 | ログアウト時は `POST /v1/auth/logout` を呼び `refresh_tokens` テーブルから該当レコードを削除 |

### 6.2 タスク記録フロー（トランザクション）

タスク終了処理は必ずトランザクション内で実行し、途中でエラーが発生した場合はロールバックする。

| ステップ | 処理 |
|---|---|
| 1 | `POST /v1/tasks/start` でタスク名・カテゴリ・公開設定を送信 |
| 2 | アバターが存在しない場合は `404 NOT_FOUND` を返す（message: "アバターが作成されていません"） |
| 3 | 未完了タスクが既に存在する場合は `409 TASK_ALREADY_RUNNING` を返す（message: "進行中のタスクがあります。先に終了してください"） |
| 4 | サーバーが `start_time` を記録し `in_progress` 状態で保存 |
| 5 | `PATCH /v1/tasks/:id/end` をリクエスト。指定した `:id` のタスクが他ユーザーのものである場合は `403 FORBIDDEN`、存在しない場合は `404 NOT_FOUND` を返す |
| 6 | `end_time = now()` をサーバーが記録 |
| 7 | **BEGIN** トランザクション開始 |
| 8 | `duration_minutes = (end_time - start_time)` を自動計算 |
| 9 | `effective_minutes = min(duration_minutes, 180)` を計算 |
| 10 | `exp = effective_minutes × 10` を計算 |
| 11 | カテゴリの `ratio × exp` でステータス増加量を計算 |
| 12 | キャラクタータイプの補正倍率を適用 |
| 13 | `tasks` テーブルの `end_time` / `duration_minutes` / `effective_minutes` / `exp_gained` を更新 |
| 14 | `avatars` テーブルのステータスを更新 |
| 15 | `league_memberships` の `last_task_at` を更新 |
| 16 | **COMMIT** トランザクション終了 |

```sql
-- タスク終了処理の擬似コード（ステップ7〜16）
BEGIN;
  UPDATE tasks SET end_time = now(), duration_minutes = ..., effective_minutes = ..., exp_gained = ... WHERE id = $1;
  UPDATE avatars SET int = int + $2, str = str + $3, foc = foc + $4, spi = spi + $5 WHERE user_id = $6;
  UPDATE league_memberships SET last_task_at = now() WHERE user_id = $6;
COMMIT;
```

### 6.3 フォローフロー

| ステップ | 処理 |
|---|---|
| 1 | `POST /v1/follows/:user_id` でフォロー対象を指定 |
| 2 | `follower_id === followee_id` の場合は `400 VALIDATION_ERROR` を返す |
| 3 | すでにフォロー済みの場合は `409 FOLLOW_ALREADY_EXISTS` を返す（DB の一意制約違反を利用） |
| 4 | `follows` テーブルに `(follower_id, followee_id)` を挿入 |
| 5 | フォロー解除は `DELETE /v1/follows/:user_id` でレコードを削除。存在しない場合は `404 NOT_FOUND` |

### 6.4 タイムライン取得フロー

| ステップ | 処理 |
|---|---|
| 1 | `GET /v1/timeline` をリクエスト |
| 2 | `visibility = public` のタスクは全件取得 |
| 3 | `visibility = followers` のタスクは `follows` テーブルを参照し、リクエストユーザーがフォローしている投稿者のものだけ取得 |
| 4 | `visibility = private` のタスクは除外 |
| 5 | `posted_at` 降順でソートして返却 |

### 6.5 デイリーバトルフロー（冪等性保証）

> **タイムゾーン基準：** バトルスケジュール（00:00・06:00）およびアクティブユーザー判定の「3日以内」はすべて **JST（UTC+9）** を基準とする。

| 時刻 (JST) | ステップ | 処理 |
|---|---|---|
| 00:00 | 1 | `battle_executions` テーブルに `battle_date = today` のレコードが存在する場合はスキップ（2重実行防止） |
| 00:00 | 2 | アクティブユーザー（3日以内にタスクあり）を取得 |
| 00:00 | 3 | リーグごとにユーザーをリストアップ |
| 00:00 | 4 | リーグ内ユーザーが2人未満の場合はそのリーグのバトルをスキップ |
| 00:00 | 5 | リーグ内ユーザーをランダムにシャッフルしてペアを組む（奇数の場合は1人バイ） |
| 00:00 | 6 | 各ペアの `base_power = INT×1.1 + STR×1.0 + FOC×1.2 + SPI×1.0` を計算 |
| 00:00 | 7 | `random_range = floor(base_power × 0.1)` のランダム幅を加算した power で1戦ごとに勝敗を決定 |
| 00:00 | 8 | 両者の power が完全に同値の場合はランダムで勝者を決定 |
| 00:00 | 9 | 5回バトルを実施し、3勝以上した方をペアの勝者とする |
| 00:00 | 10 | **トランザクション内で** 全ペアを `battles` テーブルに `is_published = false` で保存し、同一トランザクション内で `battle_executions` に `battle_date = today` を INSERT |
| 06:00 | 11 | `is_published = true` に更新 |
| 06:00 | 12 | `league_memberships` の `wins` / `losses` / `match_count` を更新 |
| 06:00 | 13 | 昇格: 勝率（`wins / match_count`）上位 `floor(リーグ人数 × 0.2)` 人を上位リーグへ（S リーグは昇格なし）。同率の場合は総戦闘力（`base_power`）で判断。`match_count = 0` のユーザーは昇格対象外。 |
| 06:00 | 14 | 降格: 勝率（`wins / match_count`）下位 `floor(リーグ人数 × 0.2)` 人を下位リーグへ（C リーグは降格なし）。同率の場合は総戦闘力（`base_power`）で判断。`match_count = 0` のユーザーは降格対象外。 |

### 6.6 マッチング詳細

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
effective_minutes = min(duration_minutes, 180)
exp = effective_minutes × 10
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

## 8. DBテーブル定義・インデックス

### 8.1 follows テーブル

```sql
CREATE TABLE follows (
  follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, followee_id),
  CHECK (follower_id <> followee_id)
);
```

### 8.2 battle_executions テーブル（バッチ冪等性管理）

バッチの2重実行を防ぐための専用テーブル。`battles` テーブルは1日に複数レコードを持つため、冪等性の管理を分離している。

```sql
CREATE TABLE battle_executions (
  battle_date DATE PRIMARY KEY,
  executed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

バッチ処理の冪等チェックと保存は以下の流れで行う。**`battles` への全ペア保存と `battle_executions` への INSERT は同一トランザクション内で実行すること。** これにより、COMMIT前のクラッシュ時はロールバックされ、復旧後の再実行で正常に処理される。

```js
// バッチ開始時：実行済みチェック
const already = await db.query(
  'SELECT 1 FROM battle_executions WHERE battle_date = $1',
  [today]
);
if (already.rows.length > 0) return; // スキップ

// 全ペアのバトル計算後：トランザクションで一括保存
const client = await db.connect();
try {
  await client.query('BEGIN');

  // 全ペアを battles テーブルに保存
  for (const battle of battleResults) {
    await client.query(
      'INSERT INTO battles (...) VALUES (...)',
      [...]
    );
  }

  // 同一トランザクション内で実行済みを記録
  await client.query(
    'INSERT INTO battle_executions (battle_date) VALUES ($1)',
    [today]
  );

  await client.query('COMMIT');
} catch (err) {
  await client.query('ROLLBACK');
  throw err;
} finally {
  client.release();
}
```

### 8.3 インデックス定義

タイムライン取得・フォロー参照のパフォーマンスを確保するために以下のインデックスを定義する。

```sql
-- タイムライン取得用：visibility でフィルタし posted_at 降順ソート
CREATE INDEX tasks_visibility_posted_at_idx ON tasks(visibility, posted_at DESC);

-- フォロー参照用：follower_id でフォロー先を高速検索
CREATE INDEX follows_follower_id_idx ON follows(follower_id);

-- フォロワー参照用：followee_id でフォロワーを高速検索
CREATE INDEX follows_followee_id_idx ON follows(followee_id);
```

> **スケーラビリティ注記：** 上記インデックスにより数万件規模までは問題なく動作する。それ以上のスケールではfanoutアーキテクチャまたはキャッシュ層が必要（v2以降で検討）。

---

## 9. エラーハンドリング方針

| HTTP ステータス | code | 説明 |
|---|---|---|
| 400 | `VALIDATION_ERROR` | リクエストの形式不正・必須項目欠如 |
| 401 | `UNAUTHORIZED` | 認証失敗・トークン期限切れ・無効 |
| 403 | `FORBIDDEN` | アクセス権限なし |
| 404 | `NOT_FOUND` | リソースが存在しない |
| 409 | `TASK_ALREADY_RUNNING` | 進行中のタスクが既に存在する |
| 409 | `FOLLOW_ALREADY_EXISTS` | すでにフォロー済み |
| 409 | `AVATAR_ALREADY_EXISTS` | アバターが既に作成済み |
| 500 | `INTERNAL_ERROR` | サーバー内部エラー |

### 9.1 エラーレスポンス共通形式

```json
{ "error": { "code": "TASK_ALREADY_RUNNING", "message": "進行中のタスクがあります。先に終了してください" } }
```

### 9.2 409サブコードの判別方法

DB の一意制約違反（`err.code === "23505"`）が発生した場合、`err.constraint` の制約名でどの 409 を返すか判別する。

| 制約名 | 返すコード |
|---|---|
| `tasks_user_id_active_unique`（未終了タスク制約） | `TASK_ALREADY_RUNNING` |
| `follows_pkey`（フォロー複合主キー制約） | `FOLLOW_ALREADY_EXISTS` |
| `avatars_user_id_unique`（アバター一意制約） | `AVATAR_ALREADY_EXISTS` |

### 9.3 方針

- 全ての controller は try-catch で囲み、500 エラーを必ずログ出力する
- クライアントには詳細なスタックトレースを返さない
- JWT 検証失敗 (`JsonWebTokenError` / `TokenExpiredError`) は 401 として返す
- 409 のメッセージはユーザーが次に取るべき行動を明示する

---

## 10. ブランチ運用ルール

| ブランチ | 用途 | マージ先 |
|---|---|---|
| `main` | 本番相当・直接 push 禁止 | - |
| `develop` | 開発統合ブランチ | `main` |
| `feature/xxx` | 機能ごとの作業ブランチ | `develop` |
| `fix/xxx` | バグ修正ブランチ | `develop` |

### 10.1 開発フロー

- `develop` から `feature/xxx` ブランチを切る
- 実装・動作確認後に PR を出す
- レビューしてもらってから `develop` にマージ
- 直接 `main` / `develop` へ push しない

---

## 11. コーディング規約

### 11.1 命名規則

| 対象 | スタイル | 例 |
|---|---|---|
| 変数・関数 | camelCase | `taskName`, `getUserById` |
| 定数 | UPPER_SNAKE_CASE | `JWT_SECRET` |
| ファイル名 | camelCase | `auth.js`, `dailyBattle.js` |
| DB カラム | snake_case | `task_name`, `start_time` |
| 環境変数 | UPPER_SNAKE_CASE | `DATABASE_URL` |

### 11.2 コード規約

- インデントはスペース 2 つ
- 文字列はシングルクォート (`'`) を使う
- セミコロンは必ずつける
- async/await を使い Promise チェーンは使わない
- controller は必ず try-catch で囲む
- `console.log` はデバッグ用のみ。本番コードには残さない

### 11.3 コミットメッセージ規約

| プレフィックス | 用途 | 例 |
|---|---|---|
| `feat` | 新機能追加 | `feat: 認証 API 実装` |
| `fix` | バグ修正 | `fix: ログイン時のエラー修正` |
| `chore` | 設定・環境変更 | `chore: Docker 設定追加` |
| `docs` | ドキュメント更新 | `docs: 設計書追加` |
| `refactor` | リファクタリング | `refactor: controller 整理` |
