#!/usr/bin/env bash
set -uo pipefail
cfg=$(kubectl -n starfleet get configmap prometheus-config -o jsonpath='{.data.prometheus\.yml}' 2>/dev/null)
if echo "$cfg" | grep -Fq '${1}:7777'; then echo "PASS: the job connects to port 7777"; exit 0; fi
echo "FAIL: the relabel rule must set __address__ to the pod IP and port 7777"; exit 1
