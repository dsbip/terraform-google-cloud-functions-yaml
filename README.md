# terraform-google-cloud-functions-yaml

[![CI](https://github.com/dsbip/terraform-google-cloud-functions-yaml/actions/workflows/ci.yml/badge.svg)](https://github.com/dsbip/terraform-google-cloud-functions-yaml/actions/workflows/ci.yml)

A Terraform module that deploys any number of **Cloud Run functions** (Cloud Functions 2nd gen) from one YAML file:

- **HTTP and event-driven functions**: Pub/Sub, Cloud Storage, Firestore, Cloud Audit Logs and any other Eventarc event, with filters, path patterns, retries and trigger service accounts
- **Source code from anywhere**: a local directory (zipped and uploaded under a content hash), a prebuilt zip, an existing Cloud Storage object (optionally pinned to a generation) or Cloud Source Repositories
- **Runtime settings**: memory, CPU, concurrency, scaling, timeouts, ingress, environment variables, Secret Manager secrets as variables or files
- **Networking and security**: Serverless VPC Access connectors, Direct VPC egress, CMEK, Binary Authorization, private Cloud Build worker pools, build service accounts, deletion protection
- **Access**: invokers (`roles/run.invoker`), function IAM with conditions
- **Defaults** shared by every function, merged three levels deep, plus `${...}` templating and `%{ if }` blocks for one file across environments

Each function is one YAML entry instead of a resource, a source upload and IAM grants in HCL, and the module catches mistakes before anything reaches Google Cloud. A typo fails the plan with its YAML path and a suggestion, for example `functions.api.service_config: unknown key "memory" (did you mean available_memory?)`.

```yaml
# functions.yaml
defaults:
  region: europe-west1
  functions:
    build_config:
      runtime: python312
      source: { bucket: my-function-sources }

functions:
  hello:
    build_config:
      entry_point: hello
      source: { dir: src/hello }        # zipped, uploaded, redeployed when it changes
    invokers: [allUsers]                # public HTTP function

  order-events:
    build_config:
      entry_point: on_order
      source: { dir: src/orders }
    service_config:
      max_instance_count: 10
      secret_environment_variables:
        - { key: API_KEY, secret: orders-api-key }
    event_trigger:
      pubsub_topic: orders              # short name: projects/<project>/topics/orders
```

```hcl
module "functions" {
  source = "github.com/dsbip/terraform-google-cloud-functions-yaml?ref=v1.0.0"

  project_id  = "my-project"
  config_file = "${path.module}/functions.yaml"
}
```

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Usage](#usage)
- [Module structure](#module-structure)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Examples](#examples)
- [Documentation](#documentation)
- [Testing](#testing)

## Features

| Area | What the YAML covers | Docs |
|---|---|---|
| File | `project_id`, `defaults` (region, labels, function defaults), templating, `enabled` | [configuration.md](docs/configuration.md) |
| Build | runtime, entry point, build variables, Artifact Registry repository, build service account, worker pool, base image update policy | [functions.md](docs/functions.md#build_config) |
| Source | local `dir` (with `excludes`), local `zip`, existing `object` (+ `generation`), Cloud Source Repositories `repo` | [functions.md](docs/functions.md#source) |
| Runtime | memory, CPU, timeout, min/max instances, concurrency, environment variables, secrets (variables and volumes), ingress, runtime service account, traffic, Binary Authorization | [functions.md](docs/functions.md#service_config) |
| Networking | VPC connector with egress settings, Direct VPC egress with network interfaces and tags | [functions.md](docs/functions.md#service_config) |
| Triggers | any Eventarc event type, Pub/Sub shortcuts, event filters with path patterns, retry policy, trigger region, trigger service account | [functions.md](docs/functions.md#event_trigger) |
| Access | invokers, IAM bindings with conditions | [functions.md](docs/functions.md#invokers-and-iam) |
| Validation | unknown keys, types, enumerations, ranges, patterns, required keys, cross-field rules, duplicates, missing files: all reported at once with YAML paths | [configuration.md](docs/configuration.md#validation) |

## Requirements

| | Version |
|---|---|
| Terraform | >= 1.5 (the unit tests need >= 1.7) |
| `hashicorp/google` provider | >= 7.42, < 9.0 |
| `hashicorp/archive` provider | >= 2.4, < 3.0 (only used for local `dir` sources) |

APIs: Cloud Functions, Cloud Build, Cloud Run, Artifact Registry, Cloud Storage; Eventarc and Pub/Sub for event-driven functions. The bucket for uploaded sources, service accounts, secrets, topics, connectors and keys referenced in the YAML must already exist.

## Usage

1. Write a YAML file (start from an [example](examples/README.md)). Add this line at the top to get autocompletion and validation in editors that support the YAML language server:

   ```yaml
   # yaml-language-server: $schema=<path to>/schemas/cloud-functions-config.schema.json
   ```

2. Call the module with `config_file` (rendered with `templatefile()`) or `config_yaml` (used as-is):

   ```hcl
   module "functions" {
     source = "github.com/dsbip/terraform-google-cloud-functions-yaml?ref=v1.0.0"

     project_id    = var.project_id
     region        = "europe-west1"
     config_file   = "${path.module}/functions.yaml"
     template_vars = { env = "prod", source_bucket = google_storage_bucket.sources.name }
     labels        = { managed-by = "terraform" }
   }
   ```

3. `terraform plan`. If the file has problems, the plan fails with all of them:

   ```text
   The Cloud Functions YAML configuration has 3 problem(s):
     - functions.api: unknown key "descripton" (did you mean description?)
     - functions.api.service_config.ingress_settings: must be one of ALLOW_ALL, ALLOW_INTERNAL_ONLY, ALLOW_INTERNAL_AND_GCLB (got "INTERNAL")
     - functions.worker.build_config.source: set exactly one of dir, zip, object and repo (found dir, object)
   ```

## Module structure

The module is three layers, and the lower two work on their own:

```text
root module (this directory)          YAML → validated, merged, normalised inputs
  │  main.tf        load + template + defaults merge
  │  validation.tf  schema-driven checks + rules, gate for_each
  │  functions.tf   module "function" { for_each = functions }
  ▼
modules/function                      one function + invokers + IAM (typed inputs)
  ▼
modules/source-archive                zip a directory / take a zip, upload under its MD5
```

- [`modules/function`](modules/function/README.md): deploys one function from typed HCL inputs. Use it directly when you don't want YAML, as in [examples/standalone-modules](examples/standalone-modules).
- [`modules/source-archive`](modules/source-archive/README.md): packages and uploads source code. Use it to share one upload between several functions.
- [`schemas/cloud-functions-config.schema.json`](schemas/cloud-functions-config.schema.json): the YAML format. Editors use it for completion; `validation.tf` reads allowed keys, types, enumerations, ranges and patterns from it, so the two cannot disagree.

See [docs/design.md](docs/design.md) for why it is built this way.

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `config_file` | Path to the YAML file, rendered with `templatefile()` (`$${...}` placeholders, `%{ if }` directives). Exactly one of `config_file` and `config_yaml`. | `string` | `null` |
| `config_yaml` | YAML as a string, used as-is (e.g. `yamlencode({...})`). | `string` | `null` |
| `template_vars` | Values for placeholders in `config_file`. `project_id` and `region` are always available. | `any` | `{}` |
| `project_id` | Default project. The YAML's top-level `project_id` and a function's own `project_id` take precedence. | `string` | `null` |
| `region` | Default region. `defaults.region` and a function's own `region` take precedence. | `string` | `null` |
| `labels` | Labels added to every function; YAML labels win on conflicts. | `map(string)` | `{}` |
| `base_path` | Directory that relative `source.dir` / `source.zip` paths resolve against. Defaults to the directory of `config_file` (or the root module with `config_yaml`). | `string` | `null` |
| `archive_output_dir` | Where zipped directories are written locally before upload. | `string` | `.terraform/cloud-functions-yaml` in the root module |

## Outputs

| Name | Description |
|---|---|
| `functions` | Per YAML key: `id`, `name`, `project_id`, `region`, `uri`, `url`, `service`, `service_account_email`, `state`, `event_trigger`, `source` |
| `uris` | YAML key → HTTPS URI |
| `ids` | YAML key → function ID |
| `config` | The normalised configuration of every function (after defaults and path resolution), including disabled ones. Useful for debugging. |

## Examples

| Example | Shows |
|---|---|
| [basic](examples/basic) | one public HTTP function from a local directory |
| [http-functions](examples/http-functions) | Python, Node.js, Go and Java; scaling, concurrency, secrets, ingress, invokers, shared defaults |
| [event-driven](examples/event-driven) | Pub/Sub (same and other project), Cloud Storage, Firestore and Audit Log triggers |
| [networking-and-security](examples/networking-and-security) | VPC connector, Direct VPC egress, CMEK, secret volumes, Binary Authorization, private builds, conditional IAM, deletion protection |
| [prebuilt-artifacts](examples/prebuilt-artifacts) | local zip, existing objects (pinned generation), Cloud Source Repositories, release variables |
| [multi-environment](examples/multi-environment) | one file for dev/staging/prod with placeholders, `%{ if }` blocks and `enabled` |
| [complete](examples/complete) | every configuration key (checked by a test) |
| [standalone-modules](examples/standalone-modules) | the submodules from plain HCL, without YAML |

## Documentation

- [docs/configuration.md](docs/configuration.md): file structure, templating, defaults and how they merge, precedence, validation
- [docs/functions.md](docs/functions.md): every key of a function
- [docs/design.md](docs/design.md): how configuration flows through the module
- [docs/testing.md](docs/testing.md): the test layers and how to run them
- [docs/troubleshooting.md](docs/troubleshooting.md): common errors and their fixes

## Testing

```bash
scripts/test.sh     # fmt, validate, 70+ terraform tests (mocked provider), schema/doc checks, real-provider plans of every example
```

A live test deploys [tests/integration](tests/integration) into a real project, checks that a second plan is empty, updates in place and destroys everything; see [docs/testing.md](docs/testing.md).

## License

Apache 2.0, see [LICENSE](LICENSE).
