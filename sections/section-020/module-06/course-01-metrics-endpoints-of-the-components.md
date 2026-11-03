# Metrics Endpoints Of The Components

Prometheus collects metrics by reading a web page from each target at a fixed interval. The page is plain text. Each line is a metric name, optional labels and a value. Before you set up any collection, you need to know which pods serve such a page, on which port, and how to read it by hand.

## Which components serve metrics

The Argo Events controller serves metrics on port 7777 at the path `/metrics`. This is the endpoint this module scrapes. The EventSource and Sensor pods are built from the same image family, and the upstream project documents metrics for them as well. The set of metrics and the ports can differ between versions, so this part shows how to check your own cluster instead of listing names from memory.

## Read the controller page by hand

The namespace `argo-events` has one pod in the playground. Read its address and fetch the page from the pod `shuttle`:

<!-- astrona:playground:renew -->

```sh
IP=$(kubectl -n argo-events get pods -o jsonpath='{.items[0].status.podIP}')
kubectl -n starfleet exec shuttle -- curl -s "http://$IP:7777/metrics" | head -n 20
```

Every metric has two comment lines that start with `#`: the line `HELP` with a description and the line `TYPE` with one of `counter`, `gauge`, `histogram` or `summary`. A counter only grows. A gauge goes up and down. A histogram has several lines for each metric: buckets, a sum and a count.

Count the metrics that carry a prefix of Argo Events:

```sh
kubectl -n starfleet exec shuttle -- curl -s "http://$IP:7777/metrics" | grep '^# TYPE' | head -n 40
```

The list shows the names that your version serves. Metrics from the Go runtime and the process start with `go_` and `process_`. Metrics of Argo Events have their own prefix. Use the names that you see.

## Check the ports of an EventSource and a Sensor

Create a webhook EventSource and a Sensor. Save this as `fleet.yaml`:

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
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: fleet
  namespace: starfleet
spec:
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: report-dep
      eventSourceName: fleet
      eventName: report
  triggers:
    - template:
        name: run-report
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: report-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: main
                templates:
                  - name: main
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [echo, report]
```

```sh
kubectl apply -f fleet.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=fleet --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=fleet --timeout=180s
```

Print the ports that each pod declares:

```sh
kubectl -n starfleet get pod -l eventsource-name=fleet -o jsonpath='{.items[0].spec.containers[0].ports}{"\n"}'
kubectl -n starfleet get pod -l sensor-name=fleet -o jsonpath='{.items[0].spec.containers[0].ports}{"\n"}'
```

A pod lists only the ports that its template declares. If a metrics port is listed, try the page. If none is listed, a port can still be open, so try port 7777 directly:

```sh
ES=$(kubectl -n starfleet get pod -l eventsource-name=fleet -o jsonpath='{.items[0].status.podIP}')
kubectl -n starfleet exec shuttle -- curl -s -m 5 -o /dev/null -w '%{http_code}\n' "http://$ES:7777/metrics"
```

A status code `200` means the pod serves a metrics page there. A refused connection means that nothing listens on that port in your version. The result decides whether you add a scrape job for these pods in the third part.

## Clean up

```sh
kubectl -n starfleet delete -f fleet.yaml
```

## Common pitfalls

> [!WARNING]
> - **Copying metric names from a blog or from memory.** Print the page of your version first.
> - **Assuming that every component serves the same port.** Check the declared ports and test the page.
> - **Scraping through a Service that has no endpoints.** Read from the pod address when you test.
> - **Treating a counter as a current value.** A counter is the total since the start of the process, so use a rate.
