#!/bin/bash

# This script file is used as the main interface for SQLite3.
# Source it wherever it's needed and gain access to the db
#
# DB table schema for reference
#┌──┬────┬───────────┬─────────────────┬──────┬────────────────┐
#│0 | 1  | 2         | 3               | 4    | 5              │
#├──┼────┼───────────┼─────────────────┼──────┼────────────────┤
#|id|name|working_dir|installed_version|app_id|steam_auth_level|
#└──┴────┴───────────┴─────────────────┴──────┴────────────────┘
################################################################################

export DB_FILE="/opt/info.db"
TABLE="services"

function db_query() {
  sqlite3 "$DB_FILE" "$1"
}

# Get all entries
function db_get_all() {
  db_query "SELECT * FROM $TABLE;"
}

function db_get_all_names() {
  db_query "SELECT name from $TABLE;"
}

# Gets all fields given a name
function db_get_all_by_name() {
  db_query "SELECT * FROM $TABLE WHERE name = '$1';"
}

# Get the installed_version given a name
function db_get_version() {
  db_query "SELECT installed_version FROM $TABLE WHERE name = '$1';"
}

# Set the installed_version given a name
function db_set_version() {
  db_query "UPDATE $TABLE SET installed_version = $2 WHERE name = '$1';"
}

# Get the working_dir given a name
function db_get_working_dir() {
  db_query "SELECT working_dir FROM $TABLE WHERE name = '$1';"
}

# Delete and entry given a name
function db_delete_by_name() {
  db_query "DELETE FROM $TABLE WHERE name = '$1';"
}
