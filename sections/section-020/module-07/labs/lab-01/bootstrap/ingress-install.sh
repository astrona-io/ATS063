#!/usr/bin/env bash
# Installs the ingress-nginx controller (kind provider manifest, controller v1.12.0).
# The kind manifest schedules the controller on a node with the label ingress-ready=true.
set -euo pipefail
kubectl label node --all ingress-ready=true --overwrite
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/kind/deploy.yaml
kubectl -n ingress-nginx wait --for=condition=Available deployment/ingress-nginx-controller --timeout=300s
kubectl -n ingress-nginx wait --for=condition=Complete job/ingress-nginx-admission-create --timeout=300s
