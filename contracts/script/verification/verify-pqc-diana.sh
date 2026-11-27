#!/usr/bin/env bash
# SPDX-License-Identifier: MIT OR Apache-2.0

set -euo pipefail

ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd
)"

readonly ROOT

cd "$ROOT"

readonly MODE="${1:-native}"
readonly RPC_URL="${DIANA_RPC_URL:-https://evm-testnet.qore.host}"
readonly FIXTURE="test/fixtures/cryptography/qoresign/v1.json"

readonly EXPECTED_CHAIN_ID="0x2648"
readonly PQC_PRECOMPILE="0x0000000000000000000000000000000000000a01"

readonly EXPECTED_FIXTURE_HASH="b72bc9620f39c78790cada49f4b237f2b8e960bcb54a3d276fd73684cd5fd110"

readonly PROBE="test/helpers/cryptography/qorechain/QorePqcVerifierCreationProbe.sol:QorePqcVerifierCreationProbe"

# Explicit simulation gas budget, not an estimate of actual consumption.
readonly CALL_GAS="0x1e8480"

PASSED=0

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$#" -le 1 ]] ||
    die "Usage: $0 [native|adapter]"

case "$MODE" in
    native|adapter) ;;
    *) die "Usage: $0 [native|adapter]" ;;
esac

for tool in curl jq cast sha256sum; do
    command -v "$tool" >/dev/null ||
        die "Missing dependency: $tool"
done

[[ -f "$FIXTURE" ]] ||
    die "Missing fixture. Run the QoreSign vector importer first."

# =============================================================================
# Fixture validation
# =============================================================================

FIXTURE_HASH="$(sha256sum "$FIXTURE")"
FIXTURE_HASH="${FIXTURE_HASH%% *}"

[[ "$FIXTURE_HASH" == "$EXPECTED_FIXTURE_HASH" ]] ||
    die "Unexpected fixture SHA-256: $FIXTURE_HASH"

jq -e '
    .source.repository == "qorechain/qoresign"
    and .source.version == "v0.2.0"
    and .source.gitBlob == "1c8111d4b135a5997e99d655c3f0b25267a90e9f"
    and .algorithm == "ML-DSA-87"
    and .algorithmId == 1
    and (.publicKey | test("^0x[0-9a-f]{5184}$"))
    and (.otherPublicKey | test("^0x[0-9a-f]{5184}$"))
    and (.publicKey != .otherPublicKey)
    and (.cases | length == 2)
    and (.cases[0].message | test("^0x[0-9a-f]{130}$"))
    and (.cases[1].message | test("^0x[0-9a-f]{76}$"))
    and (.cases[0].message != .cases[1].message)
    and (.cases[0].signature != .cases[1].signature)
    and all(.cases[];
        (.signature | test("^0x[0-9a-f]{9254}$"))
    )
' "$FIXTURE" >/dev/null ||
    die "Invalid verification fixture."

# =============================================================================
# Read-only JSON-RPC
# =============================================================================

rpc() {
    local method="$1"
    local params="$2"
    local payload

    case "$method" in
        eth_chainId|eth_blockNumber|eth_getBlockByNumber|eth_call)
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
        "$RPC_URL" \
        -H 'Content-Type: application/json' \
        --data-binary "$payload" |
        jq -ce '
            if .error != null then
                error(.error | tostring)
            elif .id != 1 or .jsonrpc != "2.0" then
                error("Unexpected JSON-RPC response")
            elif has("result") and .result != null then
                .result
            else
                error("Missing JSON-RPC result")
            end
        '
}

# =============================================================================
# Network and block validation
# =============================================================================

CHAIN_ID="$(rpc eth_chainId '[]' | jq -er '.')"

[[ "$CHAIN_ID" == "$EXPECTED_CHAIN_ID" ]] ||
    die "Unexpected chain ID: $CHAIN_ID. Diana testnet required."

if [[ -n "${DIANA_BLOCK:-}" ]]; then
    [[ "$DIANA_BLOCK" =~ ^(0|[1-9][0-9]*)$ ]] ||
        die "DIANA_BLOCK must be a canonical decimal block number."

    BLOCK_HEX="$(cast to-hex "$DIANA_BLOCK")"
else
    BLOCK_HEX="$(rpc eth_blockNumber '[]' | jq -er '.')"
fi

[[ "$BLOCK_HEX" =~ ^0x(0|[1-9a-f][0-9a-f]*)$ ]] ||
    die "Invalid block number: $BLOCK_HEX"

BLOCK_PARAMS="$(
    jq -cn --arg block "$BLOCK_HEX" '[$block, false]'
)"

