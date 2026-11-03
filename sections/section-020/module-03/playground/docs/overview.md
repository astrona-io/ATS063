# Overview: Trigger Types, Policies And Delivery Guarantees (Playground)

This is a playground, not a lab. It starts a fresh cluster with Argo Workflows and Argo Events installed, and then waits. There is no task, no `astrona submit` and no pass or fail. Build objects, break them, run `astrona destroy` and start again.

## What is in the environment

- A kind cluster running Kubernetes 1.35. `kubectl` points at it as the cluster administrator.
- Argo Events v1.9.6 in `argo-events` and Argo Workflows v3.7.3 in `argo`, both installed for the whole cluster.
- In `starfleet`: the EventBus `default` with three replicas, the pod and Service `beacon`, the EventSource `gate`, the pod `shuttle` with `curl`, and the service accounts `event-trigger` (may create Workflows) and `workflow-runner` (the identity of Workflow pods).
- The service `beacon` listens on port 8080 and has two paths. The path `/cgi-bin/hook` needs the header `X-Fleet-Token: nova`, answers `503` to a body with the word `poison`, and answers `503` to a body with the word `flaky` until it has seen that body three times. The path `/cgi-bin/dead` stores every body. The records are in `/tmp/state` in the pod `beacon`.
- The EventSource `gate` has the webhook event `relay` on port 12000 and the event `board` on port 13000. Its Service is `gate-eventsource-svc`. No Sensor exists.

## Helpers

Paste these once in each new terminal. `post` sends a JSON body to a Service and a path in `starfleet`. `sensor_log` prints the last lines of the log of one Sensor. `beacon_log` prints one of the records of the beacon. `conditions` prints the conditions of a Sensor.

```sh
post() {
  kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' \
    -X POST -H 'Content-Type: application/json' -d "$3" "http://$1/$2"
}
sensor_log() {
  kubectl -n starfleet logs -l sensor-name="$1" --tail="${2:-20}"
}
beacon_log() {
  kubectl -n starfleet exec beacon -- cat "/tmp/state/${1:-requests.log}"
}
conditions() {
  kubectl -n starfleet get sensor "$1" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'
}
```

The call `post gate-eventsource-svc:12000 relay '{"id":"scout-1"}'` sends one event.

## Practice tasks

- Write a Sensor with a log trigger and an HTTP trigger on the event `relay`. Send an event and find its trace in the Sensor log and in `requests.log`.
- Change the HTTP trigger to the method `PUT`, then to `HEAD`. Read the conditions of the Sensor and explain why one of them is rejected.
- Write a Sensor that patches a ConfigMap from the event `board`. Remove the extra Role and read the error in the Sensor log. Add the Role and try the strategies `application/json-patch+json` and `application/merge-patch+json`.
- Write an `argoWorkflow` trigger with the operation `submit`, and then one with an empty operation. Read the conditions of the Sensor for the second one.
- Send the body `{"id":"poison-1"}` to an HTTP trigger without a `policy`. Read the log and explain why the Sensor reports success.
- Add `policy.status.allow` and then a `retryStrategy` without `atLeastOnce`. Count the requests in `requests.log`. Add `atLeastOnce: true` and count again.
- Create a `policy.k8s` trigger for a Workflow that always fails. Compare `errorOnBackoffTimeout` with `true` and `false`, and measure the time with `steps: 5`, `duration: 1s` and `factor: 2`.
- Add a `dlqTrigger` without `atLeastOnce` and read the condition `TriggersProvided`. Fix it and read `dead.log`.
- Set `rateLimit` to one request per minute, send three events, and watch `accepted.log`. Then add a failing body and see how the retries use the tokens.
- Set `revisionHistoryLimit` to `1`, change the Sensor three times, and list the ReplicaSets of its Deployment.
