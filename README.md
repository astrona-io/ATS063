# Argo Events (ATS063)

Certified Argo Project Associate (CAPA): Argo Events, worth 12% of the official curriculum. The course targets Argo Events 1.9.6 and Argo Workflows 3.7.3 on a kind cluster.

Every module has a landing page, deep-dive parts, a summary, an ungraded playground and a graded lab. Every section ends with a graded capstone lab and a quiz. A final domain quiz covers both sections.

All labs and playgrounds are UNTESTED. They passed `astrona validate` and static syntax checks only; nobody has run them.

## Course Outline

| Section | Module | Title |
| --- | --- | --- |
| 010 | 01 | Event-Driven Automation And The Argo Events Flow |
| 010 | 02 | Receiving Events With EventSources |
| 010 | 03 | Reacting With Sensors And Triggers |
| 010 | 04 | More EventSource Types |
| 010 | 05 | Kafka And AMQP Brokers |
| 010 | capstone | Build The Harbor Pipeline |
| 020 | 01 | The EventBus And JetStream |
| 020 | 02 | Sensor Evaluation: Filters, Conditions And Transforms |
| 020 | 03 | Trigger Types, Policies And Delivery Guarantees |
| 020 | 04 | The Controller, Installation And High Availability |
| 020 | 05 | Observing And Securing The Components |
| 020 | 06 | Metrics With Prometheus |
| 020 | 07 | Exposing Webhooks Through Ingress |
| 020 | capstone | Build The Escalation Pipeline |

## Hands-On Coverage

| Module | Graded lab |
| --- | --- |
| 010/01 | Build A Webhook Pipeline With Argo Events |
| 010/02 | Secure A Webhook And Add A Calendar Event |
| 010/03 | Fix A Sensor That Never Fires |
| 010/04 | Fix A NATS EventSource |
| 010/05 | Fix A Kafka EventSource |
| 010/capstone | Build The Harbor Pipeline |
| 020/01 | Build A Dedicated EventBus |
| 020/02 | Fix A Sensor That Admits The Wrong Ships |
| 020/03 | Make The Relay Deliver |
| 020/04 | Restore A Highly Available Calendar EventSource |
| 020/05 | Repair A Pipeline That Never Runs |
| 020/06 | Fix A Prometheus Scrape Job |
| 020/07 | Fix An Ingress For A Webhook |
| 020/capstone | Build The Escalation Pipeline |

## Assessments

Section quizzes are `sections/section-010/quiz.yaml` and `sections/section-020/quiz.yaml`, 35 and 46 questions. The final domain quiz is `sections/final-domain-quiz.yaml`. All are draft question banks.

## More

See [curriculum coverage](CURRICULUM.md), [primary sources](SOURCES.md) and [contribution instructions](CONTRIBUTING.md).
