# Network Validation

**Last validation:** 2026-11-27

## Purpose

This document records experimental evidence supporting Vigiver's
blockchain integrations and security architecture.

It is not a general introduction to QoreChain, a protocol specification,
an independent security audit, or a claim of production readiness.

The objective is to establish which capabilities Vigiver can rely on,
under which conditions, and with which limitations.

## Evidence classification

| Classification | Meaning |
|---|---|
| Observation | Data retrieved from an identified network endpoint. |
| Simulation | Execution evaluated without committing a transaction. |
| Cryptographic verification | A signature or commitment checked against explicit inputs. |
| State proof | Membership or non-membership verified against a specified application root. |
| Confirmed execution | A transaction processed by the network. |
| Verified outcome | An independently checked security-relevant postcondition. |

A successful RPC response is not an independently authenticated state proof.

A successful simulation is not a confirmed transaction.

A valid cryptographic signature is not necessarily an authorized operation.

## Development environment

| Component | Observed version |
|---|---|
| Operating system | Debian 13.8 |
| Environment | WSL2 |
| Foundry | 1.10.0 |
| Foundryup | 2.0.0 |
| Solidity | 0.8.39 |
| EVM target | Prague |
| Soldeer | 0.12.1 |
| forge-std | 1.17.0 |
| QoreX browser extension | 0.4.5 |
| Isolated Go verification toolchain | 1.26.11 |

Local compilation, execution, unit testing and fuzz testing have
been performed.

Native protocol behavior is evaluated separately from local EVM tests.

## Supported test networks

| Network | Chain ID | Purpose |
|---|---:|---|
| QoreChain Diana | 9800 | PQC integration and protected execution |
| Arbitrum Sepolia | 421614 | External EVM investigation |

### Diana endpoints

| Interface | Endpoint |
|---|---|
| Native chain ID | qorechain-diana |
| EVM JSON-RPC | https://evm-testnet.qore.host |
| Native REST API | https://api-testnet.qore.host |
| CometBFT RPC | https://rpc-testnet.qore.host |

### Arbitrum Sepolia

RPC endpoint:

https://sepolia-rollup.arbitrum.io/rpc

Connectivity, chain identity and block retrieval have been observed.

QoreChain-specific precompiles and authorization mechanisms must
not be assumed to exist on Arbitrum.

## Diana capability summary

| Capability | Result |
|---|---|
| EVM chain identity | Observed |
| Historical EVM calls | Observed |
| Native ML-DSA-87 verification | Positive and negative controls passed |
| Solidity verification adapter | Validated through simulated execution |
| Registered PQC key status | Three account states observed |
| QoreX hybrid message signing | Validated with an installed wallet |
| Browser EVM RPC connectivity | Validated |
| Browser native REST connectivity | Blocked by CORS |
| Browser CometBFT connectivity | Blocked by CORS |
| ICS-23 membership and non-membership | Cryptographically verified |
| Historical validator signatures | Cryptographically verified |
| Independent consensus trust anchor | Not established |
| Application contract deployment | Pending |
| Application-level authorization | Pending |
| Scoped EVM window execution | Pending |
| Key rotation lifecycle | Pending |

## Native post-quantum verification

### Precompile interfaces

| Capability | Address |
|---|---|
| Signature verification | 0x0000000000000000000000000000000000000a01 |
| Registered key status | 0x0000000000000000000000000000000000000a02 |

Verification ABI:

`pqcVerify(bytes,bytes,bytes)(bool)`

Registered-key status ABI:

`pqcKeyStatus(address)(bool,uint8,bytes,bool)`

The observed algorithm identifier is `1`, representing ML-DSA-87
and exposed by the network under the historical name `dilithium5`.

| Input | Required size |
|---|---:|
| ML-DSA-87 public key | 2592 bytes |
| ML-DSA-87 signature | 4627 bytes |
| Verification response | 32 bytes |

A valid response contains the canonical ABI representation
of either `true` or `false`.

Failed calls, empty responses, malformed responses and unsupported
algorithms must not grant authority.

Native precompile availability must not be inferred solely from
ordinary contract bytecode.

### Public verification fixtures

Source:

- QoreSign v0.2.0.
- Original file: `vectors/qoresign-v1.json`.
- Git blob: `1c8111d4b135a5997e99d655c3f0b25267a90e9f`.

