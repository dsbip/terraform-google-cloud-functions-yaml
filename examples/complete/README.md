# Complete example

Every configuration key the module supports, across eight functions (one of them disabled). `tests/python/test_schema.py` fails if a key is ever missing from this example. Read [`config.yaml`](config.yaml) next to [docs/functions.md](../../docs/functions.md).

| Function | Trigger | Source | Highlights |
|---|---|---|---|
| `checkout` (deployed as `shop-checkout`) | HTTP, public | local directory, `tests/**` excluded | 2 CPUs, concurrency 80, warm instance, secret env vars (one cross-project), label override, viewer IAM |
| `inventory-sync` | Pub/Sub | local directory | other region, Direct VPC egress, internal ingress, cross-project secret volume |
| `webhooks` | Cloud Storage | local directory | CMEK, private build, VPC connector, Binary Authorization, `PREVENT` deletion |
| `receipts` | HTTP | local zip | Node.js, `ON_DEPLOY` updates, extra build variable, conditional IAM |
| `tax-rates` | HTTP | existing object, pinned generation | deployed to another project |
| `cleanup` | Pub/Sub | Cloud Source Repositories commit | 540 s timeout, no retries |
| `user-events` | Firestore | Cloud Source Repositories tag | `match-path-pattern` filter |
| `legacy-checkout` | – | repository branch in another project | `enabled: false` |

The defaults show all three merge levels: `build_config.runtime` (level 2), `build_config.source.bucket` (level 3), and `service_config.environment_variables`, whose keys are merged with each function's own variables.
