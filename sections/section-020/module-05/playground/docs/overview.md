# Overview: Observing And Securing The Components (Playground)

This is a playground, not a lab. It starts a fresh cluster with Argo Workflows and Argo Events installed, and then waits. There is no task, no `astrona submit` and no pass or fail. Build objects, break them, run `astrona destroy` and start again.

## What is in the environment

- A kind cluster running Kubernetes 1.35. `kubectl` points at it as the cluster administrator.
- Argo Events v1.9.6 in `argo-events`, installed for the whole cluster, and Argo Workflows v3.7.3 in `argo`. The validating webhook is not installed.
- In `starfleet`: an EventBus named `default` with three replicas, the pod `shuttle` with `curl`, and the service accounts `event-trigger` (may create Workflows) and `workflow-runner` (the identity of Workflow pods). In `outpost`: the pod `drifter` with `curl`.
- No EventSource and no Sensor exists.

## Helpers

Paste these once in each new terminal. `eslog` and `snlog` read the logs of the pods of an EventSource or a Sensor, `ctllog` reads the log of the controller, and `post` sends a JSON body to a Service and a path in `starfleet`.

```sh
eslog() { kubectl -n starfleet logs -l "eventsource-name=$1" --tail="${2:-30}"; }
snlog() { kubectl -n starfleet logs -l "sensor-name=$1" --tail="${2:-30}"; }
ctllog() { kubectl -n argo-events logs deploy/controller-manager --tail="${1:-30}"; }
post() {
  kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' \
    -X POST -H 'Content-Type: application/json' -d "$3" "http://$1/$2"
}
```

Use `post fleet-eventsource-svc:12000 report '{"ship":"scout"}'` to send an event to the EventSource `fleet`.

## Practice tasks

- Create a Sensor without a `serviceAccountName`, send an event, and find the `Forbidden` line in its log. Test the same action with `kubectl auth can-i --as`, then add the identity.
- List the rights of the service account `event-trigger` with `kubectl auth can-i --list`.
- Set `LOG_LEVEL` to `debug` for an EventSource and compare its log before and after.
- Fetch the metrics page of the controller from `shuttle` and list the names that start with the prefix of Argo Events.
- Send an event to an EventSource from `drifter` in `outpost`, then add a NetworkPolicy and send it again. Find out if your cluster enforces it.
- Write a NetworkPolicy that selects a Sensor and allows only egress to the bus, DNS and the API server. Find out what stops working when you leave one out.
- Create an EventSource with `eventBusName` set to a bus that does not exist, and read the reason.
- Change the `eventName` of a dependency and compare the logs of the EventSource and the Sensor.
