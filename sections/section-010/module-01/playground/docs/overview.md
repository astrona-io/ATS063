# Overview: Event-Driven Automation And The Argo Events Flow (Playground)

This is a playground, not a lab. It starts a fresh cluster with Argo Workflows and Argo Events installed and waits. There is no task, no `astrona submit` and no pass or fail. Build objects, break them, run `astrona destroy` and start again.

## What is in the environment

- A kind cluster running Kubernetes 1.35. `kubectl` points at it as the cluster administrator.
- Argo Events v1.9.6 in the namespace `argo-events`, installed for the whole cluster. The Deployment `controller-manager` reconciles EventBus, EventSource and Sensor objects in every namespace.
- Argo Workflows v3.7.3 in the namespace `argo`. The Deployment `workflow-controller` runs Workflow objects.
- In `starfleet`: the pod `shuttle` with `curl`, and the service accounts `event-trigger` (may create Workflows) and `workflow-runner` (the identity of Workflow pods).
- In `outpost`: the pod `drifter` with `curl`, for requests from another namespace.
- No EventBus, EventSource or Sensor exists.

## Helpers

Paste these once in each new terminal. `send_event` posts a JSON message to a webhook EventSource Service in `starfleet`. `wf_messages` prints the name and the first argument of every Workflow.

```sh
send_event() {
  kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' \
    -X POST -H 'Content-Type: application/json' \
    -d "{\"message\":\"$3\"}" "http://$1-eventsource-svc:12000/$2"
}
wf_messages() {
  kubectl -n starfleet get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[0].value}{"\n"}{end}'
}
```

Use them like this: `send_event webhook example "hello"` posts to the Service `webhook-eventsource-svc` at the path `/example`.

## Practice tasks

- Create an EventBus named `default` with three JetStream replicas, an EventSource named `webhook` with one event, and a Sensor that creates a Workflow. Send an event and read the message in the Workflow.
- Change the `eventName` in the dependency of the Sensor to a name that does not exist. Send an event and find out which stage shows the problem, and which does not.
- Remove `spec.service` from the EventSource and look at the Services in `starfleet`. Send a request from `shuttle` and read the `curl` error.
- Remove the `serviceAccountName` line from the Sensor and read the Sensor pod log after an event. Put it back.
- Send the same event from `drifter` in `outpost` with the full Service name `webhook-eventsource-svc.starfleet` and compare it with the short name from `shuttle`.
- Add a second event under `webhook` with another port and path, and give the Service the second port.
