# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-010/module-02/labs/lab-01
```

Look at the starting state. The EventSource `dispatch` has no `authSecret`, and nothing named `ticker` exists:

```sh
kubectl -n starfleet get eventsources,sensors
kubectl -n starfleet get eventsource dispatch -o yaml
```

## Step 1: Protect the order event

Add `authSecret` to the event `order`. The `name` is the Secret and the `key` is the entry inside it. Save this as `dispatch.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: dispatch
  namespace: starfleet
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    order:
      port: "12000"
      endpoint: /order
      method: POST
      authSecret:
        name: dispatch-token
        key: token
```

Apply it and wait for the controller to replace the EventSource pod:

```sh
kubectl apply -f dispatch.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/dispatch --timeout=180s
kubectl -n starfleet get pods -l eventsource-name=dispatch
```

Repeat the last command until only one pod is listed and it is `Running`. Then submit:

```sh
astrona submit --keep
```

The checks `order-auth-configured` and `order-requires-token` pass. Test it by hand if you want to see the difference. The header is `Authorization: Bearer` followed by the token, and the token is the value in the Secret:

```sh
TOKEN=$(kubectl -n starfleet get secret dispatch-token -o jsonpath='{.data.token}' | base64 --decode)
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" -d '{"message":"signed"}' http://dispatch-eventsource-svc:12000/order
```

## Step 2: Add the calendar EventSource

A calendar EventSource opens no port, so it needs no `service`. The `interval` is a duration. Save this as `ticker-eventsource.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: ticker
  namespace: starfleet
spec:
  calendar:
    beat:
      interval: 30s
```

```sh
kubectl apply -f ticker-eventsource.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/ticker --timeout=180s
astrona submit --keep
```

The check `ticker-eventsource` passes.

## Step 3: Add the Sensor

The dependency names the EventSource `ticker` and the event `beat`. The trigger creates a Workflow with `generateName: beat-`. Save this as `ticker-sensor.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: ticker
  namespace: starfleet
spec:
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: beat-dep
      eventSourceName: ticker
      eventName: beat
  triggers:
    - template:
        name: run-beat
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: beat-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: report
                templates:
                  - name: report
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [echo]
                      args: ["tick"]
```

```sh
kubectl apply -f ticker-sensor.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/ticker --timeout=180s
kubectl -n starfleet get workflows --watch
```

A Workflow named `beat-...` appears every thirty seconds. Stop the watch with Ctrl+C and submit:

```sh
astrona submit
```

All checks pass.

## Why this works

The token check is part of the webhook event, so one field in the EventSource decides which requests become events. Changing the EventSource makes the controller replace the pod, which is why the test must wait. The calendar event has no sender, so its timing comes from `interval`, and the Sensor reacts to it in the same way as to a request. The Sensor needs the service account `event-trigger` because it creates Workflows through the Kubernetes API.
