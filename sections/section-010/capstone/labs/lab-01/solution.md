# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-010/capstone/labs/lab-01
```

Look at the starting state. The bus and the Secret exist, and nothing else does:

```sh
kubectl -n starfleet get eventbus,eventsources,sensors,secrets
```

## Step 1: Create the EventSource with two protected events

Each webhook event is one entry under `spec.webhook`, and the key of the entry is the event name. The field `authSecret` names the Secret and the key that hold the token. Both events use port `12000` and different paths. Save this as `eventsource.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: harbor
  namespace: starfleet
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    arrival:
      port: "12000"
      endpoint: /arrival
      method: POST
      authSecret:
        name: harbor-token
        key: token
    departure:
      port: "12000"
      endpoint: /departure
      method: POST
      authSecret:
        name: harbor-token
        key: token
```

Apply it and wait for the controller to report it as deployed:

```sh
kubectl apply -f eventsource.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/harbor --timeout=180s
```

Run `astrona submit`. The checks for the EventSource pass, and the others fail.

## Step 2: Create the Sensor

The Sensor has one dependency for each event. The names of the dependencies are local to the Sensor, and `eventName` is the key under `spec.webhook`. Without `conditions` the trigger would wait for both events, so the condition joins the two dependency names with `||`.

The Workflow parameters come from two places. The ship is in the body of the request, so `dataKey: body.ship` reads it. The event name is in the context of the event, and `contextKey: subject` reads it. Because the trigger can run for either dependency, each value has one parameter entry for each dependency, without a `value`. The entry of the dependency that did not deliver an event is skipped. Positions in `dest` count from zero.

Save this as `sensor.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: logbook
  namespace: starfleet
spec:
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: arrival-dep
      eventSourceName: harbor
      eventName: arrival
    - name: departure-dep
      eventSourceName: harbor
      eventName: departure
  triggers:
    - template:
        name: record-movement
        conditions: "arrival-dep || departure-dep"
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: logbook-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: main
                arguments:
                  parameters:
                    - name: ship
                      value: unset
                    - name: movement
                      value: unset
                templates:
                  - name: main
                    inputs:
                      parameters:
                        - name: ship
                        - name: movement
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [sh, -c]
                      args: ["echo {{inputs.parameters.movement}} {{inputs.parameters.ship}}"]
          parameters:
            - src:
                dependencyName: arrival-dep
                dataKey: body.ship
              dest: spec.arguments.parameters.0.value
            - src:
                dependencyName: departure-dep
                dataKey: body.ship
              dest: spec.arguments.parameters.0.value
            - src:
                dependencyName: arrival-dep
                contextKey: subject
              dest: spec.arguments.parameters.1.value
            - src:
                dependencyName: departure-dep
                contextKey: subject
              dest: spec.arguments.parameters.1.value
```

Apply it and wait for the Sensor and the two pods:

```sh
kubectl apply -f sensor.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/logbook --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=harbor --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=logbook --timeout=180s
```

Run `astrona submit`.

## Step 3: Send requests

Read the token from the Secret and send one request with it and one without it:

```sh
TOKEN=$(kubectl -n starfleet get secret harbor-token -o jsonpath='{.data.token}' | base64 --decode)
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" -d '{"ship":"aurora"}' http://harbor-eventsource-svc:12000/arrival
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"ship":"comet"}' http://harbor-eventsource-svc:12000/departure
kubectl -n starfleet get workflows
```

Only the first request creates a Workflow, named `logbook-...`. Read its parameters:

```sh
kubectl -n starfleet get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[*].value}{"\n"}{end}'
```

If no Workflow appears, read the log of the Sensor with `kubectl -n starfleet logs -l sensor-name=logbook`. A wrong dependency name, a refusal from the Kubernetes API or a failed parameter shows there. Run `astrona submit` again. All checks pass.

## Why this works

The EventSource checks the token before it publishes an event, so a request without the token never reaches the bus. The Sensor combines three rules: the or condition decides when the trigger runs, the parameters copy values from the event into the Workflow, and one parameter for each dependency is needed because only the dependency that delivered an event provides values.
