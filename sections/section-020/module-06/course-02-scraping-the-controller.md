# Scraping The Controller

A Prometheus server reads a configuration file that lists scrape jobs. A job says where to find targets and how to turn what it finds into an address. The playground runs a server with one job for the controller. This part reads that configuration, asks the server for its targets, and runs the first query.

## Read the configuration

The configuration is in the ConfigMap `prometheus-config`:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet get configmap prometheus-config -o jsonpath='{.data.prometheus\.yml}'
```

It has three parts that matter here:

- `scrape_interval: 10s` sets how often every target is read.
- `kubernetes_sd_configs` with `role: pod` asks the Kubernetes API for the pods of the namespace `argo-events`. Each pod becomes a possible target and receives labels that start with `__meta_kubernetes_`.
- `relabel_configs` changes the labels of a target before it is scraped. This job sets the label `__address__`, which is the address that Prometheus connects to, to the pod IP and the port 7777.

Pod discovery needs the right to list pods across the cluster. The playground gives the service account `prometheus` a ClusterRole for that:

```sh
kubectl get clusterrole prometheus-pod-discovery -o yaml
```

The rule allows `get`, `list` and `watch` on `pods`. Without it, Prometheus finds no targets and logs a `forbidden` error.

## Why the address is set by relabeling

With pod discovery, Prometheus creates one target for each port that a pod declares. A pod that declares no port gets one target without a port, which Prometheus cannot scrape. The relabel rule builds the address from the pod IP and the port that you choose, so the job works whatever the pod declares.

## Ask for the targets

The API of the server is at `/api/v1`. The helper from the overview of the playground calls it through the pod `shuttle`. Without the helper, use `curl` directly:

```sh
kubectl -n starfleet exec shuttle -- curl -s http://prometheus.starfleet.svc:9090/api/v1/targets
```

The reply is JSON. The list `activeTargets` has one entry for each target, with its labels, the URL it scrapes, the field `health` and the field `lastError`. The health is `up` after a successful scrape and `down` after a failed one, and `lastError` holds the reason.

Wait about twenty seconds after the server starts and ask again. The entry for the controller should have the health `up`.

## Run the first query

Every successful or failed scrape produces the metric `up` with the value 1 or 0:

```sh
kubectl -n starfleet exec shuttle -- curl -s -G http://prometheus.starfleet.svc:9090/api/v1/query --data-urlencode 'query=up{job="argo-events-controller"}'
```

The reply is JSON with a result list. Each result has a `metric` object with labels and a `value` pair of a timestamp and the value as a string. The value `"1"` means the last scrape worked.

The query language selects series by label. `up{job="argo-events-controller"}` selects the series of `up` that carry that label. Remove the selector to see every target.

## Where the first fault shows

When a job finds nothing, the reply of `targets` has no entry for it, and `up` has no series. When a job finds a pod but cannot connect, the entry exists with the health `down` and a `lastError` such as a refused connection. Read both places before you change the configuration:

- No entry: the discovery is wrong. Check the namespace, the role and the right to list pods.
- Entry with `down`: the address is wrong. Check the port in the relabel rule and test it by hand from `shuttle`.

## Common pitfalls

> [!WARNING]
> - **Reading a missing series as a healthy target.** No `up` series means no target exists.
> - **Forgetting that `__address__` decides the port.** A wrong port gives a target that is `down`.
> - **Querying before the first scrape.** Wait for at least one interval.
> - **Giving Prometheus a Role instead of a ClusterRole for pod discovery across namespaces.** Discovery in `argo-events` from `starfleet` needs the right in that namespace.
