
-- ===== Block 1 =====
CREATE EXTENSION pg_stat_statements;

-- ===== Block 2 =====
SELECT
    queryid,
    calls,
    total_exec_time::int AS total_ms,
    mean_exec_time::int AS mean_ms,
    rows,
    LEFT(query, 80) AS query
  FROM pg_stat_statements
 ORDER BY total_exec_time DESC LIMIT 10;

-- ===== Block 3 =====
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;

-- ===== Block 4 =====
EXPLAIN ANALYZE SELECT count(*) FROM logs;

-- ===== Block 5 =====
SELECT reltuples::bigint AS estimated_rows
  FROM pg_class WHERE relname = 'logs';

-- ===== Block 6 =====
EXPLAIN ANALYZE
SELECT id, occurred_at FROM logs
 ORDER BY id LIMIT 10 OFFSET 100000;

-- ===== Block 7 =====
EXPLAIN ANALYZE
SELECT id, occurred_at FROM logs
 WHERE id > 100000
 ORDER BY id LIMIT 10;

-- ===== Block 8 =====
CREATE EXTENSION pg_trgm;
CREATE INDEX users_name_trgm
    ON users USING GIN (name gin_trgm_ops);

SELECT id FROM users WHERE name LIKE '%user-1234%';

-- ===== Block 9 =====
CREATE INDEX orders_amount_idx ON orders (amount DESC);

-- ===== Block 10 =====
SELECT u.id FROM users u
  JOIN (VALUES (1),(2),(3),(5),(8),(13),(21),(34),(55),(89),
              (144),(233),(377),(610),(987),(1597),(2584))
        AS t(id) ON u.id = t.id;

-- ===== Block 11 =====
ANALYZE users; ANALYZE orders;
EXPLAIN ANALYZE
SELECT u.id, count(o.id) AS cnt
  FROM users u
  LEFT JOIN orders o ON o.user_id = u.id
 GROUP BY u.id LIMIT 100;

-- ===== Block 12 =====
CREATE INDEX users_active_idx
    ON users (id) WHERE deleted_at IS NULL;

-- ===== Block 13 =====
DO $$
DECLARE
    last_id bigint := 0;
BEGIN
    LOOP
        UPDATE users SET ranked_score = ranked_score * 1.1
         WHERE id > last_id ORDER BY id LIMIT 1000
         RETURNING id INTO last_id;
        EXIT WHEN NOT FOUND;
        COMMIT;
    END LOOP;
END $$;

-- ===== Block 14 =====
SET work_mem = '64MB';

-- ===== Block 15 =====
EXPLAIN ANALYZE
SELECT user_id, count(*) AS cnt
  FROM orders
 GROUP BY user_id
 ORDER BY user_id LIMIT 100;

-- ===== Block 16 =====
\copy logs FROM '/path/to/logs.csv' WITH (FORMAT csv, HEADER);

-- ===== Block 17 =====
\copy logs FROM 'logs.csv'
   WITH (FORMAT csv, HEADER, ON_ERROR ignore, LOG_VERBOSITY verbose);

-- ===== Block 18 =====
INSERT INTO logs (occurred_at, level, message) VALUES
    ('2026-05-09 10:00:00+00', 'INFO', 'msg 1'),
    ('2026-05-09 10:00:01+00', 'INFO', 'msg 2'),
    ('2026-05-09 10:00:02+00', 'WARN', 'msg 3');

-- ===== Block 19 =====
CREATE INDEX users_lower_email_idx ON users (lower(email));

-- ===== Block 20 =====
SELECT relname, last_analyze, last_autoanalyze
  FROM pg_stat_user_tables
 WHERE schemaname = 'app';

-- ===== Block 21 =====
ANALYZE users;
ALTER TABLE users ALTER COLUMN city SET STATISTICS 1000;
ANALYZE users;

-- ===== Block 22 =====
CREATE EXTENSION pgstattuple;
SELECT * FROM pgstattuple('huge_logs');

-- ===== Block 23 =====
ALTER SEQUENCE users_id_seq CACHE 100;

-- ===== Block 24 =====
ALTER TABLE users ADD COLUMN channel text
    GENERATED ALWAYS AS (metadata->>'channel') STORED;
CREATE INDEX users_channel_idx ON users (channel);

