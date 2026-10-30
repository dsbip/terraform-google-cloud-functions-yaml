# Functions

Each entry under `functions` deploys one Cloud Run function (Cloud Functions 2nd gen, `google_cloudfunctions2_function`), plus its source upload, invoker grants and IAM. Key names follow the Google provider, so the [provider documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions2_function) applies too.

```yaml
functions:
  orders-api:
    description: Order intake API.
    labels: { tier: critical }
    build_config:
      runtime: nodejs22
      entry_point: createOrder
      source: { dir: src/orders, bucket: fn-sources }
    service_config:
      available_memory: 1Gi
      max_instance_count: 50
      secret_environment_variables:
        - { key: API_KEY, secret: orders-api-key }
    invokers: [serviceAccount:checkout@my-project.iam.gserviceaccount.com]
```

## Function

| Key | Description |
|---|---|
| `enabled` | `false` skips the function (default `true`); it is still validated. |
| `name` | Function name, default: the YAML key. Lowercase letters, digits and hyphens, starting with a letter, at most 63 characters. Cannot be a default. |
| `project_id` | Project of this function. |
| `region` | Region of this function, e.g. `europe-west1`. |
| `description` | Description. |
| `labels` | Labels, merged over the module, `defaults.labels` and `defaults.functions.labels` labels. Numbers and booleans become strings. |
| `kms_key_name` | Cloud KMS key that encrypts the function and its image (CMEK): `projects/P/locations/L/keyRings/R/cryptoKeys/K`. The Cloud Functions and Artifact Registry service agents need `roles/cloudkms.cryptoKeyEncrypterDecrypter`; set `build_config.docker_repository` to a CMEK repository too. |
| `deletion_policy` | `DELETE` (default), `PREVENT` (`terraform destroy` fails) or `ABANDON` (removed from state, left running). |
| `build_config` | How the function is built, see [build_config](#build_config). Required (here or in defaults). |
| `service_config` | How the function runs, see [service_config](#service_config). |
| `event_trigger` | Makes the function event-driven, see [event_trigger](#event_trigger). Without it, the function is an HTTP function. |
| `invokers` | Members allowed to call the function, see [Invokers and IAM](#invokers-and-iam). |
| `iam` | IAM grants on the function, see [Invokers and IAM](#invokers-and-iam). |

## build_config

| Key | Description |
|---|---|
| `runtime` | Runtime ID: `python312`, `nodejs22`, `go123`, `java21`, `ruby33`, `php83`, `dotnet8`, ... Required. |
| `entry_point` | Name of the function in the code (for Java the fully qualified class). |
| `source` | Where the code comes from, see [source](#source). Required. |
| `environment_variables` | Build-time environment variables (for buildpacks), e.g. `GOOGLE_BUILDABLE`, `PIP_INDEX_URL`. |
| `docker_repository` | Artifact Registry repository for the image: `projects/P/locations/L/repositories/R`. Default: `gcf-artifacts`. |
| `service_account` | Service account that runs the build: `projects/P/serviceAccounts/EMAIL`. |
| `worker_pool` | Private Cloud Build worker pool: `projects/P/locations/L/workerPools/W`. |
| `runtime_update_policy` | Base image security updates: `AUTOMATIC` (applied continuously) or `ON_DEPLOY` (applied when you deploy). Unset: the provider default. |

## source

Set exactly one of `dir`, `zip`, `object` and `repo`.

| Key | Description |
|---|---|
| `dir` | Local directory, relative to the configuration file. Zipped (file timestamps ignored, file modes fixed to `0644`) and uploaded to `bucket` as `<object_prefix><name>-<md5>.zip`. Changed code → new hash → new object → the function is rebuilt; unchanged code plans no changes. |
| `zip` | Local `.zip` file, relative to the configuration file. Uploaded as-is under its MD5 hash. |
| `excludes` | Glob patterns of files in `dir` to leave out, e.g. `[node_modules/**, "tests/**"]`. |
| `bucket` | Bucket name (no `gs://`) for uploads, or holding `object`. Required with `dir`, `zip` and `object`. Typically set once in `defaults.functions.build_config.source`. |
| `object_prefix` | Prefix of uploaded object names, e.g. `functions/`. |
| `object` | Existing object in `bucket` that holds the zipped code, e.g. uploaded by CI. |
| `generation` | Object generation to deploy (default: the latest). Pinning makes re-uploads of the same object name harmless. |
| `repo` | Cloud Source Repositories reference, see [repo](#repo). |

### repo

| Key | Description |
|---|---|
| `repo_name` | Repository name. Required. |
| `project_id` | Project of the repository (default: the function's project). |
| `branch_name` | Branch regex, e.g. `^main$`. |
| `tag_name` | Tag regex, e.g. `^v1\.`. |
| `commit_sha` | Exact commit. |
| `dir` | Directory in the repository that holds the function. |
| `invert_regex` | Match everything *except* `branch_name` / `tag_name`. |

Set exactly one of `branch_name`, `tag_name` and `commit_sha`.

## service_config

| Key | Description |
|---|---|
| `available_memory` | Memory per instance: `128M`, `256M`, `512M`, `1Gi`, `2Gi`, `4Gi`, ... |
| `available_cpu` | CPUs per instance, as a string: `"0.583"`, `"1"`, `"2"`, `"4"`. Default: derived from memory. |
| `timeout_seconds` | Request timeout: up to 3600 for HTTP functions, 540 for event-driven functions. |
| `min_instance_count` | Instances kept warm (billed while idle). |
| `max_instance_count` | Upper bound of instances. |
| `max_instance_request_concurrency` | Concurrent requests per instance (1–1000). Above 1 needs at least 1 CPU. |
| `environment_variables` | Runtime environment variables. Merged with the default's variables key by key. |
| `ingress_settings` | `ALLOW_ALL` (default), `ALLOW_INTERNAL_ONLY` or `ALLOW_INTERNAL_AND_GCLB`. |
| `all_traffic_on_latest_revision` | Send all traffic to the newest revision (provider default `true`). |
| `service_account_email` | Runtime service account. Default: the Compute Engine default service account; set a dedicated one. |
| `vpc_connector` | Serverless VPC Access connector: `projects/P/locations/R/connectors/C`. |
| `vpc_connector_egress_settings` | `PRIVATE_RANGES_ONLY` or `ALL_TRAFFIC` through the connector. Needs `vpc_connector`. |
| `direct_vpc_network_interface` | Direct VPC egress (no connector): a list of `{ network, subnetwork, tags }`. Use this or `vpc_connector`. |
| `direct_vpc_egress` | `VPC_EGRESS_PRIVATE_RANGES_ONLY` or `VPC_EGRESS_ALL_TRAFFIC`. Needs `direct_vpc_network_interface`. |
| `binary_authorization_policy` | Binary Authorization policy checked on deploy, e.g. `default`. |
| `secret_environment_variables` | Secrets as environment variables, see below. |
| `secret_volumes` | Secrets as files, see below. |

### direct_vpc_network_interface

| Key | Description |
|---|---|
| `network` | VPC network name or self link. Optional when `subnetwork` is set. |
| `subnetwork` | Subnetwork name or self link. |
| `tags` | Network tags, e.g. for firewall rules. |

### Secrets

```yaml
service_config:
  secret_environment_variables:
    - { key: API_KEY, secret: api-key }                          # latest, same project
    - { key: DB_PASSWORD, secret: db-password, version: "7" }    # pinned
    - { key: SHARED, secret: shared, project_id: vault-project } # other project
  secret_volumes:
    - mount_path: /etc/tls
      secret: tls                                                # /etc/tls/tls, latest
    - mount_path: /etc/creds
      secret: creds
      versions:
        - { path: current.json, version: latest }
        - { path: previous.json, version: "3" }
```

`secret_environment_variables` items:

| Key | Description |
|---|---|
| `key` | Environment variable name. Required. |
| `secret` | Secret ID in Secret Manager. Required. |
| `version` | Version, default `latest`. |
| `project_id` | Project of the secret, default: the function's project. |

`secret_volumes` items:

| Key | Description |
|---|---|
| `mount_path` | Directory to mount at. Required. |
| `secret` | Secret ID in Secret Manager. Required. |
| `project_id` | Project of the secret, default: the function's project. |
| `versions` | Which versions to mount, under which file names (see below). Default: the latest version, in a file named after the secret. |

`versions` items:

| Key | Description |
|---|---|
| `path` | File name, relative to `mount_path`. Required. |
| `version` | Secret version, e.g. `latest` or `"3"`. Required. |

The runtime service account needs `roles/secretmanager.secretAccessor` on each secret.

## event_trigger

```yaml
event_trigger:
  event_type: google.cloud.storage.object.v1.finalized
  trigger_region: us                     # the bucket's location
  retry_policy: RETRY_POLICY_RETRY
  service_account_email: trigger@my-project.iam.gserviceaccount.com
  event_filters:
    - { attribute: bucket, value: uploads }
```

| Key | Description |
|---|---|
| `event_type` | Eventarc event type, e.g. `google.cloud.pubsub.topic.v1.messagePublished`, `google.cloud.storage.object.v1.finalized`, `google.cloud.firestore.document.v1.written`, `google.cloud.audit.log.v1.written`. Default with `pubsub_topic`: the Pub/Sub type. |
| `pubsub_topic` | Topic for Pub/Sub triggers. A short name (`orders`) means a topic in the function's project; `projects/P/topics/T` for others. |
| `trigger_region` | Region of the trigger (default: the function's region). Storage triggers need the bucket's location (`us`, `eu`, `europe-west1`, ...); Audit Log triggers can be `global`. |
| `retry_policy` | `RETRY_POLICY_RETRY` (failed events are redelivered, so the code must be idempotent), `RETRY_POLICY_DO_NOT_RETRY` or `RETRY_POLICY_UNSPECIFIED`. |
| `service_account_email` | Identity the trigger uses to call the function. Add it to `invokers`. |
| `event_filters` | Attribute filters, see below. |

`event_filters` items:

| Key | Description |
|---|---|
| `attribute` | Event attribute: `bucket` (Storage), `database`/`document`/`namespace` (Firestore), `serviceName`/`methodName`/`resourceName` (Audit Logs), ... Required. |
| `value` | Value to match. Required. |
| `operator` | `match-path-pattern` to match path patterns such as `users/{userId}` or `logs/**`. |

## Invokers and IAM

```yaml
invokers:
  - allUsers                                             # public
  - serviceAccount:caller@my-project.iam.gserviceaccount.com
iam:
  - role: roles/cloudfunctions.viewer
    members: [group:support@example.com]
  - role: roles/cloudfunctions.developer
    members: [user:contractor@example.com]
    condition:
      title: until-2027
      description: Contract ends.
      expression: request.time < timestamp("2027-01-01T00:00:00Z")
```

- `invokers` grants `roles/run.invoker` on the function's Cloud Run service, which is what calling a 2nd gen function requires (`allUsers` makes it public, and may be blocked by the *Domain restricted sharing* organization policy). Event-driven functions need their trigger's service account here.
- `iam` grants roles on the function itself (`google_cloudfunctions2_function_iam_member`).

Both are non-authoritative: grants made outside Terraform are left alone. Duplicate members collapse into one grant.

`iam` items:

| Key | Description |
|---|---|
| `role` | Role, e.g. `roles/cloudfunctions.viewer`. Required. |
| `members` | `user:`, `group:`, `serviceAccount:`, `domain:`, `principal://`, `principalSet://`, `allUsers` or `allAuthenticatedUsers`. At least one. |
| `condition` | `{ title, expression, description }`: an IAM condition in CEL. `title` and `expression` are required. |
