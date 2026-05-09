
-- ===== Block 1 =====
-- アプリケーション用データベースを作る
CREATE DATABASE textbook OWNER app;

-- 接続切り替え
\c textbook

-- スキーマを作る
CREATE SCHEMA app AUTHORIZATION app;

-- テーブルを作る
CREATE TABLE app.users (
    id          bigserial PRIMARY KEY,
    email       text NOT NULL UNIQUE,
    name        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

INSERT INTO app.users (email, name) VALUES
    ('alice@example.com', 'Alice'),
    ('bob@example.com',   'Bob');

-- ===== Block 2 =====
ALTER ROLE app SET search_path = app, public;

-- ===== Block 3 =====
-- 読み取り専用グループロール
CREATE ROLE readonly NOLOGIN;
GRANT CONNECT ON DATABASE textbook TO readonly;
GRANT USAGE ON SCHEMA app TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO readonly;

-- 個別ユーザーを readonly に所属させる
CREATE ROLE bob_readonly LOGIN PASSWORD 'pass';
GRANT readonly TO bob_readonly;

-- 今後作成されるテーブルにも自動付与
ALTER DEFAULT PRIVILEGES IN SCHEMA app
    GRANT SELECT ON TABLES TO readonly;

-- ===== Block 4 =====
CREATE DATABASE textbook
    ENCODING 'UTF8'
    LC_COLLATE 'C'
    LC_CTYPE 'C.UTF-8'
    TEMPLATE template0;
