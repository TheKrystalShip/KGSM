#!/usr/bin/env bash

# Disabling SC2086 globally:
# Exit code variables are guaranteed to be numeric and safe for unquoted use.
# shellcheck disable=SC2086

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../lib/bootstrap.sh"

function usage() {
  local UNDERLINE="\e[4m"
  local END="\e[0m"

  echo -e "${UNDERLINE}HTTP Webhook Event Transport for Krystal Game Server Manager${END}

Manages HTTP webhook event delivery for remote system integration and monitoring.

${UNDERLINE}Usage:${END}
  $(basename "$0") [OPTIONS] [COMMAND]

${UNDERLINE}Options:${END}
  -h, --help                  Display this help information

${UNDERLINE}Commands:${END}
  --enable                    Enable HTTP webhook event transport
                              Updates configuration and validates dependencies
  --disable                   Disable HTTP webhook event transport
                              Stops webhook delivery and updates configuration
  --test                      Test webhook functionality by sending a test event
                              Verifies connectivity and endpoint response
  --configure                 Interactive webhook configuration wizard
                              Guides through URL, authentication, and retry settings
  --status                    Show detailed webhook transport status
                              Displays configuration, endpoints, and connectivity

${UNDERLINE}Examples:${END}
  $(basename "$0") --configure
  $(basename "$0") --enable
  $(basename "$0") --test
  $(basename "$0") --status
  $(basename "$0") --disable

${UNDERLINE}Notes:${END}
  • Webhook transport requires 'wget' for HTTP requests
  • Supports primary and secondary webhook URLs for redundancy
  • Includes retry logic with exponential backoff
  • Optional HMAC-SHA256 signature verification
  • --enable: Activates transport and validates dependencies
  • --disable: Deactivates transport
  • --configure: Interactive setup for webhook endpoints
  • --test: Sends a test event to verify functionality
"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage && exit 0
    ;;
  *)
    break
    ;;
  esac
  shift
done

if [[ "$#" -eq 0 ]]; then
  __print_error "Missing arguments"
  exit ${EC_MISSING_ARG:-1}
fi

