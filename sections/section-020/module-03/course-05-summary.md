# Summary

A Sensor trigger has one block under `template` that says what to run. The `http` trigger sends a request with a method, a URL, headers and a payload built from event data, and the default method is `POST`. The `log` trigger writes the event to the log of the Sensor pod and never fails. The `k8s` trigger creates, updates, patches or deletes an object. A patch uses the strategy in `patchStrategy`, and the default is a merge patch. The `argoWorkflow` trigger runs the `argo` command-line program with one of eight operations, and every operation except `submit` needs the name of an existing Workflow. A Sensor uses its own service account for these calls, so the account needs a verb for each operation.

The Sensor decides alone whether a trigger worked. For an HTTP trigger without `policy.status`, every response is a success, including `500` and `503`. With `policy.status.allow`, only the listed statuses are. For a trigger that creates an object, `policy.k8s` waits for labels on the object, with a required backoff, and the field `errorOnBackoffTimeout` decides whether a timeout is a failure. A transport error is always a failure.

A `retryStrategy` repeats a failed trigger with steps, a first wait, a factor and jitter. Without it the Sensor tries once. The flag `atLeastOnce` decides whether the Sensor waits for the result. Without it, the trigger runs in the background, a failure is only a log line, and neither the retry nor the dead letter trigger ever runs. A `dlqTrigger` runs after the last failed attempt, and it needs `atLeastOnce` on itself and on the main trigger, or the Sensor is not deployed.

With JetStream, the Sensor acknowledges a message after the trigger, its retries and the dead letter trigger are done, and it does that whether they succeeded or not. A failed message is therefore not delivered again by the bus. A pod that stops during the wait causes the bus to send the message again. The Sensor remembers event identifiers for a short time and drops repeats. The field `rateLimit` takes a token before every attempt, retries included. The field `revisionHistoryLimit` is copied to the Deployment of the Sensor. The field `errorOnFailedRound` is declared in version 1.9.6 and no code reads it.

Key facts:

- The `policy` and the `retryStrategy` belong next to `template`, not inside it. Misplaced fields are accepted and ignored.
- The factor and jitter of a backoff are numbers, and a `steps` value of `0` means `5`.
- A `dlqTrigger` cannot have a `dlqTrigger` of its own.
- The result of a trigger is visible in the Sensor log and in the conditions of the Sensor object.

The HTTP trigger can start a second pipeline by calling the Service of a webhook EventSource. The `secureHeaders` field sends a header value from a Secret, `payload` builds a JSON body from event data, and `policy.status` makes a refused request count as a failure. The first request is answered when the first EventSource accepts it, so the two pipelines are not tied together in time.

<!-- astrona:playground:destroy -->
