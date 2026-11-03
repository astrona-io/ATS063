# Finding The Failing Component

A pipeline has an entry point, a bus and an exit point, and each can fail in a way that looks the same from outside: nothing happens. This part gives an order of checks that follows an event from the sender to the Workflow, and a table that links each symptom to the component that causes it. It ends with a pipeline that has three faults, so that you can follow the order step by step.

## Follow the event, not the objects

An event takes this path, and a fault at one step hides all later steps.

1. The sender reaches the Service of the EventSource.
2. The EventSource pod accepts the request and publishes it to the bus.
3. The bus stores it in a stream.
4. The Sensor pod receives it, if the name of its dependency matches the EventSource and the event.
5. The Sensor evaluates filters and conditions.
6. The trigger calls the API server with the identity of the Sensor.
7. The target object does what it should, for example a Workflow runs.

Checks go from the start of this path toward the end, because the first broken step explains everything after it.

## The order of checks

Run these in order and stop at the first one that shows a fault.

1. Status of the objects. `kubectl -n starfleet get eventbus,eventsource,sensor` shows if each object is `Deployed`. An object that is not `Deployed` has a reason in its status: `kubectl -n starfleet get eventsource <name> -o jsonpath='{.status.conditions}'`. A missing bus gives `EventBusNotFound`.
2. Pods. `kubectl -n starfleet get pods` shows if each component has a running pod. An object that is `Deployed` without a pod is rare. A pod that is not ready is read with `kubectl describe pod`.
3. The entry. Send a request from `shuttle`. A refused connection means the Service or the port is wrong. A success code means the EventSource accepted it. Check the Service with `kubectl -n starfleet get endpoints <name>-eventsource-svc`.
4. The EventSource log. Does it show the request and a publish? If not, the request did not arrive at the right endpoint or method.
5. The Sensor log. Does it show the event? If the EventSource published and the Sensor shows nothing, the dependency names are wrong or the bus is broken.
6. The trigger. If the Sensor shows the event and the trigger failed, the error in the log names the cause, such as `Forbidden`.
7. The target. If the object was created, for example a Workflow, read its own status and events.

## Symptom to cause

| Symptom | Where to look | Likely cause |
| --- | --- | --- |
| EventSource has no pod and `Deployed` is `False` | Status of the EventSource | Wrong `eventBusName`, or an invalid spec |
| Request is refused or times out | Service and endpoints | Wrong port, no Service in `spec.service`, a policy that blocks it |
| Request returns an error code | EventSource log | Wrong method or endpoint |
| EventSource logs the event, Sensor logs nothing | Sensor spec | Wrong `eventSourceName` or `eventName`, or a different bus |
| Sensor logs the event, no trigger runs | Filters and conditions | A filter that does not match, or a condition that waits for another dependency |
| Trigger runs and the log shows `Forbidden` | Sensor identity | `serviceAccountName` missing or without the right |
| Workflow is created and fails | The Workflow | Not an Argo Events fault. Read the Workflow status |

Use the table as a map and confirm each cause in the log before you change anything.

## A pipeline with three faults

Save this as `broken.yaml`. It is a webhook EventSource and a Sensor with one fault in the EventSource and two in the Sensor:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: relay
  namespace: starfleet
spec:
  eventBusName: main
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    signal:
      port: "12000"
      endpoint: /signal
      method: POST
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: relay
  namespace: starfleet
spec:
  dependencies:
    - name: signal-dep
      eventSourceName: relay
      eventName: signals
  triggers:
    - template:
        name: run-signal
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: signal-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: main
                templates:
                  - name: main
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [echo, signal]
```

<!-- astrona:playground:renew -->

Apply it:

```sh
kubectl apply -f broken.yaml
kubectl -n starfleet get eventbus,eventsource,sensor
```

### Fault 1: the bus

Read the conditions of the EventSource:

```sh
kubectl -n starfleet get eventsource relay -o jsonpath='{.status.conditions}{"\n"}'
kubectl -n starfleet get pods -l eventsource-name=relay
```

The condition `Deployed` is not true, the reason is about a missing bus, and there is no pod. The field `eventBusName: main` names a bus that does not exist, and the only bus is `default`. Remove the field, which makes the EventSource use `default`. Save the EventSource without it as `relay-es.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: relay
  namespace: starfleet
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    signal:
      port: "12000"
      endpoint: /signal
      method: POST
```

```sh
kubectl apply -f relay-es.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/relay --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=relay --timeout=180s
```

### Fault 2: the name of the event

Send a request and read the logs of both pods:

```sh
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -d '{}' http://relay-eventsource-svc:12000/signal
kubectl -n starfleet logs -l eventsource-name=relay --tail=10
kubectl -n starfleet logs -l sensor-name=relay --tail=10
kubectl -n starfleet get workflows
```

The request succeeds and the EventSource logs it. The Sensor logs no event, and no Workflow exists. The EventSource calls its event `signal`, and the dependency of the Sensor asks for `signals`. A dependency matches on both the name of the EventSource and the name of the event, so this one never matches. Correct it in the Sensor and apply it together with the next fix.

### Fault 3: the identity

With the event name fixed and no identity, the trigger fails as in the first part. Save the repaired Sensor as `relay-sn.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: relay
  namespace: starfleet
spec:
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: signal-dep
      eventSourceName: relay
      eventName: signal
  triggers:
    - template:
        name: run-signal
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: signal-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: main
                templates:
                  - name: main
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [echo, signal]
```

```sh
kubectl apply -f relay-sn.yaml
kubectl -n starfleet get pods -l sensor-name=relay
```

Repeat the second command until only one Sensor pod is listed and it is `Running`. Send the request again and list the Workflows:

```sh
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -d '{}' http://relay-eventsource-svc:12000/signal
kubectl -n starfleet get workflows
```

A Workflow named `signal-...` appears. Each fault showed up at a different step of the path, and each check found the first fault in order.

Delete the objects when you are done:

```sh
kubectl -n starfleet delete eventsource relay
kubectl -n starfleet delete sensor relay
```

## Common pitfalls

> [!WARNING]
> - **Fixing the last step first.** A permission change does nothing if the event never reaches the Sensor.
> - **Changing several things at once.** You then do not know which change helped. Fix one fault, then repeat the check.
> - **Reading the status of the Workflow when none exists.** A missing Workflow means the trigger did not run, so read the Sensor log.
> - **Sending the test event to the pod instead of the Service.** The Service tests the path that real senders use.
