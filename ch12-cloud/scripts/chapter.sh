#!/usr/bin/env bash
# 書籍に掲載されたコマンドの参照用ファイルです。一括実行用ではありません。
# 必要なブロックを必要な環境(本番 / ステージング / ローカル)で個別に実行してください。
exit 0

# ===== Block 1 =====
# Pull Request ごとにブランチを作成
neonctl branches create --name pr-1234 --parent main

# プレビュー環境で接続
psql $(neonctl connection-string pr-1234)

# テスト後にブランチ削除
neonctl branches delete pr-1234

# ===== Block 2 =====
# 物理スタンバイから論理レプリカを作成(PG 17+)
pg_createsubscriber \
    --pgdata=/var/lib/postgresql/18/data \
    --publisher-server="host=primary dbname=appdb user=replica" \
    --database=appdb \
    --subscriber-username=postgres

# ===== Block 3 =====
# Step 1: 新バージョンを別パスにインストール
sudo apt install postgresql-18

# Step 2: 新クラスタを初期化
sudo -u postgres /usr/lib/postgresql/18/bin/initdb \
    -D /var/lib/postgresql/18/data

# Step 3: --check で事前検証(本番停止不要)
sudo -u postgres /usr/lib/postgresql/18/bin/pg_upgrade \
    --old-bindir /usr/lib/postgresql/17/bin \
    --new-bindir /usr/lib/postgresql/18/bin \
    --old-datadir /var/lib/postgresql/17/data \
    --new-datadir /var/lib/postgresql/18/data \
    --check

# Step 4: 旧バージョンを停止 → アップグレード実行
sudo systemctl stop postgresql@17-main
sudo -u postgres /usr/lib/postgresql/18/bin/pg_upgrade \
    --old-bindir /usr/lib/postgresql/17/bin \
    --new-bindir /usr/lib/postgresql/18/bin \
    --old-datadir /var/lib/postgresql/17/data \
    --new-datadir /var/lib/postgresql/18/data \
    --jobs 4 \
    --clone

# Step 5: 新バージョン起動 → 統計再計算は不要(PG 18 既定)
sudo systemctl start postgresql@18-main

# Step 6: 拡張を更新
sudo -u postgres psql -c "ALTER EXTENSION pg_stat_statements UPDATE;"
