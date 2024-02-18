#!/bin/bash

WORKING_DIR="/home/$USER/servers/terraria/install/latest"

exec "$WORKING_DIR/Linux/TerrariaServer.bin.x86_64" -config "$WORKING_DIR/serverconfig.txt"
