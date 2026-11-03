#!/usr/bin/env bash
# Lab starting state: the default EventBus and the Secret harbor-token. The learner builds the rest.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/harbor-token.yaml"
