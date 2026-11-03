# Curriculum Coverage

Exam: Certified Argo Project Associate (CAPA). Domain: Argo Events (12%).

The teaching structure is independently authored and does not add official requirements. AUTHORING.yaml records the measurable goals and the adaptation sources.

| Section | Official objective | Modules |
| --- | --- | --- |
| 010 | Understand Argo Events Fundamentals | 5 and a capstone |
| 020 | Understand Argo Event Components and Architecture | 7 and a capstone |

| Section / module | Module | Parts |
| --- | --- | --- |
| 010 / 01 | Event-Driven Automation And The Argo Events Flow | 4 |
| 010 / 02 | Receiving Events With EventSources | 4 |
| 010 / 03 | Reacting With Sensors And Triggers | 4 |
| 010 / 04 | More EventSource Types | 4 |
| 010 / 05 | Kafka And AMQP Brokers | 4 |
| 020 / 01 | The EventBus And JetStream | 4 |
| 020 / 02 | Sensor Evaluation: Filters, Conditions And Transforms | 4 |
| 020 / 03 | Trigger Types, Policies And Delivery Guarantees | 4 |
| 020 / 04 | The Controller, Installation And High Availability | 4 |
| 020 / 05 | Observing And Securing The Components | 4 |
| 020 / 06 | Metrics With Prometheus | 4 |
| 020 / 07 | Exposing Webhooks Through Ingress | 4 |

## Hands-On Coverage

Twelve ungraded playgrounds, twelve module labs and two capstone labs. All are UNTESTED: they passed `astrona validate` and static syntax checks, and nobody has run them.

| Module | Lab | Difficulty |
| --- | --- | --- |
| 010/01 | Build A Webhook Pipeline With Argo Events | intermediate |
| 010/02 | Secure A Webhook And Add A Calendar Event | intermediate |
| 010/03 | Fix A Sensor That Never Fires | intermediate |
| 010/04 | Fix A NATS EventSource | intermediate |
| 010/05 | Fix A Kafka EventSource | intermediate |
| 010/capstone | Build The Harbor Pipeline | advanced |
| 020/01 | Build A Dedicated EventBus | intermediate |
| 020/02 | Fix A Sensor That Admits The Wrong Ships | intermediate |
| 020/03 | Make The Relay Deliver | intermediate |
| 020/04 | Restore A Highly Available Calendar EventSource | intermediate |
| 020/05 | Repair A Pipeline That Never Runs | intermediate |
| 020/06 | Fix A Prometheus Scrape Job | intermediate |
| 020/07 | Fix An Ingress For A Webhook | intermediate |
| 020/capstone | Build The Escalation Pipeline | advanced |

## Assessments

Two section quizzes of 35 and 46 questions and one final domain quiz of 28 questions, all draft.
