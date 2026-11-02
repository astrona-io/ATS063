---
draft: true
exam_objectives:
- Understand Argo Event Components and Architecture
---
# Prerequisites

Use astrona, kubectl, kind, Python 3, Podman, curl, Helm and a shell. Node inspection exercises use the containers in this environment, not the physical host.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-063-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-063-lab-020-01-01" || exit 1
node_name="astro-ats-063-lab-020-01-01-control-plane"
worker_name="astro-ats-063-lab-020-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.
