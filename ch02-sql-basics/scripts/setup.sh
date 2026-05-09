#!/usr/bin/env bash
# Chapter 02 shell commands
set -euo pipefail

$ psql -1 -v ON_ERROR_STOP=1 -f migration.sql
