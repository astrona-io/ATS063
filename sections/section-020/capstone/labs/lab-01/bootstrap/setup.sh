#!/usr/bin/env bash
# Shared starting state for every ATS063 environment: Argo Workflows (the
# example trigger target), Argo Events (cluster-wide install) and the
# Starfleet example workloads. It creates no EventBus, EventSource or Sensor.
# Module-specific objects are added by bootstrap/prepare.sh when a module needs them.
# UNTESTED: written from the upstream manifests, not run yet.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fetch_manifest() {
  local url="$1" expected_sha256="$2" target="$3"
  curl --fail --silent --show-error --location --max-time 120 "$url" -o "$target"
  local actual_sha256
  actual_sha256="$(sha256sum "$target" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$target" | cut -d' ' -f1)"
  if [ "$actual_sha256" != "$expected_sha256" ]; then
    echo "[setup] Checksum differs for $url" >&2
    exit 1
  fi
}

work_dir="$(mktemp -d)"

# Argo Workflows v3.7.3 (quick-start-minimal), controller only, images pinned.
kubectl create namespace argo --dry-run=client -o yaml | kubectl apply -f -
fetch_manifest 'https://raw.githubusercontent.com/argoproj/argo-workflows/v3.7.3/manifests/quick-start-minimal.yaml' \
  '7534087591979b7b1576f88e1699dc15b1c1b471a27d6cdedbe0b91423fb1c31' "$work_dir/workflows.yaml"
sed -i.bak \
  -e 's#quay.io/argoproj/workflow-controller:latest#quay.io/argoproj/workflow-controller:v3.7.3#' \
  -e 's#quay.io/argoproj/argocli:latest#quay.io/argoproj/argocli:v3.7.3#' \
  "$work_dir/workflows.yaml"
kubectl apply --server-side -n argo -f "$work_dir/workflows.yaml"
kubectl -n argo scale deployment/argo-server --replicas=0
kubectl -n argo set env deployment/workflow-controller ARGO_EXECUTOR_IMAGE=quay.io/argoproj/argoexec:v3.7.3 >/dev/null 2>&1 || true
kubectl -n argo patch deployment workflow-controller --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--executor-image=quay.io/argoproj/argoexec:v3.7.3"}]' >/dev/null 2>&1 || true
kubectl -n argo rollout status deployment/workflow-controller --timeout=300s

# Argo Events v1.9.6, cluster-wide install (controller-manager in argo-events).
kubectl create namespace argo-events --dry-run=client -o yaml | kubectl apply -f -
fetch_manifest 'https://raw.githubusercontent.com/argoproj/argo-events/v1.9.6/manifests/install.yaml' \
  'b0c2c377c35e92ac6ac1c37b106ecbf23fb029c6d410147da2b7a7f6d656f162' "$work_dir/events.yaml"
kubectl apply --server-side -n argo-events -f "$work_dir/events.yaml"
kubectl -n argo-events rollout status deployment/controller-manager --timeout=300s
rm -rf "$work_dir"

# Example workloads and the service accounts for Sensors and Workflows.
kubectl apply -f "$DIR/manifests/start.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=180s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=180s
kubectl apply -f "$DIR/manifests/event-rbac.yaml"

if [ -x "$DIR/prepare.sh" ]; then
  "$DIR/prepare.sh"
fi
echo "[setup] Ready."
