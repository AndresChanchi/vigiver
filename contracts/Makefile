# Development workflow
# GNU Make: https://www.gnu.org/software/make/manual/
# Foundry: https://getfoundry.sh/

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.NOTPARALLEL:

# Overridable development tools
FORGE ?= forge
CAST ?= cast
ANVIL ?= anvil

FOUNDRY_PROFILE ?= default
export FOUNDRY_PROFILE

# Supported test networks
QORE_RPC ?= diana
ARBITRUM_RPC ?= arbitrum_sepolia

# Local tests exclude explicitly selected network-dependent suites.
LOCAL_TEST_FLAGS := --no-match-path 'test/{fork,integration}/**'

.PHONY: help versions install update config remappings \
        build clean fmt fmt-check lint \
        test test-unit test-fuzz test-invariant test-regression \
        test-fork-diana test-fork-arbitrum test-integration \
        coverage gas-report snapshot \
        check ci deep network-check anvil

# =============================================================================
# Help and environment
# =============================================================================

help: ## Display available development commands
	@awk 'BEGIN {FS = ":.*## "; printf "\nUsage: make <target>\n\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

versions: ## Display installed toolchain versions
	@$(FORGE) --version
	@$(CAST) --version
	@$(ANVIL) --version
	@$(FORGE) soldeer version

config: ## Display the effective Foundry configuration
	$(FORGE) config

remappings: ## Display effective Solidity import remappings
	$(FORGE) remappings

# =============================================================================
# Dependencies
# =============================================================================

install: ## Restore dependencies through Soldeer
	$(FORGE) soldeer install

update: ## Intentionally update Solidity dependencies
	$(FORGE) soldeer update

# =============================================================================
# Build and static checks
# =============================================================================

build: ## Compile smart contracts
	$(FORGE) build

clean: ## Remove Foundry build artifacts and compiler cache
	$(FORGE) clean

fmt: ## Format Solidity source files
	$(FORGE) fmt

fmt-check: ## Check formatting without modifying files
	$(FORGE) fmt --check

lint: ## Run Foundry's Solidity linter
	$(FORGE) lint

# =============================================================================
# Local testing
# =============================================================================

test: ## Run local tests without fork or integration suites
	$(FORGE) test $(LOCAL_TEST_FLAGS) -vv

test-unit: ## Run unit tests
	$(FORGE) test --match-path 'test/unit/**' -vv

test-fuzz: ## Run fuzz tests
	$(FORGE) test --match-path 'test/fuzz/**' -vv

test-invariant: ## Run stateful invariant tests
	$(FORGE) test --match-path 'test/invariant/**' -vv

test-regression: ## Run regression tests
	$(FORGE) test --match-path 'test/regression/**' -vv

# =============================================================================
# Explicit network-dependent testing
# =============================================================================

test-fork-diana: ## Run Diana fork tests using BLOCK=<number>
	@test -n "$(BLOCK)" || { echo "Usage: make test-fork-diana BLOCK=<number>"; exit 1; }
	$(FORGE) test \
		--match-path 'test/fork/diana/**' \
		--fork-url "$(QORE_RPC)" \
		--fork-block-number "$(BLOCK)" -vvv

test-fork-arbitrum: ## Run Arbitrum fork tests using BLOCK=<number>
	@test -n "$(BLOCK)" || { echo "Usage: make test-fork-arbitrum BLOCK=<number>"; exit 1; }
	$(FORGE) test \
		--match-path 'test/fork/arbitrum/**' \
		--fork-url "$(ARBITRUM_RPC)" \
		--fork-block-number "$(BLOCK)" -vvv

test-integration: ## Run explicitly selected integration tests
	$(FORGE) test --match-path 'test/integration/**' -vvv

# =============================================================================
# Coverage and gas analysis
# =============================================================================

coverage: ## Generate coverage for local test suites
	$(FORGE) coverage $(LOCAL_TEST_FLAGS) \
		--report summary \
		--report lcov

gas-report: ## Display gas usage for local test suites
	$(FORGE) test $(LOCAL_TEST_FLAGS) --gas-report

snapshot: ## Generate a local gas snapshot
	$(FORGE) snapshot $(LOCAL_TEST_FLAGS)

# =============================================================================
# Quality gates
# =============================================================================

check: fmt-check lint build test ## Run local quality checks

ci: ## Run quality checks with the CI profile
	$(MAKE) FOUNDRY_PROFILE=ci check

deep: ## Run extended fuzz and invariant campaigns
	$(MAKE) FOUNDRY_PROFILE=deep test

# =============================================================================
# Networks
# =============================================================================

network-check: ## Verify supported testnet chain identities
	@test "$$($(CAST) chain-id --rpc-url "$(QORE_RPC)")" = "9800"
	@echo "QoreChain Diana: chain ID 9800 verified"
	@test "$$($(CAST) chain-id --rpc-url "$(ARBITRUM_RPC)")" = "421614"
	@echo "Arbitrum Sepolia: chain ID 421614 verified"

anvil: ## Start a local Prague-compatible development node
	$(ANVIL) --hardfork prague --chain-id 31337 --host 127.0.0.1
