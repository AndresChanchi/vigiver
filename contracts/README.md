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

Forge Standard Library is the initial selected dependency, pending installation.

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

Once the Foundry configuration and dependency lockfile have been committed, restore dependencies:

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

The development configuration, contracts, and test suite are introduced incrementally. Commands depending on those files become available when their corresponding implementation is committed.

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

During the initial dependency configuration, the release tag will be resolved to its full Git commit and pinned.

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

## Development commands

All commands below are intended to run from `contracts/` once the corresponding source files and configuration are available.

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

## Development history

Changes are recorded through focused [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

A commit should represent a coherent implementation, specification, correction, or verification result.

Dependency changes must include the corresponding lockfile changes.

Private keys, recovery credentials, and sensitive environment files must never be committed.

## Technical documentation

- [System Architecture](../docs/ARCHITECTURE.md)
- [Immutable Contract Registry ADR](../docs/adr/0001-immutable-contract-registry.md)

Contract specifications, network evidence, deployment instructions, and security findings are added as their corresponding capabilities become available.
