# Overview: Receiving Events With EventSources (Playground)

This is a playground, not a lab. It starts a fresh cluster with Argo Workflows and Argo Events installed and an EventBus ready, and then waits. There is no task, no `astrona submit` and no pass or fail. Build objects, break them, run `astrona destroy` and start again.

## What is in the environment

- A kind cluster running Kubernetes 1.35. `kubectl` points at it as the cluster administrator.
- Argo Events v1.9.6 in `argo-events` and Argo Workflows v3.7.3 in `argo`, both installed for the whole cluster.
- In `starfleet`: the EventBus `default` with three JetStream replicas, the pod `shuttle` with `curl`, and the service accounts `event-trigger` (may create Workflows) and `workflow-runner` (the identity of Workflow pods).
- In `outpost`: the pod `drifter` with `curl`.
- No EventSource and no Sensor exists.

## Helpers

Paste these once in each new terminal. `post` sends a JSON body to a Service and a path in `starfleet`, with an optional token. `sensor_log` prints the last lines of the log of one Sensor.

```sh
post() {
  kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' \
    -X POST -H 'Content-Type: application/json' ${4:+-H "Authorization: Bearer $4"} \
    -d "$3" "http://$1/$2"
}
sensor_log() {
  kubectl -n starfleet logs -l sensor-name="$1" --tail="${2:-20}"
}
```

Use them like this: `post webhook-eventsource-svc:12000 order '{"item":"fuel"}' mytoken` and `sensor_log orders`.

## Practice tasks

- Create a webhook EventSource with two events on two ports, a Sensor with a log trigger for each event, and read what each Sensor logs. Then call `/health` on both ports.
- Protect one event with `authSecret`. Send a request without a token, with a wrong token and with the right token, and compare the Sensor logs.
- Create your own Service with the selector `eventsource-name` and send a request through it from `drifter` in `outpost`.
- Create a calendar EventSource with an interval of 10 seconds and one with a schedule of `* * * * *`. Compare when their first events arrive.
- Add `metadata` to a calendar event and read it in the Sensor log. Then use `metadata` as a dataKey in a Workflow trigger.
- Create a resource EventSource for Secrets without giving its service account the permission. Read the EventSource pod log, then add the Role and the binding.
- Watch ConfigMaps with `afterStart: false` and restart the EventSource pod. Count the ADD events.
