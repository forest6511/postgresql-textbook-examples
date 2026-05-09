-- ===== Block 1 =====
CREATE EXTENSION pg_stat_statements;

-- ===== Block 2 =====
SELECT
    substring(query, 1, 80)         AS query,
    calls,
    round(total_exec_time::numeric, 2) AS total_ms,
    round(mean_exec_time::numeric, 2)  AS mean_ms,
    rows
FROM pg_stat_statements
WHERE query NOT LIKE 'EXPLAIN%'
ORDER BY total_exec_time DESC
LIMIT 10;

-- ===== Block 3 =====
SELECT pg_stat_statements_reset();

-- ===== Block 4 =====
SELECT
    schemaname || '.' || relname AS table,
    n_live_tup,
    n_dead_tup,
    round(n_dead_tup::numeric
          / NULLIF(n_live_tup, 0) * 100, 1) AS dead_pct,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY dead_pct DESC NULLS LAST
LIMIT 20;

-- ===== Block 5 =====
SELECT
    schemaname,
    relname        AS table,
    indexrelname   AS index,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE schemaname NOT IN ('pg_catalog', 'pg_toast')
  AND idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- ===== Block 6 =====
SELECT
    backend_type,
    object,
    context,
    hits,
    reads,
    round(hits::numeric
          / NULLIF(hits + reads, 0) * 100, 2) AS hit_pct
FROM pg_stat_io
WHERE reads > 0 OR hits > 0
ORDER BY (hits + reads) DESC
LIMIT 10;

-- ===== Block 7 =====
SELECT state, count(*)
FROM pg_stat_activity
GROUP BY state
ORDER BY count(*) DESC;

-- ===== Block 8 =====
SELECT
    pid,
    usename,
    application_name,
    state,
    now() - state_change AS idle_for,
    substring(query, 1, 60) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - state_change > interval '5 min'
ORDER BY idle_for DESC;

-- ===== Block 9 =====
SELECT
    pid,
    usename,
    now() - query_start AS duration,
    substring(query, 1, 80) AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '30 sec'
ORDER BY duration DESC;

-- ===== Block 10 =====
SELECT
    blocked.pid                AS blocked_pid,
    blocked.usename            AS blocked_user,
    substring(blocked.query, 1, 60) AS blocked_query,
    blocking.pid               AS blocking_pid,
    blocking.usename           AS blocking_user,
    substring(blocking.query, 1, 60) AS blocking_query,
    blocked.wait_event_type,
    blocked.wait_event
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
  ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE pg_blocking_pids(blocked.pid) <> '{}';

-- ===== Block 11 =====
SELECT
    locktype,
    mode,
    granted,
    count(*)
FROM pg_locks
GROUP BY locktype, mode, granted
ORDER BY count(*) DESC
LIMIT 10;

-- ===== Block 12 =====
-- クエリのみキャンセル(トランザクションは残る)
SELECT pg_cancel_backend(12345);

-- セッションごと切断(idle in transaction にも有効)
SELECT pg_terminate_backend(12345);

-- ===== Block 13 =====
-- 注文テーブル: dead pct を 5% に抑える
ALTER TABLE orders SET (
    autovacuum_vacuum_threshold      = 1000,
    autovacuum_vacuum_scale_factor   = 0.05,
    autovacuum_analyze_threshold     = 500,
    autovacuum_analyze_scale_factor  = 0.02
);

-- 大量 INSERT の監査ログ: INSERT 起動側を厳しく
ALTER TABLE audit_log SET (
    autovacuum_vacuum_insert_threshold    = 10000,
    autovacuum_vacuum_insert_scale_factor = 0.05
);

-- バッチで一気に書き込む staging テーブル: 一時的に無効化
ALTER TABLE staging_import SET (autovacuum_enabled = false);

-- ===== Block 14 =====
ALTER TABLE staging_import RESET (autovacuum_enabled);

-- ===== Block 15 =====
VACUUM FULL VERBOSE orders;

-- ===== Block 16 =====
SELECT
    n.nspname AS schema,
    c.relname AS table,
    age(c.relfrozenxid) AS xid_age,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS size,
    c.reltuples::bigint AS rows
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'm')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY age(c.relfrozenxid) DESC
LIMIT 20;

-- ===== Block 17 =====
VACUUM (FREEZE, VERBOSE) orders;

-- ===== Block 18 =====
SELECT
    pid,
    datname,
    relid::regclass AS table,
    phase,
    heap_blks_total,
    heap_blks_scanned,
    round(heap_blks_scanned::numeric
          / NULLIF(heap_blks_total, 0) * 100, 1) AS scan_pct,
    index_vacuum_count
FROM pg_stat_progress_vacuum;

-- ===== Block 19 =====
CREATE ROLE monitor WITH LOGIN PASSWORD 'pass';
GRANT pg_monitor TO monitor;
