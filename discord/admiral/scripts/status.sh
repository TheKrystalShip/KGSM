#!/bin/bash

PROCESS=$1

systemctl status "$PROCESS" | head -n 3
