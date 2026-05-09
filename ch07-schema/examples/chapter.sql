
-- ===== Block 1 =====
-- 1NF 違反: 電話番号を 3 列に分けている
CREATE TABLE customers_v0 (
    id           bigint PRIMARY KEY,
    name         text NOT NULL,
    phone1       text,
    phone2       text,
    phone3       text
);

-- ===== Block 2 =====
CREATE TABLE customers (
    id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL
);

CREATE TABLE customer_phones (
    customer_id bigint NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    phone       text   NOT NULL,
    PRIMARY KEY (customer_id, phone)
);

-- ===== Block 3 =====
-- 2NF 違反: order_items の product_name は product_id だけに依存
CREATE TABLE order_items_v0 (
    order_id     bigint,
    product_id   bigint,
    product_name text,           -- product_id だけに依存
    quantity     integer,
    PRIMARY KEY (order_id, product_id)
);

-- ===== Block 4 =====
CREATE TABLE products (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  text   NOT NULL
);

CREATE TABLE order_items (
    order_id   bigint  NOT NULL REFERENCES orders(id),
    product_id bigint  NOT NULL REFERENCES products(id),
    quantity   integer NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (order_id, product_id)
);

-- ===== Block 5 =====
-- 3NF 違反: department_name は department_id に依存
CREATE TABLE employees_v0 (
    id              bigint PRIMARY KEY,
    name            text NOT NULL,
    department_id   bigint,
    department_name text          -- department_id に推移的従属
);

-- ===== Block 6 =====
CREATE TABLE departments (
    id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text   NOT NULL UNIQUE
);

CREATE TABLE employees (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          text   NOT NULL,
    department_id bigint NOT NULL REFERENCES departments(id)
);

-- ===== Block 7 =====
-- 旧来の serial(PG 10 以降は非推奨、後方互換のため残存)
CREATE TABLE users_old (
    id   bigserial PRIMARY KEY,
    name text NOT NULL
);

-- SQL 標準準拠の IDENTITY 列(本書の推奨)
CREATE TABLE users (
    id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL
);

-- 分散・外部生成が必要な場合の UUIDv7(PG 18 で組み込み)
CREATE TABLE users_uuid (
    id   uuid PRIMARY KEY DEFAULT uuidv7(),
    name text NOT NULL
);

-- ===== Block 8 =====
CREATE TABLE app.users (
    id         bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email      text        NOT NULL UNIQUE,
    name       text        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz                          -- NULL = 有効
);

-- updated_at の自動更新トリガ
CREATE OR REPLACE FUNCTION app.set_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON app.users
    FOR EACH ROW
    EXECUTE FUNCTION app.set_updated_at();

-- ===== Block 9 =====
CREATE VIEW app.users_active AS
SELECT id, email, name, created_at, updated_at
  FROM app.users
 WHERE deleted_at IS NULL;

-- ===== Block 10 =====
CREATE TYPE order_status AS ENUM ('pending', 'paid', 'cancelled');

CREATE TABLE orders (
    id     bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status order_status NOT NULL DEFAULT 'pending'
);

-- 値の追加は可能(PG 9.1 以降)
ALTER TYPE order_status ADD VALUE 'refunded';

-- ===== Block 11 =====
CREATE TABLE orders (
    id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status text   NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'paid', 'cancelled'))
);

-- ===== Block 12 =====
CREATE TABLE order_statuses (
    code        text PRIMARY KEY,
    label       text NOT NULL,
    is_terminal boolean NOT NULL DEFAULT false,
    sort_order  integer NOT NULL
);

INSERT INTO order_statuses VALUES
    ('pending',   '未払い',   false, 10),
    ('paid',      '支払済み', false, 20),
    ('cancelled', 'キャンセル', true,  30);

CREATE TABLE orders (
    id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status text   NOT NULL DEFAULT 'pending'
        REFERENCES order_statuses(code)
);

