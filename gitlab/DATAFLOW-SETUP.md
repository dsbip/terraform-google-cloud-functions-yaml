# Dataflow in the GitLab repository

How to add the YAML-driven Dataflow module ([terraform-google-dataflow-yaml](https://github.com/dsbip/terraform-google-dataflow-yaml): Dataflow jobs and Data Pipelines from one YAML file per environment) to the GitLab repository: where every file goes, what the pipeline needs, and what each environment's project needs. It is set up the same way as the Cloud Functions module:

| | Cloud Functions | Dataflow |
|---|---|---|
| Root module | `modules/cloud-functions/` | `modules/dataflow/` |
| Submodules | `modules/cf-config/` | `modules/dataflow-config/` |
| Module call | `terraform/infra/cloud-functions.tf` | `terraform/infra/dataflow.tf` |
| Configuration | `terraform/dev/cf.yaml` | `terraform/dev/dataflow.yaml` |
| Path variable | `cf_yaml_config_path` | `dataflow_yaml_config_path` |

| Folder | Contents |
|---|---|
| [`repo-root/`](repo-root) | The repository's layout, holding only the paths this change adds or touches, each at its real location. |
| [`ci-snippets/dataflow.gitlab-ci.yml`](ci-snippets/dataflow.gitlab-ci.yml) | Additions for the GitLab pipeline, to merge into the existing one. |

1. [What goes where](#1-what-goes-where)
2. [Why this layout](#2-why-this-layout)
3. [Setting it up](#3-setting-it-up)
4. [How it fits together](#4-how-it-fits-together)
5. [What each environment's project needs](#5-what-each-environments-project-needs)
6. [GitLab pipeline](#6-gitlab-pipeline)
7. [Everyday changes](#7-everyday-changes)
8. [Pitfalls](#8-pitfalls)

## 1. What goes where

```text
repo-root/                                     the root of the GitLab repository
├── modules/
│   ├── dataflow/                              NEW: the YAML-driven root module
│   │   ├── VENDORED.md                        origin, version, the local changes, how to upgrade
│   │   ├── jobs.tf, pipelines.tf              call ../dataflow-config/... (the three changed lines)
│   │   ├── main.tf, validation.tf, variables.tf, outputs.tf, versions.tf
│   │   ├── schemas/
│   │   │   └── dataflow-config.schema.json    read on every plan (validation) and by editors
│   │   ├── docs/                              configuration.md, jobs.md, pipelines.md (every key), design.md, troubleshooting.md
│   │   └── README.md, CHANGELOG.md, LICENSE
│   └── dataflow-config/                       NEW: the submodules, unchanged
│       ├── classic-job/                       google_dataflow_job
│       ├── flex-job/                          google_dataflow_flex_template_job (google-beta provider)
│       └── pipeline/                          google_data_pipeline_pipeline
└── terraform/
    ├── dev/
    │   ├── dataflow.yaml                      NEW: the jobs and pipelines of dev, next to cf.yaml, bq.yaml, ...
    │   └── variables.tfvars.dataflow.append   APPEND to variables.tfvars
    └── infra/
        ├── dataflow.tf                        NEW: module "dataflow", next to cloud-functions.tf
        ├── variables.tf.dataflow.append       APPEND to variables.tf
        └── backend.tf.dataflow.append         APPEND to the file with provider "google" (often backend.tf)
```

Files ending in `.append` hold only the lines to add. They are named `<file>.<module>.append`, so that the Cloud Functions additions to the same files can sit next to them, and so that copying the whole folder over the repository can't overwrite `variables.tf`, `variables.tfvars` or `backend.tf`.

## 2. Why this layout

**The repository's module layout, with three lines changed.** The repository keeps a YAML-driven module in `modules/<name>/` and its submodules in `modules/<name>-config/`. The files find each other by relative path, and two of those paths needed work:

| File | Refers to | Needed |
|---|---|---|
| `modules/dataflow/jobs.tf` | `./modules/classic-job` and `./modules/flex-job` upstream, which don't exist in this layout: `terraform init` would fail | Changed to `../dataflow-config/classic-job` and `../dataflow-config/flex-job` |
| `modules/dataflow/pipelines.tf` | `./modules/pipeline` upstream | Changed to `../dataflow-config/pipeline` |
| `modules/dataflow/main.tf` | `${path.module}/schemas/dataflow-config.schema.json`, read on every plan to validate the YAML | `schemas/` inside `modules/dataflow/`: without it every plan fails |

These three `source` lines, recorded in `VENDORED.md` and in a comment in each file, are the module's only code changes; every other `.tf` file and the schema are byte for byte the upstream version. If you would rather have no local change at all, nest the submodules in `modules/dataflow/modules/` instead (upstream's layout) and keep upstream's `jobs.tf` and `pipelines.tf`.

**Configuration per environment, next to the other YAMLs.** `terraform/dev/dataflow.yaml` sits beside `cf.yaml`, `bq.yaml` and `gcs.yaml` and is selected the same way, by a path in `terraform/dev/variables.tfvars`. Another environment gets its own `dataflow.yaml` and one line in its tfvars.

**`dataflow.tf` only passes the path.** The YAML carries `project_id` and `defaults.region`, and the module reads them itself. The module is created only for an environment that sets `dataflow_yaml_config_path` (`count`), so environments opt in one at a time and the others plan exactly as before. The path is deliberately not checked with `fileexists()`: a mistyped or moved file would turn into "no Dataflow", and the plan would destroy every job of the environment. Instead a wrong path fails the plan.

**The dev file deploys nothing until you say so.** Every entry starts with `enabled: false`, so the first plan checks the whole file and creates nothing but the module's validation check. A streaming job costs money from its first minute; enable entries one at a time, once their placeholders are replaced.

## 3. Setting it up

1. **Module.** Copy [`repo-root/modules/dataflow/`](repo-root/modules/dataflow) and [`repo-root/modules/dataflow-config/`](repo-root/modules/dataflow-config) into `modules/` of the repository, `schemas/` included.
2. **Wiring.** Copy [`terraform/infra/dataflow.tf`](repo-root/terraform/infra/dataflow.tf). Append [`variables.tf.dataflow.append`](repo-root/terraform/infra/variables.tf.dataflow.append) to `terraform/infra/variables.tf`.
3. **google-beta.** Flex Template jobs (most Google-provided templates, and your own Flex Templates) use the `hashicorp/google-beta` provider. Append [`backend.tf.dataflow.append`](repo-root/terraform/infra/backend.tf.dataflow.append) to the file that holds `provider "google"` (often `backend.tf`), and give the new `provider "google-beta"` block the same arguments as `provider "google"`, so that both act as the same identity. Skip this if a `provider "google-beta"` block exists already. If that file has a `required_providers` block, add google-beta to it, pinned like google:

   ```hcl
       google-beta = {
         source  = "hashicorp/google-beta"
         version = ">= 7.42.0, < 9.0.0"
       }
   ```

   A module can have only one `required_providers` block: a second one in another file fails `terraform init` with "Duplicate required providers configuration".
4. **Dev configuration.** Copy [`terraform/dev/dataflow.yaml`](repo-root/terraform/dev/dataflow.yaml). Append [`variables.tfvars.dataflow.append`](repo-root/terraform/dev/variables.tfvars.dataflow.append) to `terraform/dev/variables.tfvars`, and write the path the same way as the other `*.yaml` paths in that file: `"../dev/dataflow.yaml"` assumes Terraform runs in `terraform/infra`.
5. **Placeholders.** Replace every `REPLACE-ME` in `terraform/dev/dataflow.yaml`: project, buckets, service accounts, subnetwork, subscription, datasets. Check `region` and `time_zone` as well. [Section 5](#5-what-each-environments-project-needs) lists what must exist before an entry is enabled.
6. **Provider versions.** Make sure nothing in `terraform/infra` (often `backend.tf`) or in the other modules pins the google provider below 7.42 ([section 6](#6-gitlab-pipeline)).
7. **Pipeline.** Merge what applies from [`ci-snippets/dataflow.gitlab-ci.yml`](ci-snippets/dataflow.gitlab-ci.yml) ([section 6](#6-gitlab-pipeline)).
8. **Plan and apply.** For dev, the plan adds 1 resource, `module.dataflow[0].terraform_data.validation`: the whole file is checked and nothing is launched. Then set `enabled: true` on an entry and plan again: every enabled job adds a `google_dataflow_flex_template_job` (`google_dataflow_job` for classic templates), every enabled pipeline a `google_data_pipeline_pipeline`.

To try it locally (Terraform >= 1.5, credentials for dev), from `terraform/infra`:

```bash
terraform init            # with the backend settings you normally use
terraform plan -var-file=../dev/variables.tfvars
```

This layout was checked with google and google-beta providers 8.9.0. With Terraform 1.5.7 (the module's minimum): `fmt`, `init`, `validate`, the dev plan (1 resource), a plan with every entry enabled (4 resources: the Flex Template job, the two pipelines and the validation check) and an environment without `dataflow_yaml_config_path` (no resources), each with and without the appended google-beta block, and the validation errors (a typo, a wrong path, a missing `schemas/`). With Terraform 1.17.1: the same three plans with the google-beta block. Also the pipeline's schema check job.

## 4. How it fits together

```text
terraform/dev/variables.tfvars    dataflow_yaml_config_path = "../dev/dataflow.yaml"
        │
        ▼
terraform/infra/dataflow.tf       module "dataflow"
        │                           count       = 0 if dataflow_yaml_config_path is unset
        │                           config_file = var.dataflow_yaml_config_path
        ▼
modules/dataflow                  renders dataflow.yaml (templatefile), merges the defaults, checks the
        │                         result against schemas/ and the cross-field rules; if anything is
        │                         wrong, the plan stops and lists every problem with its YAML path
        ▼
modules/dataflow-config           one instance per enabled entry:
  ├── classic-job                   google_dataflow_job (classic templates)
  ├── flex-job                      google_dataflow_flex_template_job (Flex Templates, google-beta)
  └── pipeline                      google_data_pipeline_pipeline (scheduled or streaming pipelines)
```

A mistake in `dataflow.yaml` stops the plan before anything is planned, with every problem at once, disabled entries included. Here `machine_type` was misspelled in the shared worker settings, which `&workers` also merges into the pipeline defaults:

```text
The Dataflow YAML configuration has 2 problem(s):
  - defaults.jobs: unknown key "machine" (did you mean machine_type?)
  - defaults.pipelines: unknown key "machine" (did you mean machine_type?)
```

The outputs `dataflow_jobs` and `dataflow_pipelines` (job IDs, states, the next scheduled run) show up in the plan and apply logs.

## 5. What each environment's project needs

The module creates the jobs and pipelines. Everything they refer to has to exist first. In this repository that means entries in `sa.yaml`, `gcs.yaml`, `iam-bindings.yaml` and `bq.yaml`, applied before (or in an earlier merge request than) the entries that use them: `dataflow.yaml` names them as plain strings, so Terraform can't order their creation by itself ([Pitfalls](#8-pitfalls)).

**APIs:** `dataflow`, `compute` (the workers are Compute Engine VMs), `storage`; for pipelines also `datapipelines` and `cloudscheduler`; and whatever the templates read and write, such as `pubsub` and `bigquery`.

**Bucket** for `temp_location` and `staging_location`, in the jobs' region.

**Service accounts and roles** (the names are the ones used in `dataflow.yaml`):

| Account | Roles | Purpose |
|---|---|---|
| `dataflow-worker@` (`service_account_email`) | `roles/dataflow.worker`; what the jobs read and write, e.g. `roles/pubsub.subscriber` on the subscription, `roles/bigquery.dataEditor` on the dataset and `roles/bigquery.jobUser`, `roles/storage.objectAdmin` on the temp bucket; `roles/artifactregistry.reader` for the images of your own Flex Templates | The identity the workers, and a Flex Template's launcher VM, run as. |
| `dataflow-scheduler@` (`scheduler_service_account_email`, pipelines only) | `roles/datapipelines.invoker`; `roles/iam.serviceAccountUser` on `dataflow-worker`. If scheduled runs fail with `PERMISSION_DENIED`, also `roles/dataflow.developer` | Starts each scheduled run. Without it, Cloud Scheduler uses the Compute Engine default service account. |
| Dataflow service agent `service-<project-number>@dataflow-service-producer-prod.iam.gserviceaccount.com` | Created by Google. Shared VPC: `roles/compute.networkUser` on the host project's subnetwork (`dataflow-worker` too). CMEK: `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the key (the Compute Engine service agent too) | Manages the workers. |
| The pipeline's identity (GitLab runner) | `roles/dataflow.admin`; `roles/datapipelines.admin` for pipelines; `roles/iam.serviceAccountUser` on `dataflow-worker` and `dataflow-scheduler` | Deploys everything above. |

**Network:** `ip_configuration: WORKER_IP_PRIVATE`, the dev file's default, needs Private Google Access on the subnetwork. With Shared VPC, `subnetwork` must be the full URL. Data Pipelines can only be created in regions where Cloud Scheduler is available.

**Organization policies** that commonly stop a first launch:

| Constraint | Symptom | Way out |
|---|---|---|
| `compute.vmExternalIpAccess` | Workers with public IPs are refused | `ip_configuration: WORKER_IP_PRIVATE`, as the dev file sets. |
| `compute.restrictSharedVpcSubnetworks` | Subnetwork rejected | A subnetwork the project may use. |
| `gcp.resourceLocations` | Region rejected | An allowed `defaults.region` (and `worker_region`, `worker_zone`). |
| `iam.automaticIamGrantsForDefaultServiceAccounts` | Workers or scheduled runs lack permissions | Dedicated worker and scheduler accounts, as `dataflow.yaml` already sets. |
| `gcp.restrictNonCmekServices` | Jobs rejected without a customer-managed key | `kms_key_name` in `defaults.jobs` and `defaults.pipelines`. |

## 6. GitLab pipeline

[`ci-snippets/dataflow.gitlab-ci.yml`](ci-snippets/dataflow.gitlab-ci.yml) contains the additions as a hidden job and commented fragments. What to check:

1. **Terraform and provider versions.** The module needs Terraform >= 1.5 and `hashicorp/google` and `hashicorp/google-beta` >= 7.42, < 9.0, the same floor as the Cloud Functions module. Terraform combines provider constraints across the root and every module it calls, so a `~> 6.0` (or `~> 5.0`) anywhere in `terraform/infra` or `modules/*` makes `terraform init` fail with "no available releases match the given constraints". Find the constraints with `grep -rn "hashicorp/google" -A2 terraform modules`.
2. **The google-beta provider.** If the runners install providers from a mirror (Artifactory, or a `provider_installation` block in the runner's CLI configuration), google-beta has to be in it. If `.terraform.lock.hcl` is committed, run `terraform init` once and commit the result, or `terraform providers lock -platform=linux_amd64 -platform=windows_amd64` to cover Windows laptops too. A pipeline that runs `terraform init -lockfile=readonly` fails until then.
3. **Changes must start Terraform.** If the plan and apply jobs have `rules: changes:` filters, they must cover `modules/**/*` and `terraform/**/*`. A saved plan needs no extra artifacts: the module writes no files during the plan.
4. **Every apply launches finished batch jobs again.** The provider removes a finished batch job from the state, and the pipeline applies on every merge, so a batch job under `jobs` would run again after every merge. Recurring batch work belongs under `pipelines`, which Cloud Scheduler launches; `jobs` are for streaming.
5. **Streaming jobs and the job timeout.** With `on_delete: drain`, a destroy, or a change that replaces the job, waits until the job has drained, which can outlast the CI job's timeout. `on_delete: cancel`, the dev file's choice, returns quickly; production jobs usually drain.
6. **Optional job.** `.dataflow:validate-yaml` checks every `terraform/*/dataflow.yaml` against the schema without Google Cloud access. Extend it with a stage your pipeline has. The image and `pip` may have to go through your internal registry and proxy.

## 7. Everyday changes

| Task | How |
|---|---|
| Add a streaming job | An entry under `jobs` in `terraform/<env>/dataflow.yaml`: a template (`google_template`, `container_spec_gcs_path` or `template_gcs_path`) and its `parameters`. |
| Add recurring batch work | An entry under `pipelines` with a cron `schedule` and a template. |
| Change settings | Edit `dataflow.yaml`. Most pipeline changes are updates in place; a streaming job is updated or replaced, and renamed transforms keep their state with `transform_name_mapping`. |
| Pause a pipeline | `state: PAUSED`; `ACTIVE` resumes it. |
| New environment | `terraform/<env>/dataflow.yaml` (copy dev's; change project, buckets, service accounts, sizes; for production streaming jobs `on_delete: drain` and `deletion_policy: PREVENT`) and `dataflow_yaml_config_path = "../<env>/dataflow.yaml"` in `terraform/<env>/variables.tfvars`. |
| Keep an entry out of an environment | Leave it out of that `dataflow.yaml`, or set `enabled: false` (still validated, not deployed). |
| Remove a job or pipeline | Delete its entry; the plan destroys it, and a streaming job is drained or cancelled as `on_delete` says. |
| Protect prod | `deletion_policy: PREVENT` on production streaming jobs makes any destroy of them fail. |
| Rename | Changing a key or `name` replaces the job or pipeline. |
| One file for every environment | Pass `template_vars` (e.g. `{ env = "dev" }`) in `dataflow.tf` and use placeholders; see "Templating" in [docs/configuration.md](repo-root/modules/dataflow/docs/configuration.md#templating). |
| Upgrade the module | [`modules/dataflow/VENDORED.md`](repo-root/modules/dataflow/VENDORED.md); re-apply the three `source` changes. |

## 8. Pitfalls

- **Prerequisites in the same apply.** If a merge request adds a service account, bucket or table together with the entry that uses it, the first apply can fail because the job is launched first; apply again, or land the prerequisites first. `depends_on` on the module, prepared as a comment in `dataflow.tf`, orders them; the module reads no data sources, so it has no other effect.
- **Templating.** `dataflow.yaml` is rendered with `templatefile()`, comments included: write `$${` for a literal `${` and `%%{` for a literal `%{`.
- **YAML 1.1.** Unquoted `yes`, `no`, `on` and `off` become booleans, also as keys, and version-like values (`1.10`) become numbers; quote them. Template parameters reach Dataflow as strings.
- **Google template versions.** `google_template` launches the `latest` release unless `version` pins one, such as `2026-09-15-00_RC00`. Pin a release in production, so that a replaced job doesn't silently pick up a new template.
- **Names.** The YAML key is the default name: job names take lowercase letters, digits and hyphens; pipeline IDs letters, digits, hyphens and underscores (at most 63).
- **Regions.** Data Pipelines exist only where Cloud Scheduler is available; `worker_region` can still place the workers elsewhere, for example next to the data.

More: [docs/troubleshooting.md](repo-root/modules/dataflow/docs/troubleshooting.md).
