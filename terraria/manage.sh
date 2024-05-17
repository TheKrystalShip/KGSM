#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Launch script with: --start | --stop | --save"
  exit 1
fi

WORKING_DIR=/opt/terraria
SOCKET_FILE=/opt/terraria/terraria.stdin

# shellcheck disable=SC1091
source /etc/environment

function start() {
  exec "$WORKING_DIR"/install/TerrariaServer.bin.x86_64 -config "$WORKING_DIR"/install/serverconfig.txt
}

function stop() {
  save
  sleep 10s
  echo "exit" >"$SOCKET_FILE"
}

function save() {
  echo "save" >"$SOCKET_FILE"
}

function input() {
  echo "$1" >"$$SOCKET_FILE"
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
