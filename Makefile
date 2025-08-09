.PHONY: help kind-up kind-load deploy-baseline deploy-netpol smoke teardown lint kustomize-dev kustomize-prod

help: ## Show this help
@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*##"}; {printf "%-20s %s\n", $$1, $$2}'

kind-up: ## Create KIND cluster
kind create cluster --config tools/kind/cluster.yaml

kind-load: ## Placeholder for loading images into KIND
@echo "No images to load yet"

deploy-baseline: ## Deploy core GPU baseline components
    kubectl apply -f ./manifests/metrics-server.yaml
    kubectl apply -f ./manifests/ingress-nginx.yaml
    kubectl apply -f ./manifests/node-feature-discovery.yaml
    kubectl apply -f ./manifests/nvidia-device-plugin.yaml
    kubectl apply -f ./manifests/dcgm-exporter.yaml

deploy-netpol: ## Apply example NetworkPolicies
    kubectl apply -f ./manifests/networkpolicies/

smoke: ## Run smoke tests
    ./scripts/smoke-test.sh

teardown: ## Delete KIND cluster
kind delete cluster || true

lint: ## Run pre-commit on all files
pre-commit run --all-files

kustomize-dev: ## Render dev overlay
    kustomize build ./kustomize/overlays/dev

kustomize-prod: ## Render prod overlay
    kustomize build ./kustomize/overlays/prod
