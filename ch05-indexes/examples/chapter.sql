
-- ===== Block 1 =====
CREATE INDEX users_city_idx ON users (city);
-- USING BTREE は省略可

-- ===== Block 2 =====
EXPLAIN ANALYZE SELECT count(*) FROM users WHERE city = 'Tokyo';

-- ===== Block 3 =====
CREATE INDEX orders_user_ordered_idx
    ON orders (user_id, ordered_at DESC);

-- ===== Block 4 =====
EXPLAIN ANALYZE
SELECT id, amount FROM orders
 WHERE user_id = 12345
   AND ordered_at >= '2026-01-01'
 ORDER BY ordered_at DESC
 LIMIT 10;

-- ===== Block 5 =====
-- PG 17 まで: 先頭 user_id の指定がないので Seq Scan
-- PG 18 から: orders_user_ordered_idx の Skip Scan で利用可
EXPLAIN ANALYZE
SELECT count(*) FROM orders
 WHERE ordered_at >= '2026-04-01';

-- ===== Block 6 =====
CREATE INDEX users_enterprise_idx
    ON users (id) WHERE metadata @> '{"plan":"enterprise"}';

-- ===== Block 7 =====
SELECT
    indexrelname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
  FROM pg_stat_user_indexes
 WHERE schemaname = 'app'
   AND indexrelname IN ('users_enterprise_idx', 'users_pkey');

-- ===== Block 8 =====
-- ✅ 部分インデックスが使える
SELECT id FROM users WHERE metadata @> '{"plan":"enterprise"}';

-- ❌ 述語を満たすか実行時にしか分からない(プランナで判定不能)
SELECT id FROM users WHERE metadata @> $1;

-- ===== Block 9 =====
CREATE INDEX users_lower_email_idx ON users (lower(email));

EXPLAIN ANALYZE
SELECT id FROM users WHERE lower(email) = 'user-1234@example.com';

-- ===== Block 10 =====
CREATE INDEX orders_user_inc_idx
    ON orders (user_id) INCLUDE (status, amount);
VACUUM orders;

EXPLAIN ANALYZE
SELECT user_id, status, amount FROM orders WHERE user_id = 12345;

-- ===== Block 11 =====
CREATE INDEX users_metadata_gin
    ON users USING GIN (metadata);

EXPLAIN ANALYZE
SELECT count(*) FROM users
 WHERE metadata @> '{"channel":"mobile"}';

-- ===== Block 12 =====
CREATE INDEX users_metadata_path_gin
    ON users USING GIN (metadata jsonb_path_ops);

-- ===== Block 13 =====
-- 検索遅延を抑えたい(オンライン検索の RDBMS):
ALTER INDEX users_metadata_gin SET (fastupdate = off);

-- 一括投入後に手動でフラッシュ:
SELECT gin_clean_pending_list('users_metadata_gin');

-- ===== Block 14 =====
CREATE EXTENSION pg_trgm;
CREATE INDEX users_name_trgm
    ON users USING GIN (name gin_trgm_ops);

EXPLAIN ANALYZE
SELECT id FROM users WHERE name LIKE '%user-1234%';

-- ===== Block 15 =====
EXPLAIN ANALYZE
SELECT id, name, similarity(name, 'user-1234') AS sim
  FROM users
 WHERE name % 'user-1234'
 ORDER BY sim DESC LIMIT 5;

-- ===== Block 16 =====
CREATE INDEX logs_occurred_brin  ON logs USING BRIN (occurred_at);
CREATE INDEX logs_occurred_btree ON logs (occurred_at);

-- ===== Block 17 =====
EXPLAIN ANALYZE
SELECT count(*) FROM logs
 WHERE occurred_at >= '2026-02-01'
   AND occurred_at <  '2026-02-02';

-- ===== Block 18 =====
-- 範囲を細かくするとサイズ増・精度向上
CREATE INDEX logs_occurred_brin_64
    ON logs USING BRIN (occurred_at) WITH (pages_per_range = 64);

-- ===== Block 19 =====
SELECT
    schemaname, relname, indexrelname,
    idx_scan, idx_tup_read, idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
  FROM pg_stat_user_indexes
 WHERE schemaname = 'app'
 ORDER BY pg_relation_size(indexrelid) DESC;

-- ===== Block 20 =====
-- PG 18+ の推奨クエリ
SELECT
    schemaname, relname, indexrelname,
    idx_scan, last_idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
  FROM pg_stat_user_indexes
 WHERE last_idx_scan IS NULL
    OR last_idx_scan < now() - interval '90 days'
 ORDER BY pg_relation_size(indexrelid) DESC;

-- ===== Block 21 =====
SELECT
    indrelid::regclass AS table_name,
    array_agg(indexrelid::regclass) AS dup_indexes,
    indkey
  FROM pg_index
 GROUP BY indrelid, indkey
HAVING count(*) > 1;

-- ===== Block 22 =====
SELECT
    indexrelname,
    idx_blks_read,
    idx_blks_hit,
    round(100.0 * idx_blks_hit
          / NULLIF(idx_blks_read + idx_blks_hit, 0), 2) AS hit_pct
  FROM pg_statio_user_indexes
 WHERE schemaname = 'app'
 ORDER BY idx_blks_read DESC;

-- ===== Block 23 =====
CREATE EXTENSION pgstattuple;
SELECT * FROM pgstatindex('orders_user_ordered_idx');

-- ===== Block 24 =====
REINDEX INDEX CONCURRENTLY orders_user_ordered_idx;

-- ===== Block 25 =====
-- INVALID 状態の検出
SELECT pc.relname AS index_name
  FROM pg_class pc
  JOIN pg_index pi ON pc.oid = pi.indexrelid
 WHERE NOT pi.indisvalid;

-- 復旧: どちらかを選ぶ
DROP INDEX CONCURRENTLY orders_failed_idx;
REINDEX INDEX CONCURRENTLY orders_failed_idx;

-- ===== Block 26 =====
-- アンチパターン: B-tree が効かない
SELECT id FROM users WHERE lower(email) = 'foo@example.com';

-- 対策: 式インデックスを張る
CREATE INDEX users_lower_email_idx ON users (lower(email));

-- ===== Block 27 =====
-- user_id は bigint だが、文字列で渡してしまった
SELECT * FROM orders WHERE user_id = '12345';

-- ===== Block 28 =====
-- アンチパターン: コメント本文(平均 2 KB)を INCLUDE
CREATE INDEX comments_post_idx
    ON comments (post_id) INCLUDE (body);
