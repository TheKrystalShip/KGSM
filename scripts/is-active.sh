#!/bin/bash

PROCESS=$1

systemctl is-active "$PROCESS"
