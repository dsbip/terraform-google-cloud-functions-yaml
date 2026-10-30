# modules/dataflow

Launches Dataflow jobs and creates Data Pipelines from one YAML file per environment. In this repository it is called once, from [terraform/infra/dataflow.tf](../../terraform/infra/dataflow.tf), with the environment's `terraform/<env>/dataflow.yaml` (dev: [terraform/dev/dataflow.yaml](../../terraform/dev/dataflow.yaml)).

It is a copy of [terraform-google-dataflow-yaml](https://github.com/dsbip/terraform-google-dataflow-yaml) 1.0.0, split like the other modules in this repository: the root module here, its submodules in [modules/dataflow-config](../dataflow-config). [VENDORED.md](VENDORED.md) records the origin, the local changes and how to upgrade.

## Layout

```text
modules/
├── dataflow/                               root module: YAML → validated, merged entries
│   ├── main.tf                             loads and templates the YAML, merges defaults, template types
│   ├── validation.tf                       schema-driven checks and rules, every problem at once
│   ├── jobs.tf                             module "classic_job" / "flex_job": one instance per job
│   ├── pipelines.tf                        module "pipeline": one instance per pipeline
│   ├── variables.tf, outputs.tf, versions.tf
│   ├── schemas/
│   │   └── dataflow-config.schema.json     the YAML format, read by main.tf on every plan (required)
│   ├── docs/                               reference of every YAML key, design, troubleshooting
│   └── VENDORED.md, CHANGELOG.md, LICENSE
└── dataflow-config/                        submodules, one resource each
    ├── classic-job/                        google_dataflow_job
    ├── flex-job/                           google_dataflow_flex_template_job (google-beta provider)
    └── pipeline/                           google_data_pipeline_pipeline
```

## The YAML in short

```yaml
project_id: my-dev-project

defaults:
  region: europe-west2
  jobs:                                   # merged underneath every job
    service_account_email: dataflow-worker@my-dev-project.iam.gserviceaccount.com
    temp_location: gs://my-dev-project-dataflow/tmp

jobs:                                     # streaming jobs, launched by terraform apply
  events-to-bigquery:
    google_template: { name: PubSub_to_BigQuery_Flex }
    parameters:
      inputSubscription: projects/my-dev-project/subscriptions/events
      outputTableSpec: my-dev-project:raw.events

pipelines:                                # recurring batch work, launched by Cloud Scheduler
  nightly-export:
    schedule: "0 2 * * *"
    google_template: { name: BigQuery_to_Parquet }
    parameters:
      tableRef: my-dev-project:curated.orders
      bucket: gs://my-dev-project-exports/orders/
```

| Reference | Covers |
|---|---|
| [docs/configuration.md](docs/configuration.md) | file structure, defaults and how they merge, templating, YAML anchors, precedence, validation |
| [docs/jobs.md](docs/jobs.md) | every job key; classic, Flex and Google-provided templates |
| [docs/pipelines.md](docs/pipelines.md) | every pipeline key |
| [docs/troubleshooting.md](docs/troubleshooting.md) | common errors |

Editors with the YAML language server (in VS Code, the Red Hat YAML extension) validate and complete the file through the comment on its first line, `# yaml-language-server: $schema=../../modules/dataflow/schemas/dataflow-config.schema.json`.

**Batch jobs end.** The provider removes a finished batch job from the state, so the next `terraform apply` launches it again, and CI applies on every merge. Put recurring batch work under `pipelines`; use `jobs` for streaming.

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `config_file` | Path to the YAML file, rendered with `templatefile()`. Exactly one of `config_file` and `config_yaml`. | `string` | `null` |
| `config_yaml` | YAML as a string, used as-is. | `string` | `null` |
| `template_vars` | Values for placeholders in `config_file`. `project_id` and `region` are always available. | `any` | `{}` |
| `project_id` | Default project. The YAML's top-level `project_id` and an entry's own `project_id` take precedence. | `string` | `null` |
| `region` | Default region. `defaults.region` and an entry's own `region` take precedence. | `string` | `null` |
| `labels` | Labels added to every job and to the jobs of every pipeline; YAML labels win on conflicts. | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `jobs` | Per YAML key: `id`, `job_id`, `name`, `project_id`, `region`, `state`, `type`, `template_type` (`classic` or `flex`), `template` |
| `pipelines` | Per YAML key: `id`, `name`, `project_id`, `region`, `job_name`, `type`, `state`, `template_type`, `template`, `next_job_time` |
| `job_ids` | YAML key → Dataflow job ID |
| `config` | The normalised configuration (after defaults) of every job and pipeline, including disabled ones |

## Requirements

| | Version |
|---|---|
| Terraform | >= 1.5 |
| `hashicorp/google` provider | >= 7.42, < 9.0 |
| `hashicorp/google-beta` provider | >= 7.42, < 9.0 (Flex Template jobs exist only in google-beta) |

APIs: Dataflow; Data Pipelines and Cloud Scheduler for pipelines. Buckets, topics, tables, networks, keys and service accounts named in the YAML must exist before a job using them is launched.

## Differences from upstream

The code differs from upstream in three lines: the `source` of the submodule calls is `../dataflow-config/<name>` here instead of `./modules/<name>` (two in `jobs.tf`, one in `pipelines.tf`). Everything else, the schema and the docs included, is upstream's. [VENDORED.md](VENDORED.md) lists what was copied and how to upgrade.
