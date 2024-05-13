#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Launch script with: --start | --stop | --save"
  exit 1
fi

WORKING_DIR=/opt/terraria

# shellcheck disable=SC1091
source /etc/environment

function start() {
  exec "$WORKING_DIR"/install/TerrariaServer.bin.x86_64 -config "$WORKING_DIR"/install/serverconfig.txt
}

function stop() {
  save
  sleep 10s
  echo "exit" >./terraria.stdin
}

function save() {
  echo "save" >"$WORKING_DIR/terraria.stdin"
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
  *)
    shift
    ;;
  esac
  shift
done
