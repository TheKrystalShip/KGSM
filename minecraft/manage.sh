#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Launch script with: --start | --stop | --save | --input | --setup"
  exit 1
fi

# shellcheck disable=SC1091
source /etc/environment

MAX_HEAP_ALLOCATION="4096M"
INITIAL_HEAP_ALLOCATION="$MAX_HEAP_ALLOCATION"

WORKING_DIR="/opt/minecraft/install"
SOCKET_FILE="/opt/minecraft/minecraft.stdin"
STARTUP_FILE="release.jar"

function start() {
  (cd "$WORKING_DIR" && exec java \
    -Xmx"$MAX_HEAP_ALLOCATION" \
    -Xms"$INITIAL_HEAP_ALLOCATION" \
    -XX:+UseG1GC \
    -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+DisableExplicitGC \
    -XX:+AlwaysPreTouch \
    -XX:G1NewSizePercent=30 \
    -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M \
    -XX:G1ReservePercent=20 \
    -XX:G1HeapWastePercent=5 \
    -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 \
    -XX:+PerfDisableSharedMem \
    -XX:MaxTenuringThreshold=1 \
    -jar \
    "$STARTUP_FILE" \
    nogui)
}

function stop() {
  save
  sleep 10
  echo "/stop" >$SOCKET_FILE
}

function save() {
  echo "/save-all" >$SOCKET_FILE
}

function input() {
  echo "$1" >$SOCKET_FILE
}

function setup() {
  local service_symlink=/etc/systemd/system/minecraft.service
  if [ ! -e "$service_symlink" ]; then
    sudo ln -s /opt/minecraft/service/minecraft.service "$service_symlink"
  fi

  local socket_symlink=/etc/systemd/system/minecraft.socket
  if [ ! -e "$socket_symlink" ]; then
    sudo ln -s /opt/minecraft/service/minecraft.socket "$socket_symlink"
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
