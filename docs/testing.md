# Testing

The module is tested in four layers. The first three need no Google Cloud access and run in CI on every push; the live test runs on demand.

| Layer | Tool | What it proves | Where |
|---|---|---|---|
| Static | `terraform fmt`, `terraform validate` | Formatting; valid HCL against the provider schema, for the root module and both submodules | |
| Unit | `terraform test` with a mocked provider | Loading and templating, precedence, the defaults merge, every attribute from YAML to the planned resource, sources and hashes, triggers, IAM, outputs, the submodules on their own, every validation message, every example | `tests/*.tftest.hcl` (70+ runs) |
| Plan | pytest + real provider, dummy credentials | Every example and the live fixture pass the real provider's validation and plan logic with the expected resource count; archive hashes are reproducible; examples and fixtures match the JSON Schema; the schema stays readable by `validation.tf`; the complete example uses every key; every key is documented; links resolve | `tests/python/` |
| Live | pytest + real provider, real project | Functions deploy, a second plan is empty (no drift), in-place updates work, destroy is clean | `tests/python/test_live.py`, `tests/integration/` |

## Requirements

- Terraform >= 1.7 for the unit tests (mock providers); the module itself supports >= 1.5
- Python >= 3.9 with `pip install -r tests/python/requirements.txt` (pytest, PyYAML, jsonschema)
- Network access to download providers

## Running the tests

Everything offline, in one command:

```bash
scripts/test.sh
```

Or step by step from the repository root:

```bash
terraform fmt -check -recursive
terraform init -backend=false && terraform validate
terraform test                                    # unit tests
python -m pytest tests/python -v                  # schema, docs and real-provider plans
```

A single unit test file: `terraform test -filter=tests/validation.tftest.hcl`.

To check the minimum versions, run the plan tests with Terraform 1.5.7 and pin the provider:

```bash
TERRAFORM_BIN=/path/to/terraform-1.5.7 GOOGLE_PROVIDER_VERSION=7.42.0 python -m pytest tests/python -v
```

## Unit tests

| File | Covers |
|---|---|
| `config.tftest.hcl` | `config_file` templating (placeholders, `%{ if }`, `$${`), `config_yaml`, `yamlencode()`, blank files, project/region/label precedence, the three-level defaults merge, nulls, `enabled`, names, paths |
| `functions.tftest.hcl` | every `build_config` and `service_config` attribute, update policies, secrets, VPC connector, Direct VPC, several projects and regions |
| `sources.tftest.hcl` | directory uploads and their hashes, `excludes`, zips, existing objects and generations, repositories |
| `triggers.tftest.hcl` | Pub/Sub short names and implied event type, Storage, Firestore and Audit Log triggers, defaults for triggers |
| `iam.tftest.hcl` | invokers and IAM bindings, duplicates, conditions; that invoker grants target the function's Cloud Run service (`command = apply`) |
| `modules.tftest.hcl` | `modules/function` and `modules/source-archive` called directly, with their input validation |
| `validation.tftest.hcl` | every validation message, as complete sets |
| `examples.tftest.hcl` | the behaviour each example's README describes |
| `outputs.tftest.hcl` | outputs after a mocked apply |

Validation tests plant several mistakes and compare the complete set of messages, so a missing message and a spurious extra one both fail:

```hcl
run "rules_beyond_the_schema" {
  command         = plan
  variables { config_yaml = <<-EOT ... EOT }
  expect_failures = [terraform_data.validation]
  assert {
    condition = toset(local.validation_errors) == toset([
      "functions.two-sources.build_config.source: set exactly one of dir, zip, object and repo (found dir, object)",
      ...
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}
```

## Plan tests

`test_example_plans.py` copies the repository to a temporary directory and runs `terraform init` and `terraform plan -refresh=false` in every example with a dummy `GOOGLE_OAUTH_ACCESS_TOKEN`. The provider needs no API calls to plan new resources, so the plans exercise its full validation and diff logic offline. Each test checks the exact number of planned resources. The live-test fixture is planned the same way with every option enabled, so it stays deployable.

## Live test

The live test deploys `tests/integration/` into a real project: a source bucket, a Pub/Sub topic, an HTTP function built from a local directory and a Pub/Sub-triggered function, plus invoker and IAM grants when a member is given. It then runs:

1. `apply`
2. `plan -detailed-exitcode` must report no changes (catches permanent diffs)
3. `apply` with changed descriptions and an environment variable (in-place updates)
4. another empty plan
5. `destroy` (always, also after a failure)

All names start with `cfyaml-<random>`, instance counts are capped at one, and nothing is invoked, so a run costs next to nothing.

```bash
gcloud auth application-default login
export CF_YAML_TEST_PROJECT=my-sandbox-project
export CF_YAML_TEST_REGION=europe-west1                          # optional
export CF_YAML_TEST_MEMBER=user:me@example.com                   # optional: invoker and IAM grants
python -m pytest tests/python/test_live.py -v
```

The project needs the Cloud Functions, Cloud Build, Cloud Run, Artifact Registry, Eventarc, Pub/Sub and Cloud Storage APIs. The identity needs `roles/cloudfunctions.admin`, `roles/run.admin`, `roles/storage.admin`, `roles/pubsub.admin` and `roles/iam.serviceAccountUser`. If a run is interrupted before its destroy step, delete the leftover `cfyaml-*` functions, buckets and topics by hand.

The **Live test** workflow runs the same test from GitHub Actions. To enable it:

1. Create a Workload Identity Federation provider for the repository.
2. Set the repository variables `CF_YAML_TEST_PROJECT`, `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_SERVICE_ACCOUNT`.
3. Start the workflow from the Actions tab.

## Continuous integration

`.github/workflows/ci.yml` runs on pushes to `main` and on pull requests:

| Job | Terraform | Provider |
|---|---|---|
| fmt and validate | latest | latest |
| terraform test | 1.7.5, latest | 7.42.0, latest (4 combinations) |
| example plans, schema and docs tests | 1.5.7 with 7.42.0 (the minimums), latest with latest | |

## Adding a feature

1. Add the key to its definition in `schemas/cloud-functions-config.schema.json` (with a description; enumerations, ranges and patterns are enforced automatically).
2. Add it to the variable type in `modules/function/variables.tf` and pass it to the resource in `modules/function/main.tf`.
3. Add a rule to `validation.tf` part 2 if invalid combinations are possible, with a message that starts with the YAML path.
4. Add a unit test for the planned attribute, and a validation test if you added a rule.
5. Use it in `examples/complete` (a test fails otherwise) and document it in `docs/functions.md` (likewise).
