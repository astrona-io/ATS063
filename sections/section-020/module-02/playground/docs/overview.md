# Overview: Sensor Evaluation (Playground)

This is a playground, not a lab. It starts a fresh cluster with Argo Workflows and Argo Events installed, and then waits. There is no task, no `astrona submit` and no pass or fail. Build objects, break them, run `astrona destroy` and start again.

## What is in the environment

- A kind cluster running Kubernetes 1.35. `kubectl` points at it as the cluster administrator.
- Argo Events v1.9.6 in `argo-events` and Argo Workflows v3.7.3 in `argo`, both installed for the whole cluster.
- In `starfleet`: the EventBus `default`, the EventSource `telemetry`, the pod `shuttle` with `curl`, and the service accounts `event-trigger` (may create Workflows) and `workflow-runner` (the identity of Workflow pods).
- The EventSource `telemetry` has three webhook events: `reading` on port `12000` and path `/reading`, `alert` on port `13000` and path `/alert`, and `ack` on port `14000` and path `/ack`. Its Service is `telemetry-eventsource-svc`.
- No Sensor exists.

## Helpers

Paste these once in each new terminal. `send` posts a JSON body to a port and a path of the EventSource Service. `sensor_log` prints the last lines of the log of one Sensor. `workflows` lists the Workflows with the value of their first parameter.

```sh
send() {
  kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' \
    -X POST -H 'Content-Type: application/json' -d "$3" \
    "http://telemetry-eventsource-svc:$1/$2"
}
sensor_log() {
  kubectl -n starfleet logs -l sensor-name="$1" --tail="${2:-20}"
}
workflows() {
  kubectl -n starfleet get workflows \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[0].value}{"\n"}{end}'
}
```

## Practice tasks

- Create a Sensor on the event `reading` with a data filter that accepts a temperature of at least 80. Send the temperature 80 and the temperature 79 and read which one starts a Workflow.
- Write a string filter with the value `hull` and send the sensor names `hull`, `hull-spare` and `overhull`. Then anchor the value with `^` and `$` and repeat.
- Add a second data filter to a dependency and set `dataLogicalOperator` to `or`. Send events that satisfy one filter only.
- Replace a data filter with an expr filter that reads two fields, and then with a script filter that returns a boolean.
- Create a Sensor with the dependencies `alert-dep` and `ack-dep` and no `conditions`. Send one alert and read the log to see that nothing runs.
- Write the conditions `(alert-dep || ack-dep)` and then `alert-dep && ack-dep`. Send two alerts and one acknowledgement in both cases and count the Workflows.
- Put a dependency name with a typo into `conditions`. Read the log of the Sensor pod and find the line about the mismatch.
- Add `conditionsReset` with a six-field cron expression and read `TriggersProvided` in the status. Then use a five-field expression.
- Add a jq transformation that upper-cases a field, and then write the same change as a Lua script.
- Make a transformation return a string instead of an object and watch the events disappear.
