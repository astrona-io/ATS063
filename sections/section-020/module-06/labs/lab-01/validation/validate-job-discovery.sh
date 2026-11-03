#!/usr/bin/env bash
set -uo pipefail
cfg=$(kubectl -n starfleet get configmap prometheus-config -o jsonpath='{.data.prometheus\.yml}' 2>/dev/null)
if echo "$cfg" | grep -Eq 'names: \[argo-events\]'; then echo "PASS: the job discovers pods in argo-events"; exit 0; fi
echo "FAIL: the job argo-events-controller must discover pods in the namespace argo-events"; exit 1
