#!/usr/bin/env bash
# SPDX-License-Identifier: MIT OR Apache-2.0

set -euo pipefail

# Public verification inputs derived from QoreSign v0.2.0.
# Upstream license: Apache-2.0.
# https://github.com/qorechain/qoresign/tree/v0.2.0

readonly ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd
)"

readonly VERSION="v0.2.0"
readonly SOURCE_URL="https://raw.githubusercontent.com/qorechain/qoresign/${VERSION}/vectors/qoresign-v1.json"
readonly EXPECTED_BLOB="1c8111d4b135a5997e99d655c3f0b25267a90e9f"

readonly OUTPUT="${ROOT}/test/fixtures/cryptography/qoresign/v1.json"

for tool in curl git jq base64 od tr; do
    command -v "$tool" >/dev/null || {
        printf 'Missing dependency: %s\n' "$tool" >&2
        exit 1
    }
done

WORK_DIR="$(mktemp -d)"
trap 'rm -rf -- "$WORK_DIR"' EXIT

readonly UPSTREAM="${WORK_DIR}/upstream.json"
readonly EXTRACTED="${WORK_DIR}/fixture.json"

printf 'Downloading QoreSign %s vectors...\n' "$VERSION"

curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --connect-timeout 10 \
    --max-time 60 \
    "$SOURCE_URL" \
    -o "$UPSTREAM"

# Reject unexpected upstream contents before processing.
ACTUAL_BLOB="$(git hash-object "$UPSTREAM")"

if [[ "$ACTUAL_BLOB" != "$EXPECTED_BLOB" ]]; then
    printf 'Unexpected Git blob: %s\n' "$ACTUAL_BLOB" >&2
    exit 1
fi

# Validate the expected upstream structure.
jq -e '
    (.message.cases | length) == 2
    and (.canonical | length) == 2
    and all(.message.cases[];
        .signature.pq.algorithmId == 1
    )
' "$UPSTREAM" >/dev/null

SIGNER="$(jq -er '.message.signer' "$UPSTREAM")"

PUBLIC_KEY="$(
    jq -er --arg signer "$SIGNER" '
        .canonical[]
        | select(.address == $signer)
        | .publicKey
    ' "$UPSTREAM"
)"

OTHER_PUBLIC_KEY="$(
    jq -er --arg signer "$SIGNER" '
        .canonical[]
        | select(.address != $signer)
        | .publicKey
    ' "$UPSTREAM"
)"

decode_signature() {
    local index="$1"

    jq -er --argjson index "$index" '
        .message.cases[$index].signature.pq.signature
    ' "$UPSTREAM" |
        base64 --decode |
        od -An -v -tx1 |
        tr -d '[:space:]'
}

SIGNATURE_0="$(decode_signature 0)"
SIGNATURE_1="$(decode_signature 1)"

MESSAGE_0="$(jq -er '.message.cases[0].pqSignBytes' "$UPSTREAM")"
MESSAGE_1="$(jq -er '.message.cases[1].pqSignBytes' "$UPSTREAM")"

# Export public verification material only.
jq -n \
    --arg source "$SOURCE_URL" \
    --arg version "$VERSION" \
    --arg blob "$EXPECTED_BLOB" \
    --arg publicKey "0x${PUBLIC_KEY}" \
    --arg otherPublicKey "0x${OTHER_PUBLIC_KEY}" \
    --arg message0 "0x${MESSAGE_0}" \
    --arg message1 "0x${MESSAGE_1}" \
    --arg signature0 "0x${SIGNATURE_0}" \
    --arg signature1 "0x${SIGNATURE_1}" \
    '{
        source: {
            repository: "qorechain/qoresign",
            version: $version,
            url: $source,
            gitBlob: $blob,
            license: "Apache-2.0"
        },
        algorithm: "ML-DSA-87",
        algorithmId: 1,
        publicKey: $publicKey,
        otherPublicKey: $otherPublicKey,
        cases: [
            {
                id: "message-0",
                message: $message0,
                signature: $signature0
            },
            {
                id: "message-1",
                message: $message1,
                signature: $signature1
            }
        ]
    }' > "$EXTRACTED"

# Validate the extracted verification inputs.
jq -e '
    (.publicKey | test("^0x[0-9a-f]{5184}$"))
    and (.otherPublicKey | test("^0x[0-9a-f]{5184}$"))
    and (.publicKey != .otherPublicKey)
    and (.cases[0].message | test("^0x[0-9a-f]{130}$"))
    and (.cases[1].message | test("^0x[0-9a-f]{76}$"))
    and all(.cases[];
        (.signature | test("^0x[0-9a-f]{9254}$"))
    )
    and (.cases[0].message != .cases[1].message)
    and (.cases[0].signature != .cases[1].signature)
' "$EXTRACTED" >/dev/null

mkdir -p -- "$(dirname -- "$OUTPUT")"
mv -- "$EXTRACTED" "$OUTPUT"

printf 'Verified Git blob: %s\n' "$EXPECTED_BLOB"
printf 'Fixture generated: %s\n' "$OUTPUT"
printf 'Algorithm: ML-DSA-87\n'
printf 'Verification vectors: 2\n'
printf 'Private signing material exported: none\n'
