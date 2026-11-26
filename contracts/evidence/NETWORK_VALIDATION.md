# Network Validation

## Purpose

This document records the infrastructure capabilities experimentally observed before application contract development.

It distinguishes successful network probes from features that remain to be implemented or verified.

The observations are not an independent security audit.

## Development environment

| Component | Observed version |
|---|---|
| Operating system | Debian 13.8 |
| Environment | WSL2 |
| Foundry | 1.10.0 |
| Foundryup | 2.0.0 |
| Solidity | 0.8.39 |
| EVM target | Prague |

An isolated Solidity compilation and execution test completed successfully:

```text
Compiler run successful!

[PASS] testToolchain()

1 tests passed
0 failed
0 skipped
```

## QoreChain Diana

### Network configuration

| Parameter | Value |
|---|---|
| Environment | Testnet |
| EVM chain ID | 9800 |
| Native chain ID | qorechain-diana |
| EVM RPC | https://evm-testnet.qore.host |
| REST API | https://api-testnet.qore.host |
| Native RPC | https://rpc-testnet.qore.host |

### Connectivity

```bash
export QORE_RPC="https://evm-testnet.qore.host"

cast chain-id --rpc-url "$QORE_RPC"
```

Observed chain identity:

```text
9800
```

### Observed capabilities

| Capability | Observation |
|---|---|
| EVM RPC connectivity | Confirmed |
| EVM chain identity | Confirmed |
| PQC verification | Positive and negative calls successful |
| PQC key status | Unregistered account response decoded |
| Scoped EVM authorization | Feature enabled; execution not yet verified |
| CORS preflight | HTTP 204 |
| CORS JSON-RPC request | HTTP 200 |

## Post-quantum signature verification

The QoreChain PQC verification precompile provides an EVM-accessible cryptographic verification boundary.

Address:

`0x0000000000000000000000000000000000000a01`

Observed ABI:

`pqcVerify(bytes,bytes,bytes)(bool)`

### Test vector provenance

The verification used the published ML-DSA-87 test vector from QoreSign v0.2.0.

