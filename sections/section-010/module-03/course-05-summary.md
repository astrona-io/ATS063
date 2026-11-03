# Summary

A Sensor connects events to actions. It lists the events it depends on, it holds one or more triggers, and its pod template carries the service account under which the triggers run. The controller runs each Sensor as its own pod, and each pod keeps its own record of which events have arrived.

A Sensor with several dependencies waits for all of them unless a trigger states another rule. The `conditions` field of a trigger holds a boolean expression over dependency names, with `&&`, `||` and parentheses. Dependencies only read, so any number of Sensors can depend on the same event, and each one receives its own copy and decides on its own. The dependency name is local to the Sensor, while the EventSource name and the event name point at the event.

Parameterization carries values from an event into the object that a trigger creates. A parameter reads from the data or the context with a key or a template, and it can carry a default value for a missing key. It writes to a destination path inside the trigger resource, where list positions count from zero. The operation decides whether the new value replaces, follows or precedes the old one. The values in the Sensor object stay unchanged, and every event gets its own filled copy.

The Kubernetes trigger creates, updates, patches or deletes any object, and it needs the matching API verb for the service account of the Sensor. The Argo Workflow trigger runs Argo Workflows operations. It submits Workflows by default, adds labels with the Sensor and trigger names to what it submits, and needs more verbs than a plain create. A refused trigger does not reach the sender of the event. The evidence is in the log of the Sensor pod, and an event that failed is not run again.

Key facts:

- Without `conditions`, a trigger runs only when every dependency of the Sensor has delivered an event.
- Parameters have a source, a destination and an operation. The operation is `overwrite`, `append` or `prepend`.
- Data sources win over context sources when both are named in one parameter.
- The trigger runs with the service account in `spec.template.serviceAccountName`.

A Sensor that is deployed can still be silent. A dependency matches an event by `eventSourceName` and `eventName`, and a wrong name is not an error, because the controller does not check that the event exists. Find the fault in the direction of the event: the log of the EventSource, the names in the dependency, then the log of the Sensor. A silent Sensor with no error line usually has a name or filter problem, and a trigger problem shows an error line.

<!-- astrona:playground:destroy -->
