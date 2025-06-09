# Blueprints 101

This document explains what blueprints are, how they work in KGSM, and how to create or customize them.

## Creating a new blueprint

If KGSM doesn't have a blueprint for your desired game server, you have several options to create one:

### Using the Blueprint Creation Tool

KGSM provides a built-in tool to create new blueprints:

```sh
./kgsm.sh --create-blueprint --name <game-name> --port <port-number> --launch-bin <executable-name> [--stop-command <command>]
```

This will guide you through creating a new blueprint with the basic required parameters.

### Manual Blueprint Creation

For more advanced configurations:

1. Create a new file in the appropriate `blueprints/custom` directory (`native` for traditional game servers, `container` for Docker-based).
2. Use the `key=value` format to define the server configuration. Ensure the file includes all required keys.
3. Save the file with the proper extension (`.bp` for native servers or `.docker-compose.yml` for containers).

You can use an existing blueprint as a template by copying it from the default directory:

```sh
cp blueprints/default/native/minecraft.bp blueprints/custom/native/my-custom-game.bp
```

Then edit the new file to match your game server's requirements.

## Using Blueprints to Create Game Servers

Once you have a blueprint, you can create a new game server instance with:

```sh
./kgsm.sh --create <blueprint> --name <instance-name> --install-dir <path>
```

For example:

```sh
./kgsm.sh --create minecraft --name survival-server --install-dir /opt/servers
```

## Contributing Your Blueprints

The list of supported game servers in KGSM is constantly growing! If you create a blueprint that works well, consider contributing it back to the project to help other users.

To submit your blueprint:
1. Ensure it is well-tested and properly configured
2. Create a pull request on GitHub with your blueprint file
3. Alternatively, [submit a feature request](https://github.com/TheKrystalShip/KGSM/issues/new?template=add_game_server.md) with your blueprint attached

Community contributions are what make KGSM better for everyone!

## What is a blueprint?

Blueprints in KGSM are configuration files that define the parameters needed to create a game server. These parameters typically include server settings such as port numbers, game world names, maximum player counts, and other initialization values required to start and configure the server properly. Think of them like an architect's blueprint: a detailed plan to build something specific. Each blueprint is a plain text file using a simple `key=value` format.

KGSM comes with a growing collection of pre-configured blueprints for popular game servers, making it easy to get started quickly without having to create custom configurations from scratch.

## Where are blueprints stored?

Blueprints are stored in specific locations within the KGSM directory structure, each serving a distinct purpose:

- **Default Blueprints:** These are the standard, pre-configured blueprints provided by KGSM and stored in the `blueprints/default` directory. They are divided into two types:
  - `blueprints/default/native`: For game servers that run directly on your system
  - `blueprints/default/container`: For game servers that run in Docker containers

- **Custom Blueprints:** These are stored in the corresponding folders in the `blueprints/custom` directory:
  - `blueprints/custom/native`: For your custom native server blueprints
  - `blueprints/custom/container`: For your custom container-based server blueprints

Custom blueprints take precedence over default ones if they share the same name, allowing you to tailor configurations without altering the originals.

### Listing Available Blueprints

To list all available blueprints, run:

```sh
./kgsm.sh --blueprints
```

For more detailed information about each blueprint, use:

```sh
./kgsm.sh --blueprints --detailed
```

You can also get the output in JSON format for scripting purposes:

```sh
./kgsm.sh --blueprints --json
```

## Customizing an existing blueprint

To modify a default blueprint (e.g., changing the starting game world, server port, or other settings):

1. Copy the desired blueprint from `blueprints/default/native` or `blueprints/default/container` into the corresponding `blueprints/custom` directory.
2. Edit the copied file to adjust the values as needed.

The custom blueprint will override the default one as long as it shares the same name. Ensure the file retains the `.bp` extension for native servers or `.docker-compose.yml` for container-based servers.

> [!IMPORTANT]
> Always place your custom blueprints in the appropriate `blueprints/custom` directory. Do not modify files directly in the `blueprints/default` directories, as these may be overwritten during KGSM updates.

### Blueprint to Override Relationship

The `name` field in a blueprint connects it to a corresponding override file. For example, if a blueprint has `name=factorio`, KGSM will use `overrides/factorio.overrides.sh` for custom functions.

For details about overrides and how they provide custom functionality for specific game servers, see [Overrides 101](overrides.md).

### Example: Default Blueprint Template

Below is an example of the default blueprint file for `7 Days to Die`. It includes comments explaining each key-value pair:

```bash
# KGSM Blueprint for 7 Days to Die (7dtd)
#
# Author: Cristian Moraru <cristian.moraru@live.com>
# Version: 2.0
#
# Copyright (c) 2025 The Krystal Ship
# Licensed under the GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.en.html
#
# DO NOT MODIFY THIS FILE
# Instead, copy it to the custom blueprints directory and modify it there

# Unique name, lowercase with no spaces
name=7dtd

# Port(s), used by UFW
# Wrap in single quotes (')
# Example: '1111:2222/tcp|1111:2222/udp'
ports='26900:26903/tcp|26900:26903/udp'

# Steam APP_ID
# Values: 0 if not applicable, Valid Steam app id otherwise
# Default: 0
steam_app_id=294420

# (Optional)
# Only used if steam_app_id != 0
# Values: 0 for anonymous, 1 for account required
is_steam_account_required=0

# Name of the executable that will start the server
# Values: start.sh / my_game.x86_64 / start_server
executable_file=7DaysToDieServer.x86_64

# Savefile name or world name, level, whichever is applicable
# Values: my_world / de_dust2 / my_cool_factorio_map
level_name=default

# (Optional)
# If the executable happens to be in a subdirectory from the main install
# and needs to be ran from inside that subdirectory
# Values: Relative path from inside install directory: $INSTALL_DIR/bin
executable_subdirectory=

# Any args passed onto the executable
# Available vars that can be used:
#   $INSTANCE_LAUNCH_DIR
#   $INSTANCE_WORKING_DIR
#   $INSTANCE_BACKUPS_DIR
#   $INSTANCE_TEMP_DIR
#   $INSTANCE_LOGS_DIR
#   $INSTANCE_INSTALL_DIR
#   $INSTANCE_SAVES_DIR
#   $INSTANCE_LEVEL_NAME
executable_arguments="-quit -batchmode -nographics -headless -dedicated -configfile=$INSTANCE_INSTALL_DIR/serverconfig.xml"

# (Optional)
# Stop command sent to the input socket
stop_command=

# (Optional)
# Save command sent to the input socket
save_command=
```

