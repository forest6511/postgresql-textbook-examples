# 第NN章: <章タイトル>

「PostgreSQL の教科書」第NN章のサンプルコード。

## 動作環境

- Docker / Docker Compose
- PostgreSQL 17(`docker-compose.yml` で指定)

## 起動

```bash
docker compose up -d
psql -h localhost -U postgres -d textbook -f init.sql
```

実行例:

```bash
psql -h localhost -U postgres -d textbook -f examples/<topic>.sql
```

停止 + クリーンアップ:

```bash
docker compose down -v
```

## ファイル構成

- `docker-compose.yml` — PG 17/18 起動
- `init.sql` — 初期スキーマとシードデータ
- `examples/*.sql` — 章本文の SQL
- `scripts/*.sh` — pg_dump / EXPLAIN 取得などのコマンド例

## 接続情報

| 項目 | 値 |
|------|-----|
| host | localhost |
| port | 5432 |
| user | postgres |
| password | postgres |
| database | textbook |
