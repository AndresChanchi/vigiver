# Contract Registry — Kernel Specification

**Status:** Proposed specification

## What is the kernel?

The kernel is an immutable smart contract that acts as an on-chain notary and version directory for the project's contracts.

Its purpose is simple: provide a canonical place where developers, users, and other contracts can discover which implementations exist, which versions are currently selected, and how those versions have evolved.

It does not contain application business logic.

Instead, it provides a stable set of getters, authorized state-changing operations, and events for managing independently deployed contracts throughout their lifecycle.

The kernel's executable code remains immutable. Its registered release history and authorized version pointers evolve over time.

## The problem it solves

Consider a system that initially deploys three contracts:

- A cryptographic verifier.
- An authorization controller.
- A recovery mechanism.

Over time, the verifier may become obsolete, the authorization controller may require stronger protections, or the recovery mechanism may need additional capabilities.

Replacing implementations behind upgradeable proxies is one possible approach.

The kernel takes a different approach: deploy new immutable contracts, register their existence, and explicitly update the corresponding version pointers.

Every implementation remains independently identifiable.

## How it works

### Initial deployment

The kernel is deployed first.

Each participating contract receives the kernel's address through its constructor and stores it as an immutable reference.

```text
              +-----------------------+
              |        KERNEL         |
              |  Immutable bytecode   |
              |  Canonical address    |
              +-----------+-----------+
                          |
           +--------------+--------------+
           |              |              |
           v              v              v
      +---------+    +---------+    +---------+
      |Verifier |    | Author. |    |Recovery |
      |   v1    |    |   v1    |    |   v1    |
      +---------+    +---------+    +---------+
       Address A      Address B      Address C

       All three contracts know the kernel address.
```

The contracts are registered through authorized kernel operations.

The kernel maintains their release information and current selections.

### Introducing a new version

Suppose the cryptographic verifier requires a security improvement.

A new verifier is deployed at a new address and registered.

```text
BEFORE

Kernel
  |
  +-- Verification --> Address A (v1)


AFTER REGISTRATION

Kernel
  |
  +-- Verification
        |
        +-- Address A (v1) [Active]
        |
        +-- Address D (v2) [Registered]


AFTER AUTHORIZED ACTIVATION

Kernel
  |
  +-- Verification
        |
        +-- Address A (v1) [Historical]
        |
        +-- Address D (v2) [Active]
```

Address A is not overwritten.

Address D is not hidden behind Address A.

Both deployments remain independently inspectable.

Consumers can discover the new implementation through the kernel and adopt it when their compatibility and security requirements allow.

### Discovering a contract

The kernel supports two forms of discovery:

```text
Dynamic resolution

Consumer --> Kernel --> Currently selected release


Explicit version selection

Consumer --> Kernel --> Specific registered release
```

Dynamic resolution allows consumers to follow authorized release changes.

Explicit version selection allows consumers to evaluate or pin a particular implementation.

The kernel returns release information. Application calls are made directly to the selected implementation rather than being forwarded through a delegatecall proxy.

Consumers must enforce their own applicable compatibility and security requirements.

## Responsibilities

| Responsibility | Description |
|---|---|
| Registration | Record independently deployed contract releases. |
| Discovery | Retrieve registered implementations. |
| Version selection | Maintain authorized active release pointers. |
| Compatibility | Record compatibility information and enforce supported checks. |
| Lifecycle | Deprecate or revoke unsuitable releases. |
| Transparency | Emit events describing registry state changes. |
| History | Preserve previously registered release information. |

The kernel must not become responsible for application execution, asset custody, AI reasoning, or arbitrary transaction forwarding.

## Domain model

A module represents a system capability, such as cryptographic verification.

A release represents a particular deployed implementation of that capability.

A compatibility family groups implementations expected to satisfy a shared behavioral contract.

An active selection identifies the release currently selected for a module and compatibility family.

```text
Kernel
  |
  +-- Cryptographic verification
  |     |
  |     +-- Compatibility family A
  |     |     +-- Release 1
  |     |     +-- Release 2 [Active]
  |     |
  |     +-- Compatibility family B
  |           +-- Release 3
  |
  +-- Authorization
  |     |
  |     +-- Compatibility family A
  |           +-- Release 1 [Active]
  |
  +-- Recovery
        |
        +-- Compatibility family A
              +-- Release 1 [Active]
```