# Core function: Send webhook event with retry logic
function __webhook_send() {
  local url="$1"
  local payload="$2"
  local retry_count="${3:-0}"
  local is_secondary="${4:-false}"

  # Validate inputs
  if [[ -z "$url" ]]; then
    __print_error "Webhook URL is required"
    return 1
  fi

  if [[ -z "$payload" ]]; then
    __print_error "Webhook payload is required"
    return 1
  fi

  # Check if wget is available
  if ! command -v wget >/dev/null 2>&1; then
    __print_error "wget is required for webhook events but is not installed"
    return 1
  fi

  # Prepare wget options
  local wget_opts=(
    --quiet
    --timeout "${config_webhook_timeout_seconds:-10}"
    --header "Content-Type: application/json"
    --header "User-Agent: KGSM/$(get_version 2>/dev/null || echo 'unknown')"
    --post-data "$payload"
  )

  # Add signature header if webhook secret is configured
  if [[ -n "$config_webhook_secret" ]]; then
    local signature
    if command -v openssl >/dev/null 2>&1; then
      signature=$(echo -n "$payload" | openssl dgst -sha256 -hmac "$config_webhook_secret" -binary | base64)
      wget_opts+=(--header "X-KGSM-Signature: sha256=$signature")
    else
      __print_warning "openssl not available, skipping signature generation"
    fi
  fi

  # Add timestamp and attempt headers
  wget_opts+=(--header "X-KGSM-Timestamp: $(date -u +%s)")
  wget_opts+=(--header "X-KGSM-Retry-Count: $retry_count")

  # Attempt the webhook request
  local webhook_result
  webhook_result=$(wget "${wget_opts[@]}" -O - "$url" 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    # Success - log if not secondary webhook or if in test mode
    if [[ "$is_secondary" != "true" ]] || [[ -n "$WEBHOOK_TEST_MODE" ]]; then
      __print_info "Webhook event sent successfully to $url"
    fi
    return 0
  else
    # Failure - determine if we should retry
    local max_retries="${config_webhook_retry_count:-2}"

    if [[ $retry_count -lt $max_retries ]]; then
      # Exponential backoff: 1s, 2s, 4s, 8s, 16s
      local delay=$((2 ** retry_count))
      __print_warning "Webhook request failed (attempt $((retry_count + 1))/$((max_retries + 1))), retrying in ${delay}s: $webhook_result"
      sleep "$delay"
      __webhook_send "$url" "$payload" $((retry_count + 1)) "$is_secondary"
      return $?
    else
      __print_error "Webhook request failed after $((max_retries + 1)) attempts to $url: $webhook_result"
      return 1
    fi
  fi
}

export -f __webhook_send

# Core function: Send event to webhook (used by lib/events.sh)
function __webhook_emit_event() {
  local payload="$1"

  if [[ -z "$payload" ]]; then
    __print_error "Event payload is required"
    return 1
  fi

  local overall_result=0

  # Send to primary webhook
  if [[ -n "$config_webhook_url" ]]; then
    __webhook_send "$config_webhook_url" "$payload" 0 false &
    local primary_pid=$!

    # Send to secondary webhook if primary fails and secondary is configured
    if [[ -n "$config_webhook_secondary_url" ]]; then
      # Wait for primary webhook to complete
      wait $primary_pid
      if [[ $? -ne 0 ]]; then
        __print_info "Primary webhook failed, trying secondary webhook"
        __webhook_send "$config_webhook_secondary_url" "$payload" 0 true &
        wait
        overall_result=$?
      fi
    else
      wait $primary_pid
      overall_result=$?
    fi
  else
    __print_error "No webhook URL configured"
    return 1
  fi

  return $overall_result
}

export -f __webhook_emit_event

# Enable webhook transport
function _webhook_enable() {
  __print_info "Enabling HTTP webhook event transport..."

  # Check dependencies
  if ! command -v wget >/dev/null 2>&1; then
    __print_error "wget is required but not installed"
    __print_error "Install wget: sudo apt-get install wget (Ubuntu/Debian) or sudo yum install wget (RHEL/CentOS)"
    return $EC_MISSING_DEPENDENCY
  fi

  # Check if webhook URL is configured
  if [[ -z "$config_webhook_url" ]]; then
    __print_warning "No webhook URL configured"
    __print_info "Use --configure to set up webhook endpoints"
    __print_info "Or manually set webhook_url in configuration"
  fi

  # Enable in configuration
  __set_config_value "enable_webhook_events" "true"
  local result=$?
  if [[ $result -eq 0 ]]; then
    __print_success "HTTP webhook event transport enabled"
    if [[ -n "$config_webhook_url" ]]; then
      __print_info "Primary webhook: $config_webhook_url"
      __print_info "Use --test to verify functionality"
    fi
  fi

  return $result
}

# Disable webhook transport
function _webhook_disable() {
  __print_info "Disabling HTTP webhook event transport..."

  # Disable in configuration
  __set_config_value "enable_webhook_events" "false"
  local result=$?
  if [[ $result -eq 0 ]]; then
    __print_success "HTTP webhook event transport disabled"
  fi

  return $result
}

# Interactive webhook configuration
function _webhook_configure() {
  echo "Webhook Configuration Wizard"
  echo "============================"
  echo ""

  # Primary webhook URL
  echo "Primary Webhook URL:"
  echo "Enter the HTTP/HTTPS endpoint that will receive KGSM events"
  echo "Example: https://your-server.com/webhook"
  echo ""
  read -p "Primary webhook URL: " primary_url

  if [[ -n "$primary_url" ]]; then
    __set_config_value "webhook_url" "$primary_url" || return $?
    echo ""
  fi

  # Secondary webhook URL
  echo "Secondary Webhook URL (optional):"
  echo "Enter a backup endpoint for redundancy (leave empty to skip)"
  echo ""
  read -p "Secondary webhook URL: " secondary_url

  if [[ -n "$secondary_url" ]]; then
    __set_config_value "webhook_secondary_url" "$secondary_url" || return $?
  fi
  echo ""

  # Timeout configuration
  echo "Request Timeout:"
  echo "How long should KGSM wait for webhook responses? (1-300 seconds)"
  echo "Current: ${config_webhook_timeout_seconds:-10} seconds"
  echo ""
  read -p "Timeout in seconds [${config_webhook_timeout_seconds:-10}]: " timeout

  if [[ -n "$timeout" ]]; then
    __set_config_value "webhook_timeout_seconds" "$timeout" || return $?
  fi
  echo ""

  # Retry configuration
  echo "Retry Count:"
  echo "How many times should failed requests be retried? (0-5)"
  echo "Current: ${config_webhook_retry_count:-2}"
  echo ""
  read -p "Retry count [${config_webhook_retry_count:-2}]: " retries

  if [[ -n "$retries" ]]; then
    __set_config_value "webhook_retry_count" "$retries" || return $?
  fi
  echo ""

  # Secret configuration
  echo "Authentication Secret (optional):"
  echo "Enter a secret key for HMAC-SHA256 signature verification"
  echo "Leave empty to disable authentication"
  echo ""
  read -s -p "Webhook secret: " secret
  echo ""

  if [[ -n "$secret" ]]; then
    __set_config_value "webhook_secret" "$secret" || return $?
    __print_success "Authentication enabled with HMAC-SHA256 signatures"
  else
    __set_config_value "webhook_secret" "" || return $?
    __print_info "Authentication disabled"
  fi
  echo ""

  __print_success "Webhook configuration completed!"
  __print_info "Use --enable to activate webhook transport"
  __print_info "Use --test to verify your configuration"
}

# Test webhook functionality
function _webhook_test() {
  export WEBHOOK_TEST_MODE=1
  __print_info "Testing HTTP webhook event transport..."

  # Check if enabled
  if [[ "$config_enable_webhook_events" != "true" ]]; then
    __print_error "Webhook transport is not enabled"
    __print_error "Use --enable to activate webhook transport first"
    return 1
  fi

  # Check if URL is configured
  if [[ -z "$config_webhook_url" ]]; then
    __print_error "No webhook URL configured"
    __print_error "Use --configure to set up webhook endpoints"
    return 1
  fi

  # Check dependencies
  if ! command -v wget >/dev/null 2>&1; then
    __print_error "wget is required but not installed"
    return $EC_MISSING_DEPENDENCY
  fi

  __print_info "Primary webhook URL: $config_webhook_url"
  if [[ -n "$config_webhook_secondary_url" ]]; then
    __print_info "Secondary webhook URL: $config_webhook_secondary_url"
  fi

  # Create test event payload
  local test_payload
  test_payload=$(
    jq -n \
      --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg hostname "$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "${HOSTNAME:-localhost}")" \
      --arg kgsm_version "$(get_version 2>/dev/null || echo 'unknown')" \
      '{
        EventType: "webhook_test",
        Data: {
          InstanceName: "test-instance",
          Message: "This is a test webhook event from KGSM"
        },
        Timestamp: $timestamp,
        Hostname: $hostname,
        KGSMVersion: $kgsm_version
      }'
  )

  # Send test webhook
  __webhook_send "$config_webhook_url" "$test_payload" 0 false
  local result=$?

  if [[ $result -eq 0 ]]; then
    __print_success "Webhook test completed successfully!"

    # Test secondary webhook if configured
    if [[ -n "$config_webhook_secondary_url" ]]; then
      __print_info "Testing secondary webhook..."
      __webhook_send "$config_webhook_secondary_url" "$test_payload" 0 true
      local secondary_result=$?
      if [[ $secondary_result -eq 0 ]]; then
        __print_success "Secondary webhook test completed successfully!"
      else
        __print_warning "Secondary webhook test failed, but primary succeeded"
      fi
    fi

    return 0
  else
    __print_error "Webhook test failed. Check your webhook URL and network connectivity."
    return 1
  fi
}

