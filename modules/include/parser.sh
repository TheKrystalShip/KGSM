#!/bin/bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

function __parse_ufw_to_upnp_ports() {
  local ufw_ports=$1
  local grouped_ports=()

  # Split the input into individual port ranges
  IFS='|' read -ra ranges <<< "$ufw_ports"

  for range in "${ranges[@]}"; do

    # Port range with protocol specified
    if [[ "$range" =~ ^([0-9]+):([0-9]+)/([a-z]+)$ ]]; then
      local start_port="${BASH_REMATCH[1]}"
      local end_port="${BASH_REMATCH[2]}"
      local protocol="${BASH_REMATCH[3]}"

      for port in $(seq "$start_port" "$end_port"); do
        grouped_ports+=("$port" "$protocol")
      done

    # Single port with protocol specified
    elif [[ "$range" =~ ^([0-9]+)/([a-z]+)$ ]]; then
      local port="${BASH_REMATCH[1]}"
      local protocol="${BASH_REMATCH[2]}"

      grouped_ports+=("$port" "$protocol")

    # Port range without protocol (assume both TCP and UDP)
    elif [[ "$range" =~ ^([0-9]+):([0-9]+)$ ]]; then
      local start_port="${BASH_REMATCH[1]}"
      local end_port="${BASH_REMATCH[2]}"

      for port in $(seq "$start_port" "$end_port"); do
        for protocol in tcp udp; do
          grouped_ports+=("$port" "$protocol")
        done
      done

    # Single port without protocol (assume both TCP and UDP)
    elif [[ "$range" =~ ^([0-9]+)$ ]]; then
      local port="${BASH_REMATCH[1]}"

      grouped_ports+=("$port" "tcp" "$port" "udp")

    # Nothing mathes, definition might be wrongly formatted
    else
      __print_error "Invalid port definition: $range"
      return $EC_GENERAL
    fi
  done

  echo "${grouped_ports[@]}"
}

export -f __parse_ufw_to_upnp_ports

function __parse_ufw_to_docker_ports() {
  local ufw_ports="$1"
  local docker_ports=()

  # Split the input into individual port ranges
  IFS='|' read -ra ranges <<< "$ufw_ports"

  for range in "${ranges[@]}"; do
    # Parse port range and protocol
    if [[ "$range" =~ ^([0-9]+):([0-9]+)/([a-z]+)$ ]]; then
      local start_port="${BASH_REMATCH[1]}"
      local end_port="${BASH_REMATCH[2]}"
      local protocol="${BASH_REMATCH[3]}"

      for port in $(seq "$start_port" "$end_port"); do
        docker_ports+=("-p ${port}:${port}/${protocol}")
      done

    elif [[ "$range" =~ ^([0-9]+)/([a-z]+)$ ]]; then
      local port="${BASH_REMATCH[1]}"
      local protocol="${BASH_REMATCH[2]}"

      docker_ports+=("-p ${port}:${port}/${protocol}")

    elif [[ "$range" =~ ^([0-9]+):([0-9]+)$ ]]; then
      local start_port="${BASH_REMATCH[1]}"
      local end_port="${BASH_REMATCH[2]}"

      for port in $(seq "$start_port" "$end_port"); do
        for protocol in tcp udp; do
          docker_ports+=("-p ${port}:${port}/${protocol}")
        done
      done

    elif [[ "$range" =~ ^([0-9]+)$ ]]; then
      local port="${BASH_REMATCH[1]}"

      for protocol in tcp udp; do
        docker_ports+=("-p ${port}:${port}/${protocol}")
      done

    else
      __print_error "Invalid port definition: $range"
      return 1
    fi
  done

  # Join all port mappings into a single string
  echo "${docker_ports[*]}"
}

export -f __parse_ufw_to_docker_ports

export KGSM_PARSER_LOADED=1
