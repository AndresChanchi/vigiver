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