-- ===== Block 25 =====
WITH RECURSIVE tree AS (
    SELECT id, parent_id, ARRAY[id] AS path, 1 AS depth
      FROM org WHERE parent_id IS NULL
    UNION ALL
    SELECT o.id, o.parent_id, t.path || o.id, t.depth + 1
      FROM org o JOIN tree t ON o.parent_id = t.id
     WHERE NOT (o.id = ANY(t.path))
       AND t.depth < 100
)
SELECT * FROM tree;

-- ===== Block 26 =====
ALTER TABLE huge_logs SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_vacuum_threshold = 1000
);

-- ===== Block 27 =====
SELECT relname, n_live_tup, n_dead_tup,
       round(n_dead_tup * 100.0 / NULLIF(n_live_tup, 0), 2) AS dead_pct,
       last_autovacuum
  FROM pg_stat_user_tables
 ORDER BY n_dead_tup DESC LIMIT 10;

-- ===== Block 28 =====
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';
SELECT pg_reload_conf();

-- ===== Block 29 =====
SELECT pid, usename, application_name,
       now() - xact_start AS xact_age, state, query
  FROM pg_stat_activity
 WHERE state = 'idle in transaction'
   AND xact_start < now() - interval '1 minute'
 ORDER BY xact_start;

-- ===== Block 30 =====
INSERT INTO users (email, name, city)
VALUES ('exists@example.com', 'dup', 'Tokyo')
ON CONFLICT (email) DO NOTHING;

-- ===== Block 31 =====
SET lock_timeout = '10s';
ALTER TABLE users ADD COLUMN ranked_score int;
ALTER TABLE users ALTER COLUMN ranked_score SET DEFAULT 0;

-- ===== Block 32 =====
SELECT a.pid, a.usename, a.query,
       now() - a.xact_start AS xact_age,
       l.locktype, l.mode, l.granted
  FROM pg_locks l
  JOIN pg_stat_activity a USING (pid)
 WHERE NOT l.granted
   AND l.relation = 'users'::regclass;

-- ===== Block 33 =====
SELECT pg_stat_statements_reset();

-- ===== Block 34 =====
CREATE MATERIALIZED VIEW orders_per_user AS
SELECT user_id, count(*) AS cnt FROM orders GROUP BY user_id;

CREATE UNIQUE INDEX ON orders_per_user (user_id);

-- 1 時間おきに pg_cron でリフレッシュ
SELECT cron.schedule('refresh_opu', '0 * * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY orders_per_user');

-- ===== Block 35 =====
DO $$
BEGIN
    IF pg_try_advisory_lock(12345) THEN
        PERFORM pg_advisory_unlock(12345);
    ELSE
        RAISE NOTICE 'lock busy, skipping';
    END IF;
END $$;

-- ===== Block 36 =====
-- アクティブセッションと wait event
SELECT pid, state, wait_event_type, wait_event,
       now() - xact_start AS xact_duration, query
  FROM pg_stat_activity
 WHERE state != 'idle' ORDER BY xact_start;

-- テーブル単位の dead tuple とブロート
SELECT relname, n_live_tup, n_dead_tup, last_autovacuum
  FROM pg_stat_user_tables
 WHERE n_dead_tup > 1000 ORDER BY n_dead_tup DESC LIMIT 20;

-- 接続数の状態別カウント
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;

-- ===== Block 37 =====
-- 大規模 REINDEX の前に一時的に上げる
SET maintenance_work_mem = '4GB';
REINDEX TABLE CONCURRENTLY huge_logs;
RESET maintenance_work_mem;

-- ===== Block 38 =====
SELECT backend_type, object, context,
       reads, writes, write_time, hit_pct
  FROM pg_stat_io
 WHERE backend_type = 'client backend'
 ORDER BY reads DESC LIMIT 10;

-- ===== Block 39 =====
-- (1) 直近のスローログ Top 10
SELECT calls, mean_exec_time::int AS mean_ms,
       total_exec_time::int AS total_ms,
       LEFT(query, 60) FROM pg_stat_statements
 ORDER BY total_exec_time DESC LIMIT 10;

-- (2) ロック待ちセッション
SELECT pid, usename, wait_event_type, wait_event,
       now() - xact_start AS xact_age, query
  FROM pg_stat_activity
 WHERE wait_event IS NOT NULL AND state != 'idle';

-- (3) キャッシュヒット率
SELECT datname,
       round(blks_hit * 100.0
             / NULLIF(blks_hit + blks_read, 0), 2) AS hit_pct
  FROM pg_stat_database WHERE datname IS NOT NULL;
