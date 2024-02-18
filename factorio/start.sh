#!/bin/bash

WORKING_DIR=/home/"$USER"/servers/factorio

exec "$WORKING_DIR"/install/bin/x64/factorio --start-server "$WORKING_DIR"/saves/tks.zip
