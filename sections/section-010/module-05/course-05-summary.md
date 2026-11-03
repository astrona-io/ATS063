# Summary

Kafka and AMQP EventSources are subscription types. The pod connects out to the broker, so no Service and no route from a sender is needed, and the pod needs a network path, a name that resolves, the location to read, and credentials as references to a Secret. They are active-passive, so with several replicas one pod serves and the others wait.

A Kafka event has `url`, `topic`, `partition` as a string, `jsonBody`, an optional `consumerGroup` and `connectionBackoff`. One event reads one partition. Without a consumer group the pod tracks its own position, and with one the broker stores the offset of the group. A topic is created when a producer first writes to it if automatic creation is on.

An AMQP event has `url` with the scheme, `exchangeName`, `exchangeType`, `routingKey`, `auth` and `jsonBody`. The EventSource declares an exchange and a queue. A fanout exchange does not store messages, and the management API answers `routed: false` when no queue received a publish. The virtual host `/` is written `%2F` in the path of the API.

A broker EventSource fails in the log first. The object stays `Deployed` while the broker is down, the name is wrong or the credentials are refused. Read the log of the EventSource, then check the Service, the Secret and the topic or exchange. A pod that used up its `connectionBackoff` must be replaced.

Key facts:

- The Kafka image in this course is `apache/kafka:3.9.0` and the RabbitMQ image is `rabbitmq:4.0.5-management`.
- The field `partition` is a string.
- Credentials are references to keys of a Secret in the namespace of the EventSource.
- A message dropped by a fanout exchange without a bound queue is not recoverable.

<!-- astrona:playground:destroy -->
