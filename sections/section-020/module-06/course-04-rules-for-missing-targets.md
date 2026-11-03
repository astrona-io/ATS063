# Rules For Missing Targets

A dashboard shows a problem only when someone looks at it. A rule evaluates a query at a fixed interval and records the result. An alerting rule fires when its query returns a result for long enough. This part writes two rules for the controller: one for a target that is down, and one for a target that is missing. It reads their state through the HTTP API, and does not need a notification service.

## Two different faults

The metric `up` has the value 0 when a scrape fails. The query `up == 0` finds those targets. A target that does not exist has no `up` series at all, so `up == 0` returns nothing and stays silent. For a missing target, use the function `absent`, which returns one series with the value 1 when its argument matches nothing:

```text
absent(up{job="argo-events-controller"})
```

A good monitoring set has both rules, because a controller that was deleted is as serious as a controller that does not answer.

## Add a rule file

Save the configuration with a rule file as `prometheus-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: starfleet
data:
  prometheus.yml: |
    global:
      scrape_interval: 10s
      evaluation_interval: 10s
    rule_files:
      - /etc/prometheus/rules.yml
    scrape_configs:
      - job_name: argo-events-controller
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names: [argo-events]
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_ip]
            regex: (.+)
            target_label: __address__
            replacement: "${1}:7777"
  rules.yml: |
    groups:
      - name: argo-events
        rules:
          - alert: ControllerDown
            expr: up{job="argo-events-controller"} == 0
            for: 30s
            labels:
              severity: critical
          - alert: ControllerMissing
            expr: absent(up{job="argo-events-controller"})
            for: 30s
            labels:
              severity: critical
```

The key `for` keeps an alert pending until its query has returned a result for that long. This avoids alerts for a single failed scrape.

<!-- astrona:playground:renew -->

Apply the file and restart the server. Both files are in the same ConfigMap, so the server reads both:

```sh
kubectl apply -f prometheus-config.yaml
kubectl -n starfleet rollout restart deployment/prometheus
kubectl -n starfleet rollout status deployment/prometheus --timeout=180s
```

## Read the rules

```sh
kubectl -n starfleet exec shuttle -- curl -s http://prometheus.starfleet.svc:9090/api/v1/rules
```

The reply lists the group `argo-events` and its two rules, with the field `state` and the field `health`. The state of both alerts is `inactive` while the controller is healthy.

## Cause a fault and watch the state

Scale the controller to zero. This stops the processing of every EventSource and Sensor in the cluster, so do it only in the playground:

```sh
kubectl -n argo-events scale deployment controller-manager --replicas=0
```

Wait about one minute. Prometheus drops the target because the pod no longer exists, so `up` has no series, and the rule `ControllerMissing` becomes pending and then firing. Read the alerts:

```sh
kubectl -n starfleet exec shuttle -- curl -s http://prometheus.starfleet.svc:9090/api/v1/alerts
```

The rule `ControllerDown` does not fire in this case, because no series with the value 0 exists. This shows why the second rule is needed.

Scale the controller back:

```sh
kubectl -n argo-events scale deployment controller-manager --replicas=1
kubectl -n argo-events rollout status deployment/controller-manager --timeout=180s
```

After a minute the alert returns to inactive.

## Where the notification goes

A firing alert is only a state in Prometheus. A separate service, Alertmanager, receives alerts from Prometheus and sends them to a person or a system. It is not part of this playground. The rules above are the part that you write for Argo Events.

## Common pitfalls

> [!WARNING]
> - **Writing only `up == 0`.** A deleted controller has no series and never fires.
> - **Leaving out `for`.** A single failed scrape then creates an alert.
> - **Scaling the controller to zero outside a test cluster.** No EventSource or Sensor is changed or created while it is gone.
> - **Putting the rule file in the config but not in `rule_files`.** The rules are never loaded.
