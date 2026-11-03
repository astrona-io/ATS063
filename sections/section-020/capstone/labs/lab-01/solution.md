# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/capstone/labs/lab-01
```

Look at the starting state. The namespace has no EventBus, no EventSource and no Sensor:

```sh
kubectl -n starfleet get eventbus,eventsources,sensors
```

## Step 1: Create the EventBus signals

The block `spec.jetstream` sets the number of replicas, the storage and the stream limits. The stream limit `maxAge` goes into `streamConfig`, which is a YAML text. Save this as `bus.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: signals
  namespace: starfleet
spec:
  jetstream:
    version: 2.10.10
    replicas: 3
    persistence:
      accessMode: ReadWriteOnce
      volumeSize: 1Gi
    streamConfig: |
      maxAge: 12h
```

Apply it and wait for it:

```sh
kubectl apply -f bus.yaml
kubectl -n starfleet wait --for=condition=Deployed eventbus/signals --timeout=300s
kubectl -n starfleet get pvc
```

Run `astrona submit`. The check for the bus passes.

## Step 2: Create the EventSource with two pods

The field `replicas` sets how many pods serve the EventSource. A webhook EventSource supports more than one pod, and every pod serves requests. The field `eventBusName` selects the bus, because the default name `default` does not exist. Save this as `eventsource.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: beacon
  namespace: starfleet
spec:
  eventBusName: signals
  replicas: 2
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    alert:
      port: "12000"
      endpoint: /alert
      method: POST
    ack:
      port: "12000"
      endpoint: /ack
      method: POST
```

Apply it and wait for both pods:

```sh
kubectl apply -f eventsource.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/beacon --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=beacon --timeout=180s
kubectl -n starfleet get pods -l eventsource-name=beacon
```

The list has two pods. Run `astrona submit`.

## Step 3: Create the Sensor with a filter and two triggers

The data filter is set on the dependency `alert-dep`. The `path` is relative to the data of the event, so the key `level` of the request body is `body.level`. Events that do not match are dropped for that dependency. The dependency `ack-dep` has no filter.

With two dependencies and no conditions, a trigger waits for both. Each trigger therefore names exactly one dependency in `conditions`. Save this as `sensor.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: escalate
  namespace: starfleet
spec:
  eventBusName: signals
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: alert-dep
      eventSourceName: beacon
      eventName: alert
      filters:
        data:
          - path: body.level
            type: string
            value:
              - critical
    - name: ack-dep
      eventSourceName: beacon
      eventName: ack
  triggers:
    - template:
        name: page
        conditions: "alert-dep"
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: page-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: main
                arguments:
                  parameters:
                    - name: site
                      value: unset
                templates:
                  - name: main
                    inputs:
                      parameters:
                        - name: site
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [sh, -c]
                      args: ["echo page {{inputs.parameters.site}}"]
          parameters:
            - src:
                dependencyName: alert-dep
                dataKey: body.site
              dest: spec.arguments.parameters.0.value
    - template:
        name: close
        conditions: "ack-dep"
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: close-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: main
                arguments:
                  parameters:
                    - name: site
                      value: unset
                templates:
                  - name: main
                    inputs:
                      parameters:
                        - name: site
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [sh, -c]
                      args: ["echo close {{inputs.parameters.site}}"]
          parameters:
            - src:
                dependencyName: ack-dep
                dataKey: body.site
              dest: spec.arguments.parameters.0.value
```

Apply it and wait for the pod:

```sh
kubectl apply -f sensor.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/escalate --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=escalate --timeout=180s
```

## Step 4: Send events

Send an alert that must be dropped, an alert that must page, and an acknowledgement:

```sh
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"level":"info","site":"outpost-1"}' http://beacon-eventsource-svc:12000/alert
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"level":"critical","site":"outpost-4"}' http://beacon-eventsource-svc:12000/alert
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"site":"outpost-4"}' http://beacon-eventsource-svc:12000/ack
kubectl -n starfleet get workflows
```

One `page-` Workflow and one `close-` Workflow appear, and the `info` alert creates nothing. If a Workflow is missing, read the log of the Sensor with `kubectl -n starfleet logs -l sensor-name=escalate`. Run `astrona submit` again. All checks pass.

## Why this works

The bus is a namespaced object, so the EventSource and the Sensor must name it with `eventBusName`. The filter runs inside the Sensor before the dependency counts as satisfied, so a dropped alert never reaches a trigger. The condition of each trigger decides which satisfied dependency runs it, and the parameters copy one field of that event into the Workflow.
