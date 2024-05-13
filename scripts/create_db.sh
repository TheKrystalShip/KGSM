#!/bin/bash

DB_FILE="/opt/info.db"

sqlite3 "$DB_FILE" "\
DROP TABLE IF EXISTS services; \
CREATE TABLE IF NOT EXISTS services ( \
    id INTEGER PRIMARY KEY, \
    name TEXT NOT NULL, \
    working_dir TEXT NOT NULL, \
    installed_version TEXT DEFAULT '0', \
    app_id TEXT DEFAULT '0'\
);"

if [ "$1" = "--populate" ]; then
  sqlite3 "$DB_FILE" "\
    INSERT INTO \
        services (name, working_dir, installed_version, app_id) \
    VALUES \
        ('7dtd', '/opt/7dtd', '0', '294420'), \
        ('corekeeper', '/opt/corekeeper', '0', '1963720'), \
        ('factorio', '/opt/factorio', '0', '0'), \
        ('minecraft', '/opt/minecraft', '0', '0'), \
        ('projectzomboid', '/opt/projectzomboid', '0', '380870'), \
        ('starbound', '/opt/starbound', '0', '211820'), \
        ('terraria', '/opt/terraria', '0', '0'), \
        ('valheim', '/opt/valheim', '0', '896660');"
fi
