# ===== Block 1 =====
pg_basebackup \
    -h primary.example.com \
    -U repl_user \
    -D /var/lib/postgresql/18/data \
    -X stream \
    -R \
    -S standby1_slot \
    -P

# ===== Block 2 =====
pg_ctl -D /var/lib/postgresql/18/data promote

# ===== Block 3 =====
pg_rewind \
    -D /var/lib/postgresql/18/data \
    --source-server="host=new-primary user=repl_user dbname=postgres"
