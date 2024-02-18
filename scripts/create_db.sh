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
        ('7dtd', '/home/cristian/servers/7dtd', '0', '294420'), \
        ('corekeeper', '/home/cristian/servers/corekeeper', '0', '1963720'), \
        ('factorio', '/home/cristian/servers/factorio', '0', '0'), \
        ('minecraft', '/home/cristian/servers/minecraft', '0', '0'), \
        ('projectzomboid', '/home/cristian/servers/projectzomboid', '0', '380870'), \
        ('starbound', '/home/cristian/servers/starbound', '0', '211820'), \
        ('terraria', '/home/cristian/servers/terraria', '0', '0'), \
        ('valheim', '/home/cristian/servers/valheim', '0', '896660');"
fi
