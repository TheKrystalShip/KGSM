#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Launch script with: --start | --stop | --save | --input"
  exit 1
fi

# shellcheck disable=SC1091
source /etc/environment

WORKING_DIR=/opt/corekeeper/install

function start() {
  (cd "$WORKING_DIR" && exec ./_launch.sh)
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
    input
    shift
    ;;
  *)
    shift
    ;;
  esac
  shift
done
