---
draft: true
exam_objectives:
- Understand Argo Events Fundamentals
---
# Trigger A Workflow From An Event

Deliver a webhook event and execute a Workflow using its data.

## Starting state

The Events and Workflows controllers are installed. The exercise uses an internal webhook and event bus; no external sender is configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-063-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-063-lab-010-01-01" || exit 1
node_name="astro-ats-063-lab-010-01-01-control-plane"
worker_name="astro-ats-063-lab-010-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create a dependency and a Kubernetes object trigger. POST the exact JSON payload, then verify the generated Workflow consumes body.id. The fixed workflow name prevents a second same-name object; this is not a general exactly-once guarantee.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
