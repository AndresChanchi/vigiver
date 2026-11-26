# Post-Quantum Authorization

**Status:** Proposed specification

## What does this component do?

The authorization component controls which sensitive blockchain operations are allowed to execute.

Its purpose is to ensure that an operation approved by a user cannot be modified, replayed, or executed by an unauthorized actor.

It also introduces post-quantum cryptographic protection for operations that would otherwise depend exclusively on conventional digital signatures.

The initial implementation targets QoreChain's native post-quantum capabilities.

## The problem

Consider a developer who controls the administrative permissions of a smart contract through a conventional blockchain account.

If the account's private key becomes compromised, an attacker may be able to modify critical configuration, transfer assets, or introduce a malicious implementation.

The blockchain may consider those transactions valid because they contain a valid conventional signature.

An additional post-quantum authorization requirement can protect supported operations from attacks involving conventional credentials alone.

This protection applies to operations that enforce it. It does not automatically protect arbitrary existing contracts or repair compromised blockchain infrastructure.

## How it works

A sensitive operation requires both the applicable transaction-level permissions and application-level cryptographic authorization.

```text
                Proposed operation
                        |
                        v
                 +-------------+
                 | User review |
                 +------+------+
                        |
                        v
                 +-------------+
                 | PQC signer  |
                 +------+------+
                        |
                 Signed operation
                        |
                        v
             +----------------------+
             | Authorization        |
             | controller           |
             +----------+-----------+
                        |
          +-------------+-------------+
          |                           |
          v                           v
 +------------------+       +------------------+
 | Security policy  |       | PQC verification |
 +--------+---------+       +--------+---------+
          |                          |
          +-------------+------------+
                        |
                  All checks pass?
                        |
              +---------+---------+
              |                   |
             Yes                  No
              |                   |
              v                   v
       Execute operation       Reject
```

The authorization controller does not trust an operation merely because an AI agent proposed it or a wallet submitted it.

It verifies the operation against its cryptographic and application security requirements.

## Responsibilities

| Component | Responsibility |
|---|---|
| Agent | Investigates risks and prepares proposals. |
| User | Reviews operations and grants applicable permission. |
| Signer | Produces the required cryptographic signature. |
| Verifier | Determines whether a signature is cryptographically valid. |
| Policy | Defines permitted operations and applicable constraints. |
| Authorization controller | Enforces authorization and coordinates permitted execution. |

Identity, signing, verification, and execution are separate responsibilities.

A registered agent identity establishes attribution. It does not independently grant permission to control assets.

Application authentication does not constitute blockchain authorization.

## Example: protecting the kernel

The immutable contract registry must be able to register and activate new releases without allowing an attacker to introduce an unauthorized implementation.

Consider a legitimate verifier replacement:

```text
Current selection: Verifier v1
Proposed selection: Verifier v2

1. Developer reviews the new release.
2. Compatibility evidence is evaluated.
3. The exact release change is signed.
4. Required transaction permissions are established.
5. The kernel validates the authorization.
6. The active release pointer is updated.
7. The state transition is emitted as an event.
```

Now consider an attacker who controls only the developer's conventional signing credential.

```text
Attacker
  |
  +-- Valid conventional credential
  |
  +-- No valid required PQC authorization
  |
  v
Attempt to activate malicious release
  |
  v
Kernel authorization requirements
  |
  v
REJECTED
```

The intended protection is that conventional-key compromise alone cannot authorize a kernel transition requiring valid post-quantum credentials.

This guarantee depends on the implemented authority, key-registration, rotation, and recovery mechanisms.

It must be established through testing rather than assumed from the presence of a PQC verifier.

## QoreChain cryptographic verification

The initial implementation integrates the native ML-DSA-87 verification capability.

| Precompile | Address |
|---|---|
| PQC verification | 0x0000000000000000000000000000000000000a01 |
| PQC key status | 0x0000000000000000000000000000000000000a02 |

### Verification interface

`pqcVerify(bytes,bytes,bytes)(bool)`

Inputs:

- Public key.
- Signature.
- Exact signed message.

The cryptographic verifier must determine whether the signature is valid for the specified public key and message.

### Key-status interface

`pqcKeyStatus(address)(bool,uint8,bytes,bool)`

The key-status response provides registration status, algorithm identifier, public key, and proof-of-possession status.

### Verification boundary

```text
 Public key + signature + message
                 |
                 v
        +-----------------+
        | QoreChain       |
        | PQC precompile  |
        +--------+--------+
                 |
         Validate response
                 |
      +----------+----------+
      |          |          |
    Valid      Invalid    Failure
      |          |          |
      v          v          v
   Continue    Reject     Reject
```