get_block_metadata() {
    rpc eth_getBlockByNumber "$BLOCK_PARAMS" |
        jq -ce '
            {
                number,
                hash,
                timestamp,
                stateRoot
            }
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

BLOCK_METADATA="$(get_block_metadata)"

[[ "$(jq -er '.number' <<< "$BLOCK_METADATA")" == "$BLOCK_HEX" ]] ||
    die "Requested and returned block numbers differ."

BLOCK_HASH="$(jq -er '.hash' <<< "$BLOCK_METADATA")"

if [[ -n "${DIANA_BLOCK_HASH:-}" ]]; then
    [[ "$DIANA_BLOCK_HASH" =~ ^0x[0-9a-fA-F]{64}$ ]] ||
        die "Invalid expected block hash."

    [[ "${BLOCK_HASH,,}" == "${DIANA_BLOCK_HASH,,}" ]] ||
        die "Historical block hash does not match expectation."
fi

printf '\nNetwork: QoreChain Diana\n'
printf 'Chain ID: %s\n' "$CHAIN_ID"
printf 'Mode: %s\n' "$MODE"
printf 'Block: %s\n' "$(cast to-dec "$BLOCK_HEX")"

jq . <<< "$BLOCK_METADATA"

printf '\nFixture SHA-256: %s\n' "$FIXTURE_HASH"
printf 'Simulation gas budget: %s\n' "$(cast to-dec "$CALL_GAS")"

# =============================================================================
# Execution mode
# =============================================================================

if [[ "$MODE" == "adapter" ]]; then
    command -v forge >/dev/null ||
        die "Missing dependency: forge"

    CREATION_BYTECODE="$(forge inspect "$PROBE" bytecode)"

    [[ "$CREATION_BYTECODE" =~ ^0x([0-9a-fA-F]{2})+$ ]] ||
        die "Invalid compiled creation bytecode."

    printf '\nCreation probe bytecode Keccak-256:\n'
    cast keccak "$CREATION_BYTECODE"

    printf '\nExecution: deployless creation eth_call\n'
else
    printf '\nExecution: direct native precompile eth_call\n'
fi

printf 'State overrides: none\n'

# =============================================================================
# Verification helpers
# =============================================================================

flip_first_bit() {
    local value="$1"
    local first_byte
    local changed

    [[ "$value" =~ ^0x([0-9a-fA-F]{2})+$ ]] ||
        die "Cannot mutate invalid hexadecimal input."

    first_byte="${value:2:2}"

    printf -v changed '%02x' "$((16#$first_byte ^ 1))"

    printf '0x%s%s' "$changed" "${value:4}"
}

verify_signature() {
    local public_key="$1"
    local signature="$2"
    local message="$3"

    local calldata
    local constructor_args
    local params

    if [[ "$MODE" == "native" ]]; then
        calldata="$(
            cast calldata \
                'pqcVerify(bytes,bytes,bytes)' \
                "$public_key" \
                "$signature" \
                "$message"
        )"

        params="$(
            jq -cn \
                --arg target "$PQC_PRECOMPILE" \
                --arg data "$calldata" \
                --arg gas "$CALL_GAS" \
                --arg block "$BLOCK_HEX" \
                '[{to: $target, data: $data, gas: $gas}, $block]'
        )"
    else
        # ABI-encode constructor arguments without a function selector.
        constructor_args="$(
            cast abi-encode \
                'probe(bytes,bytes,bytes)' \
                "$public_key" \
                "$signature" \
                "$message"
        )"

        [[ "$constructor_args" =~ ^0x([0-9a-fA-F]{2})+$ ]] ||
            die "Invalid encoded constructor arguments."

        calldata="${CREATION_BYTECODE}${constructor_args:2}"

        # A creation call deliberately omits the destination address.
        # No third parameter or state override is permitted.
        params="$(
            jq -cn \
                --arg data "$calldata" \
                --arg gas "$CALL_GAS" \
                --arg block "$BLOCK_HEX" \
                '[{data: $data, gas: $gas}, $block]'
        )"
    fi

    # Guard the exact request shape before sending it.
    jq -e --arg mode "$MODE" '
        length == 2
        and (.[0] | type == "object")
        and (.[1] | type == "string")
        and (.[0].data | test("^0x([0-9a-fA-F]{2})+$"))
        and (
            if $mode == "adapter" then
                (.[0] | has("to") | not)
            else
                (.[0] | has("to"))
            end
        )
    ' <<< "$params" >/dev/null ||
        die "Invalid eth_call request shape."

    rpc eth_call "$params" |
        jq -er 'select(type == "string")'
}

