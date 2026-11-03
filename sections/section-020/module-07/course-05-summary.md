# Summary

A webhook EventSource listens inside the cluster. The controller creates a Service for it only when the EventSource has a `service` section, and the Service is named `<EventSource name>-eventsource-svc`. An Ingress points at that Service and at one of its ports. The Service `port`, its `targetPort` and the port in the webhook event must line up. Test the Service from inside the cluster first, so that you can tell a fault in the EventSource from a fault in the Ingress.

An Ingress needs `ingressClassName` to be taken by a controller. A rule selects a request by host and path. `Exact` matches one path, and `Prefix` matches by path elements. The path is forwarded unchanged, so it must equal the `endpoint` of the webhook event. Several EventSources can share a host with different paths, or each can have its own host.

The status code shows where a request stopped. A 404 from the controller means that no rule matched the host or the path. A 404 from the EventSource means that the path reached the pod but is not its endpoint. A 503 means no endpoints or a missing backend port, and a 502 means that the pod failed or refused the connection. A 200 only proves that the EventSource accepted the event, so check the Workflows for the result of the Sensor.

TLS uses a Secret of the type `kubernetes.io/tls` in the namespace of the Ingress, named in the `tls` section. A webhook that is open to the internet needs authentication, for example through the `authSecret` field of the EventSource.

Key facts:

- The kind provider manifest of ingress-nginx (controller v1.12.0) installs the IngressClass `nginx`.
- The controller sends traffic to pod IPs from the endpoints, not to the Service address.
- A request without the right Host header does not match a rule that has a host.

<!-- astrona:playground:destroy -->
