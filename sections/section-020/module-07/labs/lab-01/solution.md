# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-07/labs/lab-01
```

Look at the starting state:

```sh
kubectl -n starfleet get ingress gate -o yaml
kubectl -n starfleet get svc
kubectl -n starfleet get endpoints
kubectl -n starfleet get eventsource gate -o yaml
```

Three things differ. The Ingress names the Service `gate-eventsource`, but the controller created `gate-eventsource-svc`. It uses the port 12001, but the Service exposes 12000. It matches the path `/reports`, but the endpoint of the event is `/report`.

## Step 1: Correct the Service and the port

The backend must name the Service and a port that it exposes. Save the corrected Ingress as `gate-ingress.yaml`. It also fixes the path, which is the third fault:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gate
  namespace: starfleet
spec:
  ingressClassName: nginx
  rules:
    - host: gate.example.test
      http:
        paths:
          - path: /report
            pathType: Exact
            backend:
              service:
                name: gate-eventsource-svc
                port:
                  number: 12000
```

```sh
kubectl apply -f gate-ingress.yaml
astrona submit
```

The checks `ingress-backend` and `ingress-path` pass.

## Step 2: Post an event through the controller

Wait a few seconds for the controller to load the route, then post:

```sh
kubectl -n starfleet exec shuttle -- curl -s -m 10 -w '\nstatus=%{http_code}\n' -H 'Host: gate.example.test' -X POST -d '{}' http://ingress-nginx-controller.ingress-nginx.svc/report
kubectl -n starfleet get workflows
astrona submit
```

The status 200 and a Workflow named `gate-...` show that the whole route works. All three checks pass.

## Why it failed

The first request with the old Ingress could not match the path `/report` against `/reports`, so the controller answered 404. After the path is fixed, the wrong Service name or the wrong port gives 503, because the controller has no endpoints for that backend. Compare the status codes with the table in the course to find which part is wrong.
