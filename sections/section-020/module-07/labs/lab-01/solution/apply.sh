#!/usr/bin/env bash
# Reference solution: correct the Service name, the port and the path of the Ingress.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/solution.yaml"
sleep 10
