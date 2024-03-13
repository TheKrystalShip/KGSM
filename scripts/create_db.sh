#!/bin/bash

DB_FILE="/home/$USER/servers/info.db"

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
        ('7dtd', '/home/$USER/servers/7dtd', '0', '294420'), \
        ('corekeeper', '/home/$USER/servers/corekeeper', '0', '1963720'), \
        ('factorio', '/home/$USER/servers/factorio', '0', '0'), \
        ('minecraft', '/home/$USER/servers/minecraft', '0', '0'), \
        ('projectzomboid', '/home/$USER/servers/projectzomboid', '0', '380870'), \
        ('starbound', '/home/$USER/servers/starbound', '0', '211820'), \
        ('terraria', '/home/$USER/servers/terraria', '0', '0'), \
        ('valheim', '/home/$USER/servers/valheim', '0', '896660');"
fi
