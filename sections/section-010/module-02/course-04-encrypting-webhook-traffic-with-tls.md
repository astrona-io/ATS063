# Encrypting Webhook Traffic With TLS

A bearer token keeps strangers from sending events, but it travels in clear text. Anyone who can read the network between the sender and the EventSource pod can copy the token and the body of every request. Transport Layer Security (TLS) encrypts the connection, so the token and the body stay private. A webhook EventSource can serve TLS itself, with a certificate and a private key that it reads from Kubernetes Secrets.

This part creates a self-signed certificate, gives it to a webhook event, and shows what changes for the sender. It also states where the EventSource stops and where an Ingress or a service mesh takes over.

## The two fields

An event of a webhook EventSource has two optional fields for TLS. Both are references to a key in a Secret in the namespace of the EventSource.

- `serverCertSecret` points at the certificate, in PEM format. The certificate holds the public key, and the sender checks it.
- `serverKeySecret` points at the private key that belongs to the certificate. The key must stay secret, which is why it lives in a Secret and not in the EventSource.

Each field has a `name` (the Secret) and a `key` (the entry in the Secret). Both fields must be set together. When they are set, the webhook server of that event listens for HTTPS on its port. When they are not set, the server listens for plain HTTP. The setting belongs to one event, so two events of the same EventSource can use different settings, as long as each event has its own port.

## Create the certificate and the Secret

A real deployment uses a certificate from a certificate authority, for example one issued by cert-manager. In the playground, a self-signed certificate is enough to show the mechanism. The sender connects to the Service name, so the certificate must name that Service in its subject alternative name (SAN) list. The Service of an EventSource called `secure-hook` is `secure-hook-eventsource-svc`.

<!-- astrona:playground:renew -->

Create the key and the certificate with `openssl`:

```sh
openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=secure-hook-eventsource-svc" \
  -addext "subjectAltName=DNS:secure-hook-eventsource-svc"
```

The command writes two files in the current directory: `tls.crt` and `tls.key`. The certificate is valid for one day. Store both files in one Secret:

```sh
kubectl -n starfleet create secret generic hook-cert --from-file=tls.crt --from-file=tls.key
```

The Secret `hook-cert` now has the two keys `tls.crt` and `tls.key`, which the EventSource uses in the next step.

## Create the EventSource and a Sensor

Save this as `eventsource-secure-hook.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: secure-hook
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
      serverCertSecret:
        name: hook-cert
        key: tls.crt
      serverKeySecret:
        name: hook-cert
        key: tls.key
```

Apply it and wait until it is deployed:

```sh
kubectl apply -f eventsource-secure-hook.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/secure-hook --timeout=180s
```

Save this Sensor as `sensor-secure-log.yaml`. It logs every event that arrives:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: secure-log
  namespace: starfleet
spec:
  dependencies:
    - name: order-dep
      eventSourceName: secure-hook
      eventName: order
  triggers:
    - template:
        name: print-order
        log: {}
```

Apply it:

```sh
kubectl apply -f sensor-secure-log.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/secure-log --timeout=180s
```

## Send requests with and without TLS

Send a plain HTTP request from `shuttle`. The server expects a TLS handshake, so it cannot read the request:

```sh
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  -H 'Content-Type: application/json' -d '{"item":"fuel"}' \
  http://secure-hook-eventsource-svc:12000/order
```

The status is not `200`, and the log of the Sensor shows no event. The server sees bytes that are not a TLS handshake and closes the connection.

Now send an HTTPS request. The first form skips the check of the certificate with `-k`, so it works with any certificate:

```sh
kubectl -n starfleet exec shuttle -- curl -sk -o /dev/null -w '%{http_code}\n' -X POST \
  -H 'Content-Type: application/json' -d '{"item":"fuel"}' \
  https://secure-hook-eventsource-svc:12000/order
```

The status is `200`. Read the log of the Sensor to see the event:

```sh
kubectl -n starfleet logs -l sensor-name=secure-log --tail=5
```

A good client does not skip the check. It trusts the certificate and compares the host name with the SAN. Copy the certificate into the `shuttle` pod and use `--cacert`:

```sh
kubectl -n starfleet exec -i shuttle -- sh -c 'cat > /tmp/tls.crt' < tls.crt
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/tls.crt -X POST \
  -H 'Content-Type: application/json' -d '{"item":"ore"}' \
  https://secure-hook-eventsource-svc:12000/order
```

The status is `200` again, and this time `curl` verified the certificate. If you call the Service with another name, such as its full name ending in `.svc.cluster.local`, the check fails because that name is not in the SAN list.

## What the field does not cover

The certificate protects the connection from the sender to the EventSource pod. It does not say who the sender is. For that, combine `serverCertSecret` and `serverKeySecret` with `authSecret` on the same event, so that the traffic is encrypted and each request needs the token.

The connection from the EventSource pod to the EventBus has its own settings, and the connection from a Sensor to an outside service belongs to the trigger. Many clusters also end TLS earlier, in an Ingress controller or a service mesh, and send plain HTTP to the Service inside the cluster. Both designs are valid. Use the fields of the event when the Service is exposed directly, or when the policy says that traffic inside the cluster must be encrypted too.

Delete the objects when you are done:

```sh
kubectl -n starfleet delete sensor secure-log
kubectl -n starfleet delete eventsource secure-hook
kubectl -n starfleet delete secret hook-cert
```

This part showed how one event serves HTTPS from a Secret and how a sender verifies it. The remaining question is lifetime: a certificate expires, and a pod that already runs does not notice a new one until the controller replaces it.

## Common pitfalls

> [!WARNING]
> - **Setting only one of the two fields.** The certificate and the key go together. A missing field leaves the event unable to serve TLS.
> - **A certificate without the Service name in its SAN list.** The sender compares the host name it called with the SAN entries, and a mismatch fails the check.
> - **Sending `http://` to a TLS event.** The request fails at the handshake and no event is created.
> - **Using `-k` in real clients.** It turns off the check of the certificate, so it also accepts a certificate of an attacker.
> - **Forgetting that the certificate expires.** Replace the Secret before the end date, and check that the EventSource pod uses the new files.
