# Overview: Reacting With Sensors And Triggers (Playground)

This is a playground, not a lab. It starts a fresh cluster with Argo Workflows and Argo Events installed and an EventBus ready, and then waits. There is no task, no `astrona submit` and no pass or fail. Build objects, break them, run `astrona destroy` and start again.

## What is in the environment

- A kind cluster running Kubernetes 1.35. `kubectl` points at it as the cluster administrator.
- Argo Events v1.9.6 in `argo-events` and Argo Workflows v3.7.3 in `argo`, both installed for the whole cluster.
- In `starfleet`: the EventBus `default` with three JetStream replicas, the pod `shuttle` with `curl`, and the service accounts `event-trigger` (may create Workflows) and `workflow-runner` (the identity of Workflow pods).
- No EventSource and no Sensor exists.

## Helpers

Paste these once in each new terminal. `post` sends a JSON body to a Service and a path in `starfleet`. `sensor_log` prints the last lines of the log of one Sensor.

```sh
post() {
  kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' \
    -X POST -H 'Content-Type: application/json' -d "$3" "http://$1/$2"
}
sensor_log() {
  kubectl -n starfleet logs -l sensor-name="$1" --tail="${2:-20}"
}
```

Use them like this: `post gateway-eventsource-svc:12000 alpha '{"ship":"scout"}'` and `sensor_log pair`.

## Practice tasks

- Create a webhook EventSource with two events and a Sensor with two dependencies and a log trigger. Send one event, then the other, and read the Sensor log after each.
- Add a second trigger to that Sensor with the condition `alpha || beta`, and compare when the two triggers run.
- Create a second Sensor on one of the events and send one request. Read both logs.
- Create a Sensor that makes a Workflow and fills a parameter with `dataTemplate`. Use the sprig functions `upper`, `lower` and `title`.
- Make a parameter read a key that the event does not have, first without and then with `value`. Compare the Sensor logs.
- Change the operation of a `metadata.generateName` parameter from `append` to `prepend` and read the names of the new Workflows.
- Create a ConfigMap from an event. Remove the Role of the service account and read the Sensor log.
- Submit a Workflow with the `argoWorkflow` trigger and list it by the label `events.argoproj.io/sensor`.
