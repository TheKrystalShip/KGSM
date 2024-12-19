# Blueprints 101

This document explains what blueprints are, how they work in KGSM, and how to create or customize them.

## What is a blueprint?

Blueprints in KGSM are configuration files that define the parameters needed to create a game server. These parameters typically include server settings such as port numbers, game world names, maximum player counts, and other initialization values required to start and configure the server properly. Think of them like an architect's blueprint: a detailed plan to build something specific. Each blueprint is a plain text file using a simple `key=value` format.

## Where are blueprints stored?

Blueprints are stored in two locations within the KGSM directory structure, each serving a distinct purpose:

- **Default Blueprints:** These are the standard, pre-configured blueprints provided by KGSM and stored in the `blueprints/default` directory. They should remain unmodified to avoid conflicts during updates.
- **Custom Blueprints:** Use the `blueprints` directory for any modifications or new blueprints you create. Custom blueprints override the default ones if they share the same name, allowing users to tailor configurations without altering the originals.

To list all available blueprints, run:

```sh
./kgsm.sh --blueprints
```

For example, the output might look like this:

```
minecraft.bp
valheim.bp
csgo.bp
```

## Customizing an existing blueprint

To modify a default blueprint (e.g., changing the starting game world, server port, or other settings):

1. Copy the desired blueprint from `blueprints/default` into the `blueprints` directory.
2. Edit the copied file to adjust the values as needed.

The custom blueprint will override the default one as long as it shares the same name. Ensure the file retains the `.bp` extension for KGSM to recognize it.

> [!IMPORTANT]
> Always place your custom blueprints in the `blueprints` directory. Do not modify files directly in `blueprints/default`, as these may be overwritten during updates.

### Example: Default Blueprint Template

Below is an example of the default blueprint file for `7 Days to Die`. It includes comments explaining each key-value pair:

```bash
#!/bin/bash

# DO NOT MODIFY THIS FILE
# Instead, make a copy of it in the blueprints directory and change all the
# desired parameters there.
# The name of the new file can be the same as this one, acting as an override.

# Unique name, lowercase with no spaces
BP_NAME=7dtd

# Port(s), used by UFW
# Wrap in single quotes (')
# Example: '1111:2222/tcp|1111:2222/udp'
BP_PORT='26900:26903/tcp|26900:26903/udp'

# Steam APP_ID
# Values: 0 if not applicable, Valid Steam app id otherwise
# Default: 0
BP_APP_ID=294420

# (Optional)
# Only used if BP_APP_ID != 0
# Values: 0 for anonymous, 1 for account required
BP_STEAM_AUTH_LEVEL=0

# Name of the executable that will start the server
# Values: start.sh / my_game.x86_64 / start_server
BP_LAUNCH_BIN=7DaysToDieServer.x86_64

# Savefile name or world name, level, whichever is applicable
# Values: my_world / de_dust2 / my_cool_factorio_map
BP_LEVEL_NAME=default

# (Optional)
# If the executable happens to be in a subdirectory from the main install
# and needs to be ran from inside that subdirectory
# Values: Relative path from inside install directory: $INSTALL_DIR/bin
BP_INSTALL_SUBDIRECTORY=

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
BP_LAUNCH_ARGS="-quit -batchmode -nographics -headless -dedicated -configfile=$INSTANCE_INSTALL_DIR/serverconfig.xml"

# (Optional)
# Stop command sent to the input socket
BP_STOP_COMMAND=

# (Optional)
# Save command sent to the input socket
BP_SAVE_COMMAND=
```

## Creating a new blueprint

If KGSM doesn’t have a blueprint for your desired game server, you can create one:

1. Create a new file in the `blueprints` directory.
2. Use the `key=value` format to define the server configuration. Ensure the file includes all keys present in a corresponding default blueprint, even if you only intend to change specific values. This guarantees that KGSM has all the necessary information to create and manage the game server.
3. Save the file with a `.bp` extension.

If you believe your new blueprint would benefit other users, consider contributing it to KGSM! [Submit a request](https://github.com/TheKrystalShip/KGSM/issues/new) to have your blueprint added to the project.