# Show webhook status
function _webhook_status() {
  local BOLD="\e[1m"
  local END="\e[0m"
  local GREEN="\e[32m"
  local RED="\e[31m"
  local YELLOW="\e[33m"

  echo -e "${BOLD}HTTP Webhook Transport Status${END}"
  echo "================================="
  echo ""

  # Configuration status
  echo -e "${BOLD}Configuration:${END}"
  if [[ "$config_enable_webhook_events" == "true" ]]; then
    echo -e "  Status: ${GREEN}Enabled${END}"
  else
    echo -e "  Status: ${RED}Disabled${END}"
  fi

  if [[ -n "$config_webhook_url" ]]; then
    echo "  Primary URL: $config_webhook_url"
  else
    echo -e "  Primary URL: ${RED}Not configured${END}"
  fi

  if [[ -n "$config_webhook_secondary_url" ]]; then
    echo "  Secondary URL: $config_webhook_secondary_url"
  else
    echo "  Secondary URL: Not configured"
  fi

  echo "  Timeout: ${config_webhook_timeout_seconds:-10} seconds"
  echo "  Retry count: ${config_webhook_retry_count:-2}"

  if [[ -n "$config_webhook_secret" ]]; then
    echo -e "  Authentication: ${GREEN}HMAC-SHA256 enabled${END}"
  else
    echo -e "  Authentication: ${YELLOW}Disabled${END}"
  fi
  echo ""

  # Dependencies
  echo -e "${BOLD}Dependencies:${END}"
  if command -v wget >/dev/null 2>&1; then
    echo -e "  wget: ${GREEN}Available${END} ($(wget --version 2>/dev/null | head -1 || echo 'version unknown'))"
  else
    echo -e "  wget: ${RED}Missing${END}"
    echo "    Install with: sudo apt-get install wget (Ubuntu/Debian)"
    echo "                 sudo yum install wget (RHEL/CentOS)"
  fi

  if [[ -n "$config_webhook_secret" ]]; then
    if command -v openssl >/dev/null 2>&1; then
      echo -e "  openssl: ${GREEN}Available${END} (for signature generation)"
    else
      echo -e "  openssl: ${YELLOW}Missing${END} (signatures will be skipped)"
    fi
  fi
  echo ""

  # Connectivity status
  echo -e "${BOLD}Connectivity:${END}"
  if [[ -n "$config_webhook_url" ]] && command -v wget >/dev/null 2>&1; then
    echo "  Testing primary webhook connectivity..."
    if wget --quiet --timeout 5 --spider "$config_webhook_url" >/dev/null 2>&1; then
      echo -e "  Primary endpoint: ${GREEN}Reachable${END}"
    else
      echo -e "  Primary endpoint: ${YELLOW}Unreachable or non-responsive${END}"
    fi

    if [[ -n "$config_webhook_secondary_url" ]]; then
      echo "  Testing secondary webhook connectivity..."
      if wget --quiet --timeout 5 --spider "$config_webhook_secondary_url" >/dev/null 2>&1; then
        echo -e "  Secondary endpoint: ${GREEN}Reachable${END}"
      else
        echo -e "  Secondary endpoint: ${YELLOW}Unreachable or non-responsive${END}"
      fi
    fi
  else
    echo "  Cannot test connectivity (missing URL or wget)"
  fi
}

# Handle --emit command (called by lib/events.sh)
function _webhook_emit() {
  local payload="$1"
  __webhook_emit_event "$payload"
  return $?
}

# Main argument processing
while [[ $# -gt 0 ]]; do
  case "$1" in
  --enable)
    _webhook_enable
    exit $?
    ;;
  --disable)
    _webhook_disable
    exit $?
    ;;
  --configure)
    _webhook_configure
    exit $?
    ;;
  --test)
    _webhook_test
    exit $?
    ;;
  --status)
    _webhook_status
    exit $?
    ;;
  --emit)
    shift
    if [[ -z "$1" ]]; then
      __print_error "Missing event payload for --emit"
      exit $EC_MISSING_ARG
    fi
    _webhook_emit "$1"
    exit $?
    ;;
  *)
    __print_error "Invalid argument $1"
    exit $EC_INVALID_ARG
    ;;
  esac
  shift
done

exit $?
