.PHONY: help deps kind-up kind-load deploy-baseline deploy-netpol smoke teardown lint kustomize-dev kustomize-prod

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*##"}; {printf "%-20s %s\n", $$1, $$2}'

deps: ## Install prerequisite tools
	@command -v kubectl >/dev/null || { echo "Installing kubectl"; curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; chmod +x kubectl; mv kubectl /usr/local/bin/; }
	@command -v kind >/dev/null || { echo "Installing kind"; curl -Lo kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64; chmod +x kind; mv kind /usr/local/bin/; }
	@command -v kustomize >/dev/null || { echo "Installing kustomize"; curl -Lo kustomize.tar.gz $(curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest | grep -Eo 'https://.+linux_amd64.tar.gz'); tar -xzf kustomize.tar.gz; mv kustomize*/kustomize /usr/local/bin/; chmod +x /usr/local/bin/kustomize; rm -rf kustomize* kustomize.tar.gz; }

kind-up: ## Create KIND cluster
	tools/kind/gen-config.sh | kind create cluster --config -

kind-load: ## Placeholder for loading images into KIND
	@echo "No images to load yet"

deploy-baseline: ## Deploy core GPU baseline components
	kubectl apply -f manifests/metrics-server.yaml
	kubectl apply -f manifests/ingress-nginx.yaml
	kubectl apply -f manifests/node-feature-discovery.yaml
	kubectl apply -f manifests/nvidia-device-plugin.yaml
	kubectl apply -f manifests/dcgm-exporter.yaml

deploy-netpol: ## Apply example NetworkPolicies
	kubectl apply -k manifests/networkpolicies/

smoke: ## Run smoke tests
	scripts/smoke-test.sh

teardown: ## Delete KIND cluster
	kind delete cluster || true

lint: ## Run pre-commit on all files
	pre-commit run --all-files

kustomize-dev: ## Render dev overlay
	kustomize build kustomize/overlays/dev

kustomize-prod: ## Render prod overlay
	kustomize build kustomize/overlays/prod
