#!/bin/bash

echo "==============================="
echo "*** Status Watchdog Started ***"
echo "==============================="

exec log-reader "/home/$USER/servers/services.csv"
