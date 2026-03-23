-- =============================================
-- タスク成長型SNS PvPアプリ DBスキーマ (MVP)
-- =============================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ユーザー
CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username      VARCHAR(50)  NOT NULL UNIQUE,
  email         VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- リフレッシュトークン
CREATE TABLE refresh_tokens (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token      TEXT        NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);

-- アバター（1ユーザー1アバター）
CREATE TYPE avatar_type AS ENUM ('researcher', 'warrior', 'monk');

CREATE TABLE avatars (
  id         UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID        NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  type       avatar_type NOT NULL,
  level      INT         NOT NULL DEFAULT 1,
  total_exp  INT         NOT NULL DEFAULT 0,
  stat_int   NUMERIC(10,2) NOT NULL DEFAULT 0,
  stat_str   NUMERIC(10,2) NOT NULL DEFAULT 0,
  stat_foc   NUMERIC(10,2) NOT NULL DEFAULT 0,
  stat_spi   NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- タスクカテゴリ（マスタ）
CREATE TABLE task_categories (
  id        SERIAL PRIMARY KEY,
  name      VARCHAR(50) NOT NULL UNIQUE,
  ratio_int NUMERIC(4,2) NOT NULL,
  ratio_str NUMERIC(4,2) NOT NULL,
  ratio_foc NUMERIC(4,2) NOT NULL,
  ratio_spi NUMERIC(4,2) NOT NULL,
  CONSTRAINT check_ratio_sum CHECK (
    ratio_int + ratio_str + ratio_foc + ratio_spi = 1.00
  )
);

INSERT INTO task_categories (name, ratio_int, ratio_str, ratio_foc, ratio_spi) VALUES
  ('学習',       0.40, 0.05, 0.40, 0.15),
  ('運動',       0.05, 0.60, 0.20, 0.15),
  ('瞑想・休養', 0.05, 0.10, 0.15, 0.70),
  ('創作',       0.35, 0.05, 0.45, 0.15),
  ('家事・生活', 0.10, 0.40, 0.15, 0.35),
  ('仕事',       0.35, 0.10, 0.45, 0.10),
  ('その他',     0.30, 0.20, 0.30, 0.20);

-- タスク
CREATE TYPE task_visibility AS ENUM ('public', 'followers', 'private');
CREATE TYPE task_status     AS ENUM ('in_progress', 'completed');

CREATE TABLE tasks (
  id               UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  task_name        VARCHAR(255)    NOT NULL,
  category_id      INT             REFERENCES task_categories(id),
  visibility       task_visibility NOT NULL DEFAULT 'public',
  status           task_status     NOT NULL DEFAULT 'in_progress',
  start_time       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  end_time         TIMESTAMPTZ,
  duration_minutes INT,
  exp_gained       INT,
  gain_int         NUMERIC(10,2),
  gain_str         NUMERIC(10,2),
  gain_foc         NUMERIC(10,2),
  gain_spi         NUMERIC(10,2),
  created_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  CONSTRAINT check_end_after_start CHECK (end_time IS NULL OR end_time > start_time)
);

CREATE INDEX idx_tasks_user_id     ON tasks(user_id);
CREATE INDEX idx_tasks_start_time  ON tasks(user_id, start_time DESC);
CREATE INDEX idx_tasks_in_progress ON tasks(user_id) WHERE status = 'in_progress';
CREATE INDEX idx_tasks_timeline    ON tasks(start_time DESC)
  WHERE visibility = 'public' AND status = 'completed';

-- リーグ
CREATE TYPE league_tier AS ENUM ('S', 'A', 'B', 'C');

CREATE TABLE league_memberships (
  id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID        NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  league       league_tier NOT NULL DEFAULT 'C',
  wins         INT         NOT NULL DEFAULT 0,
  losses       INT         NOT NULL DEFAULT 0,
  is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
  last_task_at TIMESTAMPTZ,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_league_by_tier ON league_memberships(league, wins DESC);

-- バトル
CREATE TABLE battles (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  league        league_tier NOT NULL,
  user1_id      UUID        NOT NULL REFERENCES users(id),
  user2_id      UUID        NOT NULL REFERENCES users(id),
  user1_power   NUMERIC(12,2) NOT NULL,
  user2_power   NUMERIC(12,2) NOT NULL,
  winner_id     UUID        REFERENCES users(id),
  is_published  BOOLEAN     NOT NULL DEFAULT FALSE,
  battled_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_battles_user1 ON battles(user1_id, battled_at DESC);
CREATE INDEX idx_battles_user2 ON battles(user2_id, battled_at DESC);

-- updated_at 自動更新
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_avatars_updated_at
  BEFORE UPDATE ON avatars FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_tasks_updated_at
  BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_league_updated_at
  BEFORE UPDATE ON league_memberships FOR EACH ROW EXECUTE FUNCTION update_updated_at();
