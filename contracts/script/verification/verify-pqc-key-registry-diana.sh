#!/usr/bin/env bash
# SPDX-License-Identifier: MIT OR Apache-2.0

set -euo pipefail

ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd
)"

readonly ROOT

cd "$ROOT"

readonly RPC_URL="${DIANA_RPC_URL:-https://evm-testnet.qore.host}"

readonly EXPECTED_CHAIN_ID="0x2648"

# Recorded historical state containing all three account states.
readonly BLOCK="0xa5e5bf"

readonly EXPECTED_BLOCK_HASH="0x1722f7ed570d590b3108008e46ab5119b3b6270ae8d80fe6f80110e2105e6ea3"

readonly EXPECTED_STATE_ROOT="0x8196e715d095226ce910bda5a61d51305ce08a9162ae54cb8efa5dfbecf575ad"

readonly CALL_GAS="0x1e8480"

readonly PROBE="test/helpers/cryptography/qorechain/QorePqcKeyRegistryCreationProbe.sol:QorePqcKeyRegistryCreationProbe"

readonly UNREGISTERED_ACCOUNT="0x0000000000000000000000000000000000000001"

readonly LEGACY_ACCOUNT="0xf1e70c24817e00aee286f7275e14e61cabd20741"

readonly PROVEN_ACCOUNT="0x7d51dec64804539adf46fbee8b1521e1635f89da"

readonly LEGACY_KEY_HASH="0x3001c5b59aa504556a47fdc75e2cd1398d812a6b32e7009bae6288dad64fcb31"

readonly PROVEN_KEY_HASH="0x243392722119701229ababb6695e145ed85fcc638722f92bf568a0022a84aed1"

printf -v ZERO_HASH '0x%064x' 0
readonly ZERO_HASH

PASSED=0

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$#" -eq 0 ]] ||
    die "Usage: $0"

for tool in curl jq cast forge; do
    command -v "$tool" >/dev/null ||
        die "Missing dependency: $tool"
done

# =============================================================================
# Read-only JSON-RPC
# =============================================================================

rpc() {
    local method="$1"
    local params="$2"
    local payload

    case "$method" in
        eth_chainId|eth_getBlockByNumber|eth_call)
            ;;
        *)
            die "Unsupported RPC method: $method"
            ;;
    esac

    payload="$(
        jq -cn \
            --arg method "$method" \
            --argjson params "$params" \
            '{
                jsonrpc: "2.0",
                id: 1,
                method: $method,
                params: $params
            }'
    )"

    curl \
        --fail \
        --silent \
        --show-error \
        --connect-timeout 10 \
        --max-time 60 \
        --url "$RPC_URL" \
        -H 'Content-Type: application/json' \
        --data-binary "$payload" |
        jq -ce '
            if .jsonrpc != "2.0" or .id != 1 then
                error("Unexpected JSON-RPC envelope")
            elif .error != null then
                error(.error | tostring)
            elif has("result") and .result != null then
                .result
            else
                error("Missing JSON-RPC result")
            end
        '
}

get_block_metadata() {
    local params

    params="$(
        jq -cn --arg block "$BLOCK" '[$block, false]'
    )"

    rpc eth_getBlockByNumber "$params" |
        jq -ce '
            {number, hash, timestamp, stateRoot}
            | select(
                (.number | type) == "string"
                and (.hash | type) == "string"
                and (.timestamp | type) == "string"
                and (.stateRoot | type) == "string"
            )
            | select(
                (.number | test("^0x(0|[1-9a-f][0-9a-f]*)$"))
                and (.timestamp | test("^0x(0|[1-9a-f][0-9a-f]*)$"))
                and (.hash | test("^0x[0-9a-fA-F]{64}$"))
                and (.stateRoot | test("^0x[0-9a-fA-F]{64}$"))
            )
        '
}

# =============================================================================
# Network and historical block validation
# =============================================================================

CHAIN_ID="$(rpc eth_chainId '[]' | jq -er '.')"

[[ "$CHAIN_ID" == "$EXPECTED_CHAIN_ID" ]] ||
    die "Unexpected chain identity."

INITIAL_BLOCK_METADATA="$(get_block_metadata)"

ACTUAL_BLOCK="$(jq -er '.number' <<< "$INITIAL_BLOCK_METADATA")"

ACTUAL_BLOCK_HASH="$(jq -er '.hash' <<< "$INITIAL_BLOCK_METADATA")"

ACTUAL_STATE_ROOT="$(jq -er '.stateRoot' <<< "$INITIAL_BLOCK_METADATA")"

[[ "$ACTUAL_BLOCK" == "$BLOCK" ]] ||
    die "Unexpected historical block number."

[[ "${ACTUAL_BLOCK_HASH,,}" == "$EXPECTED_BLOCK_HASH" ]] ||
    die "Unexpected historical block hash."

[[ "${ACTUAL_STATE_ROOT,,}" == "$EXPECTED_STATE_ROOT" ]] ||
    die "Unexpected historical state root."

printf '\n=== Diana registered-key verification ===\n'

