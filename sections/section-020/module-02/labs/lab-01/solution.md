# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-02/labs/lab-01
```

Look at the starting state. Read the Sensor and its log:

```sh
kubectl -n starfleet get sensor gatekeeper -o yaml
kubectl -n starfleet logs -l sensor-name=gatekeeper --tail=30
```

The Sensor has three problems that the checks describe. Work on them one at a time, and apply the Sensor after each change. After every change the controller replaces the Sensor pod, so wait until one pod is ready and give it about ten seconds before you send test events.

## Step 1: Repair the filters

A filter path starts at the top of the event data, and the data of a webhook event has the keys `header` and `body`. The path `fuel` does not exist, so every docking request is dropped. The path must be `body.fuel`. The comparator `>=` already accepts a fuel of exactly `20`, and a comparator of `>` would drop it.

The class value `scout` is a regular expression that matches anywhere in the string, so it also accepts `scoutship`. Anchor it as `^scout$`. The two data filters of a dependency are combined with and by default, which is what the task needs. Edit the dependency `dock-request` in the Sensor so that its filters read:

```yaml
      filters:
        data:
          - path: body.fuel
            type: number
            comparator: ">="
            value:
              - "20"
          - path: body.class
            type: string
            value:
              - "^scout$"
```

Apply the change with `kubectl edit sensor gatekeeper -n starfleet`, or save the complete Sensor from step 3 and apply it. Then run `astrona submit`. The check `dock-filter` still fails until the conditions are repaired, because no Workflow can be created yet.

## Step 2: Repair the trigger conditions

The trigger has `conditions: dock && clearance`. The expression must use the dependency names, and the names are `dock-request` and `clearance-check`. The words `dock` and `clearance` are event names, so the Sensor pod finds no dependency with those names, writes that the expression and the dependency list do not match, and never runs the trigger. The Sensor looks healthy while nothing happens. Change the line to:

```yaml
        conditions: "dock-request && clearance-check"
```

Two ampersands mean that both dependencies must have delivered. An expression with two vertical bars would start a Workflow for each event alone, and removing the dependency `clearance-check` would admit ships without a clearance, so both are wrong. Wait for the new pod and send a test pair:

```sh
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"ship":"drifter-7","class":"scout","fuel":30}' http://beacon-eventsource-svc:12000/dock
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"code":"granted"}' http://beacon-eventsource-svc:13000/clearance
kubectl -n starfleet get workflows
```

One Workflow named `admit-...` appears, and its first parameter is `drifter-7`. Run `astrona submit`. The checks for the filters and the conditions pass.

## Step 3: Change the ship name to capitals

The ship name has to arrive in capitals, and the Workflow parameter reads it from the event. A transformation on the dependency changes the data before the parameter reads it. Add this field to the dependency `dock-request`, next to `filters`:

```yaml
      transform:
        jq: ".body.ship |= ascii_upcase"
```

The operator `|=` updates the value in place and keeps every other field, so the filters still find `body.fuel` and `body.class`. A command such as `.body.ship` alone returns a string, and the Sensor discards an event whose transformation does not return an object. The complete corrected Sensor is:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: gatekeeper
  namespace: starfleet
spec:
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: dock-request
      eventSourceName: beacon
      eventName: dock
      transform:
        jq: ".body.ship |= ascii_upcase"
      filters:
        data:
          - path: body.fuel
            type: number
            comparator: ">="
            value:
              - "20"
          - path: body.class
            type: string
            value:
              - "^scout$"
    - name: clearance-check
      eventSourceName: beacon
      eventName: clearance
      filters:
        data:
          - path: body.code
            type: string
            value:
              - "^granted$"
  triggers:
    - template:
        name: admit
        conditions: "dock-request && clearance-check"
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: admit-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: report
                arguments:
                  parameters:
                    - name: ship
                      value: unset
                templates:
                  - name: report
                    inputs:
                      parameters:
                        - name: ship
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [echo]
                      args: ["{{inputs.parameters.ship}}"]
          parameters:
            - src:
                dependencyName: dock-request
                dataKey: body.ship
              dest: spec.arguments.parameters.0.value
```

Apply it, wait for the new pod, and send another pair:

```sh
kubectl apply -f gatekeeper.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=gatekeeper --timeout=120s
```

Wait about ten seconds, send the two requests from step 2 again, and list the Workflows. The newest Workflow has the value `DRIFTER-7`, and it reaches `Succeeded`. Run `astrona submit`. All checks pass.

## Why this works

The Sensor evaluates an event in a fixed order. The transformation changes the data, the filters of the dependency accept or drop the transformed event, and the trigger conditions decide whether the accepted events of both dependencies are enough. The Sensor stores an accepted event under the key of its trigger and dependency until the other dependency arrives, and it deletes both stored events when the trigger runs. This is why one pair gives one Workflow and why the order of the two requests does not matter.
