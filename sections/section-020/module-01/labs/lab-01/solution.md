# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-01/labs/lab-01
```

Look at the starting state. The namespace has no EventBus, no EventSource and no Sensor:

```sh
kubectl -n starfleet get eventbus,eventsources,sensors
```

## Step 1: Create the EventBus audit

A JetStream bus is built from the `spec.jetstream` block. The `persistence` block makes each server pod request a claim, and `streamConfig` is a YAML text with the stream limits. Save this as `bus.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: audit
  namespace: starfleet
spec:
  jetstream:
    version: 2.10.10
    replicas: 3
    persistence:
      accessMode: ReadWriteOnce
      volumeSize: 1Gi
    streamConfig: |
      maxAge: 24h
      maxMsgs: 1000
```

Apply it and wait until the controller reports it as deployed:

```sh
kubectl apply -f bus.yaml
kubectl -n starfleet wait --for=condition=Deployed eventbus/audit --timeout=300s
```

Check the claims and the merged stream configuration. The status shows the controller defaults with your two values on top:

```sh
kubectl -n starfleet get pvc
kubectl -n starfleet get eventbus audit -o jsonpath='{.status.config.jetstream.streamConfig}'
```

Then run `astrona submit`. The checks for the bus and its storage pass, and the checks for the pipeline still fail.

## Step 2: Create the EventSource and the Sensor with eventBusName

Both objects look for a bus named `default` unless `eventBusName` says otherwise. Without it they stay without pods, because no bus named `default` exists. Save this as `pipeline.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: ledger
  namespace: starfleet
spec:
  eventBusName: audit
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    entry:
      port: "12000"
      endpoint: /entry
      method: POST
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: ledger
  namespace: starfleet
spec:
  eventBusName: audit
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: entry-dep
      eventSourceName: ledger
      eventName: entry
  triggers:
    - template:
        name: record-entry
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: ledger-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: main
                arguments:
                  parameters:
                    - name: message
                      value: unset
                templates:
                  - name: main
                    inputs:
                      parameters:
                        - name: message
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [sh, -c]
                      args: ["echo entry={{inputs.parameters.message}}"]
          parameters:
            - src:
                dependencyName: entry-dep
                dataKey: body.message
              dest: spec.arguments.parameters.0.value
```

The parameter copies `body.message` from the event into the first Workflow parameter. The position `0` counts from zero. Apply it and wait for both objects:

```sh
kubectl apply -f pipeline.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/ledger --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/ledger --timeout=180s
```

## Step 3: Send an event

The EventSource and Sensor pods need a short time to connect to the bus. Wait for them and send a request:

```sh
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=ledger --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=ledger --timeout=180s
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"message":"hello"}' http://ledger-eventsource-svc:12000/entry
kubectl -n starfleet get workflows
```

A Workflow named `ledger-...` appears and reaches `Succeeded`. Run `astrona submit` again. All checks pass.

If the Sensor does not create Workflows, read its log with `kubectl -n starfleet logs -l sensor-name=ledger`. A refusal from the Kubernetes API or a wrong dependency name shows there.

## Why this works

The bus is a namespaced object, and an EventSource or a Sensor connects to the bus that its `eventBusName` names. The field defaults to `default`, so a bus with another name is used only when both ends say so. The persistence block turns the `emptyDir` of each server pod into a claim, and the stream configuration is merged over the controller defaults, so only the two changed limits need to be written.
