# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-04/labs/lab-01
```

Look at the starting state. Both objects exist, and the EventSource has two pods:

```sh
kubectl -n starfleet get eventsource,sensor
kubectl -n starfleet get pods -l eventsource-name=beacon
kubectl -n starfleet get lease
```

## Step 1: Find out why the EventSource is silent

The annotation `events.argoproj.io/leader-election: k8s` tells each pod to use a Kubernetes Lease for the election, and a calendar EventSource runs its timer only in the pod that holds the lease. The pods have no `spec.template.serviceAccountName`, so they run as the `default` ServiceAccount, which may not touch Leases. Read the log of one pod and the Lease list:

```sh
kubectl -n starfleet logs -l eventsource-name=beacon -c main --tail=20
kubectl -n starfleet auth can-i create leases.coordination.k8s.io --as=system:serviceaccount:starfleet:default
```

The second command answers `no`. No pod creates the Lease `eventsource-beacon`, so no pod becomes leader and no event is published. Run `astrona submit`. All checks fail at this point.

## Step 2: Create the ServiceAccount and the Lease Role

The pods need their own identity so that the permission is not given to every pod that uses `default`. The Role contains only the three verbs that the leader election needs. Save this as `rbac.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: beacon-es
  namespace: starfleet
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: beacon-lease
  namespace: starfleet
rules:
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["get", "create", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: beacon-lease
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: beacon-lease
subjects:
  - kind: ServiceAccount
    name: beacon-es
    namespace: starfleet
```

Apply it and check the permission:

```sh
kubectl apply -f rbac.yaml
kubectl -n starfleet auth can-i create leases.coordination.k8s.io --as=system:serviceaccount:starfleet:beacon-es
```

## Step 3: Change the EventSource

Add the ServiceAccount and the resources under `spec.template`. The field `container` sets the resources of the main container. Edit the object:

```sh
kubectl -n starfleet edit eventsource beacon
```

The `spec` must look like this. Keep the annotation in `metadata`:

```yaml
spec:
  replicas: 2
  template:
    serviceAccountName: beacon-es
    container:
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 200m
          memory: 128Mi
  calendar:
    tick:
      interval: 20s
```

The controller notices the change and updates the Deployment, which replaces the pods. Wait for the rollout:

```sh
deploy=$(kubectl -n starfleet get deployment -l eventsource-name=beacon -o jsonpath='{.items[0].metadata.name}')
kubectl -n starfleet rollout status deployment/$deploy --timeout=180s
kubectl -n starfleet get lease eventsource-beacon -o jsonpath='{.spec.holderIdentity}{"\n"}'
```

The Lease now exists and names one of the two pods. Run `astrona submit`. The checks for the EventSource, the Lease and the resources of the EventSource pass.

## Step 4: Change the Sensor

Set the replicas and the resources of the Sensor. The Sensor uses the bus for its own leader election, so no annotation and no Role is needed. Keep the ServiceAccount `event-trigger`:

```sh
kubectl -n starfleet edit sensor beacon
```

```yaml
spec:
  replicas: 2
  template:
    serviceAccountName: event-trigger
    container:
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 200m
          memory: 256Mi
```

Wait until both Sensor pods are ready:

```sh
deploy=$(kubectl -n starfleet get deployment -l sensor-name=beacon -o jsonpath='{.items[0].metadata.name}')
kubectl -n starfleet rollout status deployment/$deploy --timeout=180s
kubectl -n starfleet get workflows
```

Within a minute new Workflows named `beacon-...` appear. The Sensor deletes nothing, but each Workflow is removed by its own `ttlStrategy` two minutes after it finishes. Run `astrona submit`. All checks pass.

## Why this works

A calendar EventSource may run in only one pod at a time, because two timers would publish every event twice. Each pod therefore starts an elector first. With the annotation `k8s` the elector uses a Lease named `eventsource-beacon` in the namespace of the object, and only the pod that holds it runs the timer. Creating or updating that Lease is an API call made with the ServiceAccount of the pod, so the Role must be bound to that ServiceAccount. The standby pod keeps retrying and takes over when the holder is gone. The resources and the replica count are fields of the EventSource and Sensor objects: the controller copies them into the Deployment, so changing the Deployment by hand is not needed and does not persist as the source of truth.
