# Reading Failures And Adding TLS

A request that fails in front of an EventSource gives a status code, and the code tells you which part of the route is wrong. This part causes each failure on purpose and then adds TLS.

## Set up a working route

Save this as `fleet.yaml`, apply it and wait for the pod:

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
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fleet
  namespace: starfleet
spec:
  ingressClassName: nginx
  rules:
    - host: fleet.example.test
      http:
        paths:
          - path: /report
            pathType: Exact
            backend:
              service:
                name: fleet-eventsource-svc
                port:
                  number: 12000
```

<!-- astrona:playground:renew -->

```sh
kubectl apply -f fleet.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=fleet --timeout=180s
```

Use this helper for the tests below:

```sh
hit() { kubectl -n starfleet exec shuttle -- curl -s -m 10 -o /dev/null -w "status=%{http_code}\n" -H "Host: $1" -X POST -d '{}' "http://ingress-nginx-controller.ingress-nginx.svc$2"; }
hit fleet.example.test /report
```

## The status codes

Run these requests against the working route:

```sh
hit fleet.example.test /other
hit unknown.example.test /report
```

Both give the status 404 from the controller: no rule matches the path or no rule matches the host. Check the Host header, the host in the rule and the path.

Now break the backend. Delete the EventSource and keep the Ingress:

```sh
kubectl -n starfleet delete eventsource fleet
hit fleet.example.test /report
```

The Service is gone, so the controller has no endpoints for the backend and answers 503. Recreate the EventSource with the same file and the status returns to 200 after the pod is ready.

Two more cases:

- A backend port that the Service does not expose. The controller cannot resolve the backend and answers 503.
- A Service port that is fine but a `targetPort` that the pod does not open. The controller connects to the pod and the connection fails, which gives 502 or 503. Compare it with a direct test of the pod from the first part.

Summary of the codes:

| Status | Where to look |
| --- | --- |
| 404 from the controller | Host header, host in the rule, path, `pathType`, `ingressClassName` |
| 404 from the EventSource | The path reached the pod but is not its `endpoint` |
| 503 | The Service has no endpoints or the backend port does not exist |
| 502 | The pod accepted the connection and then failed, or refused it |
| 200 | The EventSource accepted the event. The Sensor is a separate check |

The log of the controller shows each request with its upstream:

```sh
kubectl -n ingress-nginx logs deployment/ingress-nginx-controller --tail=20
```

## Add TLS

An Ingress terminates TLS with a Secret of the type `kubernetes.io/tls`. Create a self-signed certificate for the host on your computer, and then the Secret:

```sh
openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=fleet.example.test" -addext "subjectAltName=DNS:fleet.example.test" -keyout tls.key -out tls.crt
kubectl -n starfleet create secret tls fleet-tls --cert=tls.crt --key=tls.key
```

Add the `tls` section to the Ingress and apply it:

```yaml
spec:
  ingressClassName: nginx
  tls:
    - hosts: [fleet.example.test]
      secretName: fleet-tls
  rules:
    - host: fleet.example.test
```

Keep the rules from the file above. Call the host over HTTPS from `shuttle`. The flag `--resolve` makes curl send the name of the host in the TLS handshake while it connects to the Service address, and `-k` accepts the self-signed certificate:

```sh
IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.clusterIP}')
kubectl -n starfleet exec shuttle -- curl -sk -m 10 -o /dev/null -w "status=%{http_code}\n" --resolve fleet.example.test:443:$IP -X POST -d '{}' https://fleet.example.test/report
```

The controller redirects plain HTTP to HTTPS for hosts that have a TLS section, so the earlier `hit` calls can now return a redirect status. This is normal behavior of ingress-nginx; check it against your controller version.

In a real cluster, a certificate manager creates and renews the Secret. The Secret must be in the same namespace as the Ingress.

## Clean up

```sh
kubectl -n starfleet delete ingress fleet
kubectl -n starfleet delete eventsource fleet
kubectl -n starfleet delete secret fleet-tls
```

## Common pitfalls

> [!WARNING]
> - **Reading every non-200 as an EventSource fault.** The status code and the controller log show where the request stopped.
> - **Creating the TLS Secret in another namespace.** The Ingress cannot use it.
> - **Testing HTTPS without the host name.** Without `--resolve`, the handshake uses the wrong name and the certificate does not match.
> - **Treating `-k` as a fix for production.** It only skips the check in a test.
