#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-063-lab-010-01-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
if bash "$lab_directory/validate.sh"; then
  printf 'Starting state unexpectedly passes grading\n' >&2
  exit 1
fi
bash "$lab_directory/solution/apply.sh"
for attempt in $(seq 1 20); do
  if bash "$lab_directory/validate.sh"; then exit 0; fi
  sleep 3
done
printf 'Reference result did not pass within the bounded retry period\n' >&2
exit 1
