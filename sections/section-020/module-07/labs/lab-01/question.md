# Question

Solve this question on: `terminal`

Senders post a report to `http://gate.example.test/report`. The webhook EventSource `gate` in `starfleet` listens on port 12000 at the endpoint `/report`, and the Sensor `gate` creates a Workflow named `gate-...` for every event. The ingress-nginx controller (IngressClass `nginx`) is installed. The Ingress `gate` should deliver the requests, but a POST through the controller does not reach the EventSource.

Repair the Ingress `gate` so that:

1. The backend is the Service that the controller created for the EventSource `gate`.
2. The backend port is the port on which that Service exposes the EventSource.
3. The rule matches the path on which the EventSource accepts events.

Constraints: keep the host `gate.example.test`, the class `nginx` and the name `gate`. Do not change the EventSource, the Sensor or the controller. Test from the pod `shuttle` in `starfleet`: `kubectl -n starfleet exec shuttle -- curl -s -m 10 -w '\nstatus=%{http_code}\n' -H 'Host: gate.example.test' -X POST -d '{}' http://ingress-nginx-controller.ingress-nginx.svc/report`. `kubectl` already points at the cluster as the cluster administrator.