An unsuccessful, empty, malformed, or unsupported verification response must never grant authority.

The adapter must validate both call success and the expected response representation.

The presence or absence of ordinary deployed bytecode is not sufficient to determine whether a native precompile is available.

## Trusted cryptographic keys

A mathematically valid signature is not necessarily an authorized signature.

The signer must use a key recognized by the applicable security policy.

Key validation considers:

- Registration status.
- Proof of possession.
- Supported algorithm.
- Trusted key commitment.
- Current authority epoch.

An account address alone is not necessarily a stable authority commitment if the public key associated with that address can change.

An attacker must not gain authorization by substituting an otherwise valid registered key.

Authority changes require explicitly protected transitions.

## What is actually signed?

A signature must authorize a specific operation rather than provide unrestricted permission.

For example:

```text
+-------------------------------------------+
| Authorization envelope                    |
+-------------------------------------------+
| Domain and schema                         |
| Network                                   |
| Verifying contract                        |
| Operation type                            |
| Target implementation and release         |
| Operation arguments and value             |
| Expected security-relevant state          |
| Trusted authority                         |
| Authority and policy epochs               |
| Nonce                                     |
| Expiration                                |
+-------------------------------------------+
                    |
                    v
          Canonical signed bytes
                    |
                    v
           Post-quantum signature
```

This envelope binds the approval to a particular operation.

| Field | Protection |
|---|---|
| Domain and schema version | Prevents confusion between signing formats. |
| Chain identity | Prevents cross-network replay. |
| Verifying contract | Prevents replay across controllers. |
| Operation type | Identifies the permitted transition. |
| Target and release | Prevents implementation substitution. |
| Operation data | Prevents modification of arguments or value. |
| Expected state | Detects relevant changes after user review. |
| Authority commitment | Binds the recognized signing authority. |
| Authority and policy epochs | Invalidate obsolete permissions. |
| Nonce | Prevents successful operation replay. |
| Expiration | Limits authorization validity. |

Evidence or proposal commitments may be included when traceability to a particular investigation is required.

The exact byte representation must be canonical and independently reproducible.

The final Solidity ABI and signed-message encoding will be established before implementation.

## Signing compatibility

QoreSign message signing and direct native precompile verification are different interfaces.

A signer may transform or frame a message before producing its post-quantum signature.

The application must verify the exact bytes that were signed.

```text
 Application operation
          |
          v
 Canonical authorization data
          |
          v
 Signer-specific message framing
          |
          v
 Post-quantum signature
          |
          v
 Verification against the same signed bytes
```

Framing, domain separation, encoding, algorithm identifiers, and signature lengths must be validated against reproducible test vectors.

The existing positive and negative verification probes provide an initial foundation, but do not yet establish application signing compatibility.

## Authorization lifecycle

```text
+----------+
| Proposed |
+----+-----+
     |
     v
+-----------+
| Reviewed  |
+-----+-----+
      |
      v
+------------+
| Authorized |
+------+-----+
       |
       +-------------> Expired
       |
       +-------------> Cancelled, if supported
       |
       v
+------------+
| Execution  |
| attempt    |
+------+-----+
       |
       +-------------> Failed
       |
       v
+------------+
| Executed   |
+------+-----+
       |
       v
+------------+
| Outcome    |
| verified   |
+------------+
```

These states describe the application lifecycle. They do not require every state to be stored on-chain.

Cancellation, retries, failure semantics, and nonce consumption must be defined precisely.

## Execution requirements

The authorization controller must:

1. Validate the signing domain and schema.
2. Validate the intended operation and policy.
3. Verify the target and expected release.
4. Validate relevant state preconditions.
5. Verify the nonce and expiration.
6. Validate the trusted cryptographic key.
7. Verify the signature.
8. Consume the authorization where required.
9. Execute the permitted operation.
10. Record the resulting state transition.

Authorization consumption must occur before external interaction when necessary to prevent replay and reentrancy.

If execution reverts, EVM state changes normally revert as well, including nonce updates performed within that transaction.

The implementation must therefore define whether and how failed operations can be retried.

A completed transaction must not be confused with a verified security outcome.

## Scoped EVM authorization

QoreChain provides a native mechanism for establishing scoped EVM authorization windows.

This mechanism forms an additional protection layer around application-level authorization.

