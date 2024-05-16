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
  local -n OPTIONS=$1

  # OPTIONS is just a simple array of data
  # but dialog expects the following format:
  # (0 item 1 item 2 item 3 item...)
  # so we create a copy of OPTIONS with added indexes
  local indexed_options=()
  for i in "${!OPTIONS[@]}"; do
    indexed_options+=("$i" "${OPTIONS[$i]}")
  done

  # CHOICE will be the index of the selected item
  CHOICE=$(dialog --clear \
    --backtitle "$DIALOG_TITLE" \
    --title "$TITLE" \
    --menu "$DIALOG_MENU_TITLE" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $DIALOG_CHOICE_HEIGHT \
    "${indexed_options[@]}" \
    2>&1 >/dev/tty)

  echo "$CHOICE"
}

function show_input() {
  user_input=$(
    dialog \
      --backtitle "$DIALOG_TITLE" \
      --title "$TITLE" \
      --inputbox "$DIALOG_INPUT_BOX" 8 40 \
      3>&1 1>&2 2>&3 3>&-
  )

  echo "$user_input" | tr -d '\n'
}
