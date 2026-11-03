---
estimated_duration: 35m
---

# Lab: Restore A Highly Available Calendar EventSource

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The namespace starfleet runs an EventSource named beacon and a Sensor named beacon. The EventSource has two replicas and Kubernetes leader election, but no event arrives. The task is to repair the leader election, set resource requests and limits, give the Sensor two replicas and prove that the event flow survives the loss of the leader. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-020/module-04/labs/lab-01
astrona submit -c sections/section-020/module-04/labs/lab-01
astrona destroy ats-063-lab-020-04
```

Authors prove the reference solution with `astrona test -c sections/section-020/module-04/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-eventsource-ha.sh` | EventSource beacon has two replicas, the Kubernetes leader election annotation, and two running pods that use a dedicated service account |
| `validate-leader-election.sh` | The service account of the EventSource may get, create and update leases only, the Lease eventsource-beacon names a running pod, and deleting that pod moves the lease to another pod |
| `validate-workload-resources.sh` | The main containers of the EventSource and Sensor pods have the requested resource requests and limits |
| `validate-sensor-ha.sh` | Sensor beacon has two replicas with two running pods and still uses the service account event-trigger |
| `validate-event-flow.sh` | A new beacon- Workflow is created by a calendar event and reaches Succeeded |
