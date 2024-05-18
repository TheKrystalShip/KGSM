#!/bin/bash

# shellcheck disable=SC1091
source /etc/environment

# Passed as argument
# Possible values: 0, 1, 2
AUTH_LEVEL=$1

# Used for steamcmd login
# Anonymous login by default
USERNAME="anonymous"

# Anonymous login not allowed, load username & pass
if [ "$AUTH_LEVEL" != "0" ]; then
    USERNAME="$STEAM_USERNAME $STEAM_PASSWORD"
fi

function steamcmd_get_latest_version() {
    local app_id=$1
    steamcmd \
        +login "$USERNAME" \
        +app_info_update 1 \
        +app_info_print "$app_id" \
        +quit | tr '\n' ' ' | grep \
        --color=NEVER \
        -Po '"branches"\s*{\s*"public"\s*{\s*"buildid"\s*"\K(\d*)'
}

function steamcmd_download() {
    local app_id=$1
    local output_dir=$2
    steamcmd \
        +@sSteamCmdForcePlatformType linux \
        +force_install_dir "$output_dir" \
        +login "$USERNAME" \
        +app_update "$app_id" \
        -beta none \
        validate \
        +quit
}
