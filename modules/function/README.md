# modules/function

Deploys one Cloud Run function (Cloud Functions 2nd gen) with its source upload, invoker grants and IAM. The YAML root module calls it once per function; it works the same from plain HCL.

```hcl
module "status" {
  source = "github.com/dsbip/terraform-google-cloud-functions-yaml//modules/function?ref=v1.0.0"

  name       = "status"
  project_id = "my-project"
  region     = "europe-west1"

  build_config = {
    runtime     = "python312"
    entry_point = "status"
    source      = { dir = "${path.module}/src/status", bucket = "my-function-sources" }
  }

  service_config = {
    available_memory   = "256M"
    max_instance_count = 2
  }

  event_trigger = null          # HTTP function
  invokers      = ["allUsers"]
}
```

## Resources

| Resource | When |
|---|---|
| `google_cloudfunctions2_function.this` | always |
| `module.source_archive` ([modules/source-archive](../source-archive/README.md)) | `build_config.source.dir` or `.zip` is set |
| `google_cloud_run_v2_service_iam_member.invoker` | one per `invokers` member (`roles/run.invoker` on the function's Cloud Run service) |
| `google_cloudfunctions2_function_iam_member.this` | one per `iam` role and member |

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | Function name (validated). |
| `project_id` | `string` | | Project; also the default project of short Pub/Sub topic names, secrets and repositories. |
| `region` | `string` | | Region. |
| `description` | `string` | `null` | |
| `labels` | `map(string)` | `{}` | |
| `kms_key_name` | `string` | `null` | CMEK key. |
| `deletion_policy` | `string` | `null` | `DELETE`, `PREVENT` or `ABANDON`. |
| `build_config` | `object` | | `runtime`, `entry_point`, `environment_variables`, `docker_repository`, `service_account`, `worker_pool`, `runtime_update_policy` (`AUTOMATIC`/`ON_DEPLOY`) and `source` (exactly one of `dir`, `zip`, `object`, `repo`; plus `bucket`, `object_prefix`, `excludes`, `generation`). |
| `service_config` | `object` | `{}` | The provider's `service_config` keys; secrets default to `project_id` and version `latest`. `null` is treated like `{}`. |
| `event_trigger` | `object` | `null` | `event_type`, `pubsub_topic` (short names expanded), `trigger_region`, `retry_policy`, `service_account_email`, `event_filters`. `event_type` defaults to the Pub/Sub type when `pubsub_topic` is set. |
| `invokers` | `list(string)` | `[]` | Members granted `roles/run.invoker`. |
| `iam` | `list(object)` | `[]` | `{ role, members, condition = { title, expression, description } }`. |
| `archive_output_dir` | `string` | `null` | Local directory for zipped directories (default `.terraform/cloud-functions-yaml` in the root module). |

The keys are documented in detail in [docs/functions.md](../../docs/functions.md); the YAML uses exactly these names.

## Outputs

| Name | Description |
|---|---|
| `id`, `name`, `project_id`, `region` | Identity of the function. |
| `uri` | HTTPS URI of the function's Cloud Run service. |
| `url` | `cloudfunctions.net` URL. |
| `service` | Name of the Cloud Run service. |
| `service_account_email` | Runtime service account. |
| `state` | e.g. `ACTIVE`. |
| `event_trigger` | Eventarc trigger name, or `null` for HTTP functions. |
| `source` | `{ bucket, object, repo }` the function is built from. |
| `invoker_members`, `iam_members` | The grants made. |
| `function` | The whole `google_cloudfunctions2_function` resource. |
