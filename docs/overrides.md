# Overrides 101

This document explains what overrides are, how they work in KGSM, and how to create and use them effectively to customize game server management.

## Overview of Overrides

### What are overrides and why do they exist?

Overrides are custom script files that allow you to replace specific functions in a game server's management script with your own implementations. They serve several important purposes:

- **Enable support for diverse game servers**: Particularly useful for non-Steam games that require custom installation, update, or runtime handling
- **Keep KGSM's core modular**: By externalizing game-specific code, the main codebase remains clean and maintainable
- **Provide flexibility**: Allow any management function to be customized without modifying KGSM's core scripts

Common customization scenarios include:
- Creating custom version-checking for games with unique versioning systems
- Implementing specialized download procedures for games not available through Steam
- Adding unique startup/shutdown sequences for games with special requirements
- Developing custom backup and restoration logic for complex game data structures

### How overrides work

When KGSM creates a management script for a game server instance:

1. It scans for an override file matching the blueprint name
2. Any function defined in that override file **replaces** the corresponding function in the generated management script
3. Functions not defined in the override use their default implementations from the template

This selective replacement system means you only need to implement the specific functions that require customization for your game server. You can override any function from the `manage.native.tp` template, including but not limited to:

- Server startup and shutdown procedures
- Version checking and updating mechanisms
- File downloading and deployment processes
- Backup creation and restoration methods
- Log handling and command input processing

### Overridable Functions

Any function from the `manage.native.tp` template can be overridden. Here are some of the most commonly overridden functions:

#### Core Version Management

```sh
# Gets the latest available version from whatever source
# INPUT: void
# OUTPUT: Echoes version string or returns 1 for error
function _get_latest_version() { ... }

# Gets the currently installed version
# INPUT: void
# OUTPUT: Echoes version string
function _get_installed_version() { ... }

# Compares installed and latest versions
# INPUT: void
# OUTPUT: Echoes latest version if different, returns 1 if same
function _compare_versions() { ... }

# Saves version information to file
# INPUT: $1 - Version string
# OUTPUT: return code 0 for success, 1 for error
function _save_version() { ... }
```

#### Installation and Updates

```sh
# Downloads server files 
# INPUT: $1 - Version, $2 - Destination directory
# OUTPUT: return code 0 for success, 1 for error
function _download() { ... }

# Deploys files from temp dir to install dir
# INPUT: void (uses INSTANCE variables)
# OUTPUT: return code 0 for success, 1 for error
function _deploy() { ... }

# Handles the complete update process
# INPUT: void
# OUTPUT: return code 0 for success, 1 for error  
function _update() { ... }
```

#### Server Management

```sh
# Starts the server in current terminal
# INPUT: void
# OUTPUT: Launches server process
function _start() { ... }

# Starts server in background
# INPUT: void
# OUTPUT: return code 0 for success, 1 for error
function _start_background() { ... }

# Stops the server
# INPUT: optional flags like --no-save, --no-graceful
# OUTPUT: return code 0 for success, 1 for error
function _stop_server() { ... }

# Saves the game state
# INPUT: void
# OUTPUT: return code 0 for success, 1 for error
function _send_save_command() { ... }
```

#### Backup Management

```sh
# Creates a backup of the server
# INPUT: void
# OUTPUT: return code 0 for success, 1 for error
function _create_backup() { ... }

# Restores a backup
# INPUT: $1 - Backup name
# OUTPUT: return code 0 for success, 1 for error
function _restore_backup() { ... }
```

These are just a few examples of the functions you can override. You can implement any of these functions in your override file, and KGSM will use your implementation instead of the default one when generating the instance's management script.

### Linking Blueprints and Overrides

Overrides are linked to blueprints through the `name` field in the blueprint file. For a complete explanation of blueprints and how they work, see [Blueprints 101](blueprints.md).

The naming convention is simple:
- A blueprint with `name=factorio` will use `overrides/factorio.overrides.sh`
- A custom blueprint with `name=my-custom-game` will use `overrides/my-custom-game.overrides.sh`

> [!IMPORTANT]
> If the naming convention is not followed, KGSM will not recognize the override script.

This allows multiple blueprint variants to share the same override file if they have the same `name` value, or use custom overrides by specifying unique names.

## Creating New Overrides

To create a new override script:

1. Copy the contents of `templates/overrides.tp` into a new file.
2. Identify which functions you need to customize for your game server.
3. Implement only the functions you need to override - any function not defined in your override will use the default implementation from the template.
4. Save the file using the following naming convention:
```
name.overrides.sh
```

### Example: Custom Download Function

Here's an example of a simple override that customizes how Minecraft server files are downloaded:

```bash
#!/usr/bin/env bash

# Override the download function for Minecraft
function _download() {
  local version=$1
  local dest=$2
  
  __print_info "Downloading Minecraft server version $version..."
  
  # Download the server jar directly from Mojang
  if ! wget "https://launcher.mojang.com/v1/objects/a16d67e5807f57fc4e550299cf20226194497dc2/server.jar" -O "$dest/server.jar"; then
    __print_error "Failed to download Minecraft server"
    return 1
  fi
  
  # Create necessary configuration files
  echo "eula=true" > "$dest/eula.txt"
  
  __print_success "Download complete"
  return 0
}
```

This override would only modify the download behavior, while all other functions would use their default implementations.

## File Permissions

Override files are sourced by KGSM and do not require execution permissions. Ensure the file has read permissions, such as with `chmod 644`, to allow KGSM to source it correctly.

## Best Practices

- **Keep it Simple:** Only implement the necessary functions for the game server's unique requirements.
- **Test Thoroughly:** Ensure the override functions work as intended by testing installation, updates, and deployments.
- **Document Changes:** Add comments in the override file to explain any custom behavior for future reference.

---
By using overrides effectively, you can extend KGSM's functionality to support a wide variety of game servers while maintaining the integrity of its core scripts.
