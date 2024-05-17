#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Launch script with: --start | --stop | --save | --input"
  exit 1
fi

# shellcheck disable=SC1091
source /etc/environment

WORKING_DIR=/opt/projectzomboid/install
SOCKET_FILE=/opt/projectzomboid/projectzomboid.stdin

function start() {
  exec "$WORKING_DIR"/start-server.sh -servername "TKS"
}

function stop() {
  save
  sleep 10
  echo "quit" >"$SOCKET_FILE"
}

function save() {
  echo "save" >"$SOCKET_FILE"
}

function input() {
  echo "$1" >"$SOCKET_FILE"
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
