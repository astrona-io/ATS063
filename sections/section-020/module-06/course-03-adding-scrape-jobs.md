# Adding Scrape Jobs

The playground server scrapes only the controller. To collect metrics from other pods, you add a job to the ConfigMap and make the server read it again. This part adds a job for the EventSource and Sensor pods of a pipeline and shows the two ways to reload.

## Decide what the job selects

Pod discovery returns every pod of the namespaces you list. A job usually keeps only the pods that you want. Two labels identify the pods built by the controller: `eventsource-name` and `sensor-name`. Discovery exposes pod labels as meta labels, with characters that are not letters or digits replaced by underscores. The label `eventsource-name` becomes `__meta_kubernetes_pod_label_eventsource_name`.

A `keep` action drops every target whose source label does not match the regular expression. With the regular expression `.+` on the label, a pod is kept only if it carries the label.

## Check that the port serves metrics first

A job for a port that serves nothing creates targets that are `down`. Test your pods as the first part showed, and use the port that answers. This part assumes that you found a pod page on port 7777. If your pods answer on another port, use that port in the rule.

## Create a pipeline to scrape

Save this as `fleet.yaml` and apply it:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: fleet
  namespace: starfleet
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    report:
      port: "12000"
      endpoint: /report
      method: POST
```

<!-- astrona:playground:renew -->

```sh
kubectl apply -f fleet.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=fleet --timeout=180s
```

## Add the job

Save the new configuration as `prometheus-config.yaml`. It keeps the old job and adds a second one for the pods of EventSources in `starfleet`:

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
      - job_name: argo-events-eventsources
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names: [starfleet]
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_eventsource_name]
            regex: .+
            action: keep
          - source_labels: [__meta_kubernetes_pod_ip]
            regex: (.+)
            target_label: __address__
            replacement: "${1}:7777"
          - source_labels: [__meta_kubernetes_pod_label_eventsource_name]
            target_label: eventsource
```

The last rule copies the label value to a label named `eventsource`, so that a query can select one EventSource.

## Make the server read it again

Apply the ConfigMap. A ConfigMap that is mounted in a pod is refreshed in the pod after some time, so wait before the next step:

```sh
kubectl apply -f prometheus-config.yaml
```

The server was started with `--web.enable-lifecycle`, so it can reload its configuration through an HTTP call. If the reload comes before the file is refreshed, the server reads the old file. The safe way is to restart the pod:

```sh
kubectl -n starfleet rollout restart deployment/prometheus
kubectl -n starfleet rollout status deployment/prometheus --timeout=180s
```

The other way is a call to the lifecycle endpoint after the file has changed in the pod:

```sh
kubectl -n starfleet exec shuttle -- curl -s -X POST http://prometheus.starfleet.svc:9090/-/reload
```

Check that the new file is in the pod before you reload, by printing it from the pod:

```sh
kubectl -n starfleet exec deploy/prometheus -- cat /etc/prometheus/prometheus.yml
```

## Confirm the new target

Wait one scrape interval, then query:

```sh
kubectl -n starfleet exec shuttle -- curl -s -G http://prometheus.starfleet.svc:9090/api/v1/query --data-urlencode 'query=up{job="argo-events-eventsources"}'
```

A result with the label `eventsource="fleet"` shows that the target exists. The value tells you if the scrape worked. If the value is `0`, read `lastError` in the targets and compare the port with the result of your test.

## Restore the playground

```sh
kubectl -n starfleet delete -f fleet.yaml
```

## Common pitfalls

> [!WARNING]
> - **Reloading before the mounted file has changed.** The server keeps the old configuration. Print the file in the pod first, or restart the pod.
> - **Writing the label as `eventsource-name` in a rule.** In relabeling it is `__meta_kubernetes_pod_label_eventsource_name`.
> - **Leaving out `action: keep`.** The job then scrapes every pod of the namespace.
> - **Adding a job for a port that serves nothing.** The targets are `down` and the alerts are noise.
