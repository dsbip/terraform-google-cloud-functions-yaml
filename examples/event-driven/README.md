# Event-driven example

Five functions triggered through Eventarc:

| Function | Event source | Notes |
|---|---|---|
| `order-events` | Pub/Sub topic `orders` | short topic name, expanded to `projects/PROJECT/topics/orders`; event type implied |
| `partner-feed` | Pub/Sub topic in another project | full topic name, no retries |
| `thumbnails` | Cloud Storage `object.v1.finalized` | bucket filter; `trigger_region` matches the bucket location |
| `profile-sync` | Firestore `document.v1.written` | `match-path-pattern` filter on `users/{userId}` |
| `audit-watch` | Cloud Audit Logs | `serviceName` and `methodName` filters, global trigger |

The defaults give every trigger the `events-trigger` service account, retry failed events, and list that service account in `invokers`, which grants it `roles/run.invoker` on each function. A function can override any of this (`partner-feed` and `audit-watch` turn retries off).

Before applying, create the `events-runtime` and `events-trigger` service accounts and the `orders` topic; grant `events-trigger` `roles/eventarc.eventReceiver`; for the storage trigger, grant the Cloud Storage service agent `roles/pubsub.publisher`; enable Data Access audit logs for IAM for `audit-watch`.
