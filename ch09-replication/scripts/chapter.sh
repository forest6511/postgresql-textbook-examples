#!/usr/bin/env bash
# 書籍に掲載されたコマンドの参照用ファイルです。一括実行用ではありません。
# 必要なブロックを必要な環境(本番 / ステージング / ローカル)で個別に実行してください。
exit 0

# ===== Block 1 =====
pg_basebackup \
    -h primary.example.com \
    -U repl_user \
    -D /var/lib/postgresql/18/data \
    -X stream \
    -R \
    -S standby1_slot \
    -P

# ===== Block 2 =====
pg_ctl -D /var/lib/postgresql/18/data promote

# ===== Block 3 =====
pg_rewind \
    -D /var/lib/postgresql/18/data \
    --source-server="host=new-primary user=repl_user dbname=postgres"
