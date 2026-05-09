#!/usr/bin/env bash
# Chapter 01 — 書籍に掲載されたコマンドの参照用です。
# このファイルは一括実行用ではありません。各ブロックを必要に応じてターミナルへ
# コピーして実行してください(macOS / Ubuntu / Docker / RDS で前提が異なるため)。
exit 0

# ---- macOS (Homebrew) ----
brew update
brew install postgresql@17
brew services start postgresql@17
echo 'export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"' \
    >> ~/.zshrc
source ~/.zshrc

# ---- Ubuntu (PGDG) ----
sudo apt update
sudo apt install -y postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
sudo apt install -y postgresql-17

sudo systemctl enable --now postgresql
sudo systemctl status postgresql

# ---- Docker (推奨。docker-compose.yml と併用) ----
docker exec -it textbook-pg18 psql -U app -d textbook

# ---- RDS 接続 ----
psql -h textbook.xxxxx.ap-northeast-1.rds.amazonaws.com \
    -U app -d textbook -p 5432

# ---- マイグレーション実行(エラー時に停止) ----
psql -v ON_ERROR_STOP=1 \
    -h localhost -U app -d textbook -f migration.sql

# ---- 設定リロード ----
docker exec -it textbook-pg17 \
    psql -U app -d textbook -c "SELECT pg_reload_conf();"