The repository retains public verification inputs in:

`test/fixtures/cryptography/qoresign/v1.json`

Fixture import helper:

`script/helpers/import-qoresign-vectors.sh`

The original upstream fixture may contain unrelated test signing
material. Vigiver retains only the required public verification inputs.

### Verification matrix

The direct precompile and Solidity adapter were exercised using
valid signatures and modified verification inputs.

| Scenario | Observed outcome |
|---|---|
| Valid text-message vector | Accepted |
| Valid binary-message vector | Accepted |
| Modified message | Rejected |
| Modified signature | Rejected |
| Incorrect public key | Rejected |
| Signature from another vector | Rejected |
| Truncated public key | Rejected |
| Truncated signature | Rejected |

Eleven distinct cases were completed across multiple probe runs.

The Solidity adapter rejects invalid input lengths before calling
the native precompile.

These results establish the tested cryptographic verification
boundary, not application-level signing authority.

## Simulation compatibility

A direct `eth_call` without state overrides successfully invoked
QoreChain's native PQC verification.

However, the tested state-override execution path behaved differently.

| Execution path | Observed result |
|---|---|
| Direct call without overrides | Expected PQC response |
| Direct call with explicit null overrides | Expected PQC response |
| Direct call with empty override object | Empty response |
| Direct call with unrelated overrides | Empty response |
| Nested PQC call under tested overrides | Empty return data |
| Standard SHA-256 precompile under tested overrides | Expected response |
| Deployless Solidity creation call without overrides | Successful |

The adapter correctly rejected the unexpected empty response.

A deployless harness using contract creation through `eth_call`,
without state overrides, successfully exercised the real native
verification boundary.

Harness runtime Keccak-256:

`0x6703a5d2ee12fb63e1bb16c9d1de72abf2d75be0c6519ca3886805639b50534b`

This is an observed compatibility limitation of the tested network
execution path.

The exact private node implementation responsible for the difference
has not been established.

Generic EVM forks and state overrides must not be treated as
equivalent to native Diana execution.

The live verification script must use an execution path that
preserves the native precompiles.

### Gas observation

For the examined verification calldata:

| Metric | Value |
|---|---:|
| Total calldata | 7524 bytes |
| Zero bytes | 272 |
| Nonzero bytes | 7252 |
| Calldata tokens | 29280 |
| Standard intrinsic gas calculation | 138120 |
| EIP-7623 calldata floor | 313800 |
| Observed gas estimate | 313800 |

The observed estimate matches the calculated calldata floor.

This does not independently establish the internal execution gas
charged by the native precompile.

Gas requirements must be evaluated again for the complete
authorization transaction.

## Registered PQC keys

### Historical browser probe

Height: `10872255`

Block hash:

`0x1722f7ed570d590b3108008e46ab5119b3b6270ae8d80fe6f80110e2105e6ea3`

| Account state | Registered | Algorithm | Key bytes | Possession |
|---|---|---:|---:|---|
| Unregistered | false | 0 | 0 | false |
| Registered without proven possession | true | 1 | 2592 | false |
| Registered with proven possession | true | 1 | 2592 | true |

All three responses passed canonical ABI validation.

The public legacy account was:

`qor178nscfyp0cq2ac5x7un4u98xrj4ayp6pt0kw08`

Public key SHA-256:

`3001c5b59aa504556a47fdc75e2cd1398d812a6b32e7009bae6288dad64fcb31`

The public possession-proven account was:

`qor104gaa3jgq3fe4h6xl0hgk9fpu934lzw6wu64q2`

Public key SHA-256:

`243392722119701229ababb6695e145ed85fcc638722f92bf568a0022a84aed1`

A registered key without proven possession is not sufficient
for the proposed Vigiver authorization policy.

The contract must obtain the recognized key through the native
registry rather than accepting an arbitrary caller-supplied key.

The `qor_getPQCKeyStatus` JSON-RPC method also returned account
records through the EVM endpoint.

An absent `possession_proven` JSON field must not be interpreted
as affirmative proof of possession.

## QoreX integration

QoreX v0.4.5 was tested through a local browser origin.

Observed capabilities include:

- Native provider injection.
- EVM provider injection.
- SVM provider injection.
- EIP-6963 provider discovery.
- Native account connection.
- `signArbitrary`.
- `verifyArbitrary`.

