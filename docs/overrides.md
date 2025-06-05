# Overrides 101

This document provides a detailed explanation of script overrides in KGSM: why they exist, how they function, and how to create and use them effectively to keep the KGSM codebase clean and extensible.

## What is an override?

Overrides are custom script files used to support game servers that do **not** originate from Steam or require special handling during their installation and deployment processes. This "special handling" may involve tasks such as downloading files from non-standard sources, unpacking and arranging custom file structures, or applying patches to prepare the server for deployment. They allow for custom behavior without altering the core KGSM codebase.

By implementing overrides, KGSM can accommodate a wide range of game servers while maintaining a clean, modular, and game-server-agnostic structure. For example, Minecraft servers often require overrides due to their unique download and setup requirements, which differ significantly from Steam-based installations.

## Why do overrides exist?

Override files enable:

- Support for non-Steam game servers that require unique installation or setup steps.
- Externalizing custom code to keep KGSM’s core functionality simple and maintainable.
- Easy adaptability for adding new game servers without modifying KGSM’s core scripts.

## How are overrides used internally?

Override script files are sourced by KGSM at runtime and invoked during specific steps in the game server installation and deployment processes. These scripts are mandatory only for non-standard game servers that require custom handling; they are not needed for most Steam-based servers that follow standard installation and deployment procedures. These scripts contain functions that handle custom behavior for:

1. Retrieving the latest version of the server software.
2. Downloading and preparing the server files.
3. Deploying the files to the appropriate directory structure.

### Function Definitions
Below is an explanation of the main functions found in an override file, as defined in the template:

```sh
# INPUT:
# - void
#
# OUTPUT:
# - echo "$version": Success
# - exit 1: Error
func_get_latest_version       # Retrieves the latest available version. Exits with 1 on error.

# INPUT:
# - $1: Version
# - $2: Destination directory, absolute path
#
# OUTPUT:
# - exit 0: Success
# - exit 1: Error
func_download                 # Downloads all required files, extracts zips, and prepares a working setup.

# INPUT:
# - $1: Source directory, absolute path
# - $2: Destination directory, absolute path
#
# OUTPUT:
# - exit 0: Success
# - exit 1: Error
func_deploy                   # Moves files from the source to the destination and performs final cleanup.
```

Each function can be implemented in the override script if needed. By default, KGSM provides implementations for these functions, designed to support standard Steam-based installations. If a function is not implemented in the override, KGSM will fall back to its default behavior. This ensures that non-Steam game servers or those requiring custom behavior can still function seamlessly while relying on defaults where appropriate.

### Linking Blueprints and Overrides
Blueprints specify which override script to use through the `blueprint_name` field. The `blueprint_name` value links a blueprint to its corresponding override file.

#### Examples

**Default Blueprint and Override:**

- **Blueprint File:** `blueprints/default/factorio.bp`
  ```sh
  # Unique name, lowercase with no spaces
  blueprint_name=factorio
  ```
- **Override File:** `overrides/factorio.overrides.sh`

**Custom Blueprint with Default Override:**

- **Blueprint File:** `blueprints/my-factorio-server.bp`
  ```sh
  # Unique name, lowercase with no spaces
  blueprint_name=factorio
  ```
- **Override File:** `overrides/factorio.overrides.sh`

**Custom Blueprint with Custom Override:**

- **Blueprint File:** `blueprints/7dtd-custom03.bp`
  ```sh
  # Unique name, lowercase with no spaces
  blueprint_name=7dtd-custom03
  ```
- **Override File:** `overrides/7dtd-custom03.overrides.sh`

## Creating New Overrides

To create a new override script:

1. Copy the contents of `templates/overrides.tp` into a new file.
2. Uncomment and implement only the required functions.
3. Save the file using the following naming convention:
```
blueprint_name.overrides.sh
```
For example, for a blueprint `valheim.bp`, the override file should be named `valheim.overrides.sh`.

> [!IMPORTANT]
> If the naming convention is not followed, KGSM will not recognize the override script.

## File Permissions

Override files are sourced by KGSM and do not require execution permissions. Ensure the file has read permissions, such as with `chmod 644`, to allow KGSM to source it correctly.

## Best Practices

- **Keep it Simple:** Only implement the necessary functions for the game server’s unique requirements.
- **Test Thoroughly:** Ensure the override functions work as intended by testing installation, updates, and deployments.
- **Document Changes:** Add comments in the override file to explain any custom behavior for future reference.

---
By using overrides effectively, you can extend KGSM’s functionality to support a wide variety of game servers while maintaining the integrity of its core scripts.

