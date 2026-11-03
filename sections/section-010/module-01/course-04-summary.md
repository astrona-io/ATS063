# Summary

Argo Events turns an occurrence outside or inside the cluster into an action in the cluster. It does this with three objects that run as separate pods: an EventBus that transports events, an EventSource that receives or watches for occurrences, and a Sensor that decides when to run a trigger.

Every event has the same envelope. A context block carries metadata such as the source, the type, the identifier and the time. A data block carries the payload, with a header and a body for webhook events. Filters and parameters address fields in both blocks.

The EventBus stores events so that a restart or a slow Sensor does not lose them. The default bus is named `default`, and an EventSource or Sensor without `eventBusName` uses the bus with that name in its own namespace. The JetStream bus needs three replicas.

An EventSource has a type, such as `webhook`, and holds one or more named events. The pair of EventSource name and event name is the address that a Sensor subscribes to. The Service of a webhook EventSource is created only when `spec.service` is set, and its name is the EventSource name followed by `-eventsource-svc`.

A Sensor has dependencies and triggers. A dependency points at an EventSource name and an event name. A trigger names an action, and its parameters copy fields from the event into the object that the trigger creates. The Sensor needs a service account that is allowed to create that object.

Failures are found by stage. The HTTP status code shows whether the EventSource accepted the request. The EventSource pod log and status show the publish to the bus. The Sensor pod log and status show the receipt and the trigger. The created object shows the effect.

Key facts:

- EventBus, EventSource and Sensor are namespaced and connect by name.
- The event name is the key under the EventSource type, not the dependency name.
- The Sensor pod, not the controller, calls the Kubernetes API for a trigger.
- The controller sets the labels `eventsource-name` and `sensor-name` on the pods it creates.

<!-- astrona:playground:destroy -->
