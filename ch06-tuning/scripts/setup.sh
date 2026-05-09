#!/usr/bin/env bash
# Chapter 06 shell commands
set -euo pipefail

pg_dump -Fd -j 4 -f /backup/dump.d -h replica.example.com mydb
