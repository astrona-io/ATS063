# Sensor Evaluation: Filters, Conditions And Transforms

A Sensor receives every event that its EventSource publishes, but it should start a trigger only for some of them. The decision is made in three places, and each place has its own rules. A dependency can change the event and filter it, and a trigger can wait for several dependencies before it runs. Getting these rules wrong gives a Sensor that fires on events it should ignore, or one that never fires and shows no error. This module explains how the Sensor evaluates an event and what it remembers between events.

## Learning objectives

After this module you can:

- Write data filters for strings, numbers and booleans, and explain why an unanchored string value matches more than expected.
- Combine filters with `dataLogicalOperator`, `exprLogicalOperator` and `filtersLogicalOperator`, and describe the expr, script, context and time filters.
- Write trigger conditions with `&&`, `||` and parentheses, and explain the default when `conditions` is missing.
- Explain how the Sensor stores events between two arrivals, what resets that state, and how `conditionsReset` with a cron expression and a timezone works.
- Transform event data with jq or Lua, and explain the order of transformation, filters and conditions.
- Find out from the Sensor pod log and the Sensor status why a trigger fires too often or not at all.

## Before you start

You know how an EventSource and a Sensor connect by name, and you can send a request from the `shuttle` pod with `curl`.

The playground is a kind cluster with Argo Workflows and Argo Events installed. It contains the following objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `argo-events` | Deployment `controller-manager` | The Argo Events controller |
| `argo` | Deployment `workflow-controller` | The Argo Workflows controller |
| `starfleet` | EventBus `default` | The message service, ready to use |
| `starfleet` | EventSource `telemetry` | A webhook source with the events `reading`, `alert` and `ack` on the ports 12000, 13000 and 14000 |
| `starfleet` | pod `shuttle` | A client pod with `curl` |
| `starfleet` | service accounts `event-trigger` and `workflow-runner` | The identity of Sensors that create Workflows and of Workflow pods |

No Sensor exists yet. You create the Sensors in the four parts. The first part filters events on a dependency. The second part combines dependencies with trigger conditions and resets the stored state. The third part transforms event data before it is filtered. The fourth part runs the expression, script and time filters against real requests.

## What you build

Each part adds one Sensor to the playground and tests it with real requests:

- `hull-watch` accepts only hot readings of one sensor and ignores the rest.
- `dock-gate` waits for an alert and an acknowledgement before it starts a Workflow.
- `hull-label` changes the sensor name to capitals before the filter reads it.

The lab at the end of the module gives you a Sensor that admits the wrong ships, or none, and asks you to repair its filters, its conditions and its data.

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
