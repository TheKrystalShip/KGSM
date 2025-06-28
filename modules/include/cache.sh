#!/usr/bin/env bash

# KGSM Cache Module
#
# This module provides intelligent caching for instance configurations and blueprints
# to dramatically improve performance when multiple modules access the same data.
#
# Features:
# - Instance configuration caching with automatic staleness detection
# - Blueprint caching for both native and container blueprints
# - Modification time tracking for cache invalidation
# - Comprehensive cache management and debugging tools

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# Check for KGSM_ROOT
if [[ -z "$KGSM_ROOT" ]]; then
  # Absolute path to this script file
  SELF_PATH="$(dirname "$(readlink -f "$0")")"
  while [[ "$SELF_PATH" != "/" ]]; do
    [[ -f "$SELF_PATH/kgsm.sh" ]] && KGSM_ROOT="$SELF_PATH" && break
    SELF_PATH="$(dirname "$SELF_PATH")"
  done
  [[ -z "$KGSM_ROOT" ]] && echo "${0##*/} ERROR: Could not locate kgsm.sh. Ensure the directory structure is intact." && exit 1

  export KGSM_ROOT
fi

# =============================================================================
# CACHE STORAGE ARRAYS
# =============================================================================

# Instance config caching arrays
declare -gA KGSM_INSTANCE_LOADED_FLAGS=()
declare -gA KGSM_INSTANCE_LOADED_TIMES=()

# Blueprint caching arrays
declare -gA KGSM_BLUEPRINT_LOADED_FLAGS=()
declare -gA KGSM_BLUEPRINT_LOADED_TIMES=()
declare -gA KGSM_BLUEPRINT_PATHS=()

# =============================================================================
# INSTANCE CONFIG CACHING FUNCTIONS
# =============================================================================

