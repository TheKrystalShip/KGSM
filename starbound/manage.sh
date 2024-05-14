#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Launch script with: --start | --stop | --save | --input | --setup"
  exit 1
fi

# shellcheck disable=SC1091
source /etc/environment

WORKING_DIR=/opt/starbound/install

function start() {
  (cd "$WORKING_DIR"/linux && exec ./starbound_server)
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
  sudo ln -s /opt/starbound/service/starbound.service /etc/systemd/system/starbound.service
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
