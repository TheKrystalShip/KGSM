#!/bin/bash

DEFAULT_NR_LINES=10
PROCESS=$1
LINES="$DEFAULT_NR_LINES"

if [ $# -eq 2 ]; then
    LINES=$2
fi

journalctl -n "$LINES" -u "$PROCESS"
