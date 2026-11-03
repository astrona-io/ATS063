# Overview: More EventSource Types (Playground)

This is a playground, not a lab. It starts a fresh cluster with Argo Workflows and Argo Events installed, an EventBus ready and a NATS server, and then waits. There is no task, no `astrona submit` and no pass or fail. Build objects, break them, run `astrona destroy` and start again.

## What is in the environment

- A kind cluster running Kubernetes 1.35. `kubectl` points at it as the cluster administrator.
- Argo Events v1.9.6 in `argo-events` and Argo Workflows v3.7.3 in `argo`, both installed for the whole cluster.
- In `starfleet`: the EventBus `default` with three JetStream replicas, the NATS server pod `nats` with the Service `nats` on port 4222, the pod `natsbox` with the `nats` tool, the pod `shuttle` with `curl`, and the service accounts `event-trigger` (may create Workflows) and `workflow-runner` (the identity of Workflow pods).
- In `outpost`: the pod `drifter` with `curl`.
- No EventSource and no Sensor exists.

## Helpers

Paste these once in each new terminal. `publish` sends a message to a NATS subject. `sensor_log` prints the last lines of the log of one Sensor.

```sh
publish() {
  kubectl -n starfleet exec natsbox -- nats pub --server nats://nats.starfleet.svc:4222 "$1" "$2"
}
sensor_log() {
  kubectl -n starfleet logs -l sensor-name="$1" --tail="${2:-20}"
}
```

Use them like this: `publish fleet.arrival '{"ship":"scout"}'` and `sensor_log radio-log`.

## Practice tasks

- Create a NATS EventSource for the subject `fleet.arrival` and a Sensor with a log trigger. Publish a JSON message and a text message and compare the results with and without `jsonBody`.
- Add a Workflow trigger that copies `body.ship` into a Workflow parameter.
- Change the spec of the EventSource while you publish a message every second, and count which messages the Sensor received.
- Create one EventSource with a webhook, a calendar and a NATS event. Depend on each event in its own trigger with `conditions`.
- Use a name for a webhook event and a NATS event that is the same, and read the status of the EventSource.
- Set `replicas: 2` on the NATS EventSource and find out which pod is the leader.
