#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Launch script with: --start | --stop | --save | --input | --setup"
  exit 1
fi

# shellcheck disable=SC1091
source /etc/environment

WORKING_DIR=/opt/valheim/install

function start() {
  (cd "$WORKING_DIR" && exec "$WORKING_DIR"/start_server_bepinex.sh)
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

function setup() {
  sudo ln -s /opt/valheim/service/valheim.service /etc/systemd/system/valheim.service
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
  --setup)
    setup
    shift
    ;;
  *)
    shift
    ;;
  esac
  shift
done
