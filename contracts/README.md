# Smart Contracts

On-chain infrastructure for cryptographic verification, protected authorization, contract version management, and security recovery.

## Toolchain

| Tool | Version | Source |
|---|---|---|
| Foundry | 1.10.0 | [Release](https://github.com/foundry-rs/foundry/releases/tag/v1.10.0) |
| Foundryup | 2.0.0 | [Repository](https://github.com/foundry-rs/foundry/tree/master/foundryup) |
| Solidity | 0.8.39 | [Release](https://github.com/argotorg/solidity/releases/tag/v0.8.39) |
| Soldeer | 0.12.1 | [Release](https://github.com/mario-eth/soldeer/releases/tag/v0.12.1) |
| EVM target | Prague | [EIP-7600](https://eips.ethereum.org/EIPS/eip-7600) |

Foundry build commit:

`083e22994195d6a7e3ad3104d0b57f478c9b9062`

Soldeer is distributed as part of Foundry. Its bundled version can be inspected in the [Foundry dependency lockfile](https://github.com/foundry-rs/foundry/blob/v1.10.0/Cargo.lock).

Solidity 0.8.39 and the Prague EVM target have passed an initial local compilation and execution test.

### Dependencies

| Dependency | Version | Scope | Source |
|---|---|---|---|
| forge-std | 1.17.0 | Development and testing | [Repository](https://github.com/foundry-rs/forge-std/tree/v1.17.0) |

Forge Standard Library is the selected development dependency.

The resolved Git commit recorded in `soldeer.lock` is:

`f3dae6e6ee381f25eb6a246f7da9b85c91a68219`

No additional production libraries are currently selected.

The effective dependency versions and revisions will be recorded in `soldeer.lock`.

## Getting started

Requirements:

- Git
- Bash or a compatible shell
- cURL
- Foundry
- GNU Make for Makefile targets

### Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Open a new terminal or load the shell environment configured by the installer.

Install the selected release:

```bash
foundryup --install v1.10.0
```

Verify the installation:

```bash
foundryup --version
forge --version
cast --version
anvil --version
chisel --version
forge soldeer version
```

References:

- [Foundry Documentation](https://getfoundry.sh/)
- [Foundry Releases](https://github.com/foundry-rs/foundry/releases)

### Project setup

Run the following commands from the repository root:

```bash
cd contracts
```

Restore the dependencies recorded in the committed configuration and lockfile:

```bash
forge soldeer install
```

Inspect the effective project configuration:

```bash
forge config
```

Inspect import remappings:

```bash
forge remappings
```

Compile the project:

```bash
forge build
```

Run the available test suite:

```bash
forge test
```

The compiler version and EVM target are selected through `foundry.toml`. A separate system-wide Solidity compiler installation is not required.

The Foundry configuration, dependency lockfile, development
Makefile, PQC verification adapter and initial test suites
are available.

Additional capabilities and test categories are introduced
incrementally.

## Dependency management

Solidity dependencies are managed exclusively through Soldeer.

```text
contracts/
├── dependencies/     Downloaded dependencies
├── foundry.toml       Dependency configuration
└── soldeer.lock       Resolved dependency versions
```

Restore existing dependencies:

```bash
forge soldeer install
```

Add a dependency from the Soldeer registry:

```bash
forge soldeer install 'PACKAGE~VERSION'
```

Add a dependency from a Git repository:

```bash
forge soldeer install 'PACKAGE~VERSION' \
  --git "$GIT_URL" \
  --rev "$COMMIT_SHA"
```

Reference installation for the selected Forge Standard Library release:

```bash
forge soldeer install 'forge-std~1.17.0' \
  --git https://github.com/foundry-rs/forge-std \
  --tag v1.17.0
```

The repository already records the resolved dependency commit
in `soldeer.lock`.

Use the existing lockfile when restoring the project. The command
above documents the original installation procedure rather than
a required dependency update.

Remove a dependency:

```bash
forge soldeer uninstall PACKAGE
```

Intentionally update dependencies:

```bash
forge soldeer update
```

Review changes to `foundry.toml` and `soldeer.lock` before committing an update.

Do not use `forge install` for project dependencies.

### Configuration conventions

The project uses:

- `dependencies/` as its library directory.
- `foundry.toml` as the source of dependency configuration and import remappings.
- Relative remappings.
- Exact dependency versions.
- Full Git commit references for Git-based dependencies.
- A committed `soldeer.lock`.
- No automatic recursive dependency installation unless required.

Downloaded dependencies, compiler caches, and generated build artifacts are excluded from version control.

References:

- [Soldeer Repository](https://github.com/mario-eth/soldeer)
- [Soldeer 0.12.1 Usage Guide](https://github.com/mario-eth/soldeer/blob/v0.12.1/USAGE.md)
- [Foundry Configuration](https://getfoundry.sh/config/overview/)
- [Forge Standard Library](https://github.com/foundry-rs/forge-std)

## Project structure

```text
contracts/
├── src/
│   ├── registry/
│   ├── cryptography/
│   ├── authorization/
│   ├── policies/
│   └── recovery/
│
├── test/
│   ├── unit/
│   ├── fuzz/
│   ├── invariant/
│   │   └── handlers/
│   ├── fork/
│   ├── integration/
│   ├── regression/
│   ├── helpers/
│   ├── fixtures/
│   └── mocks/
│
├── script/
│   ├── deploy/
│   ├── interactions/
│   └── helpers/
│
├── specifications/
├── evidence/
├── deployments/
├── dependencies/
├── cache/
├── out/
├── foundry.toml
├── soldeer.lock
├── Makefile
└── README.md
```

Directories are introduced as their corresponding capabilities are developed.

Interfaces, libraries, and abstractions are located near the domain responsibilities they support.

## Current implementation

| Capability | Status |
|---|---|
| Native ML-DSA-87 verification adapter | Implemented |
| Typed verification precompile interface | Implemented |
| Public QoreSign verification fixtures | Available |
| Verification unit tests | Available |
| Verification fuzz tests | Available |
| Registered-key validation | Planned |
| Canonical authorization serialization | Planned |
| Protected administrative controller | Planned |
| Immutable contract registry | Specified |
| Live application deployment | Pending |

The existing `QorePqcVerifier` library establishes cryptographic
signature validity.

It does not independently establish signing authority,
registered-key eligibility, replay protection or execution
permission.

See the [Authorization Specification](specifications/AUTHORIZATION.md)
for the requirements of the next implementation stage.

## Development commands

All commands below are intended to run from `contracts/`.

The Makefile provides the standard development workflow:

```bash
make help
make versions
make install
make config
make remappings
make build
make check
make ci
make deep
make network-check
```

Use `make check` for local formatting, linting, compilation and
available local tests.

Use `make ci` for the CI testing profile.

Use `make deep` for extended fuzz and invariant campaigns.

Network-dependent tests are selected explicitly.

The equivalent Foundry commands remain available for direct
diagnosis and individual test execution.

A test target may exist before its corresponding suite has been
implemented. Executing an empty test category is not evidence
that its security properties have been validated.

### Compilation and formatting

```bash
forge build
```

```bash
forge fmt
forge fmt --check
```

```bash
forge lint
```

### Testing

Run the complete available test suite:

```bash
forge test
```

Display logs:

```bash
forge test -vv
```

Display execution traces for failing tests:

```bash
forge test -vvv
```

Display execution traces for all tests:

```bash
forge test -vvvv
```

Run individual test categories:

```bash
forge test --match-path 'test/unit/**'
forge test --match-path 'test/fuzz/**'
forge test --match-path 'test/invariant/**'
forge test --match-path 'test/regression/**'
```

Run a specific test:

```bash
forge test --match-test "$TEST_NAME" -vvvv
```

### Coverage and gas measurement

```bash
forge coverage
```

```bash
forge test --gas-report
```

```bash
forge snapshot
```

Coverage is a diagnostic measure, not a proof of correctness.

### Local development network

Start Anvil:

```bash
anvil --hardfork prague --chain-id 31337
```

Default local RPC:

`http://127.0.0.1:8545`

Anvil's development accounts must not be used outside controlled development environments.

### Fork testing

Configure the following public testnet RPC endpoints:

```bash
export QORE_RPC="https://evm-testnet.qore.host"
export ARBITRUM_RPC="https://sepolia-rollup.arbitrum.io/rpc"
```

Inspect network connectivity:

```bash
cast chain-id --rpc-url "$QORE_RPC"
cast chain-id --rpc-url "$ARBITRUM_RPC"
```

Inspect a block:

```bash
cast block-number --rpc-url "$QORE_RPC"
```

Start an Arbitrum Sepolia fork:

```bash
anvil \
  --fork-url "$ARBITRUM_RPC" \
  --fork-block-number "$ARBITRUM_BLOCK"
```

Run fork tests against a specified block:

```bash
forge test \
  --match-path 'test/fork/**' \
  --fork-url "$ARBITRUM_RPC" \
  --fork-block-number "$ARBITRUM_BLOCK"
```

`ARBITRUM_BLOCK` must contain a recorded block number selected for the test.

Fork tests must identify their source network and block reference.

QoreChain-specific native precompiles and protocol authorization rules must not be assumed to work identically inside a generic EVM fork.

Native behavior requires separate live testnet verification.

### Diana simulation compatibility

The tested Diana state-override execution path returned empty
responses from native PQC precompiles.

Direct calls without overrides and deployless creation calls
without overrides successfully exercised the native verification
boundary.

Live verification harnesses must account for this observed
difference.

Anvil, mocked precompiles and generic fork execution must not be
treated as equivalent to native protocol execution.

See [Network Validation](evidence/NETWORK_VALIDATION.md) for the
recorded observations.

### Contract interaction

Inspect deployed bytecode:

```bash
cast code "$CONTRACT_ADDRESS" \
  --rpc-url "$QORE_RPC"
```

Perform a read-only contract call:

```bash
cast call \
  "$CONTRACT_ADDRESS" \
  "$FUNCTION_SIGNATURE" \
  --rpc-url "$QORE_RPC"
```

Set `CONTRACT_ADDRESS` to the intended deployment and `FUNCTION_SIGNATURE` to the required ABI signature. Supply function arguments when required.

### Deployment simulation

Once a deployment script exists:

```bash
forge script "$DEPLOY_SCRIPT" \
  --rpc-url "$QORE_RPC" \
  -vvvv
```

`DEPLOY_SCRIPT` identifies the deployment script or contract.

The command does not include `--broadcast`.

Real deployments require a supported testnet, an explicitly selected signer, the appropriate QoreChain authorization window, and confirmation of the intended operations.

Broadcast instructions will be documented alongside the implemented deployment scripts.

## Supported networks

| Network | Chain ID | Purpose |
|---|---:|---|
| Local Anvil | 31337 | Local development and testing |
| QoreChain Diana | 9800 | Post-quantum execution and integration |
| Arbitrum Sepolia | 421614 | External EVM investigation and fork testing |

Application deployment initially targets QoreChain Diana.

Arbitrum Sepolia serves as an external investigation environment.

Mainnet deployments are outside the current scope.

See [Network Validation](evidence/NETWORK_VALIDATION.md) for recorded observations.

## Solidity conventions

The project follows the [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html) and the Foundry-oriented practices taught by [Cyfrin Updraft](https://updraft.cyfrin.io/).

| Element | Convention |
|---|---|
| Contracts | PascalCase |
| Interfaces | I-prefixed PascalCase |
| Constants | UPPER_SNAKE_CASE |
| Immutable state variables | i_ prefix |
| Mutable state variables | s_ prefix |
| Functions | camelCase |
| Test files | .t.sol |
| Script files | .s.sol |

Public and external behavior should be documented through NatSpec.

Custom errors communicate precise failure conditions. Events describe relevant state transitions.

Shared network configuration and deployment helpers belong under `script/helpers/`.

## Verification

Development follows specification-driven TDD:

```text
Specification
      |
      v
     RED
  Failing test
      |
      v
    GREEN
  Implementation
      |
      v
   REFACTOR
  Improve design
      |
      v
   VERIFICATION
  Additional properties
      |
      v
    Commit
```

Testing responsibilities:

| Category | Purpose |
|---|---|
| Unit | Isolated behavior and failure conditions |
| Fuzz | Properties across input ranges |
| Invariant | Properties across state transitions |
| Fork | Behavior against recorded blockchain state |
| Integration | Collaboration and real network functionality |
| Regression | Previously identified defects |

Mocks and fixtures support local testing. They do not replace live verification of network-specific functionality.

Local test commands must not broadcast transactions.

Security-critical behavior is derived from component
specifications and their required invariants.

Property testing and stateful invariant testing do not constitute
formal verification.

Live integration must distinguish:

- Read-only network observations.
- Simulated contract execution.
- Cryptographic verification.
- Confirmed transactions.
- Verified security postconditions.

Deployment and protected state-changing transactions require
an explicitly selected testnet account and user authorization.

## Development history

Changes are recorded through focused [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

A commit should represent a coherent implementation, specification, correction, or verification result.

Dependency changes must include the corresponding lockfile changes.

Private keys, recovery credentials, and sensitive environment files must never be committed.

## Technical documentation

- [System Architecture](../docs/ARCHITECTURE.md)
- [Immutable Contract Registry ADR](../docs/adr/0001-immutable-contract-registry.md)

- [Post-Quantum Authorization](specifications/AUTHORIZATION.md)
- [Contract Registry Specification](specifications/REGISTRY.md)
- [Network Validation](evidence/NETWORK_VALIDATION.md)

Contract specifications define required behavior.

Network evidence records observed behavior.

Passing tests establish the tested implementation properties
under their stated assumptions.

These responsibilities must remain distinguishable throughout
development.
