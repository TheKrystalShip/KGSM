#!/bin/bash

PROCESS=$1

systemctl is-enabled "$PROCESS"