Other advertised provider methods were discovered but are not
considered verified solely because they were exposed.

No QoreX MCP installation is required for the tested signing flow.

### Identity separation

For the tested Cosmos coin-118 account, the native authority and
the Ethereum signing account were derived from distinct keys.

The native account's hexadecimal representation is not
necessarily the wallet's Ethereum signing address.

The native account had a registered, possession-proven PQC key.

The separate Ethereum account had no PQC registration at the
observed block.

The application must resolve signing authority and transaction
executor independently.

### Real hybrid message signature

The installed wallet approved and signed a one-time research
message that did not grant transaction or asset authority.

Signature format:

`ml-dsa-87-hybrid`

| Component | Observed size |
|---|---:|
| Compressed classical public key | 33 bytes |
| Classical signature | 64 bytes |
| PQC public key | 2592 bytes |
| PQC signature | 4627 bytes |

The PQC verification input was constructed from:

`UTF8("qorechain-msg-v1|qorechain-diana|") || message`

Verification height: `10874659`

Verification block hash:

`0xb7483566699f593afa4a0fd32035d518dd1d94c990a2f477e12555c8a4b98d66`

| Verification scenario | Expected | Observed |
|---|---|---|
| Original wallet signature | true | true |
| Modified message | false | false |
| Modified signature | false | false |
| Incorrect chain domain | false | false |
| Missing signing domain | false | false |

The wallet's `verifyArbitrary` method also returned `true`.

The registered PQC public key matched before and after signing.

The classical ADR-36 signature was independently checked using
Python cryptography 46.0.4, with the following outcomes:

- Original signature accepted.
- Modified message rejected.
- Modified signature rejected.
- Substituted signer rejected.
- Native Cosmos address derivation matched.

The wallet experiment requested one off-chain signature and
broadcast no transactions.

This establishes compatibility with the tested QoreX message
signing flow.

The complete application authorization format, protected
execution and transaction-level admission remain separate
validation requirements.

## Browser connectivity

Observed browser origin:

`http://127.0.0.1:8765`

| Request | Browser result |
|---|---|
| EVM chain identity | Accessible |
| EVM historical proof | Accessible |
| EVM PQC verification | Accessible |
| EVM registered-key status | Accessible |
| Native REST parameters | Blocked by CORS |
| Native historical REST query | Blocked by CORS |
| CometBFT status | Blocked by CORS |
| CometBFT historical commit | Blocked by CORS |
| CometBFT JSON-RPC POST | Blocked by CORS |

The public EVM endpoint returned an appropriate CORS allowance.

The tested native REST and CometBFT responses did not provide
the required browser access-control headers.

A browser-only application can therefore use the tested EVM
capabilities directly.

Advanced native evidence acquisition may require a compatible
provider, an optional local tool, or imported evidence.

CORS restrictions are not cryptographic failures.

The application must not disable browser security protections
to bypass these restrictions.

## Historical state proofs

Diana returned two-layer ICS-23 proofs:

1. IAVL membership or non-membership.
2. Multistore membership connecting the module root to the
   application commitment.

The observed proof operations were:

- `ics23:iavl`
- `ics23:simple`

### EVM account and storage observations

At height `10808654`, the returned `eth_getProof` data was
validated as ICS-23 proofs rather than Ethereum Merkle Patricia
Trie proofs.

The native modules examined were `acc` and `evm`.

An account membership proof and storage non-membership proof
were validated against the application commitment at height
`10808655`.

This establishes the examined committed account and storage
records, not every field of an Ethereum-compatible RPC response.

In particular, account membership alone does not independently
prove the reported balance.

An Ethereum MPT verifier must not be assumed compatible with
Diana's observed proof representation.

### Native PQC storage

The tested PQC module used:

| Property | Observed representation |
|---|---|
| Module | pqc |
| Storage key | pqc/accounts/ followed by the Bech32 address |
| Stored account value | JSON-encoded account record |
| Inner proof | ICS-23 IAVL |
| Outer proof | ICS-23 multistore |

The alternative tested raw-20-byte address suffix returned
verified non-membership for the examined registered accounts.

### Historical application commitments

| State height | Commitment height | Verified account state |
|---:|---:|---|
| 10862835 | 10862836 | Registered without proven possession |
| 10872255 | 10872256 | Registered with proven possession |
| 10872255 | 10872256 | Unregistered |

