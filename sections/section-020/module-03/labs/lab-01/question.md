# Question

Solve this question on: `terminal`

The Sensor `relay` in `starfleet` forwards each event of the webhook EventSource `gate` to the service `beacon`. The service rejects the requests and the Sensor does not notice, so messages are lost without an error. Repair the Sensor. All of the following must be true.

1. The trigger `notify-beacon` sends the header `X-Fleet-Token` with the value `nova`. The service answers `403` to a request without it.

2. The Sensor treats only the status `200` as success. Any other status is a failure of the trigger.

3. A failed request is repeated. The service answers `503` to the first two requests of a message, so the trigger must make at least `3` attempts, with a pause of `1s` between them. The Sensor must wait for the attempts and see their result. A message such as `{"id":"cargo-1"}` must be accepted by the service exactly once.

4. A message that the service never accepts must not be tried forever and must not be lost. After the attempts have failed, the Sensor posts the same `id` to the path `/cgi-bin/dead` of the service, which stores it. The service rejects every message whose `id` contains the word `poison`, so such a message must reach `/cgi-bin/dead` exactly once and must be tried no fewer than 3 and no more than 10 times.

5. Several messages that arrive at the same time are all delivered.

Constraints: change only the Sensor. Do not edit the ConfigMap `beacon-cgi` or the pod `beacon`. Keep the dependency name `gate` and the trigger name `notify-beacon`. The service listens at `http://beacon.starfleet.svc:8080`, and the two paths are `/cgi-bin/hook` and `/cgi-bin/dead`. The EventSource Service is `gate-eventsource-svc` on port `12000`, and the path is `/relay`. The pod `shuttle` in `starfleet` has `curl`. The service keeps its records in `/tmp/state` in the pod `beacon`, in the files `requests.log`, `accepted.log` and `dead.log`. `kubectl` already points at the cluster as the cluster administrator.