printf 'Chain ID: %s\n' "$CHAIN_ID"
printf 'Block: %s\n' "$(cast to-dec "$BLOCK")"

jq . <<< "$INITIAL_BLOCK_METADATA"

# =============================================================================
# Compile deployless creation probe
# =============================================================================

CREATION_BYTECODE="$(forge inspect "$PROBE" bytecode)"

[[ "$CREATION_BYTECODE" =~ ^0x([0-9a-fA-F]{2})+$ ]] ||
    die "Invalid compiled creation bytecode."

printf '\nCreation probe bytecode Keccak-256:\n'

cast keccak "$CREATION_BYTECODE"

printf '\nExecution: deployless creation eth_call\n'
printf 'State overrides: none\n'

# =============================================================================
# Verification helpers
# =============================================================================

query_status() {
    local authority="$1"
    local constructor_args
    local calldata
    local params

    [[ "$authority" =~ ^0x[0-9a-fA-F]{40}$ ]] ||
        die "Invalid authority address."

    constructor_args="$(
        cast abi-encode \
            'probe(address)' \
            "$authority"
    )"

    [[ "$constructor_args" =~ ^0x[0-9a-fA-F]{64}$ ]] ||
        die "Invalid constructor argument encoding."

    calldata="${CREATION_BYTECODE}${constructor_args:2}"

    params="$(
        jq -cn \
            --arg data "$calldata" \
            --arg gas "$CALL_GAS" \
            --arg block "$BLOCK" \
            '[{data: $data, gas: $gas}, $block]'
    )"

    jq -e '
        length == 2
        and (.[0] | type == "object")
        and (.[0] | keys == ["data", "gas"])
        and (.[0].data | test("^0x([0-9a-fA-F]{2})+$"))
        and (.[1] | type == "string")
    ' <<< "$params" >/dev/null ||
        die "Invalid deployless eth_call request shape."

    rpc eth_call "$params" |
        jq -er '
            select(type == "string")
            | select(test("^0x[0-9a-fA-F]{320}$"))
        '
}

assert_status() {
    local label="$1"
    local authority="$2"
    local registered="$3"
    local algorithm="$4"
    local key_length="$5"
    local key_hash="$6"
    local possession="$7"

    local expected
    local actual

    expected="$(
        cast abi-encode \
            'summary(bool,uint8,uint256,bytes32,bool)' \
            "$registered" \
            "$algorithm" \
            "$key_length" \
            "$key_hash" \
            "$possession"
    )"

    if ! actual="$(query_status "$authority")"; then
        die "Registered-key query failed: $label"
    fi

    if [[ "${actual,,}" != "${expected,,}" ]]; then
        printf '[FAIL] %s\n' "$label" >&2
        printf 'Expected: %s\n' "$expected" >&2
        printf 'Actual:   %s\n' "$actual" >&2
        exit 1
    fi

    PASSED=$((PASSED + 1))

    printf '\n[PASS] %s\n' "$label"

    printf '  Authority: %s\n' "$authority"
    printf '  Registered: %s\n' "$registered"
    printf '  Algorithm: %s\n' "$algorithm"
    printf '  Public key bytes: %s\n' "$key_length"
    printf '  Public key commitment: %s\n' "$key_hash"
    printf '  Possession proven: %s\n' "$possession"
}

# =============================================================================
# Real historical registered-key states
# =============================================================================

assert_status \
    "Unregistered account" \
    "$UNREGISTERED_ACCOUNT" \
    false \
    0 \
    0 \
    "$ZERO_HASH" \
    false

assert_status \
    "Legacy registration without proven possession" \
    "$LEGACY_ACCOUNT" \
    true \
    1 \
    2592 \
    "$LEGACY_KEY_HASH" \
    false

assert_status \
    "Registration with proven possession" \
    "$PROVEN_ACCOUNT" \
    true \
    1 \
    2592 \
    "$PROVEN_KEY_HASH" \
    true

# =============================================================================
# Evidence consistency
# =============================================================================

FINAL_BLOCK_METADATA="$(get_block_metadata)"

[[ "$FINAL_BLOCK_METADATA" == "$INITIAL_BLOCK_METADATA" ]] ||
    die "Historical block metadata changed during verification."

FINAL_CHAIN_ID="$(rpc eth_chainId '[]' | jq -er '.')"

[[ "$FINAL_CHAIN_ID" == "$CHAIN_ID" ]] ||
    die "RPC chain identity changed during verification."

[[ "$PASSED" -eq 3 ]] ||
    die "Unexpected completed verification case count."

printf '\n=== FINAL VERIFICATION SUMMARY ===\n'

printf 'Registered-key states verified: %s/3\n' "$PASSED"
printf 'Failed: 0\n'
printf 'Historical block: %s\n' "$(cast to-dec "$BLOCK")"
printf 'Historical block hash: %s\n' "$EXPECTED_BLOCK_HASH"
printf 'Canonical status decoding: PASS\n'
printf 'Recorded public key commitments: PASS\n'
printf 'State overrides: none\n'
printf 'Wallet signatures requested: 0\n'
printf 'Transactions broadcast: 0\n'
printf 'Contracts deployed on-chain: 0\n'
