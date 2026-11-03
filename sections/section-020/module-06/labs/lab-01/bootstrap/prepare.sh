#!/usr/bin/env bash
# Lab starting state: a Prometheus server whose scrape job for the Argo Events controller finds no target.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/prometheus.yaml"
kubectl -n starfleet wait --for=condition=Available deployment/prometheus --timeout=300s
