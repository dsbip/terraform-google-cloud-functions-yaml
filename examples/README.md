# Examples

Each example is a root module with a `config.yaml` and a `main.tf` that calls the module. All of them are planned with the real provider in CI (`tests/python/test_example_plans.py`) and checked against their README by `tests/examples.tftest.hcl`.

| Example | Functions | Shows |
|---|---|---|
| [basic](basic) | 1 | one public HTTP function from a local directory |
| [http-functions](http-functions) | 4 | four runtimes, memory/CPU, concurrency, warm instances, timeouts, ingress, secrets, invokers, IAM, shared defaults, update policies |
| [event-driven](event-driven) | 5 | Pub/Sub (short and cross-project topics), Cloud Storage, Firestore path patterns, Audit Logs, retries, trigger service accounts |
| [networking-and-security](networking-and-security) | 3 | VPC connector, Direct VPC egress, ingress, CMEK, secret volumes, cross-project secrets, Binary Authorization, private builds, conditional IAM, deletion protection |
| [prebuilt-artifacts](prebuilt-artifacts) | 5 | local zip, existing objects, pinned generations, Cloud Source Repositories, release variables |
| [multi-environment](multi-environment) | 3 per environment | one file for dev, staging and prod: placeholders, expressions, `%{ if }` blocks, `enabled` |
| [complete](complete) | 8 | every configuration key |
| [standalone-modules](standalone-modules) | 3 | `modules/function` and `modules/source-archive` without YAML, with `for_each` |

Run one:

```bash
cd examples/basic
terraform init
terraform apply -var project_id=my-project -var source_bucket=my-function-sources
```