Application root at height `10862836`:

`516D99DC1834FBEFB05E5FE8381440CF51712237A0A9E1EC80DA8DB4A17C9AB5`

Application root at height `10872256`:

`144F1DC8B92DACD2DF2443FB1AF86EDE2611B43D3010EC02A19F8ECB743DB681`

The verifier established:

- Correct storage key.
- Correct module membership.
- Registered-account membership.
- Unregistered-account non-membership.
- Committed algorithm and public key.
- Expected public key hash.
- Committed possession status.
- Rejection of modified roots and account values.
- Rejection of substituted membership keys.

The observed application state at height H is committed by
the application root in the header at H+1.

The same-height EVM `stateRoot` must not automatically be used
as the expected root for these historical proofs.

## Historical consensus verification

Signed headers and complete validator sets were retrieved
from the native CometBFT endpoint.

The upstream CometBFT v0.38.26 verifier successfully checked
the recorded historical commits.

The following properties were checked:

- Header and commit structure.
- Recomputed block hash.
- Expected application root.
- Complete validator set.
- Validator address and public key consistency.
- Recomputed validator set hash.
- Cryptographic commit signatures.
- Rejection of an incorrect chain ID.
- Rejection of a modified commit signature.
- Parent linkage between selected adjacent headers.
- Validator set continuity between those adjacent headers.

### Validator observations

| Height | Validators | Key type | Total voting power |
|---:|---:|---|---:|
| 10808654 | 4 | Ed25519 | 338170843173 |
| 10862835 | 4 | Ed25519 | 338170844173 |
| 10862836 | 4 | Ed25519 | 338170844173 |
| 10872255 | 4 | Ed25519 | 338170844173 |
| 10872256 | 4 | Ed25519 | 338170844173 |

Between the first two sampled validator sets:

- No validator was added or removed.
- No public key changed.
- One validator's voting power increased by 1000.
- The validator set commitment changed accordingly.

No changes were observed between the latter sampled sets.

This does not establish uninterrupted validator continuity
between non-adjacent historical heights.

### Trust limitations

The sampled validator signatures use Ed25519.

Post-quantum transaction authentication must not be confused
with post-quantum consensus security.

The expected historical hashes and validator data were obtained
through the observed infrastructure.

An independent trust anchor has not been established.

The probes therefore establish cryptographic consistency
relative to the recorded headers and validator sets, rather than
independent authentication of the entire historical chain.

A complete light client is outside the initial application scope.

## Verification dependencies

The historical state and consensus verification probe used:

| Module | Version |
|---|---|
| github.com/cosmos/ics23/go | v0.11.0 |
| github.com/cometbft/cometbft | v0.38.26 |
| github.com/cosmos/gogoproto | v1.7.2 |
| github.com/cloudflare/circl | v1.6.5 |
| golang.org/x/crypto | v0.58.0 |
| golang.org/x/sys | v0.49.0 |
| google.golang.org/protobuf | v1.36.12 |

The probe resolved these versions and completed `go mod verify`.

The isolated toolchain was Go 1.26.11.

These are evidence-verification dependencies, not newly adopted
production dependencies of the application.

## Node artifact inspection

Observed Diana release: `v3.2.10`

Upgrade height: `10654800`

Archive:

`qorechaind-v3.2.10-final-r2-linux-amd64.tar.gz`

Archive SHA-256:

`05bf891db98538dce1d9a710f93e5102c0e9ace79f57b4cbf10ae688c63fecb4`

Extracted binary SHA-256:

`ffc76719d5f31bd59e42176c2d92c2e43e2386b4bcd5686964a847814ae81d3f`

The distributed artifact was inspected without executing it.

Its build metadata identified several relevant dependencies,
including ICS-23, CometBFT, Cosmos SDK, Cosmos EVM and CIRCL.

Some declared dependencies were replaced by private build paths.

The metadata does not establish exact equivalence to public
upstream source or attest which binary every remote validator runs.

The upstream verifiers were selected because they successfully
validated the examined network evidence.

## Reproduction

Run from `contracts/`:

```bash
make versions
make network-check
make test-unit
make test-fuzz
```

These commands verify the local environment, supported network
identities and available local test suites.

They do not reproduce every historical network experiment.

