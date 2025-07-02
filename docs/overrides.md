# Overrides 101

This document explains what overrides are, how they work in KGSM, and how to create and use them effectively to customize game server management.

## Table of Contents

- [What are Overrides?](#what-are-overrides)
  - [Common Use Cases](#common-use-cases)
- [How Overrides Work](#how-overrides-work)
- [Override System Components](#override-system-components)
  - [Available Functions](#available-functions)
  - [Available Variables](#available-variables)
  - [Blueprint-Override Linking](#blueprint-override-linking)
    - [Example: Multiple Blueprint Variants](#example-multiple-blueprint-variants)
- [Design Decision: Name-Based Matching](#design-decision-name-based-matching)
  - [Why Name-Based Matching Was Chosen](#why-name-based-matching-was-chosen)
  - [Comparison: Name-Based vs File-Based Matching](#comparison-name-based-vs-file-based-matching)
  - [Best Practices for Name-Based Matching](#best-practices-for-name-based-matching)
- [Creating Overrides](#creating-overrides)
  - [Getting Started](#getting-started)
  - [Basic Example](#basic-example)
  - [Error Handling](#error-handling)
- [Best Practices and Guidelines](#best-practices-and-guidelines)
  - [Core Principles](#core-principles)
  - [File Permissions](#file-permissions)

## What are Overrides?

Overrides are custom script files that allow you to replace specific functions in a game server's management script with your own implementations. They serve several important purposes:

- **Enable support for diverse game servers**: Particularly useful for non-Steam games that require custom installation, update, or runtime handling
- **Keep KGSM's core modular**: By externalizing game-specific code, the main codebase remains clean and maintainable
- **Provide flexibility**: Allow any management function to be customized without modifying KGSM's core scripts

### Common Use Cases

Overrides are typically used for:
- Creating custom version-checking for games with unique versioning systems
- Implementing specialized download procedures for games not available through Steam
- Adding unique startup/shutdown sequences for games with special requirements
- Developing custom backup and restoration logic for complex game data structures

## How Overrides Work

When KGSM creates a management script for a game server instance:

1. It extracts the `name` value from the blueprint file (not the blueprint filename)
2. It scans for an override file named `{blueprint_name}.overrides.sh` in the overrides directory
3. If an override file is found, it is sourced and any function defined in that override file **replaces** the corresponding function in the generated management script
4. Functions not defined in the override use their default implementations from the template
5. If no override file is found, all functions use their default implementations

The override loading process happens during instance creation and management script generation. Overrides are sourced using bash's `source` command, so they have access to all the same environment variables and functions as the main KGSM scripts.

This selective replacement system means you only need to implement the specific functions that require customization for your game server.

## Override System Components

### Available Functions

Any function from the `manage.native.tp` template can be overridden. The most commonly overridden functions include:

- **Version Management**: `_get_latest_version()`, `_get_installed_version()`, `_compare_versions()`, `_save_version()`
- **Installation & Updates**: `_download()`, `_deploy()`, `_update()`
- **Server Control**: `_start()`, `_start_background()`, `_stop_server()`, `_send_save_command()`
- **Backup Management**: `_create_backup()`, `_restore_backup()`
- **Port Management**: `_enable_upnp()`, `_disable_upnp()`
- **Log Management**: `_print_logs()`, `_rotate_logs()`

> [!TIP]
> For detailed function signatures, input/output specifications, and implementation examples, see the `templates/overrides.tp` file. The template contains comprehensive documentation for each function with practical examples and best practices.

### Available Variables

When your override functions are called, they have access to all the instance variables that KGSM provides. These variables are prefixed with `instance_` and include basic instance information, directory paths, process management files, runtime configuration, game server settings, Steam integration, network configuration, and more.

> [!TIP]
> For a complete list of all available variables with detailed descriptions, see the "AVAILABLE GLOBAL VARIABLES" section in `templates/overrides.tp`. The template provides comprehensive documentation of every variable you can use in your override functions.

### Blueprint-Override Linking

Overrides are linked to blueprints through the `name` field in the blueprint file, **not the blueprint filename**. For a complete explanation of blueprints and how they work, see [Blueprints 101](blueprints.md).

The naming convention is simple:
- A blueprint with `name=factorio` will use `overrides/factorio.overrides.sh`
- A custom blueprint with `name=my-custom-game` will use `overrides/my-custom-game.overrides.sh`

> [!IMPORTANT]
> The override file name is based on the blueprint's `name` variable, not the blueprint filename. If the naming convention is not followed, KGSM will not recognize the override script.

This allows multiple blueprint variants to share the same override file if they have the same `name` value, or use custom overrides by specifying unique names.

#### Example: Multiple Blueprint Variants

You can have multiple blueprint files for the same game, all sharing the same override:

```
blueprints/custom/native/terraria-vanilla.bp    (name=terraria) → overrides/terraria.overrides.sh
blueprints/custom/native/terraria-modded.bp     (name=terraria) → overrides/terraria.overrides.sh
blueprints/custom/native/terraria-hardcore.bp   (name=terraria) → overrides/terraria.overrides.sh
```

All three blueprint variants will use the same `terraria.overrides.sh` file, ensuring consistent behavior across different server configurations.

## Design Decision: Name-Based Matching

KGSM uses name-based matching (matching overrides to the blueprint's `name` variable) rather than file-based matching (matching overrides to the blueprint filename). This design decision was made after careful consideration of both approaches.

### Why Name-Based Matching Was Chosen

The name-based approach was selected because it better supports KGSM's goal of providing a flexible, maintainable system for managing diverse game server configurations. Here's why:

1. **Real-World Usage**: Most users will have multiple variants of the same game (vanilla, modded, hardcore, etc.) that share the same core logic
2. **Maintenance Efficiency**: Critical bug fixes and improvements only need to be made once
3. **Logical Grouping**: The `name` field represents the core game identity, which is what the override logic should be based on
4. **Future-Proof**: Supports complex scenarios that will become more common as KGSM grows

### Comparison: Name-Based vs File-Based Matching

#### Name-Based Matching (Current Approach)
**How it works:** `terraria-vanilla.bp` (name=terraria) → `terraria.overrides.sh`

**Pros:**
- **DRY principle**: Single override file serves multiple blueprint variants
- **Easier maintenance**: One place to update logic for all variants
- **Consistent behavior**: All variants guaranteed to use the same override logic
- **Flexible naming**: Blueprint files can have descriptive names without affecting override matching
- **Better scalability**: Supports complex scenarios like modded variants, different game modes, etc.

**Cons:**
- Less obvious relationship between blueprint files and overrides
- Potential confusion for users expecting file-based matching
- Hidden dependencies where override changes affect multiple blueprints
- Slightly more complex debugging (need to check blueprint's `name` field)

#### File-Based Matching (Alternative Approach)
**How it would work:** `terraria-vanilla.bp` → `terraria-vanilla.overrides.sh`

**Pros:**
- Simple and intuitive 1:1 mapping
- Clear file organization
- No ambiguity about which override belongs to which blueprint
- Easy debugging and troubleshooting

**Cons:**
- Code duplication across multiple similar blueprints
- Maintenance overhead - changes must be replicated across multiple files
- Risk of inconsistent behavior as override files diverge over time
- Storage inefficiency with redundant files

### Best Practices for Name-Based Matching

- **Use descriptive blueprint filenames**: `terraria-vanilla.bp`, `terraria-modded.bp`, `terraria-hardcore.bp`
- **Keep blueprint names consistent**: All variants should use the same `name=terraria` value
- **Document override dependencies**: Add comments in override files explaining which blueprint variants use them
- **Test all variants**: When modifying an override, test all blueprint variants that use it

## Creating Overrides

### Getting Started

To create a new override script:

1. Copy the contents of `templates/overrides.tp` into a new file.
2. Review the template to understand all available functions and their purposes.
3. Identify which functions you need to customize for your game server.
4. Implement only the functions you need to override - any function not defined in your override will use the default implementation from the template.
5. Save the file using the following naming convention:
```
{blueprint_name}.overrides.sh
```

Where `{blueprint_name}` is the value of the `name` variable in your blueprint file.

> [!TIP]
> The `templates/overrides.tp` file contains comprehensive documentation for each function, including detailed input/output specifications, implementation examples, and best practices. Use it as your primary reference when implementing override functions.

### Basic Example

Here's a simple example of how to override the download function:

```bash
#!/usr/bin/env bash

function _download() {
  local version=$1
  local dest=$2

  __print_info "Downloading custom game server version $version..."

  # Your custom download logic here
  # See templates/overrides.tp for comprehensive examples

  __print_success "Download complete"
  return 0
}
```

This override would only modify the download behavior, while all other functions would use their default implementations.

### Error Handling

Override functions should follow KGSM's error handling conventions:

- **Return codes**: Use `return 0` for success and `return 1` for failure
- **Error messages**: Use `__print_error` for error messages and `__print_info` for informational messages
- **Validation**: Always validate inputs and check for required files/directories
- **Cleanup**: If your function fails partway through, clean up any partial changes

> [!TIP]
> For detailed error handling examples and best practices, see the implementation examples in `templates/overrides.tp`. Each function in the template includes comprehensive error handling patterns that you can adapt for your own overrides.

## Best Practices and Guidelines

### Core Principles

- **Keep it Simple:** Only implement the necessary functions for the game server's unique requirements.
- **Test Thoroughly:** Ensure the override functions work as intended by testing installation, updates, and deployments.
- **Document Changes:** Add comments in the override file to explain any custom behavior for future reference.
- **Follow Naming Conventions:** Always use the underscore prefix (`_`) for override function names.
- **Validate Inputs:** Always check that required parameters and files exist before proceeding.
- **Handle Errors Gracefully:** Use proper error handling and cleanup in case of failures.
- **Use KGSM Functions:** Leverage KGSM's built-in functions like `__print_info`, `__print_error`, and `__print_success` for consistent messaging.

### File Permissions

Override files are sourced by KGSM and do not require execution permissions. Ensure the file has read permissions, such as with `chmod 644`, to allow KGSM to source it correctly.

> [!TIP]
> For detailed debugging tips, advanced error handling patterns, and comprehensive best practices, see the "IMPORTANT GUIDELINES" section in `templates/overrides.tp`. The template provides extensive guidance on writing robust, production-ready override functions.

---

By using overrides effectively, you can extend KGSM's functionality to support a wide variety of game servers while maintaining the integrity of its core scripts.
