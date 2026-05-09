
-- ===== Block 1 =====
EXPLAIN SELECT count(*) FROM app.users WHERE city = 'Tokyo';

-- ===== Block 2 =====
EXPLAIN ANALYZE SELECT count(*) FROM app.users WHERE city = 'Tokyo';

-- ===== Block 3 =====
BEGIN;
EXPLAIN ANALYZE UPDATE app.orders SET status = 'paid' WHERE id = 1;
ROLLBACK;

-- ===== Block 4 =====
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT * FROM app.users WHERE id = 12345;

-- ===== Block 5 =====
EXPLAIN (ANALYZE, FORMAT JSON)
SELECT count(*) FROM app.users WHERE city = 'Tokyo';

-- ===== Block 6 =====
SET enable_nestloop = off;
SET enable_hashjoin = off;
SET enable_mergejoin = off;  -- 全部 off は不可

-- ===== Block 7 =====
EXPLAIN ANALYZE
SELECT u.name, count(o.id) AS orders
FROM app.users u
JOIN app.orders o ON o.user_id = u.id
WHERE u.city = 'Sapporo'
GROUP BY u.id, u.name
ORDER BY count(o.id) DESC
LIMIT 10;

-- ===== Block 8 =====
ANALYZE app.orders;
ANALYZE VERBOSE app.orders;  -- 進捗表示
ANALYZE;                     -- 全テーブル

-- ===== Block 9 =====
ALTER TABLE app.orders ALTER COLUMN status SET STATISTICS 1000;
ANALYZE app.orders;
