#!/bin/bash

WORKING_DIR="/home/$USER/servers/terraria"

function main() {
  if [ "$1" = "--start" ]; then
    start
  elif [ "$1" = "--stop" ]; then
    stop
  fi
}

function start() {
  "$WORKING_DIR"/install/TerrariaServer.bin.x86_64 -config "$WORKING_DIR"/config/serverconfig.txt
}

function stop() {
  echo "exit" >"$WORKING_DIR"/../terraria.stdin
}

main "$@"
exit
