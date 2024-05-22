#!/bin/bash

export DIALOG_HEIGHT=15
export DIALOG_WIDTH=40
export DIALOG_CHOICE_HEIGHT=4
export DIALOG_TITLE="Game Server Manager v0.1"
export DIALOG_MENU_TITLE="Choose one of the following options:"
export DIALOG_INPUT_BOX="Enter value:"

# INPUT: An array of options to display
# with the format: (0 string 1 string 2 string...)
# OUTPUT: The selected index from the options array
function show_dialog() {
  # Array of data
  local -n options=$1

  # options is just a simple array of data
  # but dialog expects the following format:
  # (0 item 1 item 2 item 3 item...)
  # so we create a copy of options with added indexes
  local indexed_options=()
  declare -i index=0
  for item in "${options[@]}"; do
    indexed_options+=("$index" "$item")
    index+=1
  done

  # choice will be the index of the selected item
  choice=$(dialog --clear \
    --backtitle "$DIALOG_TITLE" \
    --title "$TITLE" \
    --menu "$DIALOG_MENU_TITLE" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $DIALOG_CHOICE_HEIGHT \
    "${indexed_options[@]}" \
    2>&1 >/dev/tty) || echo -1

  echo "$choice"
}

function show_input() {
  local placeholder=${1:-}
  user_input=$(
    dialog \
      --backtitle "$DIALOG_TITLE" \
      --title "$TITLE" \
      --inputbox "$DIALOG_INPUT_BOX" 8 40 "$placeholder" \
      3>&1 1>&2 2>&3 3>&-
  ) || echo -1

  echo "$user_input" | tr -d '\n'
}
