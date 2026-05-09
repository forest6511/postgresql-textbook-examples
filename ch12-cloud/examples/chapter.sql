-- ===== Block 1 =====
-- 自分の投稿のみ閲覧可能
CREATE POLICY "users_view_own_posts"
ON posts FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 認証済みユーザーは投稿可能(自分の user_id でしか書けない)
CREATE POLICY "users_insert_own_posts"
ON posts FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- ===== Block 2 =====
-- staging_orders を本番 orders に取り込む
MERGE INTO orders t
USING staging_orders s ON s.id = t.id
WHEN MATCHED AND s.deleted THEN DELETE
WHEN MATCHED THEN UPDATE
    SET status = s.status, updated_at = now()
WHEN NOT MATCHED BY TARGET THEN INSERT
    (id, status, created_at) VALUES (s.id, s.status, now())
WHEN NOT MATCHED BY SOURCE AND t.archived_at IS NULL THEN
    UPDATE SET archived_at = now()
RETURNING merge_action(), t.id, t.status;

-- ===== Block 3 =====
WITH api_response AS (
    SELECT '[
      {"id": 1, "name": "Alice", "age": 30},
      {"id": 2, "name": "Bob",   "age": 25}
    ]'::jsonb AS data
)
SELECT t.id, t.name, t.age
FROM api_response,
     JSON_TABLE(data, '$[*]' COLUMNS (
         id   bigint   PATH '$.id',
         name text     PATH '$.name',
         age  smallint PATH '$.age'
     )) AS t;

-- ===== Block 4 =====
-- failover slot の作成(PG 17+)
SELECT pg_create_logical_replication_slot(
    'mysub_slot',
    'pgoutput',
    false,    -- temporary?
    false,    -- two_phase?
    true      -- failover(PG 17 新)
);

-- ===== Block 5 =====
-- PG 18+ で利用可能
SELECT uuidv7();
-- 0192d5c9-4a31-7c8e-9b1d-3a4f5e6c7d8a

-- テーブル定義で使う
CREATE TABLE events (
    id   uuid PRIMARY KEY DEFAULT uuidv7(),
    type text,
    payload jsonb,
    created_at timestamptz DEFAULT now()
);

-- ===== Block 6 =====
CREATE TABLE products (
    id          bigint PRIMARY KEY,
    price_yen   integer NOT NULL,
    -- VIRTUAL: ストレージ消費なし、参照時に計算(PG 18+)
    price_usd   numeric GENERATED ALWAYS AS (price_yen / 150.0) VIRTUAL
);

-- ===== Block 7 =====
ALTER TABLE orders
ADD CONSTRAINT fk_user_id
    FOREIGN KEY (user_id) REFERENCES users(id) NOT ENFORCED;

-- ===== Block 8 =====
-- 移行不可な reg* 型
-- regcollation / regconfig / regdictionary / regnamespace
-- regoper / regoperator / regproc / regprocedure

-- 移行可能な reg* 型
-- regclass / regrole / regtype
