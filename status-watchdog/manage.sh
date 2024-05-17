#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Launch script with: --start | --stop | --save | --input"
  exit 1
fi

# shellcheck disable=SC1091
source /etc/environment

WORKING_DIR=/opt/status-watchdog/install
CONFIG_FILE="$WORKING_DIR"/services.csv

function start() {
  echo "==============================="
  echo "*** Status Watchdog Started ***"
  echo "==============================="

  exec "$WORKING_DIR"/log-reader "$CONFIG_FILE"
}

function stop() {
  return
}

function save() {
  return
}

function input() {
  return
}

#Read the argument values
while [ $# -gt 0 ]; do
  case "$1" in
  --start)
    start
    shift
    ;;
  --stop)
    stop
    shift
    ;;
  --save)
    save
    shift
    ;;
  --input)
    input "$2"
    shift
    ;;
  *)
    shift
    ;;
  esac
  shift
done
