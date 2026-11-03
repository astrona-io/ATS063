# Broker Failures And Signs In The Log

A broker EventSource has more ways to fail than a webhook. The broker can be down, the name can be wrong, the topic can be wrong, and the credentials can be refused. All of them show up first in the log of the EventSource pod. This part causes two of these faults and reads the log.

## Create a Kafka EventSource

Save this as `probe.yaml`. It reads a topic that the broker has not seen:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: probe
  namespace: starfleet
spec:
  kafka:
    ping:
      url: kafka.starfleet.svc:9092
      topic: pings
      partition: "0"
      jsonBody: true
      connectionBackoff:
        duration: 2s
        steps: 5
        factor: 2
```

<!-- astrona:playground:renew -->

```sh
kubectl apply -f probe.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=probe --timeout=180s
kubectl -n starfleet logs -l eventsource-name=probe --tail=20
```

The object is `Deployed` and the pod is running. The status of the object does not show whether the connection works, so the log is the evidence. Read the last lines. They show the connection and the topic that the EventSource tried to read.

## Fault 1: the broker is down

Scale the Deployment of the broker to zero pods and follow the log of the EventSource:

```sh
kubectl -n starfleet scale deployment kafka --replicas=0
kubectl -n starfleet logs -l eventsource-name=probe --tail=20 -f
```

Stop the log with `Ctrl+C` after some lines. The EventSource reports that it cannot connect and retries. The setting `connectionBackoff` decides how often it retries and when it gives up, so a pod that used up its steps may stop trying. Check whether the pod is still running:

```sh
kubectl -n starfleet get pods -l eventsource-name=probe
```

Bring the broker back and wait for it:

```sh
kubectl -n starfleet scale deployment kafka --replicas=1
kubectl -n starfleet wait --for=condition=Available deployment/kafka --timeout=180s
```

If the EventSource pod is still retrying, it connects by itself. If it stopped, delete the pod so that the controller creates a new one:

```sh
kubectl -n starfleet delete pod -l eventsource-name=probe
```

## Fault 2: a name that does not resolve

Change the `url` to a name that does not exist. Save this as `probe-wrong.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: probe
  namespace: starfleet
spec:
  kafka:
    ping:
      url: kafkaa.starfleet.svc:9092
      topic: pings
      partition: "0"
      jsonBody: true
```

```sh
kubectl apply -f probe-wrong.yaml
kubectl -n starfleet get pods -l eventsource-name=probe
kubectl -n starfleet logs -l eventsource-name=probe --tail=20
```

The log shows an error about the address. The object is still `Deployed`, because the controller built the pod and did not test the address. You can reproduce the check yourself from the pod `shuttle`:

```sh
kubectl -n starfleet exec shuttle -- nslookup kafkaa.starfleet.svc
```

If the tool is not in the image, use `kubectl -n starfleet get svc` to list the services and compare the name. A Service that does not exist is the most common cause.

## A table of signs

| Sign in the log | Likely cause | Check |
| --- | --- | --- |
| Cannot connect, retries | Broker down, wrong port, or a policy blocks it | `kubectl get pods`, `kubectl get svc`, the NetworkPolicy |
| Name does not resolve | Wrong Service name or namespace | `kubectl get svc` |
| Authentication refused | Wrong key or value in the Secret | `kubectl get secret -o yaml`, the broker log |
| Connected and nothing arrives | Wrong topic, partition, exchange or key | Compare with the broker |
| Events arrive and the Sensor is silent | Names in the dependency | The Sensor log |

## Clean up

```sh
kubectl -n starfleet delete eventsource probe
```

## Common pitfalls

> [!WARNING]
> - **Trusting `Deployed`.** It shows that the pod exists, not that the connection works.
> - **Letting the backoff run out.** A pod that gave up needs to be replaced.
> - **Fixing the Sensor when the log of the EventSource shows a connection error.** The fault is before the bus.
> - **Scaling a broker to zero in a shared cluster.** Every client of the broker stops.
