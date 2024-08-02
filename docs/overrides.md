# Overrides

## Existing overrides

Files in `overrides` should follow the following naming convention:

`BLUEPRINT_NAME.overrides.sh`

Where `BLUEPRINT_NAME` does NOT include the **.bp** extension.
It has to be an exact case-sensitive match, otherwise it won't be picked up.

## Creating new overrides

To create new overrides, simply copy the contents from `templates/overrides.tp` into a new file and uncomment whatever parts are needed.

## File permissions

Override files are always sourced into existing scripts and are never called directly.

They don't need execution permissions.
