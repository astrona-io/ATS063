# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-010/module-03/labs/lab-01
```

Look at the starting state. The Sensor has two dependencies and a trigger, and the trigger has no `conditions` and no `parameters`:

```sh
kubectl -n starfleet get eventsources,sensors
kubectl -n starfleet get sensor launch -o yaml
```

Send one request to the event `scout` and look for Workflows. None appears, because the Sensor waits for both events:

```sh
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"ship":"aurora"}' http://fleet-eventsource-svc:12000/scout
kubectl -n starfleet get workflows
```

## Step 1: Run the trigger on either event

Without `conditions`, a trigger runs only when every dependency has delivered an event. Add the condition to the trigger template. The names in the expression are the dependency names `scout-dep` and `relay-dep`, not the event names.

Export the Sensor, edit it, and apply it again:

```sh
kubectl -n starfleet edit sensor launch
```

In the editor, add this line next to `name: launch-ship`, at the same indentation:

```yaml
        conditions: "scout-dep || relay-dep"
```

Save and close the editor, wait until the controller has replaced the Sensor pod, and check the Sensor:

```sh
kubectl -n starfleet get pods -l sensor-name=launch
```

There must be one pod, and it must be ready. Then run:

```sh
astrona submit --keep
```

The check `launch-conditions` passes. The check `launch-either-event` passes when a request to either event creates one Workflow.

## Step 2: Copy the ship into the Workflow

The trigger now runs, but the Workflow prints `unset`, because nothing writes the parameter. The trigger needs `parameters` that read `body.ship` from the event and write it to the first parameter of the Workflow. One parameter is needed for each dependency. A parameter names the dependency that it reads from. When the trigger runs for the other event, the parameter of the dependency that delivered nothing is skipped, and the parameter of the one that did deliver writes the value. A single parameter on `scout-dep` would be skipped for every request to `relay`.

Add this list under `k8s`, at the same indentation as `source` and `operation`. Add it in the editor with `kubectl edit`:

```yaml
          parameters:
            - src:
                dependencyName: scout-dep
                dataKey: body.ship
              dest: spec.arguments.parameters.0.value
            - src:
                dependencyName: relay-dep
                dataKey: body.ship
              dest: spec.arguments.parameters.0.value
```

Do not add `value` to these parameters. A parameter with `value` whose dependency did not deliver an event would write its default and overwrite the real ship name.

Apply the change, wait for a single ready Sensor pod and send one request to each event:

```sh
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"ship":"aurora"}' http://fleet-eventsource-svc:12000/scout
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"ship":"borealis"}' http://fleet-eventsource-svc:13000/relay
kubectl -n starfleet get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[*].value}{"\t"}{.status.phase}{"\n"}{end}'
```

The new Workflows carry the ship names `aurora` and `borealis`. Then run:

```sh
astrona submit --keep
```

The checks `launch-carries-ship` and `launch-workflow-succeeds` pass.

## Why this works

The trigger condition changes the rule from all dependencies to either dependency. A request to one event then runs the trigger once. The trigger resolves each parameter against the events that arrived, so the parameter for the dependency that did not deliver is skipped. Together the two parameters copy the ship name from whichever event started the trigger.

The reference solution is in `solution/solution.yaml`. It is the complete Sensor with the condition and both parameters.
