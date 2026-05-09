# PostgreSQL の教科書 — サンプルコード

書籍 **『PostgreSQL の教科書 — 現場で使える基礎と実践』** (森川 陽介 著) のサンプルコード集です。

書籍内で扱う SQL / Docker Compose / `postgresql.conf` / `pg_hba.conf` / シェルスクリプトの動作確認済みコードを章別に配置しています。

## 動作環境

- Docker / Docker Compose
- PostgreSQL 17 / 18(章により切替)
- macOS / Linux(Ubuntu 22.04+)

ホストに PostgreSQL をインストールする必要はありません。各章の `docker-compose.yml` で必要なバージョンが起動します。

## 章構成

| ディレクトリ | 章 | 主な内容 |
|------------|-----|---------|
| `ch01-setup/` | 第1章 | 環境構築、Docker Compose、psql/pgAdmin/DBeaver |
| `ch02-sql-basics/` | 第2章 | DDL / DML / トランザクション |
| `ch03-types/` | 第3章 | データ型・制約・インデックス基礎 |
| `ch04-explain/` | 第4章 | EXPLAIN ANALYZE の読み方 |
| `ch05-indexes/` | 第5章 | B-tree / GIN / BRIN 設計パターン |
| `ch06-tuning/` | 第6章 | クエリチューニング 20 ケース |
| `ch07-schema/` | 第7章 | テーブル設計と正規化・非正規化 |
| `ch08-partitioning/` | 第8章 | パーティショニング |
| `ch09-replication/` | 第9章 | レプリケーション・HA |
| `ch10-backup/` | 第10章 | バックアップ・PITR |
| `ch11-monitoring/` | 第11章 | 監視・VACUUM 戦略 |
| `ch12-cloud/` | 第12章 | クラウド差分 + PG 17/18 新機能 |
| `appendix-a-psql/` | 付録A | psql チートシート |
| `appendix-b-conf/` | 付録B | postgresql.conf 早見表 |

## 各章の起動方法

各章ディレクトリに `README.md` があります。基本パターン:

```bash
cd ch04-explain
docker compose up -d
psql -h localhost -U postgres -f init.sql
psql -h localhost -U postgres -c "\i examples/seq_scan.sql"
```

停止 / クリーンアップ:

```bash
docker compose down -v   # ボリュームごと削除
```

## ライセンス

MIT License。書籍を参照する範囲で自由に改変・利用できます。

## 書籍情報

- タイトル: PostgreSQL の教科書 — 現場で使える基礎と実践
- 著者: 森川 陽介
- 価格: ¥980(Kindle Unlimited 対応)
- ペーパーバック: ¥2,500(予定)
- 発売日: 未定

## サポート

- 誤植・コード不具合は GitHub Issues へ
- 書籍に関する質問はレビュー欄または著者連絡先(書籍奥付参照)
