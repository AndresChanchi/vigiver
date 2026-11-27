# Roadmap

Vigiver evolves through independently verifiable capabilities.

The project prioritizes complete security workflows over isolated
infrastructure components.

Each milestone must produce a meaningful result that can be
inspected, tested or demonstrated.

## Initial product milestone

Deliver an end-to-end blockchain resilience workflow that
investigates a security problem, identifies a feasible mitigation,
protects its execution and verifies the outcome.

The first scenario focuses on protecting transferable
administrative authority against conventional-key compromise.

QoreChain provides the initial post-quantum execution environment.

Concordium provides verifiable agent identity and proposal
attribution.

Arbitrum provides an external EVM investigation environment.

These integrations form one application workflow.

## Phase 1 — Validated foundation

- [x] Define the initial architecture and trust boundaries.
- [x] Establish reproducible contract development workflows.
- [x] Establish local unit and fuzz testing.
- [x] Validate native ML-DSA-87 verification on Diana.
- [x] Validate the Solidity verification adapter through simulation.
- [x] Investigate registered PQC key status and proof of possession.
- [x] Validate QoreX hybrid message-signing compatibility.
- [x] Investigate browser connectivity and simulation constraints.
- [x] Verify selected historical state proofs and validator signatures.
- [ ] Preserve the principal research probes as reproducible scripts.
- [ ] Resolve outstanding application authorization requirements.

The observed infrastructure capabilities and limitations are
recorded in [Network Validation](../contracts/evidence/NETWORK_VALIDATION.md).

Infrastructure research continues when it resolves a concrete
implementation requirement.

A complete consensus light client is not a prerequisite for
the first product milestone.

## Phase 2 — Protected authorization

- [ ] Define canonical authorization messages.
- [ ] Implement registered-key validation.
- [ ] Implement operation-specific authorization.
- [ ] Bind the authority, executor, controller and target.
- [ ] Enforce nonces, expiry and policy epochs.
- [ ] Enforce security-relevant state preconditions.
- [ ] Implement cancellation and authority lifecycle rules.
- [ ] Test malformed signatures and infrastructure responses.
- [ ] Test replay, unauthorized execution and compromised executors.
- [ ] Validate the required native EVM authorization windows.
- [ ] Execute a protected administrative operation on Diana.

**Completion:** A real testnet operation succeeds only when the
implemented application and native authorization requirements
are satisfied.

## Phase 3 — Investigation and agent attribution

This phase can progress alongside authorization development.

### Investigation

- [ ] Implement a portable EVM investigation capability.
- [ ] Inspect contract bytecode, ownership and relevant permissions.
- [ ] Identify supported authority-transfer mechanisms.
- [ ] Produce structured, reproducible findings.
- [ ] Identify unavailable or unsafe mitigation paths.
- [ ] Demonstrate external read-only investigation on Arbitrum Sepolia.

### Agent

- [ ] Connect the agent to bounded investigation tools.
- [ ] Support iterative tool selection and evidence evaluation.
- [ ] Generate typed mitigation proposals.
- [ ] Validate proposals through deterministic rules.
- [ ] Prevent untrusted external content from overriding policy.
- [ ] Register and verify an agent identity on Concordium testnet.
- [ ] Establish verifiable proposal attribution.

**Completion:** An identifiable agent investigates a real target
and prepares an evidence-backed proposal without unrestricted
execution authority.

## Phase 4 — Integrated resilience workflow

- [ ] Present investigation findings in accessible language.
- [ ] Support read-only use without mandatory authentication.
- [ ] Connect a compatible user-controlled signing wallet.
- [ ] Present the exact proposed operation and its expected effects.
- [ ] Simulate the intervention where supported.
- [ ] Request explicit operation-specific authorization.
- [ ] Establish the protected controller as the target authority.
- [ ] Execute an authorized administrative operation.
- [ ] Verify the resulting security postconditions.
- [ ] Demonstrate rejection of a classical-only authorization attempt.
- [ ] Preserve evidence sufficient for independent reproduction.

### Acceptance criteria

The initial product milestone is complete when:

1. A user provides a blockchain security objective.
2. The agent investigates through real tools.
3. Findings are supported by identifiable evidence.
4. A technically feasible mitigation is identified.
5. Relevant preconditions and expected effects are evaluated.
6. The agent's Concordium identity and attribution are verified.
7. A sensitive operation receives actual PQC protection on Diana.
8. The user reviews and authorizes the operation.
9. The resulting blockchain state is independently inspected.
10. The workflow has reproducible positive and negative evidence.

The demonstration must distinguish actual execution from
simulation.

An investigation without a feasible intervention must terminate
with an explicit explanation.

## Phase 5 — Security and release validation

- [ ] Complete adversarial unit and fuzz testing.
- [ ] Exercise stateful authorization invariants.
- [ ] Validate real network integration.
- [ ] Perform security assessments, including QCAI where applicable.
- [ ] Resolve findings and add regression tests.
- [ ] Publish reproducible deployment and verification evidence.

Security review begins with the first security-critical
implementation and continues throughout development.

A passing test suite or automated audit does not establish
unconditional security.

## Phase 6 — Contract evolution

- [ ] Introduce the immutable contract release registry.
- [ ] Register independently deployed implementations.
- [ ] Establish protected release selection.
- [ ] Validate compatibility and lifecycle transitions.
- [ ] Prevent unauthorized downgrades.
- [ ] Establish explicit successor and migration mechanisms.
- [ ] Demonstrate cryptographic agility through versioned releases.

A minimal registry capability may be introduced earlier if required
by the initial workflow.

The complete release-management system is not a prerequisite for
demonstrating one protected intervention.

## Future capabilities

Potential extensions include:

- Additional classes of blockchain security investigation.
- Vulnerability and dependency assessment.
- Permission revocation and broader recovery operations.
- Additional cryptographic verification mechanisms.
- Multi-chain investigation.
- Delegated and bounded autonomous execution.
- Active-session and persistent monitoring.
- Imported cryptographic evidence bundles.
- Independently anchored light-client verification.
- Privacy-preserving evidence and decentralized distribution.
- Formal verification of selected security-critical components.

These capabilities require separate specifications and acceptance
criteria.

Production deployment requires additional security and operational
readiness decisions.
