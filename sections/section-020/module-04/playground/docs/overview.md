# Overview: The Controller, Installation And High Availability (Playground)

This is a playground, not a lab. It starts a fresh cluster with Argo Workflows and Argo Events installed, and then waits. There is no task, no `astrona submit` and no pass or fail. Build objects, break them, run `astrona destroy` and start again.

## What is in the environment

- A kind cluster running Kubernetes 1.35. `kubectl` points at it as the cluster administrator.
- Argo Events v1.9.6 in `argo-events`, installed for the whole cluster, and Argo Workflows v3.7.3 in `argo`. The validating webhook is not installed.
- In `starfleet`: an EventBus named `default` with three replicas, the pods `shuttle` and `drifter` with `curl`, and the service accounts `event-trigger` (may create Workflows) and `workflow-runner` (the identity of Workflow pods).
- No EventSource and no Sensor exists.

## Helpers

Paste these once in each new terminal. `post` sends a JSON body to a Service and a path in `starfleet`. `pods_of` lists the pods that the controller built for an EventSource or a Sensor. `lease_holder` prints the holder of a Lease.

```sh
post() {
  kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' \
    -X POST -H 'Content-Type: application/json' -d "$3" "http://$1/$2"
}
pods_of() {
  kubectl -n starfleet get pods -l "$1-name=$2" --show-labels
}
lease_holder() {
  kubectl -n starfleet get lease "$1" -o jsonpath='{.spec.holderIdentity}{"\n"}'
}
```

Use `pods_of eventsource gate` to list the pods of the EventSource `gate`, and `lease_holder eventsource-pulse` to print the holder of its Lease.

## Practice tasks

- Read the arguments and the image of the Deployment `controller-manager`, and the key `controller-config.yaml` of its ConfigMap. Name the three controllers inside the process.
- Create a webhook EventSource with a Service. Find its Deployment, its labels, its owner reference and the annotation `resource-spec-hash`. Delete the EventSource and watch the objects disappear.
- Create a webhook EventSource with two replicas and confirm that no Lease exists. Create a calendar EventSource with two replicas and the annotation for a Lease, and find out what happens without a Role.
- Add the ServiceAccount, Role and RoleBinding for Leases, read the holder, delete the holder pod, and read the holder again.
- Put a webhook and a calendar into one EventSource and read the reason in its status.
- Set a `nodeSelector` that no node satisfies and find the cause with `kubectl describe pod`.
- Scale a generated Deployment by hand and compare it with `spec.replicas`. Then change `spec.replicas` and watch the controller.
- Add a field with a wrong name under `spec.template`, and confirm that the pod has no trace of it.
