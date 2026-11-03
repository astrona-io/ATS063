# Question

Solve this question on: `terminal`

The namespace `starfleet` runs a Prometheus server (Deployment `prometheus`) that should scrape the Argo Events controller. The controller runs in the namespace `argo-events` and serves its metrics on port 7777 at `/metrics`. The server was configured with the ConfigMap `prometheus-config`, but the job `argo-events-controller` has no working target: the query `up{job="argo-events-controller"}` returns no series.

Repair the configuration so that:

1. The job `argo-events-controller` discovers the pods of the namespace where the controller runs.
2. The relabel rule connects to the port on which the controller serves its metrics.
3. The server reads the new configuration and reports the target as up.

Constraints: keep the job name, the discovery role `pod` and the scrape interval. Do not change the service account, the ClusterRole or the controller. The server can be queried from the pod `shuttle` in `starfleet` at `http://prometheus.starfleet.svc:9090/api/v1/query`. `kubectl` already points at the cluster as the cluster administrator.
