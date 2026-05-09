#!/usr/bin/env bash
# Chapter 02 — 書籍に掲載されたコマンドの参照用です。
# このファイルは一括実行用ではありません。
exit 0

# ---- マイグレーション実行(エラー時に停止) ----
psql -1 -v ON_ERROR_STOP=1 -f migration.sql
