# Calendar Events From Time

Some work has no sender. A report must run every night, a cleanup must run every hour, and a health probe must run every thirty seconds. No outside system calls the cluster for these jobs, and the only thing that happens is that time passes. The calendar EventSource turns time into events, so the same Sensors and triggers that react to requests can react to a clock.

The EventBus `default` exists in the playground. The EventSource, the Sensors and the Workflow in this part are created by you.

## Interval and schedule

A calendar event has one of two ways to say when it fires:

- `interval` is a duration such as `15s`, `30m` or `2h`. The EventSource fires again every time that duration has passed, counted from the start of the pod.
- `schedule` is a cron expression with five fields: minute, hour, day of month, month and day of week. The expression `30 * * * *` fires at minute 30 of every hour.

An event uses one of them. The first is relative to the moment the pod started, and the second is anchored to the wall clock. The choice matters after a restart. An interval starts counting again from the new pod, while a schedule fires at the same clock times as before.

Two optional fields refine a schedule. The `timezone` field names a time zone from the tz database, so that a schedule written as `0 3 * * *` means three o'clock in that zone and not in UTC. The `exclusionDates` field lists dates on which the schedule does not fire. Each entry has the form `EXDATE:20260101T000000Z`, and the year, the month and the day of the entry are matched.

## Create a calendar EventSource

Save this as `eventsource-calendar.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: calendar
  namespace: starfleet
spec:
  calendar:
    heartbeat:
      interval: 15s
      metadata:
        ship: scout
    nightly:
      schedule: "0 3 * * *"
      timezone: America/New_York
      exclusionDates:
        - "EXDATE:20261225T030000Z"
```

The EventSource has two events. The event `heartbeat` fires every fifteen seconds. The event `nightly` fires at three o'clock New York time every day except on the excluded date. The `metadata` of `heartbeat` is a static payload: a map of text values that the EventSource adds to every event it sends. A calendar EventSource needs no `service`, because it opens no port.

<!-- astrona:playground:renew -->

Apply it and wait until it is deployed:

```sh
kubectl apply -f eventsource-calendar.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/calendar --timeout=180s
```

## Read the events

Save this Sensor as `sensor-heartbeat-log.yaml`. It depends on the event `heartbeat` and logs what it receives:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: heartbeat-log
  namespace: starfleet
spec:
  dependencies:
    - name: beat
      eventSourceName: calendar
      eventName: heartbeat
  triggers:
    - template:
        name: print-beat
        log: {}
```

Apply it, wait about half a minute and read its log:

```sh
kubectl apply -f sensor-heartbeat-log.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/heartbeat-log --timeout=180s
kubectl -n starfleet logs -l sensor-name=heartbeat-log --tail=20
```

A new log line appears for every interval of fifteen seconds. Each line holds the data of the event: the field `eventTime` with the time of the event, and the field `metadata` with `{"ship":"scout"}`. The event context in the same line has the type `calendar`, the source `calendar` and the subject `heartbeat`. The subject is the event name, so the log line tells you which event produced it.

The data of a calendar event is small on purpose. The only fields are the time and the static metadata. A calendar event carries no request body, so any value that the trigger needs must come from the time or from the metadata.

## Use the static payload in a trigger

The `metadata` map is how a schedule tells the Sensor what the event is for. A trigger reads it with the path `metadata.ship`, and the time with the path `eventTime`. Save this as `sensor-heartbeat-workflow.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: heartbeat-workflow
  namespace: starfleet
spec:
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: beat
      eventSourceName: calendar
      eventName: heartbeat
  triggers:
    - template:
        name: report-beat
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: heartbeat-
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
                      args: ["heartbeat from {{inputs.parameters.ship}}"]
          parameters:
            - src:
                dependencyName: beat
                dataKey: metadata.ship
              dest: spec.arguments.parameters.0.value
```

Apply it, wait for the next interval, and read the argument of the Workflows that appear:

```sh
kubectl apply -f sensor-heartbeat-workflow.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/heartbeat-workflow --timeout=180s
kubectl -n starfleet get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[0].value}{"\n"}{end}'
```

Every Workflow whose name starts with `heartbeat-` has the argument `scout`. A new one appears about every fifteen seconds, so delete the Sensor when you have seen enough:

```sh
kubectl -n starfleet delete sensor heartbeat-workflow
```

## Events that are missed

A calendar EventSource runs inside a pod. While the pod is down, no clock events are produced. By default those events are lost, because the EventSource has no record of when it last fired. The `persistence` field changes this. It stores the time of the last event in a ConfigMap, and a catch-up setting sends the missed events after a restart:

```yaml
    nightly:
      schedule: "0 3 * * *"
      persistence:
        catchup:
          enabled: true
          maxDuration: 5m
        configMap:
          createIfNotExist: true
          name: nightly-state
```

The `maxDuration` limits how far back the catch-up reaches. The EventSource pod needs a service account that may get, create and update ConfigMaps, which is set with `spec.template.serviceAccountName`. Without that permission the persistence cannot save its state.

A calendar EventSource also has a high availability rule. With more than one replica, only one pod is active and the others wait to take over. Two active pods would fire every event twice, which is why the calendar type is active-passive.

## Common pitfalls

> [!WARNING]
> - **Setting both `interval` and `schedule` on one event.** Use one of them. They are two different ways to answer the same question.
> - **Writing a schedule in a different time zone than you think.** Without `timezone`, the schedule uses the time zone of the pod, which is normally UTC.
> - **Reading `body` in a calendar event.** The data has `eventTime` and `metadata`. A path such as `body.message` finds nothing.
> - **Expecting missed events after a restart.** They are lost unless persistence with catch-up is configured and its ConfigMap permissions exist.
> - **Leaving a fast interval running.** Every tick with a Workflow trigger creates a Workflow, so a short interval fills the namespace quickly.
