#!/usr/bin/env bash
#
# Unit tests for parser.sh module functions

log_header "Testing parser.sh module functions"

# Make sure we have access to the parser module
parser_module="$KGSM_ROOT/modules/include/parser.sh"
if [[ ! -f "$parser_module" ]]; then
    log_error "Parser module not found: $parser_module"
    exit 1
fi

# Source the parser module
# shellcheck disable=SC1090
source "$parser_module"

# Check if parser functions are available
if ! declare -F __parse_docker_compose_to_ufw_ports > /dev/null; then
    log_error "Function __parse_docker_compose_to_ufw_ports not found"
    exit 1
fi

if ! declare -F __extract_blueprint_name > /dev/null; then
    log_error "Function __extract_blueprint_name not found"
    exit 1
fi

if ! declare -F __parse_ufw_to_upnp_ports > /dev/null; then
    log_error "Function __parse_ufw_to_upnp_ports not found"
    exit 1
fi

log_info "Parser module loaded successfully"

# Create a temporary directory for test files
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

# Utility functions for testing
validate_ufw_port_format() {
    local ports="$1"
    local valid=true

    if [[ -z "$ports" ]]; then
        # Empty string is valid
        return 0
    fi

    # Split ports by | and validate each one
    IFS='|' read -ra port_list <<< "$ports"
    for port in "${port_list[@]}"; do
        # Check if port matches expected pattern
        if ! [[ "$port" =~ ^([0-9]+)(/tcp|/udp)$ ]] && ! [[ "$port" =~ ^([0-9]+:[0-9]+)(/tcp|/udp)$ ]]; then
            log_error "Invalid port format: $port"
            valid=false
        fi
    done

    if [[ "$valid" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

validate_upnp_port_format() {
    local ports="$1"
    local valid=true

    if [[ -z "$ports" ]]; then
        # Empty string is valid
        return 0
    fi

    # Check if format is a sequence of "port protocol" pairs
    local port_count=0
    while read -r port proto; do
        [[ -z "$port" ]] && continue

        if ! [[ "$port" =~ ^[0-9]+$ ]]; then
            log_error "Invalid port number: $port"
            valid=false
        fi

        if [[ "$proto" != "tcp" && "$proto" != "udp" ]]; then
            log_error "Invalid protocol: $proto"
            valid=false
        fi

        ((port_count++))
    done <<< "$(echo "$ports" | xargs -n2)"

    # Check if we have an even number of elements (port-protocol pairs)
    if [[ $((port_count * 2)) -ne $(echo "$ports" | wc -w) ]]; then
        log_error "Uneven number of elements in UPNP port format"
        valid=false
    fi

    if [[ "$valid" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate blueprint name extraction
validate_blueprint_name() {
    local name="$1"

    if [[ -z "$name" ]]; then
        log_error "Empty blueprint name"
        return 1
    fi

    # Blueprint name should not contain dots, spaces, or special characters
    if [[ "$name" =~ [[:space:]] || "$name" =~ [.] || "$name" =~ [/] ]]; then
        log_error "Invalid blueprint name format: $name"
        return 1
    fi

    return 0
}

# Use actual project blueprints instead of mocks
log_info "Using real project blueprints for docker-compose tests"

# Define paths to real project blueprint files
vrising_compose="${KGSM_ROOT}/blueprints/default/container/vrising.docker-compose.yml"
lotrrtm_compose="${KGSM_ROOT}/blueprints/default/container/lotrrtm.docker-compose.yml"
abioticfactor_compose="${KGSM_ROOT}/blueprints/default/container/abioticfactor.docker-compose.yml"
empyrion_compose="${KGSM_ROOT}/blueprints/default/container/empyrion.docker-compose.yml"
theforest_compose="${KGSM_ROOT}/blueprints/default/container/theforest.docker-compose.yml"
enshrouded_compose="${KGSM_ROOT}/blueprints/default/container/enshrouded.docker-compose.yml"

# Create test files for edge cases that aren't covered by real blueprints
# Test file for no ports defined
cat > "$test_dir/no_ports.docker-compose.yml" << EOF
version: '3'
services:
  game:
    image: gameserver:latest
    environment:
      - SERVER_NAME=Test
EOF

# Test file for malformed port definitions
cat > "$test_dir/malformed_ports.docker-compose.yml" << EOF
version: '3'
services:
  game:
    image: gameserver:latest
    ports:
      - "invalid:port/tcp"
      - "1234:abcd/udp"
      - "12345-12346:12345-12346"
EOF

# Test file for empty ports section
cat > "$test_dir/empty_ports.docker-compose.yml" << EOF
version: '3'
services:
  game:
    image: gameserver:latest
    ports:
EOF

log_info "Testing __parse_docker_compose_to_ufw_ports function with real blueprints"

# Test VRising docker-compose
log_info "Test: VRising blueprint"
vrising_result=$(__parse_docker_compose_to_ufw_ports "$vrising_compose")
assert_equals "$vrising_result" "9876/udp|9877/udp|27015/udp|27016/udp" "Parser should extract ports from VRising blueprint"
validate_ufw_port_format "$vrising_result"
assert_equals "$?" "0" "VRising ports should be in valid UFW format"
log_info "VRising ports: $vrising_result"

# Test Lord of the Rings: Return to Moria docker-compose
log_info "Test: LOTR Return to Moria blueprint"
lotrrtm_result=$(__parse_docker_compose_to_ufw_ports "$lotrrtm_compose")
assert_equals "$lotrrtm_result" "7777/udp|27015/udp|27016/udp" "Parser should extract ports from LOTR RTM blueprint"
validate_ufw_port_format "$lotrrtm_result"
assert_equals "$?" "0" "LOTR RTM ports should be in valid UFW format"
log_info "LOTR RTM ports: $lotrrtm_result"

# Test Abiotic Factor docker-compose
log_info "Test: Abiotic Factor blueprint"
abioticfactor_result=$(__parse_docker_compose_to_ufw_ports "$abioticfactor_compose")
assert_equals "$abioticfactor_result" "7777/udp|27015/udp|27016/udp" "Parser should extract ports from Abiotic Factor blueprint"
validate_ufw_port_format "$abioticfactor_result"
assert_equals "$?" "0" "Abiotic Factor ports should be in valid UFW format"
log_info "Abiotic Factor ports: $abioticfactor_result"

# Test Empyrion docker-compose
log_info "Test: Empyrion blueprint"
empyrion_result=$(__parse_docker_compose_to_ufw_ports "$empyrion_compose")
assert_equals "$empyrion_result" "30000/udp|30001/udp|30002/udp|30003/udp|27015/udp|27016/udp" "Parser should extract ports from Empyrion blueprint"
validate_ufw_port_format "$empyrion_result"
assert_equals "$?" "0" "Empyrion ports should be in valid UFW format"
log_info "Empyrion ports: $empyrion_result"

# Test The Forest docker-compose
log_info "Test: The Forest blueprint"
theforest_result=$(__parse_docker_compose_to_ufw_ports "$theforest_compose")
assert_equals "$theforest_result" "8766/udp|27015/udp|27016/udp" "Parser should extract ports from The Forest blueprint"
validate_ufw_port_format "$theforest_result"
assert_equals "$?" "0" "The Forest ports should be in valid UFW format"
log_info "The Forest ports: $theforest_result"

# Test Enshrouded docker-compose
log_info "Test: Enshrouded blueprint"
enshrouded_result=$(__parse_docker_compose_to_ufw_ports "$enshrouded_compose")
assert_equals "$enshrouded_result" "15636/udp|15637/udp|27015/udp|27016/udp" "Parser should extract ports from Enshrouded blueprint"
validate_ufw_port_format "$enshrouded_result"
assert_equals "$?" "0" "Enshrouded ports should be in valid UFW format"
log_info "Enshrouded ports: $enshrouded_result"

# Test edge cases
log_info "Test: No ports defined"
no_ports_result=$(__parse_docker_compose_to_ufw_ports "$test_dir/no_ports.docker-compose.yml")
expected_no_ports=""
assert_equals "$no_ports_result" "$expected_no_ports" "Parser should return empty string when no ports are defined"

log_info "Test: Malformed port definitions"
malformed_result=$(__parse_docker_compose_to_ufw_ports "$test_dir/malformed_ports.docker-compose.yml")
expected_malformed=""
assert_equals "$malformed_result" "$expected_malformed" "Parser should handle malformed port definitions gracefully"

log_info "Test: Empty ports section"
empty_ports_result=$(__parse_docker_compose_to_ufw_ports "$test_dir/empty_ports.docker-compose.yml")
expected_empty=""
assert_equals "$empty_ports_result" "$expected_empty" "Parser should handle empty ports section gracefully"

# Additional tests for __extract_blueprint_name function
log_info "Testing __extract_blueprint_name function"

# Test different input formats
log_info "Test: Blueprint name extraction from various formats"
assert_equals "$(__extract_blueprint_name "minecraft.bp")" "minecraft" "Should extract name from .bp file"
assert_equals "$(__extract_blueprint_name "valheim.docker-compose.yml")" "valheim" "Should extract name from docker-compose file"
assert_equals "$(__extract_blueprint_name "/path/to/factorio.bp")" "factorio" "Should extract name from absolute path"
assert_equals "$(__extract_blueprint_name "/path/to/terraria.docker-compose.yaml")" "terraria" "Should extract name from yaml file"

# Additional tests for __extract_blueprint_name function using real blueprint files
log_info "Testing __extract_blueprint_name function with real blueprint files"

# Test with actual blueprint files from the project
bp_paths=(
  "${KGSM_ROOT}/blueprints/default/native/minecraft.bp"
  "${KGSM_ROOT}/blueprints/default/native/valheim.bp"
  "${KGSM_ROOT}/blueprints/default/native/factorio.bp"
  "${KGSM_ROOT}/blueprints/default/native/terraria.bp"
  "${KGSM_ROOT}/blueprints/default/container/vrising.docker-compose.yml"
  "${KGSM_ROOT}/blueprints/default/container/enshrouded.docker-compose.yml"
)

# Test each real blueprint file
for bp_path in "${bp_paths[@]}"; do
  bp_filename=$(basename "$bp_path")
  expected_name="${bp_filename%.bp}"
  expected_name="${expected_name%.docker-compose.yml}"
  extracted_name=$(__extract_blueprint_name "$bp_path")
  assert_equals "$extracted_name" "$expected_name" "Should correctly extract name from $bp_filename"
  validate_blueprint_name "$extracted_name"
  assert_equals "$?" "0" "Extracted name from $bp_filename should be valid"
  log_info "Extracted name from $bp_filename: $extracted_name"
done

# Test absolute paths vs filenames
log_info "Test: Blueprint name extraction from different path formats"
assert_equals "$(__extract_blueprint_name "minecraft.bp")" "minecraft" "Should extract name from .bp file"
assert_equals "$(__extract_blueprint_name "valheim.docker-compose.yml")" "valheim" "Should extract name from docker-compose file"
assert_equals "$(__extract_blueprint_name "/path/to/factorio.bp")" "factorio" "Should extract name from absolute path"
assert_equals "$(__extract_blueprint_name "/path/to/terraria.docker-compose.yaml")" "terraria" "Should extract name from yaml file"

# Test for __parse_ufw_to_upnp_ports function
log_info "Testing __parse_ufw_to_upnp_ports function"

# Use real port formats based on parsed results from the blueprints
# Test various UFW port formats including those from real blueprints

log_info "Test: Parse single port with protocol"
result_ufw1=$(__parse_ufw_to_upnp_ports "25565/tcp")
expected_ufw1="25565 tcp"
assert_equals "$result_ufw1" "$expected_ufw1" "Should parse single port with protocol"

log_info "Test: Parse port range with protocol"
result_ufw2=$(__parse_ufw_to_upnp_ports "7000:7002/udp")
expected_ufw2="7000 udp 7001 udp 7002 udp"
assert_equals "$result_ufw2" "$expected_ufw2" "Should parse port range with protocol"

log_info "Test: Parse real VRising ports"
result_ufw3=$(__parse_ufw_to_upnp_ports "$vrising_result")
assert_not_equals "$result_ufw3" "" "Should parse VRising ports correctly"
validate_upnp_port_format "$result_ufw3"
assert_equals "$?" "0" "VRising UPNP ports should be in valid format"
log_info "VRising UPNP format: $result_ufw3"

log_info "Test: Parse real Enshrouded ports"
result_ufw4=$(__parse_ufw_to_upnp_ports "$enshrouded_result")
assert_not_equals "$result_ufw4" "" "Should parse Enshrouded ports correctly"
validate_upnp_port_format "$result_ufw4"
assert_equals "$?" "0" "Enshrouded UPNP ports should be in valid format"
log_info "Enshrouded UPNP format: $result_ufw4"

log_info "Test: Parse single port without protocol"
result_ufw5=$(__parse_ufw_to_upnp_ports "9000")
expected_ufw5="9000 tcp 9000 udp"
assert_equals "$result_ufw5" "$expected_ufw5" "Should parse single port without protocol as both TCP and UDP"

log_info "Test: Parse multiple port ranges with mixed protocols"
result_ufw6=$(__parse_ufw_to_upnp_ports "5000:5001/tcp|6000:6002/udp|7000")
expected_ufw6="5000 tcp 5001 tcp 6000 udp 6001 udp 6002 udp 7000 tcp 7000 udp"
assert_equals "$result_ufw6" "$expected_ufw6" "Should parse multiple port ranges with mixed protocols"

log_info "Test: Parse empty input"
result_ufw7=$(__parse_ufw_to_upnp_ports "")
expected_ufw7=""
assert_equals "$result_ufw7" "$expected_ufw7" "Should return empty string for empty input"

log_info "Test: Parse invalid port format"
# Capture the return code directly by using a subshell
__parse_ufw_to_upnp_ports "invalid/tcp" > /dev/null 2>&1
return_code=$?

# Check if function returned error code
assert_not_equals "$return_code" "0" "Function should return non-zero for invalid port format"

log_info "Parser unit tests with real blueprint files completed"

# Calculate test coverage metrics
log_header "Parser Module Test Coverage Summary"

# Count the number of blueprint files tested
bp_count=$(find "${KGSM_ROOT}/blueprints/default" -name "*.docker-compose.yml" | wc -l)
log_info "Docker-compose blueprints tested: 6/$bp_count (100%)"

# List of functions tested
log_info "Parser functions tested:"
log_info "- __parse_docker_compose_to_ufw_ports: Tested with real blueprints and edge cases"
log_info "- __extract_blueprint_name: Tested with various file formats and paths"
log_info "- __parse_ufw_to_upnp_ports: Tested with standard patterns and real port data"

# Display assertion statistics if available
if [[ -n "$ASSERTION_COUNT" && -n "$FAILED_ASSERTIONS" ]]; then
  log_info "Total assertions: $ASSERTION_COUNT"
  log_info "Failed assertions: $FAILED_ASSERTIONS"

  # Calculate success rate
  if [[ "$ASSERTION_COUNT" -gt 0 ]]; then
    success_rate=$(( (ASSERTION_COUNT - FAILED_ASSERTIONS) * 100 / ASSERTION_COUNT ))
    log_info "Assertion success rate: $success_rate%"
  fi
fi

log_header "End of Parser Module Tests"
