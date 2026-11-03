# Summary

The Argo Events controller serves Prometheus metrics on port 7777 at `/metrics`. Read the page by hand from a pod before you build anything on it, and print the `# TYPE` lines to see the metric names of your version. Check the ports that the pods of an EventSource and a Sensor declare, and test the page on the port that answers, because metrics, ports and names can differ between versions.

A Prometheus server reads scrape jobs from its configuration. A job with `kubernetes_sd_configs` and `role: pod` finds the pods of the listed namespaces and needs the right to list pods. Relabeling turns discovery labels into an address. The rule on `__address__` fixes the port and works for pods that declare no port. A `keep` rule limits the job to pods that carry a label, and pod labels are written `__meta_kubernetes_pod_label_<name>` with underscores.

The HTTP API shows the state. `/api/v1/targets` lists the targets with `health` and `lastError`. `/api/v1/query` runs a query, and `up` is 1 for a successful scrape and 0 for a failed one. A job with no entry finds no pod, and a job with an entry that is `down` has a wrong address or port.

A changed ConfigMap reaches the pod after some time, so reload with `POST /-/reload` only after the file has changed in the pod, or restart the Deployment. Write two alert rules for a component: `up == 0` for a target that fails, and `absent(up{...})` for a target that does not exist. Use `for` to ignore single failed scrapes. Alertmanager is the service that sends a firing alert onward.

Key facts:

- The Prometheus image in this course is `quay.io/prometheus/prometheus:v3.1.0`.
- The flag `--web.enable-lifecycle` enables `POST /-/reload`.
- The query `up{job="argo-events-controller"}` returns no series when no target exists.
- A counter is a total, so use a rate to read it.

<!-- astrona:playground:destroy -->
