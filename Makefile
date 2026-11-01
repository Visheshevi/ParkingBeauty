# Parking Beauty — developer commands. Run `make help` for the list.
# Targets are stubs until the step named in their message implements them.
# Stubs exit non-zero on purpose so nothing reports a false success.

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Prints a "not implemented" message and fails. Usage: $(call todo,<step>)
define todo
	@echo "make $@: not implemented yet (step $(1)). See docs/PROGRESS.md." >&2
	@exit 1
endef

.PHONY: help dev test e2e gen migrate lint seed run-dev run-test run-prod build-test build-prod

help: ## List available commands
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

dev: ## Start the local stack (docker compose) + api/worker with live reload
	$(call todo,B0.2)

test: ## Run all unit + integration tests (Go, Python, Flutter)
	$(call todo,B0.4)

e2e: ## Run the headless end-to-end suite against the local stack
	$(call todo,B0.8)

gen: ## Regenerate code from OpenAPI, sqlc, freezed/json_serializable, tokens
	$(call todo,B0.3)

migrate: ## Apply goose migrations to the local DB
	$(call todo,B0.5)

lint: ## go vet + staticcheck, ruff, flutter analyze, import-boundary check
	$(call todo,B0.10)

seed: ## Load deterministic fixture data (TARGET=dev|test, never prod)
	$(call todo,B0.8)

run-dev: ## Run the PB Dev app against the local stack
	$(call todo,F0.6)

run-test: ## Run the PB Test app against the test environment
	$(call todo,F0.6)

run-prod: ## Run the prod app in release mode (read-only checks)
	$(call todo,F0.6)

build-test: ## Build installable test builds
	$(call todo,F0.6)

build-prod: ## Build store releases (normally CI only)
	$(call todo,F0.6)
