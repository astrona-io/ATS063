# Webhook Endpoints And Access

The webhook EventSource is the entry point for every system that can send an HTTP request: a deployment tool, a monitoring system, a script, or another service in the cluster. A first pipeline uses one endpoint. A real one needs several endpoints, a way to reach them, and a way to keep strangers out. This part covers all three.

The EventBus `default` already exists in the playground. Everything else in this part is created by you.

## One EventSource, several events

An EventSource object holds one or more events, and each event has its own name. For the webhook type, an event is one HTTP listener with a port, a path and a method. Save this as `eventsource-webhook.yaml`:

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
      - port: 13000
        targetPort: 13000
  webhook:
    order:
      port: "12000"
      endpoint: /order
      method: POST
    status:
      port: "13000"
      endpoint: /status
      method: POST
```

The EventSource is named `webhook`. This name is the `eventSourceName` that Sensors use. The keys `order` and `status` are event names, and they are the `eventName` values. The two names have different jobs, and the rule that connects them is simple: a Sensor dependency is always the pair of one EventSource name and one event name.

One rule limits the event names. Within one EventSource, an event name can appear only once, even when the events belong to different types. The reason is that the pair of EventSource name and event name must identify exactly one event.

The `service` field lists every port that the controller must put on the generated Service. Each event port must also appear there, otherwise the Service does not forward to it.

<!-- astrona:playground:renew -->

Apply the file and wait until the controller has created the pod:

```sh
kubectl apply -f eventsource-webhook.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/webhook --timeout=180s
```

## The health endpoint

A webhook EventSource opens one more endpoint on every port it uses. The path is `/health`, and a GET request to it returns the text `OK` with the status code `200`. The endpoint exists so that a load balancer or an Ingress has something to probe. Call it on both ports:

```sh
kubectl -n starfleet exec shuttle -- curl -s -w ' %{http_code}\n' http://webhook-eventsource-svc:12000/health
kubectl -n starfleet exec shuttle -- curl -s -w ' %{http_code}\n' http://webhook-eventsource-svc:13000/health
```

Each command prints `OK 200`. The health endpoint does not need a token and does not create an event. It only proves that the pod listens on that port.

## The generated Service and the Services you create

The `service` field creates a ClusterIP Service named after the EventSource, with the suffix `-eventsource-svc`. The upstream documentation states that this Service is meant for testing. For traffic from outside the cluster, create your own Service with a selector on the label `eventsource-name`, which the controller puts on the EventSource pods. Save this as `service-direct.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webhook-direct
  namespace: starfleet
spec:
  type: ClusterIP
  selector:
    eventsource-name: webhook
  ports:
    - port: 8080
      targetPort: 12000
```

Apply it and send the health request through the new Service on its own port:

```sh
kubectl apply -f service-direct.yaml
kubectl -n starfleet get endpoints webhook-direct
kubectl -n starfleet exec shuttle -- curl -s http://webhook-direct:8080/health
```

The endpoints object lists the pod address, and the request returns `OK`. The Service type here is `ClusterIP` to keep the playground simple. In production the same selector sits behind a `LoadBalancer` or an Ingress, and the `/health` path is what its health check calls.

## See what a Sensor receives

A Sensor with a log trigger prints every event that it receives. It is the quickest way to see the data of a webhook event. Save this as `sensor-orders.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: orders
  namespace: starfleet
spec:
  dependencies:
    - name: order-dep
      eventSourceName: webhook
      eventName: order
  triggers:
    - template:
        name: print-order
        log: {}
```

The log trigger does not call the Kubernetes API, so the Sensor needs no special service account. Apply it, send an event and read the Sensor log:

```sh
kubectl apply -f sensor-orders.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/orders --timeout=180s
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"item":"fuel","count":3}' http://webhook-eventsource-svc:12000/order
kubectl -n starfleet logs -l sensor-name=orders --tail=5
```

The log line for the event contains the JSON of the event data, with the fields `header` and `body`, and the event context with the source `webhook` and the subject `order`. The subject of the context is the event name.

## Require a bearer token

An open endpoint accepts a request from anyone who can reach it. The `authSecret` field of a webhook event makes the EventSource check a token. First store the token in a Secret:

```sh
kubectl -n starfleet create secret generic webhook-token --from-literal=token=s3cret-orbit-7731
```

Then add `authSecret` to the event `order`. Save this as `eventsource-webhook-auth.yaml`. It is the same EventSource with one more field:

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
      - port: 13000
        targetPort: 13000
  webhook:
    order:
      port: "12000"
      endpoint: /order
      method: POST
      authSecret:
        name: webhook-token
        key: token
    status:
      port: "13000"
      endpoint: /status
      method: POST
```

The `name` is the Secret and the `key` is the entry inside it. Apply the file. The controller replaces the EventSource pod because the Deployment changed, so wait until the new pod is ready:

```sh
kubectl apply -f eventsource-webhook-auth.yaml
kubectl -n starfleet get pods -l eventsource-name=webhook
```

Repeat the pod listing until only one pod is shown and its status is `Running`. Then send one request without a token and one with the token. The token goes into the `Authorization` header with the word `Bearer` in front of it:

```sh
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"item":"no-token"}' http://webhook-eventsource-svc:12000/order
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer s3cret-orbit-7731' \
  -d '{"item":"with-token"}' http://webhook-eventsource-svc:12000/order
kubectl -n starfleet logs -l sensor-name=orders | grep -c with-token
kubectl -n starfleet logs -l sensor-name=orders | grep -c no-token
```

The first count is `1` and the second count is `0`. Only the request with the token became an event. The `status` event has no `authSecret`, so it stays open. The token protects one event, not the whole EventSource.

## What the token does not do

The bearer token is plain HTTP authentication. It does not encrypt the request, so it travels in clear text unless the connection uses TLS. The Secret is read by the EventSource pod, so only users who can read the Secret or exec into the pod can see it. The token check also does not validate the content of the body. Validation of the content is the job of a Sensor filter.

## Common pitfalls

> [!WARNING]
> - **Forgetting a port in `spec.service`.** An event on port 13000 is unreachable through the generated Service when only port 12000 is listed.
> - **Using the same event name twice in one EventSource.** The pair of EventSource name and event name must identify one event, so a repeated name is not allowed, also across different event types.
> - **Sending the token without the word `Bearer`.** The header value must start with `Bearer` and a space.
> - **Testing right after `kubectl apply`.** The old pod can still answer for a few seconds, and the new pod is not ready yet.
> - **Putting a trailing newline in the token.** A token made with `echo` without `-n` or with a file that ends in a newline does not match the header.
