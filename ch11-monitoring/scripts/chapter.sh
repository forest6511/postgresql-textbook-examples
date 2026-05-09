# ===== Block 1 =====
# Ubuntu の場合
sudo apt install postgresql-18-repack

# 対象 DB に拡張をインストール(SUPERUSER 必要)
psql -d appdb -c "CREATE EXTENSION pg_repack;"

# ===== Block 2 =====
# テーブル単位で再構築
pg_repack -d appdb -t orders

# データベース全体を再構築
pg_repack -d appdb -a

# インデックスのみ再構築(pg_repack 1.2+)
pg_repack -d appdb -i orders_email_idx

# クラスタ化(物理順序を PRIMARY KEY 順に整列)
pg_repack -d appdb -t orders --order-by=created_at
