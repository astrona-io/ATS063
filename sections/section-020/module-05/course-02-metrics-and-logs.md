# Metrics And Logs

Every component of Argo Events writes logs, and the controller also serves metrics. Logs tell you what one component did with one event. Metrics tell you how often something happens over time. This part reads both, sets the log level of an EventSource and a Sensor, and shows what each log is good for.

## What each component logs

- The controller logs when it reconciles an EventBus, an EventSource or a Sensor, and when it cannot build the objects. A missing bus, an invalid spec and a failed update appear here.
- An EventSource pod logs the start of each event, the connection it opens to the bus, and errors from the source, such as a refused connection to a broker.
- A Sensor pod logs the connection to the bus, the dependencies it waits for, the triggers it runs and the errors from them, such as a `Forbidden` answer from the API server.

Logs are lines of JSON with a level, a time and a message. The names of the keys depend on the component and the version, so read a real line before you write a filter for it.

## Read the logs

Save these helpers, which pick the pods of an object by their labels. The labels are `eventsource-name` and `sensor-name`, as the controller module described.

```sh
eslog() { kubectl -n starfleet logs -l "eventsource-name=$1" --tail="${2:-30}"; }
snlog() { kubectl -n starfleet logs -l "sensor-name=$1" --tail="${2:-30}"; }
ctllog() { kubectl -n argo-events logs deploy/controller-manager --tail="${1:-30}"; }
```

Read the controller first, because it runs without any object of yours:

```sh
ctllog 20
```

You see the start of the controller and the leader election of the controller itself. Keep this command in mind: when you create a wrong object, the first signal is often a line here.

## Follow one event through three logs

Create a pipeline whose Sensor has an identity that may create Workflows. Save this as `fleet.yaml`:

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

<!-- astrona:playground:renew -->

Apply it and wait until both pods run:

```sh
kubectl apply -f fleet.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=fleet --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=fleet --timeout=180s
```

Send one event, then read the log of both pods:

```sh
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -d '{"ship":"scout"}' http://fleet-eventsource-svc:12000/report
eslog fleet 10
snlog fleet 10
```

The log of the EventSource has a line for the request it received. The log of the Sensor has lines for the event it received and for the trigger it ran. If a line is missing in the EventSource log, the request never reached the pod: look at the Service and the network. If the EventSource has the line and the Sensor does not, the event did not pass the bus: look at the bus and the names of the dependency. If both have lines and no Workflow exists, the trigger failed: read the error in the Sensor log.

## Change the log level

The log level of a component is set with the environment variable `LOG_LEVEL`, as the controller module explained. Set it to `debug` for the EventSource pod through the container in the template. Save this as `fleet-debug.yaml`, which changes only the EventSource:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: fleet
  namespace: starfleet
spec:
  template:
    container:
      env:
        - name: LOG_LEVEL
          value: debug
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

Apply it, wait for the replacement pod, send an event and read the log again:

```sh
kubectl apply -f fleet-debug.yaml
kubectl -n starfleet get pods -l eventsource-name=fleet
eslog fleet 40
```

Repeat the second command until one pod is `Running`. The log has more lines than before. Debug logs are for a short search, because they are long and can hold event data.

## Read the metrics of the controller

The controller serves Prometheus metrics on the port 7777 at the path `/metrics`. The pod `shuttle` has `curl`, and the namespace `argo-events` has one pod in the playground, so you can read its address and fetch the page:

```sh
IP=$(kubectl -n argo-events get pods -o jsonpath='{.items[0].status.podIP}')
kubectl -n starfleet exec shuttle -- curl -s "http://$IP:7777/metrics" | head -n 30
```

The page is plain text with one metric on each line and lines that begin with `#` for the help text and the type. The text can be long, so the command shows the first thirty lines. Count the metrics that belong to Argo Events by filtering for its prefix:

```sh
kubectl -n starfleet exec shuttle -- curl -s "http://$IP:7777/metrics" | grep -c '^argo_events'
```

If the number is `0`, read the names in the full page and use the prefix you find. The metric names can differ between versions, so confirm them against your page before you build a dashboard or an alert.

A Prometheus server finds this endpoint through a ServiceMonitor or a scrape annotation. The playground has no Prometheus, so this part stops at reading the page.

## Delete what you created

```sh
kubectl -n starfleet delete eventsource fleet
kubectl -n starfleet delete sensor fleet
```

## Common pitfalls

> [!WARNING]
> - **Reading only one log.** An event crosses three components. Read the log of each in order until you find the first one without the line.
> - **Using `kubectl logs deploy/<name>` for a replicated object.** It reads one pod. Use the label selector to see every pod.
> - **Leaving `LOG_LEVEL` on `debug`.** The logs grow quickly and can hold event bodies.
> - **Relying on a metric name from memory.** Print the page of your version first.
