# ===========================================================================================
# Rx Price Watch - command shortcuts. Run `make help` to list them.
# Every target is a thin wrapper around a command you could type yourself:
# reat the recipe to learn the real command. Targests are added module by module.
# ===========================================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Load .env (if present) and export every variable to the commands below.
-include .env
export

# Always resolve relative paths from the project root.
export RX_PROJECT_ROOT := $(CURDIR)

VENV ?= .VENV
BIN   = $(abspath $(VENV))/bin

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make <target>\n"} \
	  /^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)} \
	  /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ Module 0 — Setup
.PHONY: setup env
setup: ## Create .venv and install every dependency group from uv.lock
	uv sync --all-extras
	@test -f .env || cp .env.example .env
	@echo "✅ Setup complete. Activate with: source $(VENV)/bin/activate"

env: ## Create .env from the template (won't overwrite)
	@test -f .env && echo ".env already exists" || (cp .env.example .env && echo "created .env")

