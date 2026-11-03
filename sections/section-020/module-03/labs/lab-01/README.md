---
estimated_duration: 35m
---

# Lab: Make The Relay Deliver

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The Sensor relay forwards events to the service beacon, but the service rejects them and the Sensor does not notice. The task is to repair the trigger so that every event arrives, and so that a message that can never be delivered is parked on the dead letter endpoint. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-020/module-03/labs/lab-01
astrona submit -c sections/section-020/module-03/labs/lab-01
astrona destroy ats-063-lab-020-03
```

Authors prove the reference solution with `astrona test -c sections/section-020/module-03/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-relay-sensor-valid.sh` | Sensor relay is deployed, keeps the dependency gate and the trigger notify-beacon, and the beacon service is unchanged |
| `validate-relay-delivers-with-retries.sh` | A request to the webhook reaches the beacon with the token header and is accepted exactly once after retries |
| `validate-relay-parks-poison.sh` | A message that the beacon always rejects is stored once on the dead letter endpoint, is never accepted, and is tried between 3 and 10 times |
| `validate-relay-handles-burst.sh` | Three requests sent in a row are all accepted and none of them is dead-lettered |
