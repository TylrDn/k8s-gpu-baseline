SHELL := /bin/bash

KIND_CONFIG ?= tools/kind/cluster.yaml
OVERLAY ?= kustomize/overlays/prod

.DEFAULT_GOAL := help
.PHONY: help kind-up deploy-baseline deploy-dev smoke render lint teardown

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

kind-up: ## Create a local KIND cluster from tools/kind/cluster.yaml
	kind create cluster --config $(KIND_CONFIG)

deploy-baseline: ## Apply the prod overlay (override with OVERLAY=...)
	kubectl apply -k $(OVERLAY)

deploy-dev: ## Apply the dev overlay (adds --kubelet-insecure-tls)
	kubectl apply -k kustomize/overlays/dev

render: ## Render both overlays to stdout to verify they build
	kubectl kustomize kustomize/overlays/prod > /dev/null && echo "prod renders"
	kubectl kustomize kustomize/overlays/dev > /dev/null && echo "dev renders"

smoke: ## Run the cluster smoke test (scripts/smoke.sh)
	./scripts/smoke.sh

lint: ## Run pre-commit hooks and shellcheck over the repository
	pre-commit run --all-files
	shellcheck scripts/smoke.sh

teardown: ## Delete the local KIND cluster
	kind delete cluster || true
