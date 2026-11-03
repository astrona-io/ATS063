# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-05/labs/lab-01
```

Follow an event from the start of the path. Read the status of the objects first:

```sh
kubectl -n starfleet get eventbus,eventsource,sensor
kubectl -n starfleet get eventsource fleet -o jsonpath='{.status.conditions}{"\n"}'
```

## Step 1: Use the EventBus that exists

The EventSource has `eventBusName: main`, and the only EventBus in `starfleet` is `default`. The condition `Deployed` is not true and there is no pod. Remove the field so that the EventSource uses `default`. Save the EventSource as `fleet-es.yaml`:

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

Apply it and wait for the pod:

```sh
kubectl apply -f fleet-es.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/fleet --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=fleet --timeout=180s
```

## Step 2: Match the event name

The webhook event is called `report`, and the dependency of the Sensor asks for `reports`. A dependency matches on the name of the EventSource and the name of the event, so no event ever matches. Fix this together with step 3 in one Sensor.

## Step 3: Give the Sensor an identity

The Sensor has no `serviceAccountName`, so its trigger runs as the service account `default`, which may not create Workflows. Test it:

```sh
kubectl auth can-i create workflows.argoproj.io -n starfleet --as=system:serviceaccount:starfleet:default
kubectl auth can-i create workflows.argoproj.io -n starfleet --as=system:serviceaccount:starfleet:event-trigger
```

The first answer is `no` and the second is `yes`. Save the repaired Sensor as `fleet-sn.yaml`:

```yaml
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

Apply it and wait until one Sensor pod is running:

```sh
kubectl apply -f fleet-sn.yaml
kubectl -n starfleet get pods -l sensor-name=fleet
```

Repeat the second command until only one pod is listed and it is `Running`.

## Step 4: Send a request

```sh
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -d '{"ship":"scout"}' http://fleet-eventsource-svc:12000/report
kubectl -n starfleet get workflows
```

A Workflow named `report-...` appears and reaches the phase `Succeeded`. Submit:

```sh
astrona submit
```

All checks pass.

## Why this works

The three faults sat at three steps of the path: the EventSource could not start, the Sensor never matched the event, and the trigger could not act. Each fault hid the next one, so the order of checks from the sender toward the Workflow found them one at a time.