-- ===== Block 13 =====
CREATE TABLE user_roles (
    user_id     bigint NOT NULL REFERENCES users(id)         ON DELETE CASCADE,
    role_id     bigint NOT NULL REFERENCES roles(id)         ON DELETE RESTRICT,
    granted_at  timestamptz NOT NULL DEFAULT now(),
    granted_by  bigint REFERENCES users(id),
    PRIMARY KEY (user_id, role_id)
);

-- ===== Block 14 =====
-- アンチパターン: target_type と target_id で参照先を切り替え
CREATE TABLE comments_bad (
    id          bigint  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    target_type text    NOT NULL,        -- 'article' / 'video' 等
    target_id   bigint  NOT NULL,
    body        text    NOT NULL
);

-- ===== Block 15 =====
-- 案A: 参照先ごとに別テーブル(推奨)
CREATE TABLE article_comments (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    article_id bigint NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    body       text   NOT NULL
);

CREATE TABLE video_comments (
    id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    video_id bigint NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
    body     text   NOT NULL
);

-- 案B: 親エンティティを統一(commentable のような共通親)
CREATE TABLE commentables (
    id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type text   NOT NULL                     -- 'article' / 'video'
);

-- 各々のテーブルに commentable_id を持たせる
ALTER TABLE articles ADD COLUMN commentable_id bigint
    REFERENCES commentables(id);

-- ===== Block 16 =====
CREATE TABLE categories (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id bigint REFERENCES categories(id),
    name      text   NOT NULL
);

-- ===== Block 17 =====
WITH RECURSIVE ancestors AS (
    SELECT id, parent_id, name, 0 AS depth
      FROM categories WHERE id = 42
    UNION ALL
    SELECT c.id, c.parent_id, c.name, a.depth + 1
      FROM categories c
      JOIN ancestors a ON a.parent_id = c.id
)
SELECT * FROM ancestors;

-- ===== Block 18 =====
CREATE TABLE category_paths (
    ancestor_id   bigint  NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    descendant_id bigint  NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    depth         integer NOT NULL,
    PRIMARY KEY (ancestor_id, descendant_id)
);

-- ===== Block 19 =====
CREATE EXTENSION IF NOT EXISTS ltree;

CREATE TABLE categories_lt (
    id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text   NOT NULL,
    path ltree  NOT NULL          -- 例: 'shop.electronics.audio'
);

CREATE INDEX idx_cat_path ON categories_lt USING GIST (path);

-- 'shop.electronics' 配下の全カテゴリ
SELECT * FROM categories_lt WHERE path <@ 'shop.electronics';

-- 'audio' を末端に持つ全パス
SELECT * FROM categories_lt WHERE path ~ '*.audio';

-- ===== Block 20 =====
-- 全演算子対応(@>, ?, ?&, ?| すべて使う)
CREATE INDEX idx_users_meta_gin ON users USING GIN (metadata jsonb_ops);

-- 包含クエリ(@>) しか使わないなら軽量な jsonb_path_ops
CREATE INDEX idx_users_meta_path ON users USING GIN (metadata jsonb_path_ops);

-- ===== Block 21 =====
-- Step 1: NOT VALID 付きで制約宣言(スキャンなし、即時)
ALTER TABLE users
    ADD CONSTRAINT users_status_not_null
    CHECK (status IS NOT NULL) NOT VALID;

-- Step 2: 別トランザクションでバックフィル(オンライン)
UPDATE users SET status = 'active' WHERE status IS NULL;

-- Step 3: 制約を VALIDATE(ROW EXCLUSIVE のみ、SELECT/INSERT 並列可)
ALTER TABLE users VALIDATE CONSTRAINT users_status_not_null;

-- Step 4: 完全な NOT NULL に昇格(PG 18 で短時間化)
ALTER TABLE users ALTER COLUMN status SET NOT NULL;

-- ===== Block 22 =====
CREATE INDEX CONCURRENTLY idx_users_email
    ON users (email);
