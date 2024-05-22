#!/bin/bash

trap 'clear && exit' INT

# Template parameters to be filled in
_name=""
_port=""
_working_dir="/opt"
_app_id="0"
_steam_auth_level="0"
_launch_bin=""
_install_subdirectory=""
_launch_args=""
_uses_input_socket="0"
_socket_stop_command=""
_socket_save_command=""


COMMON_SCRIPT="$(find "$KGSM_ROOT" -type f -name common.sh)"
TEMPLATE_INPUT_FILE="$(find "$KGSM_ROOT" -type f -name blueprint.tp)"

# shellcheck disable=SC1090
source "$COMMON_SCRIPT" || exit 1

# shellcheck disable=SC2034
DIALOG_TITLE="KGSM - Blueprint creator - v0.1"
# shellcheck disable=SC2034
DIALOG_MENU_TITLE="Creating new blueprint"

# dialog form uses \n as a default separator, but since we convert the response
# into an array we need to use a different separator otherwise some options
# will get assignes different indexes when they actually belong together, like
# launch args for example.
separator="@"

# $response is a string, all content is there separated by $separator
response=$(dialog \
  --title "$DIALOG_TITLE" \
  --output-separator "$separator" \
  --form "$DIALOG_MENU_TITLE" \
  20 78 0 \
  "*Name:" 1 1 "$_name" 1 40 30 0 \
  "*Port:" 2 1 "$_port" 2 40 30 0 \
  "*Working dir:" 3 1 "$_working_dir" 3 40 30 0 \
  "App ID:" 4 1 "$_app_id" 4 40 30 0 \
  "Steam Auth Level (0|1):" 5 1 "$_steam_auth_level" 5 40 30 0 \
  "*Launch bin:" 6 1 "$_launch_bin" 6 40 30 0 \
  "Subdirectory" 7 1 "$_install_subdirectory" 7 40 30 0 \
  "Launch args:" 8 1 "$_launch_args" 8 40 30 2048 \
  "Input socket (0|1):" 9 1 "$_uses_input_socket" 9 40 30 0 \
  "Socket stop command:" 10 1 "$_socket_stop_command" 10 40 30 0 \
  "Socket save command:" 11 1 "$_socket_save_command" 11 40 30 0 \
  3>&1 1>&2 2>&3 3>&-)

# Split response into an array, use $separator to get all the options
declare -a response_array=()
IFS="$separator" read -ra TEMP <<<"$response"
for i in "${TEMP[@]}"; do
  response_array+=("$i")
done

# Get values from array, empty values are allowed
_name=${response_array[0]}
_port=${response_array[1]}
_working_dir="${response_array[2]}/${_name}"
_app_id=${response_array[3]}
_steam_auth_level=${response_array[4]}
_launch_bin=${response_array[5]}
_install_subdirectory=${response_array[6]}
_launch_args=${response_array[7]}
_uses_input_socket=${response_array[8]}
_socket_stop_command=${response_array[9]}
_socket_save_command=${response_array[10]}

clear

# Output file path
BLUEPRINT_OUTPUT_FILE="$BLUEPRINTS_SOURCE_DIR/$_name.bp"

# Create blueprint from template file
if ! eval "cat <<EOF
$(<"$TEMPLATE_INPUT_FILE")
EOF
" >"$BLUEPRINT_OUTPUT_FILE" 2>/dev/null; then
  echo ">>> ERROR: Failed to create $BLUEPRINT_OUTPUT_FILE"
fi
