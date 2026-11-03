# Consuming From RabbitMQ Over AMQP

An AMQP EventSource connects to a broker, declares an exchange and a queue, and publishes each message it receives as an event. This part creates one with credentials from a Secret, publishes through the management API of RabbitMQ, and reads the result.

## The fields of the AMQP event

- `url` is the address of the broker with the scheme, for example `amqp://rabbitmq.starfleet.svc:5672`.
- `exchangeName` and `exchangeType` name the exchange and its type: `fanout`, `direct`, `topic` or `headers`.
- `routingKey` is the key that binds the queue to the exchange.
- `auth` holds `username` and `password`, each a reference to a key of a Secret.
- `jsonBody`, `connectionBackoff` and `tls` work as in the other types.
- The fields `exchangeDeclare`, `queueDeclare` and `queueBind` set how the EventSource declares its objects on the broker. Without them it uses the defaults of the client.

## Create the pipeline

The Secret `rabbit-auth` already exists in the playground. Save this as `harbor-amqp.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: harbor-amqp
  namespace: starfleet
spec:
  amqp:
    arrival:
      url: amqp://rabbitmq.starfleet.svc:5672
      exchangeName: fleet
      exchangeType: fanout
      routingKey: arrival
      jsonBody: true
      auth:
        username:
          name: rabbit-auth
          key: username
        password:
          name: rabbit-auth
          key: password
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: harbor-amqp
  namespace: starfleet
spec:
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: arrival-dep
      eventSourceName: harbor-amqp
      eventName: arrival
  triggers:
    - template:
        name: run-arrival
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: amqp-arrival-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: report
                arguments:
                  parameters:
                    - name: ship
                      value: unset
                templates:
                  - name: report
                    inputs:
                      parameters:
                        - name: ship
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [echo]
                      args: ["arrival of {{inputs.parameters.ship}}"]
          parameters:
            - src:
                dependencyName: arrival-dep
                dataKey: body.ship
              dest: spec.arguments.parameters.0.value
```

<!-- astrona:playground:renew -->

Apply it and wait:

```sh
kubectl apply -f harbor-amqp.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=harbor-amqp --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=harbor-amqp --timeout=180s
```

## Publish a message

The management plugin offers an HTTP API. A message is published with a POST to `/api/exchanges/<vhost>/<exchange>/publish`, where the default virtual host `/` is written `%2F`. The body names the routing key and the payload:

```sh
kubectl -n starfleet exec shuttle -- curl -s -u fleet:orbit-pass -H 'content-type: application/json' -X POST http://rabbitmq.starfleet.svc:15672/api/exchanges/%2F/fleet/publish -d '{"properties":{},"routing_key":"arrival","payload":"{\"ship\":\"scout\"}","payload_encoding":"string"}'
```

The reply is a JSON object with the field `routed`. The value `true` means that at least one queue received the message. The value `false` means that no queue was bound, which happens when the EventSource has not connected yet. Wait a few seconds and list the Workflows:

```sh
kubectl -n starfleet get workflows
```

A Workflow named `amqp-arrival-...` appears. Read the exchange and queue that the EventSource declared:

```sh
kubectl -n starfleet exec shuttle -- curl -s -u fleet:orbit-pass http://rabbitmq.starfleet.svc:15672/api/exchanges/%2F/fleet/bindings/source
```

The reply lists the binding between the exchange `fleet` and the queue of the EventSource.

## Why the messages can be lost

A fanout exchange does not store messages. If no queue is bound when you publish, the message is dropped, and `routed` is `false`. A queue that the EventSource declares exists for the life of the connection or longer, depending on the queue settings, so check how your queue is declared before you rely on messages surviving a restart.

## Clean up

```sh
kubectl -n starfleet delete -f harbor-amqp.yaml
```

## Common pitfalls

> [!WARNING]
> - **Writing the vhost `/` in the path.** The slash must be written `%2F`.
> - **Putting the user name and password into the `url`.** Use `auth` with references to a Secret.
> - **Ignoring `routed: false`.** It tells you that nobody received the message.
> - **Using the wrong exchange type.** The routing key is ignored by a fanout exchange but required by a direct exchange.
