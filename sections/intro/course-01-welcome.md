# Welcome To The Course

This course teaches Argo Events, the event-driven automation part of the Argo project. It covers the Argo Events domain of the Certified Argo Project Associate (CAPA) exam, which is 12% of that exam. After the course you can build a pipeline that receives an event, filters it and starts a Kubernetes object or an Argo Workflow from it, and you can find the cause when such a pipeline does not work.

## Who this course is for

The course is for people who run or build on Kubernetes and want to react to events instead of starting work by hand. You should be able to use `kubectl`, read YAML and know what a Deployment, a Service and a service account are. You do not need earlier experience with Argo.

## What you can do at the end

- Explain the four stages of an event: source, bus, Sensor and trigger.
- Build webhook, calendar and resource EventSources and protect a webhook with a token.
- Write a Sensor with dependencies, filters, conditions and parameters, and start a Workflow from it.
- Configure an EventBus with persistence and stream limits, and explain how events are stored and delivered.
- Choose trigger types, retry policy and delivery settings, and run EventSources and Sensors with more than one pod.
- Read the status and the logs of the controller, the EventSource pods and the Sensor pods to find where an event stopped.

## How the course is laid out

The course has two sections. The first section covers the fundamentals: the event flow, EventSources, and Sensors with triggers. The second section covers the architecture: the EventBus, how a Sensor evaluates events, trigger types and delivery guarantees, and the controller with installation and high availability.

Each module has a landing page, reading parts, a summary, a playground and a graded lab. The playground is an environment without a task, where you can try every command of the reading. The lab is a graded task on its own cluster. Each section ends with a capstone lab that combines its modules and a knowledge check. After the last section there is a final knowledge check for the whole domain.

## How to read a page

Read the parts in order. Start the playground of the module when a part asks for it and run the commands as you read. A page shows command output only when the output is the same on every run. In other cases the page tells you what to look for. The knowledge checks are original practice questions, not questions from the real exam.