# Clear cache for a specific instance (useful after config changes)
# Usage: __clear_instance_cache <instance_name>
function __clear_instance_cache() {
  local instance_name="$1"

  if [[ -z "$instance_name" ]]; then
    __print_error "No 'instance_name' specified for cache clearing."
    return $EC_INVALID_ARG
  fi

  # Extract basename if absolute path provided
  if [[ "$instance_name" == /* ]]; then
    instance_name=$(basename "$instance_name")
  fi

  # Remove cache flag and timestamp
  unset KGSM_INSTANCE_LOADED_FLAGS["$instance_name"]
  unset KGSM_INSTANCE_LOADED_TIMES["$instance_name"]

  # Clear all instance variables for this instance
  local var_name
  for var_name in $(compgen -v | grep "^instance_"); do
    unset "$var_name"
  done

  return 0
}

export -f __clear_instance_cache

# Clear all instance caches (useful for cleanup)
# Usage: __clear_all_instance_caches
function __clear_all_instance_caches() {
  local instance_name

  # Clear all cached instances
  for instance_name in "${!KGSM_INSTANCE_LOADED_FLAGS[@]}"; do
    __clear_instance_cache "$instance_name"
  done

  # Reset cache arrays
  KGSM_INSTANCE_LOADED_FLAGS=()
  KGSM_INSTANCE_LOADED_TIMES=()

  return 0
}

export -f __clear_all_instance_caches

# Check if instance config file has been modified since last load
# Usage: __is_instance_config_stale <instance_name> <config_file>
# Returns: 0 if stale (needs reload), 1 if fresh
function __is_instance_config_stale() {
  local instance_name="$1"
  local config_file="$2"

  # If not previously loaded, it's considered stale
  if [[ -z "${KGSM_INSTANCE_LOADED_TIMES[$instance_name]:-}" ]]; then
    return 0
  fi

  # Get current modification time
  local current_mtime
  if ! current_mtime=$(stat -c %Y "$config_file" 2>/dev/null); then
    # If we can't get mtime, assume stale for safety
    return 0
  fi

  # Compare with cached modification time
  local cached_mtime="${KGSM_INSTANCE_LOADED_TIMES[$instance_name]}"

  if [[ "$current_mtime" -gt "$cached_mtime" ]]; then
    return 0  # Stale
  else
    return 1  # Fresh
  fi
}

export -f __is_instance_config_stale

# Check if an instance is currently cached
# Usage: __is_instance_cached <instance_name>
# Returns: 0 if cached, 1 if not cached
function __is_instance_cached() {
  local instance_name="$1"

  if [[ -z "$instance_name" ]]; then
    return 1
  fi

  # Extract basename if absolute path provided
  if [[ "$instance_name" == /* ]]; then
    instance_name=$(basename "$instance_name")
  fi

  [[ "${KGSM_INSTANCE_LOADED_FLAGS[$instance_name]:-}" == "1" ]]
}

export -f __is_instance_cached

# Mark an instance as cached with current timestamp
# Usage: __mark_instance_cached <instance_name> <config_file>
function __mark_instance_cached() {
  local instance_name="$1"
  local config_file="$2"

  if [[ -z "$instance_name" || -z "$config_file" ]]; then
    __print_error "Both instance_name and config_file must be specified."
    return $EC_INVALID_ARG
  fi

  # Extract basename if absolute path provided
  if [[ "$instance_name" == /* ]]; then
    instance_name=$(basename "$instance_name")
  fi

  # Mark as loaded and record modification time
  KGSM_INSTANCE_LOADED_FLAGS["$instance_name"]="1"
  KGSM_INSTANCE_LOADED_TIMES["$instance_name"]=$(stat -c %Y "$config_file" 2>/dev/null || echo "0")

  # Export the cache arrays to make them available to child processes
  export KGSM_INSTANCE_LOADED_FLAGS
  export KGSM_INSTANCE_LOADED_TIMES

  return 0
}

export -f __mark_instance_cached

# Hook for modules that modify instance configs to invalidate cache
# Usage: __invalidate_instance_cache <instance_name>
function __invalidate_instance_cache() {
  local instance_name="$1"

  if [[ -z "$instance_name" ]]; then
    __print_error "No 'instance_name' specified for cache invalidation."
    return $EC_INVALID_ARG
  fi

  # Clear the cache so next access will reload
  __clear_instance_cache "$instance_name"

  # Optionally emit a debug message
  if [[ "${KGSM_DEBUG:-}" == "true" ]]; then
    __print_info "Cache invalidated for instance: $instance_name"
  fi
}

export -f __invalidate_instance_cache

# =============================================================================
# BLUEPRINT CACHING FUNCTIONS
# =============================================================================

# Clear cache for a specific blueprint
# Usage: __clear_blueprint_cache <blueprint_name>
function __clear_blueprint_cache() {
  local blueprint_name="$1"

  if [[ -z "$blueprint_name" ]]; then
    __print_error "No 'blueprint_name' specified for cache clearing."
    return $EC_INVALID_ARG
  fi

  # Extract basename if absolute path provided
  if [[ "$blueprint_name" == /* ]]; then
    blueprint_name=$(basename "$blueprint_name")
  fi

  # Remove cache flag, timestamp, and path
  unset KGSM_BLUEPRINT_LOADED_FLAGS["$blueprint_name"]
  unset KGSM_BLUEPRINT_LOADED_TIMES["$blueprint_name"]
  unset KGSM_BLUEPRINT_PATHS["$blueprint_name"]

  # Clear all blueprint variables for this blueprint
  local var_name
  for var_name in $(compgen -v | grep "^blueprint_"); do
    unset "$var_name"
  done

  return 0
}

export -f __clear_blueprint_cache

# Clear all blueprint caches
# Usage: __clear_all_blueprint_caches
function __clear_all_blueprint_caches() {
  local blueprint_name

  # Clear all cached blueprints
  for blueprint_name in "${!KGSM_BLUEPRINT_LOADED_FLAGS[@]}"; do
    __clear_blueprint_cache "$blueprint_name"
  done

  # Reset cache arrays
  KGSM_BLUEPRINT_LOADED_FLAGS=()
  KGSM_BLUEPRINT_LOADED_TIMES=()
  KGSM_BLUEPRINT_PATHS=()

  return 0
}

export -f __clear_all_blueprint_caches

# Check if blueprint file has been modified since last load
# Usage: __is_blueprint_stale <blueprint_name>
# Returns: 0 if stale (needs reload), 1 if fresh
function __is_blueprint_stale() {
  local blueprint_name="$1"

  # Extract basename if absolute path provided
  if [[ "$blueprint_name" == /* ]]; then
    blueprint_name=$(basename "$blueprint_name")
  fi

  # If not previously loaded, it's considered stale
  if [[ -z "${KGSM_BLUEPRINT_LOADED_TIMES[$blueprint_name]:-}" ]]; then
    return 0
  fi

  # Get blueprint path
  local blueprint_path="${KGSM_BLUEPRINT_PATHS[$blueprint_name]}"
  if [[ -z "$blueprint_path" ]]; then
    return 0  # No path cached, consider stale
  fi

  # Get current modification time
  local current_mtime
  if ! current_mtime=$(stat -c %Y "$blueprint_path" 2>/dev/null); then
    # If we can't get mtime, assume stale for safety
    return 0
  fi

  # Compare with cached modification time
  local cached_mtime="${KGSM_BLUEPRINT_LOADED_TIMES[$blueprint_name]}"

  if [[ "$current_mtime" -gt "$cached_mtime" ]]; then
    return 0  # Stale
  else
    return 1  # Fresh
  fi
}

export -f __is_blueprint_stale

# Check if a blueprint is currently cached
# Usage: __is_blueprint_cached <blueprint_name>
# Returns: 0 if cached, 1 if not cached
function __is_blueprint_cached() {
  local blueprint_name="$1"

  if [[ -z "$blueprint_name" ]]; then
    return 1
  fi

  # Extract basename if absolute path provided
  if [[ "$blueprint_name" == /* ]]; then
    blueprint_name=$(basename "$blueprint_name")
  fi

  [[ "${KGSM_BLUEPRINT_LOADED_FLAGS[$blueprint_name]:-}" == "1" ]]
}

export -f __is_blueprint_cached

# Mark a blueprint as cached with current timestamp and path
# Usage: __mark_blueprint_cached <blueprint_name> <blueprint_path>
function __mark_blueprint_cached() {
  local blueprint_name="$1"
  local blueprint_path="$2"

  if [[ -z "$blueprint_name" || -z "$blueprint_path" ]]; then
    __print_error "Both blueprint_name and blueprint_path must be specified."
    return $EC_INVALID_ARG
  fi

  # Extract basename if absolute path provided
  if [[ "$blueprint_name" == /* ]]; then
    blueprint_name=$(basename "$blueprint_name")
  fi

  # Mark as loaded and record modification time and path
  KGSM_BLUEPRINT_LOADED_FLAGS["$blueprint_name"]="1"
  KGSM_BLUEPRINT_LOADED_TIMES["$blueprint_name"]=$(stat -c %Y "$blueprint_path" 2>/dev/null || echo "0")
  KGSM_BLUEPRINT_PATHS["$blueprint_name"]="$blueprint_path"

  # Export the cache arrays to make them available to child processes
  export KGSM_BLUEPRINT_LOADED_FLAGS
  export KGSM_BLUEPRINT_LOADED_TIMES
  export KGSM_BLUEPRINT_PATHS

  return 0
}

export -f __mark_blueprint_cached

# Invalidate blueprint cache
# Usage: __invalidate_blueprint_cache <blueprint_name>
function __invalidate_blueprint_cache() {
  local blueprint_name="$1"

  if [[ -z "$blueprint_name" ]]; then
    __print_error "No 'blueprint_name' specified for cache invalidation."
    return $EC_INVALID_ARG
  fi

  # Clear the cache so next access will reload
  __clear_blueprint_cache "$blueprint_name"

  # Optionally emit a debug message
  if [[ "${KGSM_DEBUG:-}" == "true" ]]; then
    __print_info "Blueprint cache invalidated for: $blueprint_name"
  fi
}

export -f __invalidate_blueprint_cache

# =============================================================================
# UNIFIED CACHE MANAGEMENT
# =============================================================================

# Clear all caches (instances and blueprints)
# Usage: __clear_all_caches
function __clear_all_caches() {
  __clear_all_instance_caches
  __clear_all_blueprint_caches
}

export -f __clear_all_caches

# Force reload functions for convenience
# Usage: __reload_instance <instance_name>
function __reload_instance() {
  local instance_name="$1"

  if [[ -z "$instance_name" ]]; then
    __print_error "No 'instance_name' specified for reload."
    return $EC_INVALID_ARG
  fi

  __invalidate_instance_cache "$instance_name"
}

export -f __reload_instance

# Usage: __reload_blueprint <blueprint_name>
function __reload_blueprint() {
  local blueprint_name="$1"

  if [[ -z "$blueprint_name" ]]; then
    __print_error "No 'blueprint_name' specified for reload."
    return $EC_INVALID_ARG
  fi

  __invalidate_blueprint_cache "$blueprint_name"
}

export -f __reload_blueprint

# =============================================================================
# DEBUG AND INSPECTION FUNCTIONS
# =============================================================================

# Debug function to show instance cache status
# Usage: __debug_instance_cache [instance_name]
function __debug_instance_cache() {
  local target_instance="$1"

  if [[ -n "$target_instance" ]]; then
    # Show specific instance
    echo "Instance Cache Debug: $target_instance"
    echo "  Loaded: ${KGSM_INSTANCE_LOADED_FLAGS[$target_instance]:-'No'}"
    echo "  Load Time: ${KGSM_INSTANCE_LOADED_TIMES[$target_instance]:-'Never'}"

    # Show some key variables
    local var_count=0
    # Use a safer approach to get instance variables
    local instance_vars
    instance_vars=$(compgen -v | grep "^instance_" | head -5 || true)

    if [[ -n "$instance_vars" ]]; then
      while IFS= read -r var_name; do
        if [[ -n "$var_name" ]]; then
          echo "  Variable: $var_name=${!var_name}"
          ((var_count++))
        fi
      done <<< "$instance_vars"

      if [[ $var_count -eq 5 ]]; then
        echo "  ... (showing first 5 instance variables)"
      fi
    fi
  else
    # Show all cached instances
    echo "Instance Cache Debug: All Instances"
    echo "  Total cached instances: ${#KGSM_INSTANCE_LOADED_FLAGS[@]}"

    for instance_name in "${!KGSM_INSTANCE_LOADED_FLAGS[@]}"; do
      echo "  - $instance_name (loaded: ${KGSM_INSTANCE_LOADED_FLAGS[$instance_name]}, time: ${KGSM_INSTANCE_LOADED_TIMES[$instance_name]})"
    done
  fi
}

export -f __debug_instance_cache

# Debug function to show blueprint cache status
# Usage: __debug_blueprint_cache [blueprint_name]
function __debug_blueprint_cache() {
  local target_blueprint="$1"

  if [[ -n "$target_blueprint" ]]; then
    # Show specific blueprint
    echo "Blueprint Cache Debug: $target_blueprint"
    echo "  Loaded: ${KGSM_BLUEPRINT_LOADED_FLAGS[$target_blueprint]:-'No'}"
    echo "  Load Time: ${KGSM_BLUEPRINT_LOADED_TIMES[$target_blueprint]:-'Never'}"
    echo "  Path: ${KGSM_BLUEPRINT_PATHS[$target_blueprint]:-'Unknown'}"

    # Show some key variables
    local var_count=0
    local blueprint_vars
    blueprint_vars=$(compgen -v | grep "^blueprint_" | head -5 || true)

    if [[ -n "$blueprint_vars" ]]; then
      while IFS= read -r var_name; do
        if [[ -n "$var_name" ]]; then
          echo "  Variable: $var_name=${!var_name}"
          ((var_count++))
        fi
      done <<< "$blueprint_vars"

      if [[ $var_count -eq 5 ]]; then
        echo "  ... (showing first 5 blueprint variables)"
      fi
    fi
  else
    # Show all cached blueprints
    echo "Blueprint Cache Debug: All Blueprints"
    echo "  Total cached blueprints: ${#KGSM_BLUEPRINT_LOADED_FLAGS[@]}"

    for blueprint_name in "${!KGSM_BLUEPRINT_LOADED_FLAGS[@]}"; do
      echo "  - $blueprint_name (loaded: ${KGSM_BLUEPRINT_LOADED_FLAGS[$blueprint_name]}, time: ${KGSM_BLUEPRINT_LOADED_TIMES[$blueprint_name]})"
    done
  fi
}

export -f __debug_blueprint_cache

# Comprehensive cache debug function
# Usage: __debug_cache
function __debug_cache() {
  echo "=========================================="
  echo "KGSM Cache Status Report"
  echo "=========================================="

  __debug_instance_cache
  echo ""
  __debug_blueprint_cache

  echo ""
  echo "Cache Memory Usage:"
  echo "  Instance arrays: ${#KGSM_INSTANCE_LOADED_FLAGS[@]} entries"
  echo "  Blueprint arrays: ${#KGSM_BLUEPRINT_LOADED_FLAGS[@]} entries"
  echo "  Total cached items: $((${#KGSM_INSTANCE_LOADED_FLAGS[@]} + ${#KGSM_BLUEPRINT_LOADED_FLAGS[@]}))"
}

export -f __debug_cache

# Export cache management flag
export KGSM_CACHE_LOADED=1
