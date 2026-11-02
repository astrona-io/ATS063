#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-063-lab-020-01-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="astro-ats-063-lab-020-01-01-control-plane"
worker_name="astro-ats-063-lab-020-01-01-worker"
kubectl create namespace argo --dry-run=client -o yaml | kubectl apply -f -
manifest_path="$(mktemp)"
curl --fail --silent --show-error --location --max-time 120 'https://raw.githubusercontent.com/argoproj/argo-workflows/v3.7.3/manifests/quick-start-minimal.yaml' -o "$manifest_path"
python3 - "$manifest_path" <<'CHECKSUM'
import hashlib,sys
assert hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest() == '7534087591979b7b1576f88e1699dc15b1c1b471a27d6cdedbe0b91423fb1c31', 'Controller manifest checksum differs'
CHECKSUM
python3 - "$manifest_path" <<'PIN_IMAGES'
from pathlib import Path
import sys
path=Path(sys.argv[1]);text=path.read_text()
text=text.replace('quay.io/argoproj/workflow-controller:latest','quay.io/argoproj/workflow-controller:v3.7.3').replace('quay.io/argoproj/argocli:latest','quay.io/argoproj/argocli:v3.7.3')
needle='      - args: []\n        command:\n        - workflow-controller'
assert needle in text, 'Unexpected upstream controller shape'
text=text.replace(needle,'      - args:\n        - --executor-image=quay.io/argoproj/argoexec:v3.7.3\n        command:\n        - workflow-controller')
path.write_text(text)
PIN_IMAGES
kubectl apply --server-side -n argo -f "$manifest_path"
rm -f "$manifest_path"
kubectl -n argo scale deployment/argo-server --replicas=0
kubectl -n argo rollout status deployment/workflow-controller --timeout=300s
kubectl -n argo rollout status deployment/minio --timeout=300s
kubectl -n argo patch configmap workflow-controller-configmap --type=merge -p '{"data": {"artifactRepository": "s3:\n  accessKeySecret:\n    key: accesskey\n    name: my-minio-cred\n  bucket: my-bucket\n  endpoint: minio.argo.svc:9000\n  insecure: true\n  secretKeySecret:\n    key: secretkey\n    name: my-minio-cred\n"}}'
kubectl create namespace argo-events --dry-run=client -o yaml | kubectl apply -f -
manifest_path="$(mktemp)"
curl --fail --silent --show-error --location --max-time 120 'https://raw.githubusercontent.com/argoproj/argo-events/v1.9.6/manifests/install.yaml' -o "$manifest_path"
python3 - "$manifest_path" <<'CHECKSUM'
import hashlib,sys
assert hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest() == 'b0c2c377c35e92ac6ac1c37b106ecbf23fb029c6d410147da2b7a7f6d656f162', 'Controller manifest checksum differs'
CHECKSUM
kubectl apply --server-side -n argo-events -f "$manifest_path"
rm -f "$manifest_path"
kubectl -n argo-events rollout status deployment/controller-manager --timeout=300s
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s
kubectl apply -f "$lab_directory/bootstrap/manifests/event-rbac.yaml"
