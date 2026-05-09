-- ===== Block 1 =====
CREATE ROLE repl_user WITH REPLICATION LOGIN PASSWORD 'CHANGE_ME';

-- ===== Block 2 =====
SELECT * FROM pg_create_physical_replication_slot('standby1_slot');

SELECT slot_name, slot_type, restart_lsn, active, active_pid
FROM pg_replication_slots;

-- ===== Block 3 =====
SELECT pg_promote(wait => true, wait_seconds => 60);

-- ===== Block 4 =====
SELECT
    application_name,
    state,
    sync_state,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes,
    write_lag,
    flush_lag,
    replay_lag
FROM pg_stat_replication;

-- ===== Block 5 =====
SELECT status, receive_start_lsn, written_lsn, flushed_lsn,
       last_msg_send_time, last_msg_receipt_time
FROM pg_stat_wal_receiver;

-- ===== Block 6 =====
-- 主キーがある通常テーブルは設定不要
-- 主キーがないテーブルの場合
ALTER TABLE app.events_log REPLICA IDENTITY FULL;

-- ===== Block 7 =====
-- 全テーブルを公開
CREATE PUBLICATION pub_all FOR ALL TABLES;

-- 個別テーブルを指定
CREATE PUBLICATION pub_orders
    FOR TABLE app.orders, app.order_items;

-- スキーマ単位
CREATE PUBLICATION pub_app FOR TABLES IN SCHEMA app;

-- 行フィルタ + 列リスト
CREATE PUBLICATION pub_active_users
    FOR TABLE app.users (id, email, status)
    WHERE (status = 'active');

-- ===== Block 8 =====
CREATE SUBSCRIPTION sub_orders
    CONNECTION 'host=publisher.example.com port=5432
                user=repl_user dbname=appdb password=CHANGE_ME'
    PUBLICATION pub_orders
    WITH (
        copy_data = true,
        create_slot = true,
        slot_name = 'sub_orders_slot',
        streaming = 'parallel'
    );

-- ===== Block 9 =====
-- 一時停止・再開
ALTER SUBSCRIPTION sub_orders DISABLE;
ALTER SUBSCRIPTION sub_orders ENABLE;

-- パブリケーションの追加情報を取得
ALTER SUBSCRIPTION sub_orders REFRESH PUBLICATION;

-- スロットを切り離してサブスクだけ残す
ALTER SUBSCRIPTION sub_orders SET (slot_name = NONE);

-- 2 フェーズコミット動作の変更(PG 18 で実行時変更可能に)
ALTER SUBSCRIPTION sub_orders SET (two_phase = true);

-- ===== Block 10 =====
SELECT subname, pid, received_lsn, last_msg_send_time,
       last_msg_receipt_time, latest_end_lsn, latest_end_time
FROM pg_stat_subscription;
