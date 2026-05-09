
-- ===== Block 1 =====
CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE app.events (
    id          bigint      GENERATED ALWAYS AS IDENTITY,
    user_id     bigint      NOT NULL,
    occurred_at timestamptz NOT NULL,
    payload     jsonb,
    PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

CREATE TABLE app.events_2026_05 PARTITION OF app.events
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE TABLE app.events_2026_06 PARTITION OF app.events
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

-- ===== Block 2 =====
CREATE TABLE app.users_by_region (
    id     bigint GENERATED ALWAYS AS IDENTITY,
    region text   NOT NULL,
    name   text   NOT NULL,
    PRIMARY KEY (id, region)
) PARTITION BY LIST (region);

CREATE TABLE app.users_jp PARTITION OF app.users_by_region
    FOR VALUES IN ('jp');

CREATE TABLE app.users_us PARTITION OF app.users_by_region
    FOR VALUES IN ('us', 'ca', 'mx');

CREATE TABLE app.users_other PARTITION OF app.users_by_region
    DEFAULT;

-- ===== Block 3 =====
CREATE TABLE app.sessions (
    id      bigint NOT NULL,
    payload jsonb,
    PRIMARY KEY (id)
) PARTITION BY HASH (id);

CREATE TABLE app.sessions_p0 PARTITION OF app.sessions
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE app.sessions_p1 PARTITION OF app.sessions
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE app.sessions_p2 PARTITION OF app.sessions
    FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE app.sessions_p3 PARTITION OF app.sessions
    FOR VALUES WITH (MODULUS 4, REMAINDER 3);

-- ===== Block 4 =====
EXPLAIN
SELECT * FROM app.events
 WHERE occurred_at >= '2026-05-15'
   AND occurred_at <  '2026-05-20';

-- ===== Block 5 =====
SHOW enable_partition_pruning;

-- ===== Block 6 =====
-- 親に宣言すると各パーティションに自動展開
CREATE INDEX idx_events_user_id ON app.events (user_id);

-- ===== Block 7 =====
-- Step 1: 親に無効インデックスのみ作成
CREATE INDEX idx_events_payload ON ONLY app.events
    USING GIN (payload);

-- Step 2: 各パーティションに CONCURRENTLY で個別作成
CREATE INDEX CONCURRENTLY idx_events_2026_05_payload
    ON app.events_2026_05 USING GIN (payload);

CREATE INDEX CONCURRENTLY idx_events_2026_06_payload
    ON app.events_2026_06 USING GIN (payload);

-- Step 3: 個別インデックスを親に紐付ける
ALTER INDEX idx_events_payload
    ATTACH PARTITION idx_events_2026_05_payload;

ALTER INDEX idx_events_payload
    ATTACH PARTITION idx_events_2026_06_payload;

-- ===== Block 8 =====
-- 同じ列構造の独立テーブルを用意
CREATE TABLE app.events_2026_07 (LIKE app.events INCLUDING ALL);

-- データ投入(オフライン作業可)
INSERT INTO app.events_2026_07 SELECT * FROM staging.events_july;

-- 親テーブルに ATTACH(値の範囲を明示)
ALTER TABLE app.events
    ATTACH PARTITION app.events_2026_07
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

-- ===== Block 9 =====
-- 通常の DETACH(ACCESS EXCLUSIVE で短時間ブロック)
ALTER TABLE app.events
    DETACH PARTITION app.events_2026_05;

-- オンラインで切り離す(2 段階)
ALTER TABLE app.events
    DETACH PARTITION app.events_2026_05 CONCURRENTLY;

-- ===== Block 10 =====
CREATE EXTENSION IF NOT EXISTS pg_partman;

-- 月次の RANGE パーティションを宣言
SELECT partman.create_parent(
    p_parent_table => 'app.events',
    p_control      => 'occurred_at',
    p_type         => 'range',
    p_interval     => '1 month',
    p_premake      => 4
);

-- ===== Block 11 =====
UPDATE partman.part_config
   SET retention                = '24 months',
       retention_keep_table     = false,
       infinite_time_partitions = true
 WHERE parent_table = 'app.events';

-- ===== Block 12 =====
-- BGW(バックグラウンドワーカー)モード: postgresql.conf に設定
-- shared_preload_libraries = 'pg_partman_bgw'

-- もしくは手動・cron で run_maintenance を呼ぶ
CALL partman.run_maintenance_proc();

-- ===== Block 13 =====
-- これはエラーになる
CREATE TABLE app.events_bad (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    occurred_at timestamptz NOT NULL
) PARTITION BY RANGE (occurred_at);
-- ERROR: unique constraint must include all partitioning columns

-- 主キーに occurred_at を含める必要がある
CREATE TABLE app.events_ok (
    id          bigint GENERATED ALWAYS AS IDENTITY,
    occurred_at timestamptz NOT NULL,
    PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

-- ===== Block 14 =====
-- Step 1: 新しいパーティション化親テーブルを別名で作成
CREATE TABLE app.events_new (LIKE app.events INCLUDING ALL)
    PARTITION BY RANGE (occurred_at);
ALTER TABLE app.events_new DROP CONSTRAINT events_new_pkey;
ALTER TABLE app.events_new ADD PRIMARY KEY (id, occurred_at);

-- Step 2: 既存テーブルをパーティションとして取り込む
ALTER TABLE app.events     RENAME TO events_legacy;
ALTER TABLE app.events_new RENAME TO events;
ALTER TABLE app.events ATTACH PARTITION app.events_legacy
    FOR VALUES FROM ('2020-01-01') TO ('2026-05-01');

-- Step 3: 直近月以降のパーティションを順次追加
CREATE TABLE app.events_2026_05 PARTITION OF app.events
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- ===== Block 15 =====
-- 必要に応じて有効化
SET enable_partitionwise_join = on;
SET enable_partitionwise_aggregate = on;

-- ===== Block 16 =====
-- events と orders がともに created_at で月次パーティション化
EXPLAIN
SELECT e.*, o.amount
  FROM app.events e
  JOIN app.orders o ON o.user_id = e.user_id
                   AND o.created_at = e.occurred_at
 WHERE e.occurred_at >= '2026-05-01'
   AND e.occurred_at <  '2026-06-01';

-- ===== Block 17 =====
-- 新しいパーティションを ATTACH した直後に手動 ANALYZE
ANALYZE app.events_2026_07;

-- 親テーブル全体の集計統計を更新
ANALYZE app.events;

-- ===== Block 18 =====
-- 1. 配置先が事前に分かるなら子テーブルへ直接 INSERT
INSERT INTO app.events_2026_05 (user_id, occurred_at, payload)
SELECT user_id, occurred_at, payload FROM staging.events_may;

-- 2. 親テーブル経由でも COPY なら大幅に高速
COPY app.events FROM '/tmp/events.csv' WITH (FORMAT csv);

-- 3. 数千万行を投入するならインデックスを事前に DROP
DROP INDEX idx_events_user_id;
COPY app.events FROM '/tmp/events_bulk.csv' WITH (FORMAT csv);
CREATE INDEX idx_events_user_id ON app.events (user_id);
