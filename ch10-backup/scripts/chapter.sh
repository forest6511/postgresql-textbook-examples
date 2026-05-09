#!/usr/bin/env bash
# 書籍に掲載されたコマンドの参照用ファイルです。一括実行用ではありません。
# 必要なブロックを必要な環境(本番 / ステージング / ローカル)で個別に実行してください。
exit 0

# ===== Block 1 =====
# plain(SQL テキスト、psql で復元)
pg_dump -Fp -d appdb > appdb.sql

# custom(圧縮済み単一ファイル、pg_restore で柔軟リストア)
pg_dump -Fc -d appdb -f appdb.dump

# directory(並列 -j 対応、テーブル単位ファイル)
pg_dump -Fd -d appdb -j 4 -f appdb.dir

# tar(レガシー、custom 推奨)
pg_dump -Ft -d appdb -f appdb.tar

# ===== Block 2 =====
pg_dumpall -f cluster_full.sql

# ===== Block 3 =====
# custom 形式の復元
pg_restore -d appdb -j 4 appdb.dump

# 特定テーブルのみ復元
pg_restore -d appdb -t orders appdb.dump

# スキーマだけ先に復元(データなし)
pg_restore -d appdb --schema-only appdb.dump

# ===== Block 4 =====
pg_basebackup \
    -h primary.example.com \
    -U repl_user \
    -D /backup/base/2026-05-10 \
    -X stream \
    -P \
    -Ft \
    -z

# ===== Block 5 =====
# 1. ベースバックアップ
pg_basebackup -D /backup/base -X stream

# 2. インクリメンタルバックアップ
pg_basebackup -D /backup/incr-1 \
    --incremental=/backup/base/backup_manifest

# 3. さらにインクリメンタル
pg_basebackup -D /backup/incr-2 \
    --incremental=/backup/incr-1/backup_manifest

# ===== Block 6 =====
pg_combinebackup /backup/base /backup/incr-1 /backup/incr-2 \
    -o /restore/synthesized

# ===== Block 7 =====
pg_verifybackup /backup/base
pg_verifybackup -F t /backup/base.tar

# ===== Block 8 =====
# 既存のデータディレクトリを退避
mv /var/lib/postgresql/18/data /var/lib/postgresql/18/data.bak

# ベースバックアップを展開
mkdir -p /var/lib/postgresql/18/data
tar -xzf /backup/base/base.tar.gz -C /var/lib/postgresql/18/data

# ===== Block 9 =====
touch /var/lib/postgresql/18/data/recovery.signal

# ===== Block 10 =====
pg_ctl -D /var/lib/postgresql/18/data start

# ===== Block 11 =====
pgbackrest --stanza=main stanza-create

# ===== Block 12 =====
# フルバックアップ
pgbackrest --stanza=main --type=full backup

# 差分(前回フルからの差分)
pgbackrest --stanza=main --type=diff backup

# インクリメンタル(前回任意バックアップからの差分)
pgbackrest --stanza=main --type=incr backup

# ===== Block 13 =====
# 最新バックアップでリストア
pgbackrest --stanza=main restore

# 時刻指定 PITR
pgbackrest --stanza=main \
    --type=time --target='2026-05-10 14:30:00+09' restore

# 特定バックアップからリストア
pgbackrest --stanza=main \
    --set=20260510-1430F restore

# ===== Block 14 =====
# 保持期間の変更
aws rds modify-db-instance \
    --db-instance-identifier prod-db \
    --backup-retention-period 35 \
    --apply-immediately

# ===== Block 15 =====
aws rds restore-db-instance-to-point-in-time \
    --source-db-instance-identifier prod-db \
    --target-db-instance-identifier prod-db-restored \
    --restore-time 2026-05-10T14:30:00Z
