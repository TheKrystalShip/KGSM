# Overrides 101

This document contains everything related to script overrides: why they exist,
how they work and how they are used internally to keep KGSM simple.

## What's an overrides?

Game servers can be created from multiple places, some of them have dedicated
server options that can be obtaied directly from Steam and others require a bit
more work in order to download and set up.

Overrides are used for game server that **don't** come from Steam.

## Why do overrides exist?

An override file contains functions for different steps of the installation
process that can be modified to work for a game server without the need to add
modifications to the core KGSM codebase.

They allow for the codebase to stay clean and game-server-agnostic as much as
possible, externalizing any custom code needed for non-steam game servers.

## How are they used internally?

The overrides script file will be sourced internally by KGSM and called
whenever it's needed.

Snippet from the override template file:

```sh
# INPUT:
# - void
#
# OUTPUT:
# - echo "$version": Success
# - exit 1: Error
# func_get_latest_version       Should always return the latest available
#                               version, or exit 1 in case there's any problem.
#
# INPUT:
# - $1: Version
# - $2: Destination directory, absolute path
#
# OUTPUT:
# - exit 0: Success
# - exit 1: Error
# func_download                 In charge of downloading all the required files
#                               for the service, extract any zips, move, copy,
#                               rename, remove, etc. It should leave the $2
#                               with a fully working setup that can be called
#                               and executed as if it was a full install.
#
# INPUT:
# - $1: Source directory, absolute path
# - $2: Destination directory, absolute path
#
# OUTPUT:
# - exit 0: Success
# - exit 1: Error
# func_deploy                   Will move everything from $1 into $2 and do any
#                               cleanup that couldn't be done by func_download.
```

Each of those functions can be implemented in a override script file for a
blueprint.

Blueprints are linked to overrides by the `SERVICE_NAME` field inside the
blueprint file.

**Example 1 (default bp, default override):**

Blueprint file: `blueprints/default/factorio.bp`

> \# Service name, lowercase with no spaces
>
> SERVICE_NAME=factorio
>
> [...]

Overrides file: `overrides/factorio.overrides.sh`

**Example 2 (custom bp, default override):**

Blueprint file: `blueprints/my-factorio-server.bp`

> \# Service name, lowercase with no spaces
>
> SERVICE_NAME=factorio
>
> [...]

Overrides file: `overrides/factorio.overrides.sh`

**Example 3 (custom bp, custom override):**

Blueprint file: `blueprints/7dtd-custom03.bp`

> \# Service name, lowercase with no spaces
>
> SERVICE_NAME=7dtd-custom03
>
> [...]

Overrides file: `overrides/7dtd-custom03.overrides.sh`

## Creating new overrides

To create new overrides, simply copy the contents from `templates/overrides.tp`
into a new file and uncomment whatever parts are needed.

The new file should strictly follow the naming convention:

`BLUEPRINT_NAME_WITHOUT_EXTENSION.overrides.sh`

Otherwise it won't be picked up correctly.

## File permissions

Override files are always sourced into existing scripts and are never called
directly, they don't need execution permissions.