A module can have multiple releases and compatibility families.

At most one release may be selected as active within a particular module and compatibility family.

The active selection may be absent.

## Release information

Each registered release should identify:

| Field | Purpose |
|---|---|
| Module identifier | Identifies the capability. |
| Release identifier | Uniquely identifies the release. |
| Contract address | Identifies the deployed implementation. |
| Runtime code hash | Commits to the expected deployed bytecode. |
| Compatibility identifier | Identifies the expected behavioral contract. |
| Artifact commitment | References reproducible implementation information. |
| Evidence commitment | References compatibility and verification evidence. |
| Lifecycle status | Indicates whether the release remains eligible. |

Immutable release metadata is preserved once registered.

Lifecycle status and active selections may change through explicitly authorized operations.

Human-readable version labels may supplement the release identifier, but must not replace its uniqueness guarantees.

The exact Solidity types, storage representation, and ABI will be determined through TDD.

## Getters and setters

The kernel exposes a minimal interface for discovering releases and modifying permitted registry state.

The following table describes intended capabilities, not final Solidity function signatures.

### Read operations

| Operation | Responsibility |
|---|---|
| Get release | Retrieve a registered release. |
| Get active release | Resolve the selected implementation. |
| Get release history | Inspect previously registered versions through bounded queries. |
| Get lifecycle status | Determine whether a release is eligible, deprecated, or revoked. |
| Get authority information | Inspect the applicable registry authority. |

### State-changing operations

| Operation | Responsibility |
|---|---|
| Register release | Append a new implementation record. |
| Activate release | Update an active version pointer. |
| Deprecate release | Prevent new activation under the applicable lifecycle policy. |
| Revoke release | Permanently disqualify an unsuitable release from registry selection. |
| Rotate authority | Change authorization credentials under the specified security policy. |

State-changing operations are controlled transitions, not unrestricted public setters.

## Release lifecycle

```text
                     +------------+
                     | Registered |
                     +-----+------+
                           |
              +------------+------------+
              |                         |
              v                         |
       +------------+                   |
       | Deprecated |                   |
       +------+-----+                   |
              |                         |
              +------------+------------+
                           |
                           v
                     +------------+
                     |  Revoked   |
                     +------------+
                      Terminal state
```

Activation is separate from lifecycle status.

A registered release can become active when it satisfies the applicable authorization and compatibility requirements.

Replacing the selected implementation does not automatically classify the previous implementation as vulnerable.

If a deprecated or revoked release is currently active, its selection must be cleared or replaced through an authorized transition.

No implicit fallback is permitted.

## Compatibility

The kernel must support contract evolution without assuming that every newly deployed contract is compatible with existing consumers.

Compatibility has several dimensions:

| Layer | Requirement |
|---|---|
| Interface | Expected methods and response formats. |
| Behavior | Expected functional semantics. |
| Security | Preservation of required security properties. |
| State | Explicit migration requirements where necessary. |
| Identity | Correct registry reference, network, address, and code commitment. |

```text
 New implementation
         |
         v
 +-------------------+
 | Deployment checks |
 +---------+---------+
           |
           v
 +-------------------+
 | Compatibility     |
 | checks and tests  |
 +---------+---------+
           |
           v
 +-------------------+
 | Security evidence |
 +---------+---------+
           |
           v
 +-------------------+
 | Authorized        |
 | registration      |
 +---------+---------+
           |
           v
 +-------------------+
 | Eligible release  |
 +---------+---------+
           |
           v
 Authorized activation
```

The kernel enforces compatibility checks that can be evaluated deterministically on-chain.

Other compatibility properties require reproducible tests, review, and evidence.

A malicious contract can advertise a valid interface while implementing incorrect behavior.

Consequently, registration or interface conformance alone must not be interpreted as proof of security.

## Events and transparency

The kernel provides an observable history of official release-management operations.

Expected event categories include:

- Release registration.
- Active release changes.
- Release deprecation.
- Release revocation.
- Authority changes.

```text
 Authorized release operation
             |
             v
 +---------------------------+
 |          KERNEL           |
 | Validate and update state |
 +-------------+-------------+
               |
               v
        On-chain event
               |
     +---------+---------+
     |         |         |
     v         v         v
 Developers  Auditors   Clients
```

Independent observers can inspect registry state and monitor its events.

