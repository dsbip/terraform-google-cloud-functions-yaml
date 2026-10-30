# Cloud Functions module in your GitLab repository

How to add the YAML-driven Cloud Run functions module (Cloud Functions 2nd gen) to your GitLab repository: where every file goes, what the pipeline needs, and what each environment's project needs.

| Folder | Contents |
|---|---|
| `repo-root/` | The root of your GitLab repository, holding only the paths this change adds or touches, each at its real location. |
| `ci-snippets/cloud-functions.gitlab-ci.yml` | Additions for the GitLab pipeline, to merge into the existing one. |

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
repo-root/
├── .gitattributes.cloud-functions.append APPEND to .gitattributes (create it if missing)
├── .gitignore.cloud-functions.append     APPEND to .gitignore
├── modules/
│   ├── cf-config/                        REPLACE with this folder: the submodules, unchanged
│   │   ├── function/                     one function, its invoker grants and IAM
│   │   └── source-archive/               zips a source folder and uploads it
│   └── cloud-functions/                  REPLACE with this folder: the YAML-driven root module
│       ├── VENDORED.md                   origin, version, the one local change, how to upgrade
│       ├── functions.tf                  calls ../cf-config/function (the one changed line)
│       ├── versions.tf, variables.tf, main.tf, validation.tf, outputs.tf
│       ├── schemas/
│       │   └── cloud-functions-config.schema.json   read on every plan (validation) and by editors
│       ├── docs/                         configuration.md, functions.md (every key), design.md, troubleshooting.md
│       └── README.md, CHANGELOG.md, LICENSE
├── src/
│   └── cloud-functions/                  NEW: function code, one folder per function, shared by all environments
│       ├── README.md
│       └── smoke-test/                   sample function: main.py, requirements.txt, tests/test_main.py
└── terraform/
    ├── dev/
    │   ├── cf.yaml                       REPLACE (yours is empty): the functions of dev and their settings
    │   └── variables.tfvars.cloud-functions.append   APPEND to variables.tfvars
    └── infra/
        ├── cloud-functions.tf            REPLACE your draft
        └── variables.tf.cloud-functions.append       APPEND to variables.tf
