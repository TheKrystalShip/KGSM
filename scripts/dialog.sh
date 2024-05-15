#!/bin/bash

export DIALOG_HEIGHT=15
export DIALOG_WIDTH=40
export DIALOG_CHOICE_HEIGHT=4
export DIALOG_TITLE="Game Server Manager v0.1"
export DIALOG_MENU_TITLE="Choose one of the following options:"

# INPUT: An array of options to display
# with the format: (0 string 1 string 2 string...)
# OUTPUT: The selected index from the options array
function show_dialog() {
  local -n OPTIONS=$1

  CHOICE=$(dialog --clear \
    --backtitle "$DIALOG_TITLE" \
    --title "$TITLE" \
    --menu "$DIALOG_MENU_TITLE" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $DIALOG_CHOICE_HEIGHT \
    "${OPTIONS[@]}" \
    2>&1 >/dev/tty)

  echo "$CHOICE"
}
