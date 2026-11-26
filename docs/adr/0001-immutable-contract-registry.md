# ADR 0001 — Immutable Contract Registry

**Status:** Accepted architectural direction

## Context

Smart contracts need to evolve without sacrificing the transparency that makes deployed blockchain infrastructure independently verifiable.

A contract may become unsuitable because of a vulnerability, obsolete cryptography, or changing security requirements.

The project requires a mechanism for discovering new implementations while preserving the identity and history of existing deployments.

## Decision

Introduce an immutable-code contract registry that acts as the kernel of the project's contract release system.

The kernel is an on-chain version directory.

It records which contracts belong to the system, their registered versions, compatibility information, and their current release status.

It does not contain application business logic, custody assets, or forward arbitrary calls to implementations.

Each participating contract receives the canonical registry address during deployment and retains that reference as an immutable value.

New versions are independently deployed at new addresses.

## Architecture

```text
                 +-----------------------------+
                 | Immutable Contract Registry |
                 |          (Kernel)           |
                 +-----------------------------+
                 | Registered releases        |
                 | Active version pointers     |
                 | Compatibility information   |
                 | Release lifecycle           |
                 | Historical events           |
                 +--------------+--------------+
                                |
           +--------------------+--------------------+
           |                    |                    |
           v                    v                    v
   +---------------+    +---------------+    +---------------+
   | Contract v1   |    | Contract v2   |    | Contract v3   |
   | Address A     |    | Address B     |    | Address C     |
   | Historical    |    | Active        |    | Candidate     |
   +---------------+    +---------------+    +---------------+

   Each deployment stores the same immutable registry reference.
```

The registry's executable code does not change.

Its authorized state changes as new releases are registered, selected, deprecated, or revoked.

This distinction allows a stable discovery mechanism without requiring an upgradeable execution proxy.

## Example

Consider a cryptographic verification contract that initially supports algorithm A.

A new algorithm becomes available, and an independent implementation supporting algorithm B is deployed.

```text
Initial release
---------------

Registry --> Verifier v1 --> Algorithm A


New implementation
------------------

Registry --> Verifier v1 --> Algorithm A
         |
         +-> Verifier v2 --> Algorithm B


After authorized activation
---------------------------

Registry --> Verifier v2 --> Algorithm B [Active]
         |
         +-> Verifier v1 --> Algorithm A [Historical]
```

The previous implementation remains inspectable at its original address.

Consumers can discover the new release, evaluate its compatibility, and adopt it according to their security policies.

No previous implementation is silently overwritten.

## Considered alternatives

| Approach | Main benefit | Main trade-off |
|---|---|---|
| Transparent proxy | Persistent address and storage | Upgrade authority and indirect execution |
| UUPS | Persistent address with implementation-controlled upgrades | Upgrade logic and storage compatibility requirements |
| Diamond | Fine-grained replacement of functionality | Increased routing and storage complexity |
| Independent deployments | Explicit version identity | Fragmented release discovery |
| Immutable registry with independent deployments | Stable discovery and transparent evolution | Release authority and explicit migration requirements |

Proxy-based architectures remain useful when persistent address and storage continuity are essential.

The project does not require those properties across every component.

## Rationale

The registry separates release management from execution.

A small, stable kernel can coordinate the discovery of independently deployed modules while allowing their implementations to evolve.

This supports cryptographic agility, transparent release history, independently inspectable deployments, and explicit compatibility requirements.

The design also avoids making application-wide delegatecall-based upgradeability a prerequisite for introducing new security mechanisms.

## Security considerations

Registration is not proof that a contract is secure.

A registered implementation may contain vulnerabilities, misrepresent its interface, or violate expected behavior.

Compatibility therefore requires deterministic checks, conformance testing, reproducible artifacts, and independent review.

Registry operations that change official releases or active selections must be protected by an appropriate authorization mechanism.

Consumers must account for release changes between transaction review and execution.

A vulnerable historical contract cannot be made safe simply by changing its status in the registry. Existing assets, permissions, and dependencies may require explicit migration.

## Consequences

- Previous contract versions remain independently inspectable.
- New versions receive new addresses.
- Release history remains observable on-chain.
- State and asset migration remain explicit operations.
- Consumers may resolve current releases or pin eligible versions.
- Revocation cannot prevent direct interaction with historical contracts unless the relevant enforcement mechanisms support it.

The registry becomes a long-lived trust anchor.

If the registry itself becomes unsuitable, adopting a successor registry requires explicit migration. Its immutable references cannot be silently rewritten.

## Outstanding decisions

The precise registry authority, cryptographic bootstrap, authority rotation, emergency recovery policy, and enforceable compatibility checks will be defined before deployment.

The design must not introduce an administrative bypass that undermines the cryptographic protections it is intended to preserve.

This ADR establishes the architectural direction, not a claim that all contract migrations are automatically safe or possible.
