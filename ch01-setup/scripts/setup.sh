#!/usr/bin/env bash
# Chapter 01 shell commands
set -euo pipefail

$ brew update
$ brew install postgresql@17
$ brew services start postgresql@17
$ echo 'export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"' \
    >> ~/.zshrc
$ source ~/.zshrc

$ sudo apt update
$ sudo apt install -y postgresql-common
$ sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
$ sudo apt install -y postgresql-17

$ sudo systemctl enable --now postgresql
$ sudo systemctl status postgresql

$ docker exec -it textbook-pg18 psql -U app -d textbook

$ psql -h textbook.xxxxx.ap-northeast-1.rds.amazonaws.com \
    -U app -d textbook -p 5432

$ psql -v ON_ERROR_STOP=1 \
    -h localhost -U app -d textbook -f migration.sql

$ docker exec -it textbook-pg17 \
    psql -U app -d textbook -c "SELECT pg_reload_conf();"
