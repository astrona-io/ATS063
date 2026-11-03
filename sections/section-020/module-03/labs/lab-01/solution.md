# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-03/labs/lab-01
```

Look at the starting state. The Sensor is deployed and healthy, which is the reason the faults are easy to miss:

```sh
kubectl -n starfleet get sensor relay -o yaml
kubectl -n starfleet get pods
```

Send one message and read what the beacon saw. Without the header, the beacon answers `403`, and the Sensor logs a success anyway, because without a `policy.status` the Sensor does not read the status of the response:

```sh
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"id":"probe-1"}' http://gate-eventsource-svc:12000/relay
sleep 5
kubectl -n starfleet exec beacon -- cat /tmp/state/requests.log
```

## Step 1: Add the header

Open the Sensor with `kubectl -n starfleet edit sensor relay`. Add the header next to `Content-Type` under `http.headers`:

```yaml
          headers:
            Content-Type: application/json
            X-Fleet-Token: nova
```

Save the change and wait for the new Sensor pod. Send a message with a new id. The beacon now answers `503` instead of `403`, because it has not yet seen this body three times:

```sh
kubectl -n starfleet rollout status deployment -l sensor-name=relay --timeout=180s
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"id":"probe-2"}' http://gate-eventsource-svc:12000/relay
sleep 5
kubectl -n starfleet exec beacon -- grep probe-2 /tmp/state/requests.log
```

Run `astrona submit`. The check for the Sensor passes, and the checks for delivery fail, because the Sensor still makes one attempt and counts the `503` as a success.

## Step 2: Define the failure and repeat it

Three settings work together. A `policy` with `status.allow` makes a `503` a failure. A `retryStrategy` repeats a failure. The flag `atLeastOnce: true` makes the Sensor wait for the trigger, which is the only way that the retry sees the failure. Add them as siblings of `template`, at the same level as `template`, and not inside it:

```yaml
      policy:
        status:
          allow:
            - 200
      atLeastOnce: true
      retryStrategy:
        steps: 3
        duration: 1s
```

Four plausible changes do not work. A `retryStrategy` without `atLeastOnce` is never used, because the failure is only logged. A `policy` without `atLeastOnce` finds the failure and does not repeat it. A list `allow: [200, 503]` makes the `503` a success again. A `retryStrategy` without a `policy` has nothing to retry, because every status is a success.

Wait for the new pod and send a message:

```sh
kubectl -n starfleet rollout status deployment -l sensor-name=relay --timeout=180s
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"id":"probe-3"}' http://gate-eventsource-svc:12000/relay
sleep 10
kubectl -n starfleet exec beacon -- grep probe-3 /tmp/state/requests.log | awk '{print $2}'
kubectl -n starfleet exec beacon -- grep -c probe-3 /tmp/state/accepted.log
```

The first command prints `503`, `503` and `200`, and the second prints `1`. Run `astrona submit`. The delivery check passes.

## Step 3: Park the message that never works

Send a message with the word `poison`. The Sensor makes three attempts and then stops, and the message is lost. The dead letter trigger keeps it. A `dlqTrigger` is a trigger of its own, and the Sensor refuses to deploy it unless `atLeastOnce: true` is set on the main trigger and inside the `dlqTrigger`. Add it at the end of the trigger, with the same indentation as `retryStrategy`:

```yaml
      dlqTrigger:
        atLeastOnce: true
        template:
          name: park-message
          http:
            url: http://beacon.starfleet.svc:8080/cgi-bin/dead
            method: POST
            headers:
              Content-Type: application/json
            payload:
              - src:
                  dependencyName: gate
                  dataKey: body.id
                dest: id
```

Read the condition if the Sensor does not start:

```sh
kubectl -n starfleet get sensor relay -o jsonpath='{.status.conditions[?(@.type=="TriggersProvided")].message}{"\n"}'
```

Wait for the new pod, send a poison message and read the three files:

```sh
kubectl -n starfleet rollout status deployment -l sensor-name=relay --timeout=180s
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"id":"poison-1"}' http://gate-eventsource-svc:12000/relay
sleep 15
kubectl -n starfleet exec beacon -- grep -c poison-1 /tmp/state/requests.log
kubectl -n starfleet exec beacon -- grep -c poison-1 /tmp/state/dead.log
kubectl -n starfleet exec beacon -- grep -c poison-1 /tmp/state/accepted.log
```

The commands print `3`, `1` and `0`. Run `astrona submit`. All checks pass.

## Reference solution

The complete Sensor is in `solution/solution.yaml`. The scripts in `validation/` send real messages through the webhook and read the records of the beacon, so a change that only looks right does not pass.