```text
+-----------------------------------------+
| Native QoreChain authorization          |
|                                         |
| Limited validity period                 |
| Permitted targets                       |
| Transaction count                       |
| Native-value exposure                   |
+--------------------+--------------------+
                     |
                     v
+-----------------------------------------+
| Application authorization               |
|                                         |
| Trusted PQC signature                   |
| Exact operation                         |
| Application security policy             |
| Nonce and expiration                    |
+--------------------+--------------------+
                     |
                     v
            Protected execution
```

Native authorization windows and application policies have complementary responsibilities.

Native-value restrictions do not automatically limit every ERC-20 transfer, token approval, or application-specific side effect.

Contract-level authorization must therefore enforce the security properties of the actual operation.

Window creation, target restrictions, transaction limits, expiration, and closure require live testnet verification.

Deployment operations may require a separately authorized window.

## Cryptographic agility

The authorization architecture must evolve as cryptographic mechanisms change.

The contract registry supports discovery and selection of independently deployed verifier releases.

```text
                 Kernel
                    |
       Registered verifier releases
                    |
          +---------+---------+
          |                   |
          v                   v
     Verifier v1         Verifier v2
          |                   |
          v                   v
   Current scheme       Stronger or
                        newer scheme
```

However, replacing a verifier is itself a security-sensitive operation.

A verifier must not be allowed to authorize its own unrestricted replacement.

An implementation accepting arbitrary signatures must not become a trusted verifier merely because it is registered.

Verifier selection, authority rotation, and migration must preserve the applicable security invariants.

The kernel's own authority cannot depend on an unrestricted mutable pointer that a compromised conventional credential can redirect.

Any circular dependency between kernel authorization and verifier selection must be resolved during security design.

If all supported authorization mechanisms become unavailable, the system must fail safely rather than introduce an undocumented bypass.

Recovery from complete authority failure cannot be guaranteed for every deployment.

## Security invariants

| ID | Required property |
|---|---|
| AUTH-INV-001 | Sensitive operations require valid authorization. |
| AUTH-INV-002 | Successfully consumed authorizations cannot be replayed. |
| AUTH-INV-003 | Expired authorizations cannot execute. |
| AUTH-INV-004 | Modified operation data invalidates authorization. |
| AUTH-INV-005 | Conventional credentials alone cannot bypass required PQC protection. |
| AUTH-INV-006 | Obsolete authority and policy epochs cannot authorize new operations. |
| AUTH-INV-007 | Unavailable or malformed verification cannot grant authority. |
| AUTH-INV-008 | An agent cannot grant itself additional permissions. |
| AUTH-INV-009 | Unauthorized cryptographic downgrade is rejected. |
| AUTH-INV-010 | Authorizations cannot be replayed across networks or controllers. |
| AUTH-INV-011 | Relevant release or state changes require revalidation. |

### Progress property

A valid and current authorization must be capable of progressing when the required signer, network, target, policy, and verification infrastructure are available.

Rejecting all operations is not sufficient to establish correctness.

## Verification requirements

| Test scenario | Expected result |
|---|---|
| Valid recognized key and signature | Operation can execute. |
| Invalid signature | Rejected. |
| Modified message | Rejected. |
| Unregistered required key | Rejected. |
| Missing proof of possession | Rejected. |
| Substituted registered key | Rejected. |
| Empty precompile response | Rejected. |
| Malformed precompile response | Rejected. |
| Reused nonce | Rejected. |
| Expired authorization | Rejected. |
| Different network | Rejected. |
| Different verifying contract | Rejected. |
| Modified target or arguments | Rejected. |
| Unexpected release change | Rejected. |
| Obsolete authority epoch | Rejected. |
| Unauthorized downgrade | Rejected. |
| Reentrant authorization reuse | Rejected. |

Unit, fuzz, and invariant testing establish application-controlled behavior.

Live integration testing establishes actual network-specific behavior.

Mocked verification cannot replace real cryptographic evidence.

## Outstanding design decisions

The following mechanisms remain to be finalized before deployment:

- Canonical authorization encoding.
- Signer integration and message framing.
- Initial trusted authority.
- Authority and verifier rotation.
- Nonce and cancellation semantics.
- Emergency recovery.
- Native EVM window integration.
- Protection against circular authority dependencies.

These decisions will be refined through specification-driven TDD and real network verification.

## Related documentation

- [Contract Registry — Kernel Specification](REGISTRY.md)
- [Network Validation](../evidence/NETWORK_VALIDATION.md)
- [FIPS 204 — Module-Lattice-Based Digital Signature Standard](https://csrc.nist.gov/pubs/fips/204/final)
- [QoreChain Documentation](https://docs.qorechain.io/)
