#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Launch script with: --start | --stop | --save | --input | --setup"
  exit 1
fi

# shellcheck disable=SC1091
source /etc/environment

WORKING_DIR="/opt/discord/admiral"

function start() {
  exec "$WORKING_DIR"/install/Admiral --rabbitmq
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
  local symlink=/etc/systemd/system/admiral.service
  if [ ! -e "$symlink" ]; then
    sudo ln -s /opt/discord/admiral/service/admiral.service "$symlink"
  fi
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
