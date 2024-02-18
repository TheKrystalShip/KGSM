#!/bin/bash

trap 'kill 0' EXIT

echo "==============================="
echo "*** Status Watchdog Started ***"
echo "==============================="

log-reader "7dtd" "INF Loaded (local): worldglobal" "Stopped 7 Days To Die Dedicated Server" &

log-reader "corekeeper" "Game ID" "Stopped CoreKeeper Dedicated Server" &

log-reader "factorio" "Hosting game at IP ADDR" "Stopped Factorio Dedicated Server" &

log-reader "minecraft" "For help, type help" "Stopped Minecraft Dedicated Server" &

log-reader "projectzomboid" "SERVER STARTED" "Stopped Project Zomboid Dedicated Server" &

log-reader "starbound" "UniverseServer: listening for incoming TCP connections" "Stopped Starbound Dedicated Server" &

log-reader "terrarria" "Server started" "Stopped Terraria Dedicated Server" &

log-reader "valheim" "unused Assets to reduce memory usage. Loaded Objects now" "Stopped Valheim Dedicated Server" &

wait
