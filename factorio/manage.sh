#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Launch script with: --start | --stop | --save | --input | --setup"
  exit 1
fi

# shellcheck disable=SC1091
source /etc/environment

WORKING_DIR=/opt/factorio

function start() {
  exec "$WORKING_DIR"/install/bin/x64/factorio --start-server "$WORKING_DIR"/saves/tks.zip
}

function stop() {
  save
  sleep 10
  echo "/quit" >./factorio.stdin
}

function save() {
  echo "/save" >./factorio.stdin
}

function input() {
  echo "$1" >./factorio.stdin
}

function setup() {
  sudo ln -s /opt/factorio/service/factorio.service /etc/systemd/system/factorio.service
  sudo ln -s /opt/factorio/service/factorio.socket /etc/systemd/system/factorio.socket
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
