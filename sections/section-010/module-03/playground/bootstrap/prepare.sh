#!/usr/bin/env bash
# Starting state helper: creates the default EventBus in starfleet and waits for it.
# Copy into <env>/bootstrap/prepare.sh and add module-specific objects below.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