```

Files ending in `.cloud-functions.append` hold only the lines to add. They are named that way so that copying the whole folder over the repository can't overwrite `variables.tf`, `variables.tfvars`, `.gitignore` or `.gitattributes`.

## 2. Why this layout

**The repository's module layout, with one line fixed.** The repository keeps a YAML-driven module in `modules/<name>/` and its submodules in `modules/<name>-config/`, and that is where the draft put the files: the root module in `modules/cloud-functions/`, `function/` and `source-archive/` in `modules/cf-config/`. The files find each other by relative path, and two of those paths needed work:

| File | Refers to | Needed |
|---|---|---|
| `modules/cloud-functions/functions.tf` | `./modules/function` upstream, which doesn't exist in this layout: `terraform init` fails with "Unreadable module directory … for module "function"" | Changed to `../cf-config/function`, the module's only local change (recorded in `VENDORED.md` and in a comment in the file). |
| `modules/cloud-functions/main.tf` | `${path.module}/schemas/cloud-functions-config.schema.json`, read on every plan to validate the YAML | `schemas/` inside `modules/cloud-functions/`. |
| `modules/cf-config/function/main.tf` | `../source-archive` | Already right: `function/` and `source-archive/` side by side. |

Every other file is byte for byte the upstream version. If you would rather have no local change at all, nest the two submodules in `modules/cloud-functions/modules/` instead (upstream's layout) and keep `functions.tf` as upstream has it.

**Configuration per environment, next to the other YAMLs.** `terraform/dev/cf.yaml` sits beside `bq.yaml`, `gcs.yaml` and `sa.yaml` and is selected the same way, by a path in `terraform/dev/variables.tfvars`. Another environment gets its own `cf.yaml` and one line in its tfvars.

**Code once, in `src/cloud-functions/`.** Unlike `schemas/` and `sql/` under `terraform/dev/`, function code isn't copied per environment. Every `cf.yaml` points into the same folder, so environments can't drift apart, and code reaches prod the way the rest of the repository does: through the branch or pipeline that deploys prod. `base_path` in `cloud-functions.tf` makes `source.dir` relative to `src/cloud-functions/`, so `cf.yaml` says `dir: smoke-test`.

**`cloud-functions.tf` is simpler than the draft.**

| Draft | Problem | Now |
|---|---|---|
| `yamldecode(file(var.cf_yaml_config_path))` to read `project_id` | The module already reads `project_id` from the YAML and gives it precedence. Decoding the raw file also fails on today's empty `cf.yaml` ("missing start of document") and on a file that uses `%{ if }` templating ("could not find expected directive name"). | Gone: `config_file` is enough. |
| `: object` fallback | `object` is a type, not a value, so the plan fails with "Invalid reference". | Gone. |
| `fileexists()` fallback | A mistyped or moved path would turn into "no functions", and the plan would destroy every function. | An environment without `cf_yaml_config_path` gets no functions (`count = 0`); a wrong path fails the plan with "The config_file variable must point to an existing file". |
| `module "functions"` | Vague next to the BigQuery, Composer and GCS modules of the same root. | `module "cloud_functions"`. Nothing was deployed from the draft (its YAML was empty), so the name is free to change. |

## 3. Setting it up

1. **Module.** Replace `modules/cloud-functions/` and `modules/cf-config/` in the repository with the two folders from here. Compared with what is there now, they add `schemas/`, `docs/`, the READMEs and `VENDORED.md`, and change one line in `functions.tf`.
2. **Code.** Copy `repo-root/src/` to the repository root.
3. **Wiring.** Replace `terraform/infra/cloud-functions.tf` with the one here. Append `variables.tf.cloud-functions.append` to `terraform/infra/variables.tf`.
4. **Dev configuration.** Replace `terraform/dev/cf.yaml`. Append `variables.tfvars.cloud-functions.append` to `terraform/dev/variables.tfvars`, and write the path the same way as the other `*.yaml` paths in that file: `"../dev/cf.yaml"` assumes Terraform runs in `terraform/infra`, as the draft's `../../modules/` source implies.
5. **Git.** Append `.gitattributes.cloud-functions.append` to `.gitattributes` (create the file if there is none) and `.gitignore.cloud-functions.append` to `.gitignore`. Commit `.gitattributes` together with `src/cloud-functions/`, so every checkout gets that folder with LF line endings ([Pitfalls](#8-pitfalls)).
6. **Placeholders.** Replace every `REPLACE-ME` in `terraform/dev/cf.yaml`: project, source bucket, service accounts, invoker group. [Section 5](#5-what-each-environments-project-needs) lists what must exist before the apply.
7. **Provider version.** Make sure nothing in `terraform/infra` (often `backend.tf`) or in the other modules pins the google provider below 7.42 ([section 6](#6-gitlab-pipeline)).
8. **Pipeline.** Merge what applies from `ci-snippets/cloud-functions.gitlab-ci.yml` ([section 6](#6-gitlab-pipeline)).
9. **Plan and apply.** For dev, the plan adds 4 resources: the validation check, the source archive, the `smoke-test` function and its invoker grant. After the apply, call the function (the command is in `cf.yaml`), then replace `smoke-test` with real functions.

To try it locally (Terraform >= 1.5, credentials for dev), from `terraform/infra`:

```bash
terraform init            # with the backend settings you normally use
terraform plan -var-file=../dev/variables.tfvars
```

This layout was checked with Terraform 1.17.1, google provider 8.9.0 and archive provider 2.8.1: `init`, `validate`, the dev plan (4 resources), a plan with the three patterns in `cf.yaml` uncommented (13 resources), the validation errors, a saved-plan apply without the archives, the sample's unit tests, and both pipeline job scripts.

## 4. How it fits together

```text
terraform/dev/variables.tfvars        cf_yaml_config_path = "../dev/cf.yaml"
        │
        ▼
terraform/infra/cloud-functions.tf    module "cloud_functions"
        │                               config_file = var.cf_yaml_config_path
        │                               base_path   = ../../src/cloud-functions
        ▼
modules/cloud-functions               renders cf.yaml (templatefile), merges the defaults, checks the
        │                             result against schemas/ and the cross-field rules; if anything is
        │                             wrong, the plan stops and lists every problem with its YAML path
        ▼
modules/cf-config/function            per function: google_cloudfunctions2_function,
        │                             roles/run.invoker grants, IAM
        ▼
modules/cf-config/source-archive      zips src/cloud-functions/<dir> minus the excludes and uploads it
                                      as gs://<bucket>/<object_prefix><name>-<md5>.zip
