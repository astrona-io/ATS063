# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-010/module-01/labs/lab-01
```

Before you change anything, check the starting state. The EventBus exists and is deployed, and no EventSource or Sensor exists:

```sh
kubectl -n starfleet get eventbus,eventsources,sensors
```

## Step 1: Create the EventSource

The EventSource describes the request that Argo Events must accept. The event name `mission` is the key under `webhook`. The `service` field creates the Service in front of the pod. Save this as `eventsource.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: webhook
  namespace: starfleet
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    mission:
      port: "12000"
      endpoint: /mission
      method: POST
```

Apply it and wait until the controller has created the pod:

```sh
kubectl apply -f eventsource.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/webhook --timeout=180s
```

Submit to check the EventSource:

```sh
astrona submit --keep
```

The check `eventsource-ready` passes. The checks that send events still fail, because no Sensor listens yet.

## Step 2: Create the Sensor

The Sensor connects the event to a Workflow. The dependency names the EventSource and the event. The trigger parameter copies `body.message` into the first Workflow argument, and `generateName` gives every event its own Workflow. Save this as `sensor.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: mission
  namespace: starfleet
spec:
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: mission-dep
      eventSourceName: webhook
      eventName: mission
  triggers:
    - template:
        name: run-mission
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: mission-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: report
                arguments:
                  parameters:
                    - name: message
                      value: unset
                templates:
                  - name: report
                    inputs:
                      parameters:
                        - name: message
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [echo]
                      args: ["{{inputs.parameters.message}}"]
          parameters:
            - src:
                dependencyName: mission-dep
                dataKey: body.message
              dest: spec.arguments.parameters.0.value
```

Apply it and wait:

```sh
kubectl apply -f sensor.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/mission --timeout=180s
```

Submit to check the Sensor:

```sh
astrona submit --keep
```

The check `sensor-ready` passes.

## Step 3: Send an event and read the result

Send a request from the `shuttle` pod and list the Workflows:

```sh
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"message":"hello from the shuttle"}' http://webhook-eventsource-svc:12000/mission
kubectl -n starfleet get workflows
```

A Workflow whose name starts with `mission-` appears after a few seconds. If it does not, read the logs of the EventSource pod with `kubectl -n starfleet logs -l eventsource-name=webhook` and of the Sensor pod with `kubectl -n starfleet logs -l sensor-name=mission`. Submit again:

```sh
astrona submit
```

All checks pass. The checks send their own events, so the Workflows you created by hand do not matter.

## Why this works

The webhook event `mission` receives the request and publishes it to the EventBus. The Sensor subscribes to the EventSource name and the event name, so a mismatch in either leaves the Sensor silent. The trigger parameter reads the field `message` from the body of the event and writes it into the Workflow before the Sensor creates it. The Sensor pod needs the service account `event-trigger` because it creates the Workflow through the Kubernetes API.
