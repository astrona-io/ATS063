# Summary

A Sensor decides in three steps whether an event starts a trigger. Each dependency has an optional transformation and optional filters, and each trigger has optional conditions. The order is fixed: the transformation changes the event data, the filters of the dependency accept or drop the transformed event, and the trigger conditions decide whether the accepted events of the dependencies are enough.

Filters belong to one dependency and look at one event. There are five types: `data`, `exprs`, `script`, `context` and `time`. The data filter compares a value at a path with a list of values and has the types `string`, `number` and `bool`. A string value is a regular expression that matches anywhere, so `^hull$` is needed for an exact match. A number value is written as a string, and the comparator is one of `>=`, `>`, `=`, `!=`, `<` and `<=`. Paths of a webhook event start with `body.` or `header.`. Several filters of one type combine with `dataLogicalOperator` or `exprLogicalOperator`, and the types combine with `filtersLogicalOperator`. All three operators default to `and` and take the lower case values `and` and `or`. An error inside a filter, such as a missing path, counts as false.

Trigger conditions are a boolean expression over dependency names, with `&&`, `||` and parentheses. Without the field `conditions`, a trigger needs all dependencies. An expression with `&&` makes the Sensor store each accepted event in the JetStream key-value store named after the Sensor, under the key `<trigger>/<dependency>`. One event is kept for each dependency, and the latest event replaces the older one. When the expression becomes true, the trigger runs and the stored events of that trigger are deleted. A change to a dependency or to the conditions deletes the stored events of the changed part. A name in the expression that is not a dependency is not refused when the Sensor is created, and the pod logs the mismatch while the trigger never runs.

The field `conditionsReset` deletes stored events on a schedule. Its criterion `byTime` has a five-field `cron` and an optional `timezone`. The controller refuses an invalid expression and reports it in the condition `TriggersProvided`.

A transformation is either a `jq` command or a Lua `script`. It sees only the event data, and it must produce a JSON object or a table. When it fails, the Sensor discards the event. Filters, conditions and parameters see only the transformed data. A parameter whose `dataKey` does not exist in the event stops the trigger with an error unless the `src` has a default `value`. A parameter whose dependency delivered no event is skipped when the conditions use `||`.

Key facts:

- Pipeline order: transformation, filters, conditions, trigger.
- A filter on a missing path drops the event.
- Stored events do not expire without `conditionsReset`.
- The pod of a Sensor is replaced when a dependency changes, so wait for the new pod before you send test events.

<!-- astrona:playground:destroy -->