```

The plan writes each zip to `terraform/infra/.terraform/cloud-functions-yaml/`, and the apply uploads it. The object name contains the archive's MD5, so a function is rebuilt only when its folder changes. Terraform deletes the previous archive when it uploads a new one, so the bucket needs no lifecycle rule.

A mistake in `cf.yaml` stops the plan before anything is planned, with every problem at once:

```text
The Cloud Functions YAML configuration has 4 problem(s):
  - functions.smoke-test: unknown key "descripton" (did you mean description?)
  - functions.smoke-test.service_config: unknown key "memory" (did you mean available_memory?)
  - functions.smoke-test.service_config.ingress_settings: must be one of ALLOW_ALL, ALLOW_INTERNAL_ONLY, ALLOW_INTERNAL_AND_GCLB (got "INTERNAL")
  - functions.smoke-test.build_config.source: set exactly one of dir, zip, object and repo (found dir, object)
```

The output `cloud_function_uris` (function key → HTTPS URI) shows up in the plan and apply logs.

## 5. What each environment's project needs

The module creates the functions, their source archives and their IAM grants. Everything else they refer to has to exist first. In this repository that means entries in `gcs.yaml`, `sa.yaml` and `iam-bindings.yaml`, applied before (or in an earlier merge request than) the functions that use them: `cf.yaml` names them as plain strings, so Terraform can't order their creation by itself ([Pitfalls](#8-pitfalls)).

**APIs:** `cloudfunctions`, `cloudbuild`, `run`, `artifactregistry`, `storage`, `logging`; for event-driven functions also `eventarc` and `pubsub`.

**Source bucket** (`defaults.functions.build_config.source.bucket`): ideally in the functions' region, with uniform bucket-level access.

**Service accounts and roles** (the names are the ones used in `cf.yaml`):

| Account | Roles | Purpose |
|---|---|---|
| `cf-runtime@` (`service_config.service_account_email`) | What the code needs, e.g. `roles/bigquery.dataEditor` on a dataset and `roles/bigquery.jobUser`; `roles/secretmanager.secretAccessor` on each secret | The identity the code runs as. Give functions with different access their own account. |
| `cf-build@` (`build_config.service_account`) | `roles/logging.logWriter`, `roles/artifactregistry.writer`, `roles/storage.objectViewer` on the source bucket | Runs the build. Without it, builds run as the project's default build account, which organization policies often leave without roles. |
| `cf-trigger@` (event-driven functions, `event_trigger.service_account_email`) | `roles/eventarc.eventReceiver` on the project; `roles/run.invoker` comes from `invokers` | Delivers events to the function. |
| Cloud Storage service agent `service-<project-number>@gs-project-accounts.iam.gserviceaccount.com` (Cloud Storage triggers only) | `roles/pubsub.publisher` on the project | Publishes the bucket's events. |
| The pipeline's identity (GitLab runner) | `roles/cloudfunctions.developer` (`roles/cloudfunctions.admin` if a function uses `iam:`), `roles/run.admin` (for the invoker grants), `roles/storage.objectAdmin` on the source bucket, `roles/iam.serviceAccountUser` on `cf-runtime`, `cf-build` and `cf-trigger` | Deploys everything above. The Cloud Functions service agent creates Eventarc triggers itself, so the pipeline needs no Eventarc role. |

**Organization policies** that commonly stop a first deploy:

| Constraint | Symptom | Way out |
|---|---|---|
| `iam.allowedPolicyMemberDomains` | `allUsers` or outside members rejected | Invokers from your own domain: groups and service accounts. |
| `cloudfunctions.allowedIngressSettings`, `run.allowedIngress` | Ingress setting rejected | An allowed `ingress_settings`, for example `ALLOW_INTERNAL_ONLY` everywhere. |
| `cloudfunctions.requireVPCConnector` | Deploy refused without a connector | `service_config.vpc_connector` in `defaults.functions`. |
| `gcp.resourceLocations` | Region rejected | An allowed `defaults.region`. |
| `iam.automaticIamGrantsForDefaultServiceAccounts` | Build or runtime permission errors | Dedicated build and runtime accounts, as `cf.yaml` already sets. |
| `cloudbuild.allowedWorkerPools` | Build rejected | `build_config.worker_pool` in `defaults.functions`. |

## 6. GitLab pipeline

`ci-snippets/cloud-functions.gitlab-ci.yml` contains the additions as hidden jobs and commented fragments. What to check:

1. **Terraform and provider versions.** The module needs Terraform >= 1.5 and `hashicorp/google` >= 7.42, < 9.0. Terraform combines provider constraints across the root and every module it calls, so a `~> 6.0` (or `~> 5.0`) anywhere in `terraform/infra` or `modules/*` makes `terraform init` fail with "no available releases match the given constraints". The whole root then has to move to 7.42 or later (read Google's 7.0 upgrade guide for the other modules): the module sets attributes older providers don't have. Find the constraints with `grep -rn "hashicorp/google" -A2 terraform modules` and the selected version in `terraform/infra/.terraform.lock.hcl`.
2. **The archive provider.** The module adds `hashicorp/archive`. If the runners install providers from a mirror (Artifactory, or a `provider_installation` block in the runner's CLI configuration), it has to be in the mirror. If `.terraform.lock.hcl` is committed, run `terraform init -upgrade` once and commit the result, or `terraform providers lock -platform=linux_amd64 -platform=windows_amd64` to cover Windows laptops too. A pipeline that runs `terraform init -lockfile=readonly` fails until then.
3. **Code changes must start Terraform.** If the plan and apply jobs have `rules: changes:` filters, add `src/cloud-functions/**/*`; otherwise a merge request that only changes code deploys nothing.
4. **Saved plans need their zips.** `terraform plan -out=<file>` refers to the archives in `terraform/infra/.terraform/cloud-functions-yaml/`, and `terraform apply <file>` uploads them from there without recreating them. When apply runs in a later job (a fresh checkout), add that directory to the plan job's `artifacts:paths`; otherwise the apply fails with `Error: open ./.terraform/cloud-functions-yaml/smoke-test-<hash>.zip: no such file or directory`.
5. **Optional jobs.** `.cloud-functions:unit-tests` runs each function's `tests/` in its own virtualenv; `.cloud-functions:validate-yaml` checks every `terraform/*/cf.yaml` against the schema without Google Cloud access. Extend them with a stage your pipeline has. The images and `pip` may have to go through your internal registry and proxy.

## 7. Everyday changes

| Task | How |
|---|---|
| Add a function | Code in `src/cloud-functions/<name>/`, an entry in `terraform/<env>/cf.yaml` with `source: { dir: <name> }`. |
| Change code | Edit the folder. The next apply rebuilds that function in each environment that deploys it, nothing else. |
| Change settings | Edit `cf.yaml`. Most changes are updates in place. |
| New environment | `terraform/<env>/cf.yaml` (copy dev's; change project, bucket, service accounts, sizes) and `cf_yaml_config_path = "../<env>/cf.yaml"` in `terraform/<env>/variables.tfvars`. |
| Keep a function out of an environment | Leave it out of that `cf.yaml`, or set `enabled: false` (still validated, not deployed). |
| Remove a function | Delete its entry; the plan destroys it. Delete the code folder once no environment uses it. |
| Protect prod | `deletion_policy: PREVENT` in prod's `defaults.functions` makes any destroy of a function fail. |
| Rename | Changing a key or `name` deletes the function and creates it under the new name, with a new URL. |
| Upgrade the module | `modules/cloud-functions/VENDORED.md`; re-apply the one local change in `functions.tf`. |

## 8. Pitfalls

- **Prerequisites in the same apply.** If a merge request adds a service account or bucket together with the function that uses it, the first apply can fail because the function is created first; apply again, or land the prerequisites first. `depends_on` on the module would order them, but while those modules have changes the plan postpones building the archives to the apply: archive names show as "(known after apply)", and existing functions get their source archive replaced on every such apply.
- **Line endings.** The archive hash covers file contents, so a Windows checkout with CRLF produces a different archive than the Linux runner, and a local plan shows a rebuild that the pipeline doesn't. The `.gitattributes` rule keeps `src/cloud-functions/` in LF everywhere.
- **Templating.** `cf.yaml` is rendered with `templatefile()`, comments included: write `$${` for a literal `${` and `%%{` for a literal `%{`.
- **YAML 1.1.** Unquoted `yes`, `no`, `on` and `off` become booleans, also as keys, and version-like values (`1.10`) become numbers; quote them.
- **Trigger region.** A Cloud Storage trigger needs `trigger_region` equal to the bucket's location (`europe-west2`, `eu`, ...), which can differ from the function's region.
- **Retries.** With `RETRY_POLICY_RETRY`, failed events are delivered again, so the code must cope with the same event twice.
- **Ingress.** `ALLOW_INTERNAL_ONLY` (the default in `cf.yaml`) still lets in events from the project's Pub/Sub and Eventarc, but not calls from a laptop or from outside the VPC; HTTP functions with outside callers set `ALLOW_ALL` and rely on `invokers`.
