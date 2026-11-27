# System Architecture

## Overview

The system helps users investigate blockchain infrastructure, understand security risks, and evaluate practical protection and recovery strategies.

Its architecture separates investigation, reasoning, authorization, and execution so that each responsibility can evolve independently without compromising the security of the others.

Artificial intelligence supports decision-making. Deterministic mechanisms and smart contracts enforce security-critical decisions.

## System context — C4 Level 1

The following diagram describes the system and its external relationships.

```text
                      +----------------------+
                      | Users and developers |
                      +----------+-----------+
                                 |
                     Investigate, review,
                     authorize and verify
                                 |
                                 v
                   +---------------------------+
                   | Blockchain Security Agent |
                   +-------------+-------------+
                                 |
         +-----------+-----------+-----------+-----------+
         |           |           |           |           |
         v           v           v           v           v
     QoreChain   Concordium   External     Wallet     Inference
                              EVM chains   providers  providers

     Protected   Verifiable   Blockchain   User       Reasoning
     execution   identity     analysis     signing    assistance
```

| External system | Responsibility |
|---|---|
| QoreChain | Post-quantum verification and protected execution. |
| Concordium | Verifiable agent identity and attribution. |
| External EVM networks | Investigation of existing blockchain infrastructure. |
| Wallet providers | User-controlled cryptographic authorization. |
| Inference providers | Reasoning, interpretation, and proposal generation. |

These integrations provide complementary capabilities rather than interchangeable security guarantees.

An identity verified on Concordium does not automatically authorize a transaction on QoreChain. Post-quantum protection on QoreChain does not automatically extend to contracts on another network.

## Container view — C4 Level 2

```text
+-----------------------------------------------------+
|                 Client Environment                  |
|                                                     |
|  +-----------------------------------------------+  |
|  |                  Frontend                     |  |
|  +----------------------+------------------------+  |
|                         |                           |
|           +-------------+-------------+             |
|           |                           |             |
|           v                           v             |
|  +-----------------+        +--------------------+  |
|  | Agent           |------->| Investigation and  |  |
|  | Orchestration   |        | Policy Engine      |  |
|  +--------+--------+        +---------+----------+  |
|           |                           |             |
+-----------|---------------------------|-------------+
            |                           |
            v                           v
    Inference providers          Blockchain RPCs
    Concordium identity          Simulation tools


                     User-controlled wallet
                               |
                      Authorized operations
                               |
                               v
+-----------------------------------------------------+
|                     QoreChain                       |
|                                                     |
|  +-----------------+       +---------------------+  |
|  | Security        |------>| Contract Version    |  |
|  | Contracts       |       | Registry            |  |
|  +--------+--------+       +----------+----------+  |
|           |                           |             |
|           +-------------+-------------+             |
|                         |                           |
|                         v                           |
|              Native PQC Verification                |
+-----------------------------------------------------+
```

The frontend, agent, and investigation engine are logical components that may operate within the same client runtime.

### Observed integration boundaries

Experiments on Diana established direct browser access to the
EVM JSON-RPC endpoint, including registered-key queries and
post-quantum signature verification.

The tested native REST and CometBFT endpoints were not directly
accessible from the browser because of CORS restrictions.

Consequently, the initial application must not require direct
browser access to those native endpoints.

Advanced evidence acquisition may use an optional local tool,
a compatible provider, or imported evidence bundles.

These are extension paths, not mandatory MVP infrastructure.

QoreX supports the tested browser message-signing flow without
requiring a project-operated signing service or QoreX MCP.

The application must detect supported wallet capabilities at
runtime rather than infer them from a wallet brand or version.

See [Network Validation](../contracts/evidence/NETWORK_VALIDATION.md).

Their separation does not require independent servers or microservices.

The initial architecture does not require a project-operated backend. Persistent services may be introduced when a concrete capability requires them.

The registry's relationship with native post-quantum verification represents the intended protection of sensitive release-management operations. Its authority mechanism is defined separately.

## Repository organization

```text
.
├── contracts/
├── core/
├── agent/
├── frontend/
└── docs/
```

Directories are introduced incrementally as their capabilities enter development.

### Contracts

Responsible for on-chain enforcement:

- Cryptographic verification.
- Protected authorization.
- Contract release management.
- Security policies.
- Explicitly supported recovery operations.

Contracts do not interpret natural language or depend on AI-generated conclusions.

### Core

Responsible for investigation and deterministic processing:

- Blockchain data collection.
- Security assessment.
- Evidence generation.
- Simulation.
- Mitigation planning.
- Policy validation.

The core must remain usable without an AI model or graphical interface.

### Agent

Responsible for coordinating investigation tools, reasoning about findings, producing understandable explanations, preparing proposals, and establishing verifiable attribution.

The agent cannot grant itself additional permissions or bypass contractual security requirements.

Its investigation loop is:

```text
Objective -> Plan -> Tool calls -> Evidence -> Interpretation
                ^                               |
                +------ Additional checks ------+
                                                |
                                                v
                                         Typed proposal
```

The agent can adapt its investigation plan based on tool results.

A deterministic policy boundary validates proposed actions before
they can reach the signing or execution interfaces.

Read-only tools and state-changing tools have distinct
capabilities. Arbitrary model-generated calldata is not an
authorized execution interface.

External content is untrusted data, including content retrieved
from smart contracts, repositories and protocol documentation.

Agent identity and proposal attribution are verified independently
from the correctness and authorization of the proposed operation.

### Frontend

Responsible for accessible interaction, wallet connectivity, investigation workflows, proposal review, and evidence presentation.

The interface communicates security decisions but does not replace their enforcement.

## Architectural principles

### Screaming Architecture

The repository should communicate the capabilities of the system before exposing its implementation details.

Module names such as `investigation`, `authorization`, `registry`, and `recovery` describe responsibilities rather than frameworks or product branding.

Technical abstractions should support these responsibilities instead of obscuring them.

### Separation of concerns

Each component owns a clearly defined responsibility.

A change in the inference provider should not require changes to authorization contracts. A change in the frontend should not modify cryptographic guarantees.

### Dependency direction

Portable domain behavior should not depend directly on specific wallet vendors, RPC providers, inference providers, or user-interface frameworks.

Network-specific capabilities are introduced through narrow interfaces where substitution provides practical value.

Abstractions should emerge from concrete requirements rather than hypothetical future complexity.

## Investigation and mitigation workflow

```text
+----------------------+
| User requests        |
| an investigation     |
+----------+-----------+
           |
           v
+----------------------+
| Collect blockchain   |
| state and evidence   |
+----------+-----------+
           |
           v
+----------------------+
| Assess risks and     |
| explain findings     |
+----------+-----------+
           |
           v
+----------------------+
| Prepare a mitigation |
| proposal             |
+----------+-----------+
           |
           v
+----------------------+
| Simulate the action  |
+----------+-----------+
           |
           v
   Is action possible
   and authorized?
           |
     +-----+-----+
     |           |
     No          Yes
     |           |
     v           v
 Explain      Execute through
 limitations  protected contracts
                 |
                 v
              Verify resulting
              blockchain state
                 |
                 v
              Publish evidence
```

Not every investigation results in a transaction.

The workflow must terminate safely when evidence is insufficient, permissions are unavailable, or intervention is impossible.

A proposed mitigation is not represented as successful until its intended outcome has been verified.

### Initial vertical workflow

The first integrated workflow investigates a contract with
transferable administrative authority.

The investigation engine identifies the current authority,
supported administrative actions, available transfer mechanisms,
and relevant state dependencies.

The agent prepares a mitigation proposal only when the required
capabilities can be established.

The initial protection mechanism is a QoreChain controller that
enforces operation-specific ML-DSA-87 authorization.

The controlled target must first recognize that controller as
its administrative authority.

Vigiver verifies the transfer and subsequently checks that
supported sensitive operations reject unauthorized execution.

A successful ownership transfer alone does not prove that every
administrative bypass has been removed.

The initial demonstration uses a controlled target on Diana.
External EVM investigation remains a separate read-only capability.

## Evidence model

The system distinguishes between:

| Evidence type | Meaning |
|---|---|
| Observation | Data retrieved from an identifiable source. |
| Derived finding | A conclusion obtained through a reproducible method. |
| Hypothesis | A possible explanation requiring further validation. |
| Simulation | A predicted outcome under specified assumptions. |
| Execution | An operation submitted and processed by a blockchain. |
| Verified outcome | A checked postcondition supported by observable evidence. |

Evidence should identify the relevant network, block reference, source, investigation method, and known limitations.

A transaction hash alone does not establish that the intended security outcome was achieved.

Evidence records should distinguish RPC observations, simulated
execution, cryptographic verification, state-proof verification,
and independently authenticated commitments.

A valid state proof relative to a supplied root does not establish
that the root is independently trusted.

The observed Diana account and storage proof format is ICS-23.
It must not be processed as an Ethereum Merkle Patricia Trie proof.

The first application workflow does not require a complete
consensus light client.

A proposal commitment identifies the exact evidence associated
with an operation. It does not prove the correctness of the
agent's reasoning.

Evidence publication must not disclose private credentials or
unnecessary personal information.

## Trust boundaries

| Component | Trusted for | Not trusted for |
|---|---|---|
| AI model | Reasoning and proposals | Cryptographic truth or granting permissions |
| RPC provider | Supplying accessible network data | Unconditionally proving state authenticity |
| Agent identity | Attribution | Asset custody or execution authority |
| Wallet | Supported signing operations | Replacing contractual security policies |
| Contract registry | Official release history and selection | Proving arbitrary contract behavior |
| Smart contracts | Enforcing implemented rules | Guarantees outside their specified behavior |

Each security-sensitive claim must be validated at its appropriate boundary.

## Authentication and authorization

Application authentication and blockchain authorization are separate responsibilities.

Optional authentication providers may identify an application profile. They must not implicitly grant access to blockchain signing capabilities.

Read-only investigation should remain available without mandatory authentication.

Private signing material must remain outside the AI model's context.

### Authority, executor and attribution

The initial authorization design distinguishes four identities:

| Identity | Responsibility |
|---|---|
| Agent | Produces an attributable security proposal. |
| Authority | Approves the exact operation using a recognized PQC key. |
| Executor | Submits the transaction under the applicable network rules. |
| Controller | Enforces the operation's on-chain security policy. |

The native QoreChain account and Ethereum signing account may
represent distinct keys.

An Ethereum address obtained through wallet discovery must not
automatically be interpreted as the native PQC authority.

The controller resolves the registered PQC key independently
and validates the required proof-of-possession status.

A transaction executor does not acquire the authority to modify
the operation it submits.

The initial design binds the executor, controller, chain,
operation arguments, relevant state, nonce, policy epoch and
validity period to the signed authorization.

The exact authorization protocol is defined in
[AUTHORIZATION.md](../contracts/specifications/AUTHORIZATION.md).

### Concordium attribution

Concordium provides a separate identity and attribution boundary.

The application must verify the relationship between the
registered agent identity and the attributed proposal using
supported identity mechanisms.

An off-chain identity verification must not be described as
native cross-chain verification by a QoreChain contract.

No automatic bridge or compatibility between Concordium external
key schemes and ML-DSA-87 is assumed.

### Native transaction admission

QoreChain EVM transaction admission and Vigiver application
authorization are complementary boundaries.

An application-level PQC signature does not replace the
transaction sender's required native authorization window.

A native authorization window does not replace application
constraints over operation arguments, target state or side effects.

## Monitoring

Monitoring performed by a browser or local process remains available only while that process can execute.

Persistent monitoring requires explicitly provisioned infrastructure.

The system must not claim to monitor blockchain activity when its execution environment is unavailable.

## Contract evolution

The system uses an immutable contract registry as a stable release directory.

New contract versions can introduce security improvements without replacing the executable code of previous deployments.

Release selection, compatibility, and migration are separate concerns.

The architectural decision is described in [ADR 0001](adr/0001-immutable-contract-registry.md).

## References

- [C4 Model](https://c4model.com/)
- [QoreChain Documentation](https://docs.qorechain.io/)
- [Concordium Documentation](https://docs.concordium.com/)
- [Arbitrum Documentation](https://docs.arbitrum.io/)

This document describes the intended system architecture. Component specifications and implementation evidence establish the guarantees of individual capabilities.