assert_verification() {
    local label="$1"
    local expected="$2"
    local public_key="$3"
    local signature="$4"
    local message="$5"

    local actual
    local expected_word

    printf -v expected_word '0x%064x' "$expected"

    if ! actual="$(
        verify_signature \
            "$public_key" \
            "$signature" \
            "$message"
    )"; then
        die "Verification call failed: $label"
    fi

    if [[ "${actual,,}" != "$expected_word" ]]; then
        printf '[FAIL] %s\n' "$label" >&2
        printf 'Expected: %s\n' "$expected_word" >&2
        printf 'Actual:   %s\n' "$actual" >&2
        exit 1
    fi

    PASSED=$((PASSED + 1))

    printf '[PASS] %s\n' "$label"
}

# =============================================================================
# Real cryptographic verification
# =============================================================================

PUBLIC_KEY="$(jq -er '.publicKey' "$FIXTURE")"
OTHER_PUBLIC_KEY="$(jq -er '.otherPublicKey' "$FIXTURE")"

printf '\nRunning cryptographic verification cases...\n\n'

for index in 0 1; do
    MESSAGE="$(
        jq -er --argjson index "$index" \
            '.cases[$index].message' "$FIXTURE"
    )"

    SIGNATURE="$(
        jq -er --argjson index "$index" \
            '.cases[$index].signature' "$FIXTURE"
    )"

    MODIFIED_MESSAGE="$(flip_first_bit "$MESSAGE")"
    MODIFIED_SIGNATURE="$(flip_first_bit "$SIGNATURE")"

    assert_verification \
        "Vector ${index}: original signature accepted" \
        1 "$PUBLIC_KEY" "$SIGNATURE" "$MESSAGE"

    assert_verification \
        "Vector ${index}: modified message rejected" \
        0 "$PUBLIC_KEY" "$SIGNATURE" "$MODIFIED_MESSAGE"

    assert_verification \
        "Vector ${index}: modified signature rejected" \
        0 "$PUBLIC_KEY" "$MODIFIED_SIGNATURE" "$MESSAGE"

    assert_verification \
        "Vector ${index}: different public key rejected" \
        0 "$OTHER_PUBLIC_KEY" "$SIGNATURE" "$MESSAGE"
done

MESSAGE_0="$(jq -er '.cases[0].message' "$FIXTURE")"
SIGNATURE_0="$(jq -er '.cases[0].signature' "$FIXTURE")"
SIGNATURE_1="$(jq -er '.cases[1].signature' "$FIXTURE")"

assert_verification \
    "Cross-vector signature substitution rejected" \
    0 "$PUBLIC_KEY" "$SIGNATURE_1" "$MESSAGE_0"

# These input validation properties belong to the application adapter.
if [[ "$MODE" == "adapter" ]]; then
    assert_verification \
        "Adapter rejects truncated public key" \
        0 "${PUBLIC_KEY:0:${#PUBLIC_KEY}-2}" \
        "$SIGNATURE_0" "$MESSAGE_0"

    assert_verification \
        "Adapter rejects truncated signature" \
        0 "$PUBLIC_KEY" \
        "${SIGNATURE_0:0:${#SIGNATURE_0}-2}" \
        "$MESSAGE_0"
fi

# =============================================================================
# Evidence consistency
# =============================================================================

FINAL_BLOCK_METADATA="$(get_block_metadata)"

[[ "$FINAL_BLOCK_METADATA" == "$BLOCK_METADATA" ]] ||
    die "Block metadata changed during verification."

FINAL_CHAIN_ID="$(rpc eth_chainId '[]' | jq -er '.')"

[[ "$FINAL_CHAIN_ID" == "$CHAIN_ID" ]] ||
    die "RPC chain identity changed during verification."

EXPECTED_CASES=9

if [[ "$MODE" == "adapter" ]]; then
    EXPECTED_CASES=11
fi

[[ "$PASSED" -eq "$EXPECTED_CASES" ]] ||
    die "Unexpected completed verification case count."

printf '\nVerification completed successfully.\n'
printf 'Mode: %s\n' "$MODE"
printf 'Passed: %s\n' "$PASSED"
printf 'Failed: 0\n'
printf 'Block: %s\n' "$(cast to-dec "$BLOCK_HEX")"
printf 'Block hash: %s\n' "$BLOCK_HASH"
printf 'Fixture SHA-256: %s\n' "$FIXTURE_HASH"
printf 'State overrides: none\n'
printf 'Transactions broadcast: 0\n'
printf 'Contracts deployed on-chain: 0\n'