- [QoreSign v0.2.0](https://github.com/qorechain/qoresign/tree/v0.2.0)
- [Original test vector](https://github.com/qorechain/qoresign/blob/v0.2.0/vectors/qoresign-v1.json)

Verified Git blob hash:

`1c8111d4b135a5997e99d655c3f0b25267a90e9f`

| Input | Observed length |
|---|---:|
| Public key | 2,592 bytes |
| Signature | 4,627 bytes |
| Signed message | 65 bytes |

### Reproduction procedure

Requirements:

- Cast
- cURL
- Git
- jq
- base64
- od

Download the public fixture:

```bash
export QORE_RPC="https://evm-testnet.qore.host"

VECTOR="$(mktemp)"

curl -fsSL \
  https://raw.githubusercontent.com/qorechain/qoresign/v0.2.0/vectors/qoresign-v1.json \
  -o "$VECTOR"
```

Verify its identity:

```bash
git hash-object "$VECTOR"
```

The result must match:

```text
1c8111d4b135a5997e99d655c3f0b25267a90e9f
```

Extract the public verification inputs:

```bash
SIGNER=$(jq -er '.message.signer' "$VECTOR")

PUBKEY="0x$(jq -er --arg signer "$SIGNER" \
  '.canonical[] | select(.address == $signer) | .publicKey' \
  "$VECTOR")"

MESSAGE="0x$(jq -er \
  '.message.cases[0].pqSignBytes' \
  "$VECTOR")"

SIGNATURE="0x$(jq -er \
  '.message.cases[0].signature.pq.signature' \
  "$VECTOR" |
  base64 --decode |
  od -An -v -tx1 |
  tr -d '[:space:]')"
```

Select a block:

```bash
BLOCK=$(cast block-number --rpc-url "$QORE_RPC")
```

Record its identifying metadata:

```bash
cast rpc eth_getBlockByNumber \
  "$(cast to-hex "$BLOCK")" \
  false \
  --rpc-url "$QORE_RPC" |
  jq '{number, hash, timestamp, stateRoot}'
```

The block metadata must contain non-null identifying fields before the result is recorded as historical execution evidence.

### Positive test

```bash
cast call \
  0x0000000000000000000000000000000000000a01 \
  "pqcVerify(bytes,bytes,bytes)(bool)" \
  "$PUBKEY" \
  "$SIGNATURE" \
  "$MESSAGE" \
  --block "$BLOCK" \
  --rpc-url "$QORE_RPC"
```

Observed result:

```text
true
```

The precompile accepted the published signature.

### Negative test

Append one byte to the signed message while preserving the original public key and signature.

```bash
cast call \
  0x0000000000000000000000000000000000000a01 \
  "pqcVerify(bytes,bytes,bytes)(bool)" \
  "$PUBKEY" \
  "$SIGNATURE" \
  "${MESSAGE}00" \
  --block "$BLOCK" \
  --rpc-url "$QORE_RPC"
```

Observed result:

```text
false
```

The precompile rejected the modified message.

### Interpretation

```text
 Original public key
 Original signature  ------> PQC verification ------> true
 Original message


 Original public key
 Original signature  ------> PQC verification ------> false
 Modified message
```

These observations establish successful direct verification of the selected positive and negative test cases.

They do not yet demonstrate application-level authorization, replay protection, registered-key enforcement, or protected transaction execution.

### Evidence limitation

The original calls used the same selected block variable.

However, the subsequent metadata extraction returned null fields, and the exact block number and hash were not preserved in the available terminal output.

The reproduction procedure includes an improved metadata query. That query has not yet been verified in a subsequent execution.

The original results are therefore recorded as observed network probes rather than independently reproducible historical block evidence.

The full upstream fixture contains unrelated signing test material. Application test fixtures should retain only the public verification inputs required for testing.

## PQC key status

Address:

`0x0000000000000000000000000000000000000a02`

Observed ABI:

`pqcKeyStatus(address)(bool,uint8,bytes,bool)`

The response contains registration status, algorithm identifier, public key, and proof-of-possession status.

An initial query for an unregistered address returned:

```text
false
0
0x
false
```

The registered-key path and authority rotation behavior remain to be verified.

## Browser connectivity

A JSON-RPC request containing an Origin header was submitted directly to the public EVM endpoint:

```bash
curl -i --max-time 30 \
  "$QORE_RPC" \
  -H 'Origin: https://vigiver.example' \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

Observed response:

```text
HTTP/2 200
content-type: application/json
access-control-allow-origin: *
vary: Origin

{"jsonrpc":"2.0","id":1,"result":"0x2648"}
```

A previous CORS preflight also returned HTTP 204.

These observations support direct browser integration. Actual browser-based execution remains to be tested.

## Arbitrum Sepolia

| Parameter | Value |
|---|---|
| Environment | Testnet |
| Chain ID | 421614 |
| RPC | https://sepolia-rollup.arbitrum.io/rpc |

Connectivity, chain identity, and block retrieval were observed successfully.

Arbitrum Sepolia is used to investigate Ethereum-compatible infrastructure independently of QoreChain-specific protection.

No native QoreChain PQC functionality is assumed to exist on Arbitrum.

## Outstanding validation

| Capability | Status |
|---|---|
| Application contract calling the real PQC precompile | Pending |
| Registered-key verification | Pending |
| Proof-of-possession enforcement | Pending |
| Native signing integration | Pending |
| Scoped EVM window creation and closure | Pending |
| Window target and transaction restrictions | Pending |
| Authority rotation | Pending |
| QoreChain-specific fork compatibility | Pending |
| Browser integration | Pending |

## Future evidence

Network verification records should preserve the relevant source revision, toolchain, chain identity, block number, block hash, input provenance, execution command, and observed result.

Application-level security guarantees require separate tests after implementation.

## References

- [QoreChain Documentation](https://docs.qorechain.io/)
- [Diana Testnet Release Manifest](https://download.qore.host/testnet/latest.json)
- [QoreSign](https://github.com/qorechain/qoresign)
- [Arbitrum Documentation](https://docs.arbitrum.io/)
- [Foundry Documentation](https://getfoundry.sh/)
- [FIPS 204 — Module-Lattice-Based Digital Signature Standard](https://csrc.nist.gov/pubs/fips/204/final)
