#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Launch script with: --start | --stop | --save | --input | --setup"
  exit 1
fi

WORKING_DIR=/opt/veloren

# shellcheck disable=SC1091
source /etc/environment

function start() {
  exec "$WORKING_DIR"/install/veloren-server-cli
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
  local service_symlink=/etc/systemd/system/veloren.service
  if [ ! -e "$service_symlink" ]; then
    sudo ln -s /opt/veloren/service/veloren.service "$service_symlink"
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
