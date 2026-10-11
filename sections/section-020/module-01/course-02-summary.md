---
draft: true
exam_objectives:
- Understand Argo Event Components and Architecture
---
# Summary

EventSource ingests external signals, EventBus transports them under its selected implementation, and Sensor evaluates named dependencies and invokes triggers. Controllers realize these resources into active components.

Envelope metadata and payload serve different purposes, while permissions and transport availability affect each stage. A healthy component does not prove the complete path, so investigation needs correlated event and target identities with explicit collection and retention limits.
