# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-06/labs/lab-01
```

Look at the symptoms:

```sh
kubectl -n starfleet exec shuttle -- curl -s http://prometheus.starfleet.svc:9090/api/v1/targets
kubectl -n starfleet get configmap prometheus-config -o jsonpath='{.data.prometheus\.yml}'
kubectl -n argo-events get pods
```

The list of targets has no entry for the job. The configuration names the namespace `argo-event`, but the controller runs in `argo-events`, so discovery finds no pod. The relabel rule also sets the port 7778.

## Step 1: Correct the namespace and the port

Save the corrected ConfigMap as `prometheus-config.yaml`:

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
```

```sh
kubectl apply -f prometheus-config.yaml
astrona submit
```

The checks `job-discovery` and `job-port` pass. The check `target-up` still fails, because the server runs with the old file.

## Step 2: Make the server read the file

A ConfigMap that is mounted in a pod is refreshed after some time, and the server reads its file only at start or at a reload. Restarting the Deployment is the safe way:

```sh
kubectl -n starfleet rollout restart deployment/prometheus
kubectl -n starfleet rollout status deployment/prometheus --timeout=180s
```

Wait one scrape interval and query:

```sh
kubectl -n starfleet exec shuttle -- curl -s -G http://prometheus.starfleet.svc:9090/api/v1/query --data-urlencode 'query=up{job="argo-events-controller"}'
astrona submit
```

The value `"1"` in the reply means the last scrape worked. All three checks pass.

## Why it failed

The wrong namespace gave a job with no pods, so there was no entry in the targets and no `up` series. The wrong port would have given a target with the health `down` and a connection error in `lastError`.
