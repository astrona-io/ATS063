# Overview: Metrics With Prometheus (Playground)

This is a playground, not a lab. It starts a fresh cluster with Argo Workflows and Argo Events installed, and then waits. There is no task, no `astrona submit` and no pass or fail. Build objects, break them, run `astrona destroy` and start again.

## What is in the environment

- A kind cluster running Kubernetes 1.35. `kubectl` points at it as the cluster administrator.
- Argo Events v1.9.6 in `argo-events`, installed for the whole cluster, and Argo Workflows v3.7.3 in `argo`.
- In `starfleet`: an EventBus named `default`, the pod `shuttle` with `curl`, the service accounts `event-trigger` and `workflow-runner`, and a Prometheus v3.1.0 server (Deployment and Service `prometheus` on port 9090) with the ConfigMap `prometheus-config`. The server finds pods through the Kubernetes API and has one scrape job, `argo-events-controller`.
- No EventSource and no Sensor exists.

## Helpers

```sh
prom() { kubectl -n starfleet exec shuttle -- curl -s -G "http://prometheus.starfleet.svc:9090/api/v1/$1" "${@:2}"; }
```

Use `prom query --data-urlencode 'query=up'` to run a query, `prom targets` to list the targets and `prom rules` to list the rule groups.

## Practice tasks

- List the targets of Prometheus and find the one for the controller.
- Run the query `up` and read the value for the job `argo-events-controller`.
- Fetch `http://<pod ip>:7777/metrics` of the controller from `shuttle` and read the metric names.
- Create an EventSource and a Sensor, and look at the ports of their pods.
- Add a scrape job to the ConfigMap, reload Prometheus with `POST /-/reload`, and read the new target.
- Add a rule file with an alert on `up == 0` and read it under `prom rules`.
