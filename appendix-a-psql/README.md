# 付録A: psql チートシート

「PostgreSQL の教科書」付録A のサンプルコード。

> 詳細な実行手順とファイル構成は本書の対応章を参照してください。
> 共通の起動パターンは [`_template/README.md`](../_template/README.md) を参照。

## ファイル構成

- `docker-compose.yml` — PG 起動(章執筆時に追加)
- `init.sql` — 初期データ(章執筆時に追加)
- `examples/` — 章本文の SQL
- `scripts/` — シェルスクリプト

## 起動

```bash
docker compose up -d
psql -h localhost -U postgres -d textbook -f init.sql
```

クリーンアップ:

```bash
docker compose down -v
```
