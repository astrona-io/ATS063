# Building The First Pipeline

A pipeline is three objects that point at each other by name. The EventBus has a name, the EventSource publishes to the bus of its namespace, and the Sensor names the EventSource and the event it waits for. Most mistakes in Argo Events are a wrong name in one of these places, so this part builds the pipeline one object at a time and checks each object before it adds the next.

The pipeline receives a webhook request and creates an Argo Workflow that prints a message taken from the request body.

## The EventBus

The EventSource and the Sensor both need a bus, so the bus comes first. Save this as `eventbus-default.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: starfleet
spec:
  jetstream:
    version: 2.10.10
    replicas: 3
```

The name `default` matters. An EventSource or a Sensor that does not set `eventBusName` uses the bus named `default` in its own namespace. The `jetstream` field selects NATS JetStream as the backend. The `version` is a NATS server version that the controller knows, and `replicas: 3` starts three JetStream servers, which is the minimum for the default stream settings.

<!-- astrona:playground:renew -->

Apply it:

```sh
kubectl apply -f eventbus-default.yaml
```

The controller creates a StatefulSet with three pods. Wait until the controller reports the bus as deployed:

```sh
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl -n starfleet get statefulsets,pods,services
```

The wait ends when the `Deployed` condition of the bus is `True`. The first start can take a few minutes because the cluster pulls the NATS images. The second command shows the StatefulSet that the controller created and its pods. You did not write any of these objects. The controller built them from the three fields above.

## The EventSource

The EventSource describes which kind of occurrence to receive. Save this as `eventsource-webhook.yaml`:

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
    example:
      port: "12000"
      endpoint: /example
      method: POST
```

Read it from the bottom. Under `webhook`, the key `example` is the **event name**. The event source type `webhook` can hold many events, and each key is one of them. The event listens on port 12000 at the path `/example` and accepts the method `POST`. The port is written as a string, as in the upstream examples.

The `service` field asks the controller to create a Kubernetes Service in front of the EventSource pod. Its name is the EventSource name plus `-eventsource-svc`, so here it is `webhook-eventsource-svc`. Without this field, nothing inside the cluster can reach the pod by a stable name.

Apply it and wait:

```sh
kubectl apply -f eventsource-webhook.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/webhook --timeout=180s
```

Then list what the controller created:

```sh
kubectl -n starfleet get deployments,pods,services
```

You now see one new Deployment and pod for the EventSource, and the Service `webhook-eventsource-svc`. The EventSource pod connects to the EventBus when it starts.

## The Sensor

The Sensor connects the event to an action. Save this as `sensor-example.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: example
  namespace: starfleet
spec:
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: example-dep
      eventSourceName: webhook
      eventName: example
  triggers:
    - template:
        name: print-message
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: example-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: print-message
                arguments:
                  parameters:
                    - name: message
                      value: unset
                templates:
                  - name: print-message
                    inputs:
                      parameters:
                        - name: message
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [echo]
                      args: ["{{inputs.parameters.message}}"]
          parameters:
            - src:
                dependencyName: example-dep
                dataKey: body.message
              dest: spec.arguments.parameters.0.value
```

The file has three groups of fields. Under `dependencies`, `eventSourceName: webhook` is the `metadata.name` of the EventSource and `eventName: example` is the key under `webhook`. These two values must match exactly. The `name` of the dependency, `example-dep`, is a label that the trigger parameters use.

Under `triggers`, the `k8s` trigger with `operation: create` creates the object in `source.resource`. Here it is a Workflow with `generateName: example-`, so the API server adds a random suffix and every event creates a new object.

The `parameters` list changes the object before the Sensor creates it. It takes the field `body.message` of the event from the dependency `example-dep` and writes it to the path `spec.arguments.parameters.0.value`, which is the value of the first Workflow argument. The value `unset` in the template is the default that the event data replaces.

The field `spec.template.serviceAccountName` is the identity of the Sensor pod. The Sensor uses it to call the Kubernetes API when it creates the Workflow. The service account `event-trigger` in the playground may create Workflows and nothing else.

Apply it and wait:

```sh
kubectl apply -f sensor-example.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/example --timeout=180s
```

## Send the first event

All three objects exist. Send a webhook request from the `shuttle` pod. The Service name resolves inside the `starfleet` namespace:

```sh
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' \
  -X POST -H 'Content-Type: application/json' \
  -d '{"message":"hello from the shuttle"}' \
  http://webhook-eventsource-svc:12000/example
```

The command prints the HTTP status code of the response. The EventSource answers after it has published the event to the bus. List the Workflows after a few seconds:

```sh
kubectl -n starfleet get workflows
kubectl -n starfleet get workflows -o jsonpath='{.items[*].spec.arguments.parameters[0].value}{"\n"}'
```

The first command lists one Workflow whose name starts with `example-`. The second command prints the value of its `message` argument, which is the text from the request body. That value came from the event through the Sensor parameter. The Workflow controller then runs the Workflow as a pod, and the pod prints the message.

You have built the full path: the request reached the EventSource, the EventSource published it to the bus, the Sensor received it and created the Workflow, and the Workflow controller ran it. The open question is how to see each of these steps separately, so that you can find the one that failed when a pipeline does not behave. Each of these steps leaves its own evidence in a log, a status or an object.

## Common pitfalls

> [!WARNING]
> - **Sending the event before the Sensor is deployed.** Wait for the `Deployed` condition of the EventBus, the EventSource and the Sensor first.
> - **Using the dependency name as the event name.** `eventName` is the key under `webhook` (`example`), not the dependency `name` (`example-dep`).
> - **Writing the wrong EventSource name in `eventSourceName`.** It is `metadata.name` of the EventSource, here `webhook`.
> - **Forgetting the service account of the Sensor.** Without permission to create Workflows, the Sensor receives the event but the trigger fails.
