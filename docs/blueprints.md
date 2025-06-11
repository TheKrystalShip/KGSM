# Blueprints 101

This document explains what blueprints are, how they work in KGSM, and how to create or customize them.

## Table of Contents
- [What are Blueprints?](#what-are-blueprints)
- [Blueprint Types and Storage](#blueprint-types-and-storage)
- [Managing Blueprints](#managing-blueprints)
  - [Listing Available Blueprints](#listing-available-blueprints)
  - [Creating New Blueprints](#creating-new-blueprints)
  - [Customizing Existing Blueprints](#customizing-existing-blueprints)
- [Using Blueprints](#using-blueprints)
- [Native Blueprint Reference](#native-blueprint-reference)
  - [Example Template](#native-blueprint-example-template)
  - [Key Parameters](#native-blueprint-key-parameters)
- [Container Blueprint Reference](#container-blueprint-reference)
  - [Example Template](#container-blueprint-example-template)
  - [Key Components](#container-blueprint-components)
  - [Container Images](#container-images)
- [Contributing](#contributing)
  - [Contributing Blueprints](#contributing-blueprints)
  - [Contributing Container Images](#contributing-container-images)

## What are Blueprints?

Blueprints in KGSM are configuration files that define the parameters needed to create a game server. These parameters typically include server settings such as port numbers, game world names, maximum player counts, and other initialization values required to start and configure the server properly. Think of them like an architect's blueprint: a detailed plan to build something specific.

KGSM 2.0 supports two types of blueprints:

1. **Native Blueprints** (`.bp` files): Simple text files using a `key=value` format for game servers that run directly on your system.
2. **Container Blueprints** (`.docker-compose.yml` files): Standard Docker Compose files that define containerized game servers.

KGSM comes with a growing collection of pre-configured blueprints for popular game servers, making it easy to get started quickly without having to create custom configurations from scratch.

## Blueprint Types and Storage

Blueprints are stored in specific locations within the KGSM directory structure, each serving a distinct purpose:

- **Default Blueprints:** These are the standard, pre-configured blueprints provided by KGSM and stored in the `blueprints/default` directory. They are divided into two types:
  - `blueprints/default/native`: For game servers that run directly on your system
  - `blueprints/default/container`: For game servers that run in Docker containers

- **Custom Blueprints:** These are stored in the corresponding folders in the `blueprints/custom` directory:
  - `blueprints/custom/native`: For your custom native server blueprints
  - `blueprints/custom/container`: For your custom container-based server blueprints

Custom blueprints take precedence over default ones if they share the same name, allowing you to tailor configurations without altering the originals.

> [!IMPORTANT]
> Always place your custom blueprints in the appropriate `blueprints/custom` directory. Do not modify files directly in the `blueprints/default` directories, as these may be overwritten during KGSM updates.

### Blueprint to Override Relationship

The `name` field in a blueprint connects it to a corresponding override file. For example, if a blueprint has `name=factorio`, KGSM will use `overrides/factorio.overrides.sh` for custom functions.

For details about overrides and how they provide custom functionality for specific game servers, see [Overrides 101](overrides.md).

## Managing Blueprints

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

### Creating New Blueprints

If KGSM doesn't have a blueprint for your desired game server, you have several options to create one:

#### Using the Blueprint Creation Tool (Native Servers)

KGSM provides a built-in tool to create new blueprints for native servers:

```sh
./kgsm.sh --create-blueprint --name <game-name> --port <port-number> --launch-bin <executable-name> [--stop-command <command>]
```

This will guide you through creating a new blueprint with the basic required parameters.

#### Manual Blueprint Creation

For more advanced configurations:

1. Create a new file in the appropriate `blueprints/custom` directory (`native` for traditional game servers, `container` for Docker-based).
2. For native servers, use the `key=value` format to define the server configuration. For container servers, use Docker Compose format.
3. Save the file with the proper extension (`.bp` for native servers or `.docker-compose.yml` for containers).

##### Native Blueprint Example

You can use an existing blueprint as a template by copying it from the default directory:

```sh
cp blueprints/default/native/minecraft.bp blueprints/custom/native/my-custom-game.bp
```

Then edit the new file to match your game server's requirements.

##### Container Blueprint Example

For container-based servers in KGSM 2.0, you can copy an existing Docker Compose blueprint:

```sh
cp blueprints/default/container/enshrouded.docker-compose.yml blueprints/custom/container/my-custom-container.docker-compose.yml
```

Then edit the file to match your containerized game server requirements.

### Customizing Existing Blueprints

To modify a default blueprint (e.g., changing the starting game world, server port, or other settings):

1. Copy the desired blueprint from `blueprints/default/native` or `blueprints/default/container` into the corresponding `blueprints/custom` directory.
2. Edit the copied file to adjust the values as needed.

The custom blueprint will override the default one as long as it shares the same name. Ensure the file retains the `.bp` extension for native servers or `.docker-compose.yml` for container-based servers.

## Using Blueprints

Once you have a blueprint, you can create a new game server instance with:

```sh
./kgsm.sh --create <blueprint> --name <instance-name> --install-dir <path>
```

KGSM 2.0 automatically detects whether the blueprint is native or container-based by its file extension and handles it accordingly.

### Native Server Example:

```sh
./kgsm.sh --create minecraft --name survival-server --install-dir /opt/servers
```

### Container Server Example:

```sh
./kgsm.sh --create enshrouded --name enshrouded-server --install-dir /opt/containers
```

> [!NOTE]
> Using container-based game servers requires Docker and Docker Compose to be installed on your system. KGSM will check for these dependencies when creating container-based server instances.

## Native Blueprint Reference

### Native Blueprint Example Template

Below is an example of the default blueprint file for `7 Days to Die`. It includes comments explaining each key-value pair for native game servers:

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
# Availble vars that can be used:
#  $instance_id
#  $instance_blueprint_file
#  $instance_working_dir
#  $instance_install_datetime
#  $instance_version_file
#  $instance_lifecycle_manager
#  $instance_manage_file
#  $instance_runtime
#  $instance_ports
#  $instance_executable_file
#  $instance_executable_arguments
#  $instance_socket_file
#  $instance_stop_command
#  $instance_save_command
#  $instance_pid_file
#  $instance_tail_pid_file
#  $instance_platform
#  $instance_level_name
#  $instance_steam_app_id
#  $instance_is_steam_account_required
#  $instance_save_command_timeout_seconds
#  $instance_stop_command_timeout_seconds
#  $instance_compress_backups
#  $instance_use_upnp
#  $instance_upnp_ports
executable_arguments="-quit -batchmode -nographics -headless -dedicated -configfile=$instance_install_dir/serverconfig.xml"

# (Optional)
# Stop command sent to the input socket
stop_command=

# (Optional)
# Save command sent to the input socket
save_command=
```

### Native Blueprint Key Parameters

When creating or modifying native blueprints, the following parameters are essential:

| Parameter | Description | Required | Example |
|-----------|-------------|:--------:|---------|
| `name` | Unique identifier, lowercase with no spaces | Yes | `minecraft` |
| `ports` | Network ports used by the server | Yes | `'25565:25565/tcp'` |
| `executable_file` | Name of the server executable file | Yes | `server.jar` |
| `level_name` | World/map/save name | Yes | `world` |
| `steam_app_id` | Steam App ID (0 if not applicable) | Yes | `294420` |
| `is_steam_account_required` | Whether Steam login is needed | No | `0` |
| `executable_subdirectory` | Subdirectory where executable is located | No | `bin` |
| `executable_arguments` | Command-line arguments for the server | No | `-Xmx2G -Xms1G` |
| `stop_command` | Command to gracefully stop server | No | `stop` |
| `save_command` | Command to save world/data | No | `save-all` |

## Container Blueprint Reference

### Container Blueprint Example Template

With KGSM 2.0, you can also use Docker containers to run game servers. Container-based blueprints use standard Docker Compose files with the `.docker-compose.yml` extension. 

> [!IMPORTANT]
> KGSM uses official container images from the [KGSM-Containers](https://github.com/TheKrystalShip/KGSM-Containers) project. These images are specifically tested and configured to work with the KGSM ecosystem. While you can use other container images, the official ones ensure compatibility and proper integration.

Below is an example for a containerized game server:

```yml
# KGSM Docker Compose file for V Rising
#
# Author: Cristian Moraru <cristian.moraru@live.com>
# Version: 1.0
#
# Copyright (c) 2025 The Krystal Ship
# Licensed under the GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.en.html
#
# DO NOT MODIFY THIS FILE
# Instead, copy it to the custom blueprints directory and modify it there



# This Docker Compose file is for setting up a V Rising server container.
services:
  vrising:

    # Docker image for V Rising server
    image: ghcr.io/thekrystalship/vrising:latest

    # Dynamic container name
    container_name: "${instance_name}"

    # Use the host's network stack directly.
    network_mode: host

    # Ensure these ports are forwarded to allow external access
    ports:
      - "9876:9876/udp"
      - "9877:9877/udp"
      - "27015:27015/udp"
      - "27016:27016/udp"

    volumes:
      # Local directory : Container directory
      - "${instance_working_dir:-.}:/opt/vrising"

    environment:
      # Environment variables for Steam authentication
      STEAM_USERNAME: "${STEAM_USERNAME}"
      STEAM_PASSWORD: "${STEAM_PASSWORD}"

    # Restart policy to keep the container running
    restart: unless-stopped
```

### Container Blueprint Components

When creating or modifying container blueprints, pay attention to the following key components:

#### 1. Docker Image
Specify the Docker image to use for the game server. For best compatibility and integration with KGSM, use the official TheKrystalShip images:

```yml
image: ghcr.io/thekrystalship/vrising:latest
```

These images are maintained in the [KGSM-Containers](https://github.com/TheKrystalShip/KGSM-Containers) repository and are designed to work seamlessly with KGSM.

#### 2. Container Name
KGSM will automatically set the container name based on the instance name:

```yml
container_name: "${instance_name}"
```

#### 3. Network Configuration
Most game servers benefit from using the host network for optimal performance:

```yml
network_mode: host
```

#### 4. Port Mapping
Even with host network mode, explicitly defining ports helps document which ports the server uses:

```yml
ports:
  - "27015:27015/udp"
  - "27016:27016/tcp"
```

#### 5. Volume Mounts
Map the working directory to the appropriate location in the container:

```yml
volumes:
  - "${instance_working_dir:-.}:/path/in/container"
```

#### 6. Environment Variables
Set any required environment variables:

```yml
environment:
  VARIABLE_NAME: "value"
  STEAM_USERNAME: "${STEAM_USERNAME}"
  STEAM_PASSWORD: "${STEAM_PASSWORD}"
```

#### 7. Restart Policy
For stability, include a restart policy:

```yml
restart: unless-stopped
```

### Container Images

The container images used by KGSM are maintained in a dedicated repository: [KGSM-Containers](https://github.com/TheKrystalShip/KGSM-Containers). These images are specifically designed to work well with the KGSM ecosystem and have been thoroughly tested.

## Contributing

### Contributing Blueprints

The list of supported game servers in KGSM is constantly growing! If you create a blueprint that works well, consider contributing it back to the project to help other users.

To submit your blueprint:
1. Ensure it is well-tested and properly configured
2. Create a pull request on GitHub with your blueprint file
3. Alternatively, [submit a feature request](https://github.com/TheKrystalShip/KGSM/issues/new?template=add_game_server.md) with your blueprint attached

Community contributions are what make KGSM better for everyone!

### Contributing Container Images

If you want to contribute a new container image for a game server:

1. Visit the [KGSM-Containers](https://github.com/TheKrystalShip/KGSM-Containers) repository
2. Follow the contribution guidelines specific to that project
3. Submit your container image via a Pull Request

Once your container image is accepted and published to the official repository, you can then create a corresponding `.docker-compose.yml` blueprint that uses your image.
