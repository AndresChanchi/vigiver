# Roadmap

Well... The project evolves through independently verifiable capabilities rather than fixed delivery dates.

Each milestone should produce a meaningful result that can be inspected, tested, or demonstrated before additional complexity is introduced.

## Phase 1 — Foundation

- Define the system architecture and security boundaries.
- Establish reproducible development environments.
- Investigate blockchain capabilities and integration constraints.
- Specify security-critical behavior before implementation.

**Completion:** A reviewed architecture and testable specifications supported by infrastructure evidence.

## Phase 2 — Cryptographic protection

- Integrate post-quantum verification on QoreChain.
- Establish secure authorization and replay protection.
- Verify scoped transaction authorization.
- Test invalid signatures, expired permissions, compromised classical credentials, and unexpected network responses.

**Completion:** A real sensitive operation protected by post-quantum authorization, with positive and adversarial test evidence.

## Phase 3 — Contract evolution

- Introduce an immutable on-chain contract registry.
- Register independent contract releases.
- Define compatibility requirements and protected release selection.
- Demonstrate security improvements through new deployments.
- Establish explicit migration and recovery mechanisms where appropriate.

**Completion:** Contract versions can evolve transparently without replacing previously deployed bytecode or silently weakening authorization.

## Phase 4 — Blockchain investigation

- Build a portable EVM investigation engine.
- Inspect contract code, permissions, authorities, and available state.
- Generate reproducible findings.
- Simulate candidate mitigation strategies.
- Identify situations where intervention is unavailable.

**Completion:** An external EVM contract can be investigated, and its findings can be independently reproduced.

## Phase 5 — Verifiable security agent

- Integrate verifiable agent identity through Concordium.
- Connect the agent to investigation and simulation tools.
- Attribute proposals to their originating agent instance.
- Separate model reasoning from security-critical validation.
- Require explicit authorization for sensitive actions.

**Completion:** An identifiable agent produces an evidence-backed security proposal without possessing unrestricted execution authority.

## Phase 6 — Accessible application

- Present security findings in understandable language.
- Support read-only investigation without mandatory authentication.
- Connect compatible wallets through capability-based interfaces.
- Display proposed changes, uncertainties, and expected effects.
- Provide transparent transaction and verification results.

**Completion:** A user can investigate a contract, understand its risks, review a proposal, and verify an authorized action through the application.

## Phase 7 — Security and release validation

- Perform layered testing and adversarial evaluation.
- Run security assessments, including QCAI where applicable.
- Resolve findings and establish regression coverage.
- Publish deployment information and reproducible evidence.
- Verify the integrated workflow independently.

Security review begins with the first security-critical implementation and continues throughout development. It is not postponed until the final release.

## Future exploration

Additional directions include multi-chain investigation, cryptographic migration, delegated permissions, alternative inference providers, privacy-preserving evidence, active-session monitoring, persistent monitoring infrastructure, and more advanced verification techniques.

Production deployments require separate security and operational readiness decisions.

The roadmap may evolve as research exposes new risks, capabilities, or architectural constraints.
