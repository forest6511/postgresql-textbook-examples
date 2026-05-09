
-- ===== Block 1 =====
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'users'
ORDER BY ordinal_position;

-- ===== Block 2 =====
CREATE TABLE app.books (
    id          bigserial PRIMARY KEY,
    title       text NOT NULL,
    price       integer NOT NULL CHECK (price >= 0),
    published   date,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.orders (
    id          bigserial PRIMARY KEY,
    user_id     bigint NOT NULL REFERENCES app.users(id),
    book_id     bigint NOT NULL REFERENCES app.books(id),
    quantity    integer NOT NULL CHECK (quantity > 0),
    ordered_at  timestamptz NOT NULL DEFAULT now()
);

-- ===== Block 3 =====
-- 列を追加
ALTER TABLE app.books ADD COLUMN isbn text;

-- 型を変更（互換性のあるキャスト時のみ）
ALTER TABLE app.books ALTER COLUMN price TYPE bigint;

-- 制約を追加
ALTER TABLE app.books ADD CONSTRAINT books_isbn_unique UNIQUE (isbn);

-- 列を削除
ALTER TABLE app.books DROP COLUMN isbn;

-- ===== Block 4 =====
-- CASCADE なしで失敗させる
DROP TABLE app.users;
ERROR:  cannot drop table app.users because other objects depend on it
DETAIL:  constraint orders_user_id_fkey on table app.orders depends on
table app.users

-- 依存ごと削除
DROP TABLE app.users CASCADE;
NOTICE:  drop cascades to constraint orders_user_id_fkey on table app.orders
DROP TABLE

-- ===== Block 5 =====
INSERT INTO app.books (title, price, published) VALUES
    ('PostgreSQL 教科書',     980,  '2026-06-01'),
    ('はじめての SQL',        1200, '2025-04-10'),
    ('インデックス設計入門',  1500, '2024-11-20')
RETURNING id, title;

-- ===== Block 6 =====
INSERT INTO app.books (title, price, published)
VALUES ('PostgreSQL 教科書', 980, '2026-06-01')
ON CONFLICT (title) DO UPDATE
    SET price = EXCLUDED.price,
        published = EXCLUDED.published;

-- ===== Block 7 =====
UPDATE app.books
SET price = price + 100
WHERE published < '2025-01-01'
RETURNING id, title, price;

-- ===== Block 8 =====
UPDATE app.orders o
SET quantity = quantity + 1
FROM app.books b
WHERE o.book_id = b.id AND b.title = 'PostgreSQL 教科書';

-- ===== Block 9 =====
DELETE FROM app.orders
WHERE ordered_at < now() - interval '1 year'
RETURNING id, user_id, ordered_at;

-- ===== Block 10 =====
SELECT id, title, price
FROM app.books
WHERE price BETWEEN 1000 AND 1500
  AND published >= '2025-01-01'
ORDER BY price DESC, id ASC
LIMIT 10 OFFSET 0;

-- ===== Block 11 =====
SELECT u.name, b.title, o.quantity, o.ordered_at
FROM app.orders o
INNER JOIN app.users u ON u.id = o.user_id
INNER JOIN app.books b ON b.id = o.book_id
ORDER BY o.ordered_at DESC
LIMIT 20;

-- ===== Block 12 =====
SELECT u.id, u.name, COUNT(o.id) AS order_count
FROM app.users u
LEFT JOIN app.orders o ON o.user_id = u.id
GROUP BY u.id, u.name
ORDER BY order_count DESC;

-- ===== Block 13 =====
SELECT u.id, u.name, COUNT(o.id) AS order_count
FROM app.users u
LEFT JOIN app.orders o ON o.user_id = u.id
WHERE u.created_at >= '2026-01-01'
GROUP BY u.id, u.name
HAVING COUNT(o.id) >= 3
ORDER BY order_count DESC;

-- ===== Block 14 =====
-- スカラサブクエリ（SELECT 句）
SELECT title,
       price,
       (SELECT AVG(price) FROM app.books) AS avg_price
FROM app.books;

-- IN サブクエリ（WHERE 句）
SELECT id, title FROM app.books
WHERE id IN (SELECT book_id FROM app.orders);

-- EXISTS サブクエリ（WHERE 句）
SELECT id, name FROM app.users u
WHERE EXISTS (
    SELECT 1 FROM app.orders o WHERE o.user_id = u.id
);

-- ===== Block 15 =====
WITH active_users AS (
    SELECT id, name
    FROM app.users
    WHERE created_at >= now() - interval '90 days'
),
recent_orders AS (
    SELECT user_id, COUNT(*) AS cnt
    FROM app.orders
    WHERE ordered_at >= now() - interval '30 days'
    GROUP BY user_id
)
SELECT au.id, au.name, COALESCE(ro.cnt, 0) AS recent_count
FROM active_users au
LEFT JOIN recent_orders ro ON ro.user_id = au.id
ORDER BY recent_count DESC;

-- ===== Block 16 =====
SELECT title FROM app.books WHERE price >= 1500
UNION
SELECT title FROM app.books WHERE published >= '2026-01-01'
ORDER BY title;

-- ===== Block 17 =====
BEGIN;

UPDATE app.books SET price = price + 100 WHERE id = 1;
INSERT INTO app.audit_log (table_name, action, target_id)
VALUES ('books', 'price_up', 1);

COMMIT;

-- ===== Block 18 =====
BEGIN;

INSERT INTO app.books (title, price) VALUES ('A', 100);

SAVEPOINT after_a;

INSERT INTO app.books (title, price) VALUES ('B', -50);
-- CHECK 制約違反でエラーになる場合があるとして、ここまで戻したい

ROLLBACK TO SAVEPOINT after_a;

INSERT INTO app.books (title, price) VALUES ('C', 200);

COMMIT;

-- ===== Block 19 =====
BEGIN ISOLATION LEVEL REPEATABLE READ;
-- または
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- ===== Block 20 =====
BEGIN;
SELECT price FROM app.books WHERE id = 1;
-- 980 が返る
-- ここで セッション B のコミットを待つ
SELECT price FROM app.books WHERE id = 1;
-- 1080 が返る（B の更新が見えてしまう）
COMMIT;

-- ===== Block 21 =====
BEGIN;
UPDATE app.books SET price = 1080 WHERE id = 1;
COMMIT;

-- ===== Block 22 =====
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT price FROM app.books WHERE id = 1;
-- 980
-- B が COMMIT
SELECT price FROM app.books WHERE id = 1;
-- 980（A の開始時のスナップショットが維持される）
COMMIT;

-- ===== Block 23 =====
BEGIN;
SELECT id, price FROM app.books WHERE id = 1 FOR UPDATE;
-- ここで他のトランザクションは同じ行への UPDATE を待たされる
UPDATE app.books SET price = price + 100 WHERE id = 1;
COMMIT;

-- ===== Block 24 =====
BEGIN;
UPDATE app.books SET price = 1100 WHERE id = 1;
-- ここでセッション B の動作を待つ
UPDATE app.books SET price = 2200 WHERE id = 2;

-- ===== Block 25 =====
BEGIN;
UPDATE app.books SET price = 2100 WHERE id = 2;
-- 次の UPDATE で id=1 を待つ → A は id=2 を待っている → デッドロック
UPDATE app.books SET price = 1200 WHERE id = 1;

-- ===== Block 26 =====
SELECT pid,
       pg_blocking_pids(pid) AS blocked_by,
       state,
       query
FROM pg_stat_activity
WHERE state <> 'idle';