### Direct registered-key query

```bash
cast call \
  0x0000000000000000000000000000000000000a02 \
  'pqcKeyStatus(address)(bool,uint8,bytes,bool)' \
  0x7d51dec64804539adf46fbee8b1521e1635f89da \
  --block 10872255 \
  --rpc-url https://evm-testnet.qore.host
```

Expected:

- Registered: true.
- Algorithm: 1.
- Public key: 2592 bytes.
- Possession proven: true.

### Direct signature verification

The upstream public fixture can be retrieved and checked without
using a wallet or broadcasting a transaction:

```bash
(
    set -euo pipefail

    VECTOR="$(mktemp)"
    trap 'rm -f -- "$VECTOR"' EXIT

    curl -fsSL \
      https://raw.githubusercontent.com/qorechain/qoresign/v0.2.0/vectors/qoresign-v1.json \
      -o "$VECTOR"

    test "$(git hash-object "$VECTOR")" = \
      "1c8111d4b135a5997e99d655c3f0b25267a90e9f"

    SIGNER="$(jq -er '.message.signer' "$VECTOR")"

    PUBKEY="0x$(jq -er --arg signer "$SIGNER" \
      '.canonical[] | select(.address == $signer) | .publicKey' \
      "$VECTOR")"

    MESSAGE="0x$(jq -er \
      '.message.cases[0].pqSignBytes' "$VECTOR")"

    SIGNATURE="0x$(jq -er \
      '.message.cases[0].signature.pq.signature' "$VECTOR" |
      base64 --decode |
      od -An -v -tx1 |
      tr -d '[:space:]')"

    RPC="https://evm-testnet.qore.host"
    BLOCK="$(cast block-number --rpc-url "$RPC")"

    cast rpc eth_getBlockByNumber \
      "$(cast to-hex "$BLOCK")" false \
      --rpc-url "$RPC" |
      jq -e '{number, hash, timestamp, stateRoot}'

    cast call \
      0x0000000000000000000000000000000000000a01 \
      'pqcVerify(bytes,bytes,bytes)(bool)' \
      "$PUBKEY" "$SIGNATURE" "$MESSAGE" \
      --block "$BLOCK" --rpc-url "$RPC"

    cast call \
      0x0000000000000000000000000000000000000a01 \
      'pqcVerify(bytes,bytes,bytes)(bool)' \
      "$PUBKEY" "$SIGNATURE" "${MESSAGE}00" \
      --block "$BLOCK" --rpc-url "$RPC"
)
```

Expected direct verification results are `true` and `false`.

Historical replay depends on endpoint availability and retained state.

The complete consensus, storage-proof and wallet experiments were
performed with temporary research programs.

Dedicated reproducible verification scripts and sanitized evidence
bundles remain to be incorporated into the repository.

## Outstanding validation

The following requirements remain open:

- Application authorization serialization.
- Registered-key enforcement inside application contracts.
- Replay protection, expiry and policy epochs.
- Contract deployment and protected execution.
- Native EVM window creation, restrictions and closure.
- Key rotation, revocation and recovery transitions.
- Concordium agent identity and proposal attribution.
- Integrated investigation and mitigation workflow.
- Independent verification of resulting security postconditions.

The existing evidence is sufficient to guide implementation.

It is not sufficient to claim these outstanding capabilities
have already been delivered.

## References

- [QoreChain Documentation](https://docs.qorechain.io/)
- [Diana Release Manifest](https://download.qore.host/testnet/latest.json)
- [QoreSign v0.2.0](https://github.com/qorechain/qoresign/tree/v0.2.0)
- [QoreSign Message Signing](https://docs.qorechain.io/qoresign/spec/message-signing-v1/)
- [ICS-23](https://github.com/cosmos/ics23)
- [CometBFT v0.38.26](https://github.com/cometbft/cometbft/tree/v0.38.26)
- [FIPS 204](https://csrc.nist.gov/pubs/fips/204/final)
- [EIP-7623](https://eips.ethereum.org/EIPS/eip-7623)
- [Arbitrum Documentation](https://docs.arbitrum.io/)

## Related documentation

- [System Architecture](../../docs/ARCHITECTURE.md)
- [Post-Quantum Authorization](../specifications/AUTHORIZATION.md)
- [Contract Registry](../specifications/REGISTRY.md)