An unauthorized actor may deploy a contract that references the kernel, but that deployment does not automatically become an official registered release.

Referencing the kernel does not establish endorsement.

The kernel emits events for operations it performs. Participating contracts emit their own application events.

If a participating contract needs to report information through the kernel, that behavior must be explicitly supported and authorized.

The kernel cannot automatically intercept every event emitted by another contract.

## Cryptographic agility

The kernel enables independently deployed security mechanisms to evolve.

For example:

```text
 Capability: Cryptographic verification

 Version 1
 +-------------------------+
 | Existing algorithm      |
 +-------------------------+

 Version 2
 +-------------------------+
 | Post-quantum algorithm  |
 +-------------------------+

 Version 3
 +-------------------------+
 | Future algorithm or     |
 | stronger security model |
 +-------------------------+

             ^
             |
     Kernel release history
     and authorized selection
```

New implementations can introduce algorithms, verification methods, and security policies that were not available when earlier contracts were deployed.

This mechanism supports agility at the release-management layer.

It does not guarantee that every historical contract can automatically use a new algorithm.

Each implementation must expose compatible integration points or provide an explicit migration path.

The kernel's own authority and authorization mechanism must also account for cryptographic evolution.

Introducing a replaceable verifier must not allow an attacker to replace it with an implementation that accepts unauthorized signatures.

The kernel must preserve its security invariants independently of the implementations it registers.

## Downgrade and recovery

Selecting an older version may be appropriate when a newly introduced release contains an unexpected defect.

However, an older release may itself contain known vulnerabilities or obsolete cryptographic protections.

Returning to a previous release requires an explicit authorized selection that satisfies current security requirements.

Revoked releases cannot be reactivated.

Changing the kernel's active selection does not migrate assets, contract storage, permissions, or outstanding obligations.

```text
 Release selection

 Kernel --> Select implementation B


 Stateful migration

 Contract A --> Authorized migration --> Contract B
```

These operations are intentionally separate.

Direct interactions with historical contracts remain possible unless those contracts implement applicable lifecycle restrictions.

## Security invariants

| ID | Required property |
|---|---|
| REG-INV-001 | Registered release metadata cannot be overwritten or deleted. |
| REG-INV-002 | Release identifiers remain unique. |
| REG-INV-003 | An active selection must reference an eligible registered release. |
| REG-INV-004 | A revoked release cannot be reactivated. |
| REG-INV-005 | At most one active selection exists per module and compatibility family. |
| REG-INV-006 | Unauthorized actors cannot modify protected registry state. |
| REG-INV-007 | Release selection does not modify previously deployed bytecode. |
| REG-INV-008 | Authority changes invalidate obsolete authorizations. |
| REG-INV-009 | Missing eligible releases cannot trigger insecure fallback. |
| REG-INV-010 | Classical credentials alone cannot bypass required post-quantum registry protection. |

### Progress property

An authorized, compatible release must be capable of progressing through registration and activation when the required infrastructure and authority are available.

Rejecting every release is not a correct implementation.

## Verification requirements

| Scenario | Expected behavior |
|---|---|
| Valid release registration | Accepted and recorded. |
| Duplicate release identifier | Rejected. |
| Unauthorized registration | Rejected. |
| Address without required deployed code | Rejected. |
| Incorrect registry reference | Rejected. |
| Incompatible release selection | Rejected. |
| Authorized release replacement | Active pointer updated. |
| Historical release lookup | Original metadata preserved. |
| Revoked release activation | Rejected. |
| Missing active release | Explicit absence or failure. |
| Unauthorized downgrade | Rejected. |
| Obsolete authority | Rejected. |

Stateful invariant testing must explore sequences of registrations, activations, deprecations, revocations, and authority changes across multiple actors.

Events must correspond to the registry state transitions they represent.

## Outstanding design decisions

Before deployment, the following mechanisms require precise specifications:

- Initial authority bootstrap.
- Post-quantum authorization of protected kernel operations.
- Authority and verifier rotation.
- Emergency recovery.
- Compatibility-checking interfaces.
- Migration to a successor registry if the kernel itself becomes unsuitable.

The kernel's immutability makes these decisions particularly important.

## Related documentation

[ADR 0001 — Immutable Contract Registry](../../docs/adr/0001-immutable-contract-registry.md)
