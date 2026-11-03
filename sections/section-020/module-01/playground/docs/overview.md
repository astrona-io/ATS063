# Overview: The EventBus And JetStream (Playground)

This is a playground, not a lab. It starts a fresh cluster with Argo Workflows and Argo Events installed, and then waits. There is no task, no `astrona submit` and no pass or fail. Build objects, break them, run `astrona destroy` and start again.

## What is in the environment

- A kind cluster running Kubernetes 1.35. `kubectl` points at it as the cluster administrator.
- Argo Events v1.9.6 in `argo-events` and Argo Workflows v3.7.3 in `argo`, both installed for the whole cluster.
- In `starfleet`: the pod `shuttle` with `curl`, and the service accounts `event-trigger` (may create Workflows) and `workflow-runner` (the identity of Workflow pods).
- No EventBus, no EventSource and no Sensor exists.

## Helpers

Paste these once in each new terminal. `post` sends a JSON body to a Service and a path in `starfleet`. `sensor_log` prints the last lines of the log of one Sensor. `bus` lists the objects of an EventBus.

```sh
post() {
  kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' \
    -X POST -H 'Content-Type: application/json' -d "$3" "http://$1/$2"
}
sensor_log() {
  kubectl -n starfleet logs -l sensor-name="$1" --tail="${2:-20}"
}
bus() {
  kubectl -n starfleet get eb,statefulsets,pods,services,configmaps,secrets,pvc | grep "eventbus-${1:-default}\|^eventbus"
}
```

## Practice tasks

- Create an EventBus named `default` with three replicas. Name the five kinds of objects that the controller builds and the three containers of a server pod.
- Read `status.config.jetstream.url` of the bus. Read the merged `streamConfig` after you set `maxAge: 24h`.
- Create an EventSource with `eventBusName` set to a bus that does not exist. Read its status, then create the bus and see what happens.
- Create a second bus named `audit` in the same namespace. Use `eventBusName` on an EventSource and a Sensor to send one pipeline through it.
- Delete the pod of a Sensor, send an event while it is gone, and read the log of the new pod.
- Add `persistence` to a bus. List the claims, delete one server pod, and check that its claim stays.
- Read the ConfigMap `argo-events-controller-config` in `argo-events`. Find the versions and the default stream properties.
