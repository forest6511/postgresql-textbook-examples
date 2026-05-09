
-- ===== Block 1 =====
CREATE TABLE app.invoices (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    amount      numeric(12, 2) NOT NULL CHECK (amount >= 0),
    tax_rate    numeric(5, 4)  NOT NULL DEFAULT 0.10,
    created_at  timestamptz    NOT NULL DEFAULT now()
);

-- ===== Block 2 =====
-- (1) serial(従来の PostgreSQL 拡張)
CREATE TABLE app.posts_v1 (
    id    bigserial PRIMARY KEY,
    title text NOT NULL
);

-- (2) IDENTITY 列(SQL 標準・PG 10 以降推奨)
CREATE TABLE app.posts_v2 (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title text NOT NULL
);

-- ===== Block 3 =====
CREATE TABLE app.profiles (
    user_id     bigint PRIMARY KEY REFERENCES app.users(id),
    bio         text,
    twitter_id  varchar(15),
    country     char(2) NOT NULL DEFAULT 'JP'
);

-- ===== Block 4 =====
SET TIME ZONE 'Asia/Tokyo';

CREATE TABLE app.t_demo (
    id   bigint GENERATED ALWAYS AS IDENTITY,
    naive timestamp,
    aware timestamptz
);

INSERT INTO app.t_demo (naive, aware)
VALUES ('2026-05-09 14:30:00+09', '2026-05-09 14:30:00+09');

SET TIME ZONE 'UTC';
SELECT naive, aware FROM app.t_demo;

-- ===== Block 5 =====
SELECT now() AS current_time,
       now() - interval '7 days' AS week_ago,
       now() + interval '3 hours 30 minutes' AS three_hours_later;

-- ===== Block 6 =====
CREATE TABLE app.events (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type text NOT NULL,
    payload    jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- ===== Block 7 =====
-- PostgreSQL 18 で追加された関数
SELECT uuidv4() AS v4_random;
SELECT uuidv7() AS v7_time_ordered;

-- ===== Block 8 =====
-- サンプルデータ
INSERT INTO app.events (event_type, payload) VALUES
  ('signup',  '{"user_id": 1, "plan": "free", "tags": ["new", "promo"]}'),
  ('upgrade', '{"user_id": 1, "plan": "pro",  "tags": ["paid"]}');

SELECT
    payload -> 'plan'         AS plan_jsonb,
    payload ->> 'plan'        AS plan_text,
    payload -> 'tags' -> 0    AS first_tag,
    payload @> '{"plan":"pro"}'::jsonb AS is_pro,
    payload ? 'user_id'       AS has_user_id
FROM app.events
WHERE event_type = 'upgrade';

-- ===== Block 9 =====
CREATE TABLE app.articles (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title text NOT NULL,
    tags  text[] NOT NULL DEFAULT '{}'
);

INSERT INTO app.articles (title, tags) VALUES
  ('PostgreSQL 入門', ARRAY['db', 'postgres']),
  ('運用の話',         ARRAY['db', 'ops']);

SELECT title FROM app.articles WHERE 'db' = ANY (tags);

-- ===== Block 10 =====
CREATE TYPE app.order_status AS ENUM
  ('pending', 'paid', 'shipped', 'cancelled');

CREATE TABLE app.shipments (
    id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status app.order_status NOT NULL DEFAULT 'pending'
);

-- ===== Block 11 =====
CREATE TABLE app.feature_flags (
    name    text PRIMARY KEY,
    enabled boolean NOT NULL DEFAULT false
);

-- ===== Block 12 =====
CREATE TABLE app.users_v2 (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email text NOT NULL,
    name  text NOT NULL
);

-- ===== Block 13 =====
CREATE TABLE app.user_emails (
    user_id bigint REFERENCES app.users_v2(id),
    email   text NOT NULL,
    UNIQUE (user_id, email)
);

-- ===== Block 14 =====
ALTER TABLE app.user_emails
ADD CONSTRAINT user_emails_email_unique
UNIQUE NULLS NOT DISTINCT (email);

-- ===== Block 15 =====
ALTER TABLE app.invoices
ADD CONSTRAINT invoices_amount_positive CHECK (amount > 0);

ALTER TABLE app.invoices
ADD CONSTRAINT invoices_amount_le_limit
CHECK (amount <= 1000000000);

-- ===== Block 16 =====
CREATE TABLE app.order_items (
    order_id bigint REFERENCES app.orders(id),
    line_no  integer,
    quantity integer NOT NULL,
    PRIMARY KEY (order_id, line_no)
);

-- ===== Block 17 =====
CREATE TABLE app.order_items_v2 (
    id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id bigint NOT NULL
             REFERENCES app.orders(id) ON DELETE CASCADE,
    book_id  bigint NOT NULL
             REFERENCES app.books(id)  ON DELETE RESTRICT,
    quantity integer NOT NULL CHECK (quantity > 0)
);

-- ===== Block 18 =====
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE app.reservations (
    room_id    integer NOT NULL,
    period     tstzrange NOT NULL,
    EXCLUDE USING gist (room_id WITH =, period WITH &&)
);

-- ===== Block 19 =====
CREATE TABLE app.audit_logs (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    actor      text NOT NULL,
    action     text NOT NULL,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    request_id text DEFAULT current_setting('app.request_id', true)
);

-- ===== Block 20 =====
CREATE TABLE app.body_metrics (
    user_id    bigint PRIMARY KEY,
    height_cm  numeric NOT NULL,
    weight_kg  numeric NOT NULL,
    bmi        numeric GENERATED ALWAYS AS
                 (weight_kg / ((height_cm / 100) * (height_cm / 100)))
                 STORED
);

-- ===== Block 21 =====
CREATE TABLE app.products (
    id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku      text UNIQUE NOT NULL,
    name     text NOT NULL
);

-- ===== Block 22 =====
CREATE INDEX products_name_idx ON app.products (name);

CREATE INDEX orders_user_created_idx
ON app.orders (user_id, ordered_at DESC);

-- ===== Block 23 =====
CREATE INDEX CONCURRENTLY orders_book_id_idx
ON app.orders (book_id);

-- ===== Block 24 =====
SELECT indexrelid::regclass AS index_name, indrelid::regclass AS table_name
FROM pg_index
WHERE indisvalid = false;

-- ===== Block 25 =====
CREATE INDEX orders_user_idx_with_amount
ON app.orders (user_id) INCLUDE (amount);

-- ===== Block 26 =====
CREATE INDEX orders_pending_idx
ON app.orders (created_at)
WHERE status = 'pending';

-- ===== Block 27 =====
SELECT
    schemaname || '.' || relname AS table,
    indexrelname AS index,
    idx_scan AS times_used,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname NOT IN ('pg_catalog', 'pg_toast')
ORDER BY pg_relation_size(indexrelid) DESC;
