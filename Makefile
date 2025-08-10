SHELL := /bin/bash
.RECIPEPREFIX := >

.PHONY: kind-up deploy-baseline smoke teardown

kind-up: ## Create a local KIND cluster
>kind create cluster --config tools/kind/cluster.yaml

deploy-baseline: ## Install NVIDIA plugin, NFD, DCGM, metrics, ingress
>kubectl apply -f manifests/nvidia-device-plugin.yaml
>kubectl apply -f manifests/node-feature-discovery.yaml
>kubectl apply -f manifests/dcgm-exporter.yaml
>kubectl apply -f manifests/metrics-server.yaml
>kubectl apply -f manifests/ingress-nginx.yaml
>kubectl apply -k kustomize/overlays/prod

smoke: ## Run a GPU detection job and curl ingress health
>kubectl run --rm -it nvidia-smi --image=nvidia/cuda:12.2.0-base-ubuntu22.04 --command -- nvidia-smi
>kubectl run --rm -it curl --image=curlimages/curl --command -- curl -sf http://example.com/healthz

teardown: ## Delete cluster/resources
>kind delete cluster || true
