# YAML reference

Every key of the configuration file (for example `cf.yaml`) on one page, nested the way you write it, with what it does, its default and its allowed values. [configuration.md](configuration.md) explains how defaults merge and how the file is templated; [functions.md](functions.md) has more detail on single keys.

| Tag | Meaning |
|---|---|
| `[Required]` | Must be set: on the function, or once for every function in `defaults.functions`. |
| `[Optional]` | Can be left out. *Defaults to* says what happens then. |
| `[Choose one]` | Set exactly one of the keys tagged this way in the same block. |
| `[Required if]` | Must be set in the situation named. |

Names in square brackets, such as `[FUNCTION KEY]`, are yours to choose, and `- ` starts a list item. In paths such as `projects/P/locations/L/...`, replace the capital letters with your project, location and resource names.

```yaml
project_id:                              [Required] Project the functions are deployed to. Not needed when every
                                         function sets its own project_id, or when the module call passes project_id.

defaults:                                [Optional] Settings shared by every function in this file.
  region:                                [Required] Region the functions are deployed to, e.g. europe-west2. Not needed
                                         when every function sets its own region, or when the module call passes region.
  labels:                                [Optional] Labels added to every function. Defaults to {}.
    [LABEL KEY]:                         Label value. Keys and values: lowercase letters, digits, - and _, at most 63
                                         characters.
  functions:                             [Optional] Starting values for every function: any key listed under
                                         [FUNCTION KEY] below, except name. A function's own value wins. Mappings merge
                                         (source.bucket from here plus source.dir from the function); lists such as
                                         invokers are replaced, not combined.

functions:                               [Required] The functions to deploy, one entry per function.
  [FUNCTION KEY]:                        [Required] Your key for the function, e.g. orders-api. It is also the
                                         function's name unless name is set. Renaming the key replaces the function.
    enabled:                             [Optional] false keeps the function in the file (still checked) but does not
                                         deploy it; a function that is already deployed is deleted. Defaults to true.
    name:                                [Optional] Name in Google Cloud: lowercase letters, digits and hyphens,
                                         starting with a letter, at most 63 characters. Defaults to the key.
    project_id:                          [Optional] Project of this function. Defaults to the top-level project_id.
    region:                              [Optional] Region of this function. Defaults to defaults.region.
    description:                         [Optional] Description of the function.
    labels:                              [Optional] Labels of this function, added to defaults.labels (for the same key,
                                         this one wins). Defaults to {}.
      [LABEL KEY]:                       Label value.
    kms_key_name:                        [Optional] Cloud KMS key that encrypts the function and its image (CMEK):
                                         projects/P/locations/L/keyRings/R/cryptoKeys/K. Set docker_repository to a
                                         repository encrypted with the same key. Defaults to Google-managed encryption.
    deletion_policy:                     [Optional] What terraform destroy does. Allowed values are `DELETE`, `PREVENT`
                                         (destroy fails) and `ABANDON` (Terraform forgets the function, it keeps
                                         running). Defaults to `DELETE`.

    build_config:                        [Required] How the code is built into a container image.
      runtime:                           [Required] Language and version, e.g. `python312`, `nodejs22`, `go123`,
                                         `java21`, `ruby33`, `php83`, `dotnet8`.
      entry_point:                       [Optional] Name of the function in the code that is called (Java: the fully
                                         qualified class name). Defaults to the function's name, so set it when the name
                                         has hyphens.
      environment_variables:             [Optional] Variables that exist only during the build, e.g. PIP_INDEX_URL for a
                                         private package index. Defaults to {}.
        [VARIABLE NAME]:                 Value.
      docker_repository:                 [Optional] Artifact Registry repository the built image is stored in:
                                         projects/P/locations/L/repositories/R. Defaults to `gcf-artifacts`, which
                                         Google creates on the first deploy; VPC Service Controls can block that, so
                                         create your own repository there.
      service_account:                   [Optional] Service account the build runs as, written as
                                         projects/P/serviceAccounts/EMAIL. It needs roles/logging.logWriter,
                                         roles/artifactregistry.writer and read access to the source bucket. Defaults to
                                         the project's default build service account.
      worker_pool:                       [Optional] Private Cloud Build pool to build in:
                                         projects/P/locations/L/workerPools/W. Defaults to Google's shared pool.
      runtime_update_policy:             [Optional] When security patches to the base image are applied. Allowed values
                                         are `AUTOMATIC` (continuously, without a redeploy) and `ON_DEPLOY` (only when
                                         you deploy). Defaults to `AUTOMATIC`.
      source:                            [Required] Where the code comes from. Set exactly one of dir, zip, object and
                                         repo.
        dir:                             [Choose one] Folder with the code, relative to the module's base_path (by
                                         default the folder of this file; with base_path = src/cloud-functions, write
                                         just the folder name, e.g. greeter-py). It is zipped and uploaded to bucket,
                                         and the function is rebuilt only when the code changes.
        zip:                             [Choose one] Ready-made .zip file, relative to base_path. Uploaded to bucket as
                                         it is.
        object:                          [Choose one] Zip that is already in bucket, e.g. uploaded by CI; nothing is
                                         uploaded. Replacing the file under the same name does not redeploy: change the
                                         name, or set generation.
        repo:                            [Choose one] Cloud Source Repositories repository to build from (only for
                                         projects that already use that service).
          repo_name:                     [Required] Repository name.
          project_id:                    [Optional] Project of the repository. Defaults to the function's project.
          branch_name:                   [Choose one] Branch, as a regex, e.g. ^main$.
          tag_name:                      [Choose one] Tag, as a regex, e.g. ^v1\.
          commit_sha:                    [Choose one] Exact commit.
          dir:                           [Optional] Folder in the repository that holds the code. Defaults to the
                                         repository root.
          invert_regex:                  [Optional] true builds from what branch_name / tag_name does NOT match.
                                         Defaults to false.
        bucket:                          [Required if] the source is dir, zip or object. Bucket name, without gs://.
                                         Usually set once in defaults.functions.
        object_prefix:                   [Optional] Only with dir and zip: start of the uploaded zip's name, e.g.
                                         cloud-functions/. The zip is named <prefix><function name>-<md5>.zip. Defaults
                                         to no prefix.
        excludes:                        [Optional] Only with dir: files to leave out of the zip, as glob patterns
                                         relative to dir. Defaults to [] (nothing left out).
          - [PATTERN]                    e.g. "tests/**", "**/__pycache__/**" (quote patterns that start with *).
        generation:                      [Optional] Only with object: deploy exactly this upload of the object (a
                                         number). Defaults to the latest upload.

    service_config:                      [Optional] How the function runs.
      available_memory:                  [Optional] Memory per instance, e.g. 128M, 256M, 512M, 1Gi, 2Gi, 4Gi, up to
                                         32Gi. Supported units are k, M, G, Mi, Gi; no unit means bytes. Defaults to
                                         256M.
      available_cpu:                     [Optional] CPUs per instance, e.g. "0.583", "1", "2", "4". Defaults to a share
                                         that depends on available_memory (2Gi gets 1).
      timeout_seconds:                   [Optional] A request is stopped after this many seconds: at most 3600 for HTTP
                                         functions, 540 for event-driven ones. Defaults to 60.
      min_instance_count:                [Optional] Instances kept running all the time: no cold starts, but billed
                                         while idle. Defaults to 0.
      max_instance_count:                [Optional] Most instances that run at the same time; not less than
                                         min_instance_count. Defaults to 100.
      max_instance_request_concurrency:  [Optional] Requests one instance handles at the same time, 1 to 1000. Above 1
                                         needs available_cpu of at least "1". Defaults to 1.
      environment_variables:             [Optional] Variables the code reads at run time. Merged key by key with the
                                         ones in defaults.functions. Defaults to {}.
        [VARIABLE NAME]:                 Value. Numbers and true/false are turned into strings.
      secret_environment_variables:      [Optional] Secret Manager secrets the code reads as environment variables. The
                                         runtime service account needs roles/secretmanager.secretAccessor on each
                                         secret. Defaults to [].
        - key:                           [Required] Name of the environment variable.
          secret:                        [Required] Name (ID) of the secret in Secret Manager.
          version:                       [Optional] Secret version, e.g. "3". Defaults to `latest`. A fixed number is
                                         safer: running instances keep the value they started with.
          project_id:                    [Optional] Project of the secret. Defaults to the function's project.
      secret_volumes:                    [Optional] Secret Manager secrets the code reads as files. The runtime service
                                         account needs the same access. Defaults to [].
        - mount_path:                    [Required] Folder the secret files appear in, e.g. /etc/secrets.
          secret:                        [Required] Name (ID) of the secret in Secret Manager.
          project_id:                    [Optional] Project of the secret. Defaults to the function's project.
          versions:                      [Optional] Which versions to mount, and their file names. Defaults to the
                                         latest version, in a file named after the secret.
            - path:                      [Required] File name inside mount_path, e.g. current.json.
              version:                   [Required] Secret version, e.g. latest or "3".
      ingress_settings:                  [Optional] Where calls may come from. Allowed values are `ALLOW_ALL` (anywhere,
                                         including the internet), `ALLOW_INTERNAL_ONLY` (only VPC networks and Google
                                         Cloud services of the same project or VPC Service Controls perimeter; event
                                         triggers still work) and `ALLOW_INTERNAL_AND_GCLB` (internal, plus an external
                                         Application Load Balancer). Defaults to `ALLOW_ALL`. The organization policy
                                         run.allowedIngress can limit the choice.
      all_traffic_on_latest_revision:    [Optional] Each deploy takes all traffic at once. Set false only if you split
                                         traffic in Cloud Run yourself. Defaults to true.
      service_account_email:             [Optional] Service account the code runs as (just the email); its roles decide
                                         what the code can access. Defaults to the Compute Engine default service
                                         account, so set your own.
      vpc_connector:                     [Optional] Serverless VPC Access connector for outgoing traffic:
                                         projects/P/locations/R/connectors/C. Use this or direct_vpc_network_interface,
                                         not both. The organization policy run.allowedVPCEgress can make one of them
                                         required.
      vpc_connector_egress_settings:     [Optional] Only with vpc_connector. Allowed values are `PRIVATE_RANGES_ONLY`
                                         (only traffic to private IPs goes through the connector), `ALL_TRAFFIC` and
                                         `VPC_CONNECTOR_EGRESS_SETTINGS_UNSPECIFIED`. Defaults to `PRIVATE_RANGES_ONLY`.
      direct_vpc_network_interface:      [Optional] Direct VPC egress: the subnet outgoing traffic leaves through,
                                         without a connector. Use this or vpc_connector, not both. Defaults to [].
        - network:                       [Optional] VPC network: a name, or projects/P/global/networks/N. Set network,
                                         subnetwork or both.
          subnetwork:                    [Optional] Subnet: a name, or projects/P/regions/R/subnetworks/S (Shared VPC:
                                         the full path, with the host project). Defaults to the subnet named like the
                                         network.
          tags:                          [Optional] Network tags, for firewall rules. Defaults to [].
            - [TAG]                      e.g. allow-egress.
      direct_vpc_egress:                 [Optional] Only with direct_vpc_network_interface. Allowed values are
                                         `VPC_EGRESS_PRIVATE_RANGES_ONLY` (only traffic to private IPs goes into the
                                         VPC) and `VPC_EGRESS_ALL_TRAFFIC`. Defaults to
                                         `VPC_EGRESS_PRIVATE_RANGES_ONLY`.
      binary_authorization_policy:       [Optional] Binary Authorization policy checked on deploy, e.g. default.
                                         Defaults to no check.

    event_trigger:                       [Optional] Makes the function run on events instead of HTTP calls; leave it out
                                         for an HTTP function. Needs event_type, pubsub_topic or both.
      pubsub_topic:                      [Required if] the events are Pub/Sub messages: the function runs once per
                                         message published to this topic. A short name (a topic in the function's
                                         project) or projects/P/topics/T.
      event_type:                        [Required if] the events are not Pub/Sub messages. The event that runs the
                                         function, e.g.:
                                           google.cloud.storage.object.v1.finalized        file uploaded or overwritten
                                           google.cloud.storage.object.v1.deleted          file deleted
                                           google.cloud.storage.object.v1.archived         file version archived
                                           google.cloud.storage.object.v1.metadataUpdated  file metadata changed
                                           google.cloud.firestore.document.v1.written      any change to a document
                                             (or .created, .updated, .deleted for one kind of change)
                                           google.cloud.audit.log.v1.written               audit log entry written
                                         With pubsub_topic it defaults to google.cloud.pubsub.topic.v1.messagePublished.
      event_filters:                     [Optional] Only events that match every filter run the function. Storage,
                                         Firestore and Audit Logs events need them. Defaults to [].
        - attribute:                     [Required] What to match: bucket (Storage); database, document, namespace
                                         (Firestore); serviceName, methodName, resourceName (Audit Logs).
          value:                         [Required] Value to match, e.g. a bucket name, (default), iam.googleapis.com.
          operator:                      [Optional] `match-path-pattern` matches a path pattern such as users/{userId}.
                                         Defaults to an exact match.
      trigger_region:                    [Optional] Where the trigger listens. Storage: the bucket's location (e.g. eu,
                                         europe-west2); Firestore: the database's location (e.g. eur3); Audit Logs:
                                         global or a region. Defaults to the function's region.
      retry_policy:                      [Optional] Allowed values are `RETRY_POLICY_RETRY` (failed events are delivered
                                         again, so the code must handle repeats), `RETRY_POLICY_DO_NOT_RETRY` and
                                         `RETRY_POLICY_UNSPECIFIED`. Defaults to no retries.
      service_account_email:             [Optional] Service account the trigger calls the function as; add it to
                                         invokers. For Storage, Firestore and Audit Logs events it also needs
                                         roles/eventarc.eventReceiver, and Storage events need the Cloud Storage service
                                         agent to have roles/pubsub.publisher. Defaults to the Compute Engine default
                                         service account.

    invokers:                            [Optional] Who may call the function (granted roles/run.invoker). Defaults to
                                         [] (no one is added).
      - [MEMBER]                         allUsers (public; often blocked by the organization policy
                                         iam.allowedPolicyMemberDomains), allAuthenticatedUsers, user:EMAIL,
                                         group:EMAIL, serviceAccount:EMAIL, domain:DOMAIN, principal://... or
                                         principalSet://... Event-driven functions: their trigger's service account.
    iam:                                 [Optional] Extra roles on the function itself, e.g. to let a team view it. To
                                         let someone call the function, use invokers. Defaults to [].
      - role:                            [Required] Role to grant, e.g. roles/cloudfunctions.viewer or
                                         roles/cloudfunctions.developer.
        members:                         [Required] Who gets the role: one or more members, in the same formats as
                                         invokers.
          - [MEMBER]                     e.g. group:team@example.com
        condition:                       [Optional] The grant only works while the expression is true.
          title:                         [Required] Short name of the condition.
          expression:                    [Required] CEL expression, e.g.
                                         request.time < timestamp("2027-01-01T00:00:00Z").
          description:                   [Optional] Longer explanation.
```

## Rules the module checks

Before anything is planned, the module checks the whole file and lists every problem with its YAML path:

- Each function needs a project (the top-level `project_id` or its own) and a region (`defaults.region` or its own).
- Each function needs `build_config.runtime` and `build_config.source`, on the function or in `defaults.functions`.
- A function key must be a valid function name (see `name`), unless `name` is set.
- `source` takes exactly one of `dir`, `zip`, `object` and `repo`. `bucket` is required with `dir`, `zip` and `object`, as a name without `gs://`. A `dir` must contain files and a `zip` must exist.
- `repo` takes exactly one of `branch_name`, `tag_name` and `commit_sha`.
- `event_trigger` needs `event_type` or `pubsub_topic`.
- `vpc_connector` and `direct_vpc_network_interface` can't be combined. `vpc_connector_egress_settings` needs `vpc_connector`, and `direct_vpc_egress` needs `direct_vpc_network_interface`.
- `min_instance_count` can't be more than `max_instance_count`.
- Two enabled functions can't have the same name in the same project and region.
- `name` can't be set in `defaults.functions`.
- Unknown keys (typos get a suggestion), wrong types, values outside the allowed lists and numbers out of range are errors.

## Things to watch

- **Mappings merge, lists are replaced.** A function's own value wins over `defaults.functions`. Mappings are combined (`source.bucket` from the defaults plus `source.dir` from the function), but a list such as `invokers`, `secret_environment_variables` or `event_filters` replaces the default list as a whole. An empty `key:` doesn't remove a default.
- **Keep `event_trigger` out of the defaults**: it would make every function event-driven. Keep networking out of the defaults too when functions use different options, because one function can't drop a default.
- **`enabled: false` deletes a deployed function** on the next apply, unless `deletion_policy` is `PREVENT` or `ABANDON`.
- **No `${` or `%{` anywhere in the file, not even in comments**, unless the module call passes `template_vars`. The module reads the file with Terraform's `templatefile()`, and even `${project_id}` and `${region}` only work when the module call sets `project_id` and `region`.
- **Quote what YAML could misread**: `yes`, `no`, `on`, `off` (also as keys), numbers whose exact text matters (`"1.10"`), and values that start with `*`, `[` or `{` (`"**/__pycache__/**"`).
- **`invokers` and `iam` only add grants.** Grants made outside Terraform are left alone, and removing a member here removes only that member's grant.

## Combinations

Starting points to copy. Replace every `<...>`. Every block below assumes the shared settings are at the top of the file, so a function lists only what is specific to it.

### Shared settings

```yaml
project_id: <project-id>

defaults:
  region: europe-west2
  labels:
    managed-by: terraform
  functions:
    build_config:
      runtime: python312
      service_account: projects/<project-id>/serviceAccounts/<build-sa>@<project-id>.iam.gserviceaccount.com
      docker_repository: projects/<project-id>/locations/europe-west2/repositories/<repository>
      source:
        bucket: <source-bucket>
        object_prefix: cloud-functions/
        excludes: ["tests/**", "**/__pycache__/**"]
    service_config:
      service_account_email: <runtime-sa>@<project-id>.iam.gserviceaccount.com
      available_memory: 256M
      max_instance_count: 3

functions:
  # the functions from the blocks below go here
```

### HTTP functions

```yaml
functions:
  # Private: only the listed members may call it.
  orders-api:
    description: Order intake API.
    build_config:
      entry_point: handle_order          # def handle_order(request) in main.py
      source:
        dir: orders-api                  # folder under base_path
    service_config:
      available_memory: 512M
      timeout_seconds: 120
      environment_variables:
        LOG_LEVEL: info
    invokers:
      - serviceAccount:<caller-sa>@<project-id>.iam.gserviceaccount.com
      - group:<team-group>@<domain>

  # Public: anyone with the URL may call it. Organization policies often block this.
  hello:
    build_config:
      entry_point: hello
      source:
        dir: hello
    service_config:
      ingress_settings: ALLOW_ALL
    invokers:
      - allUsers
```

### Event-driven functions

The trigger's service account must be in `invokers`, and for Storage, Firestore and Audit Logs events it also needs `roles/eventarc.eventReceiver` on the project. Storage events also need the Cloud Storage service agent (`service-<project-number>@gs-project-accounts.iam.gserviceaccount.com`) to have `roles/pubsub.publisher`.

```yaml
functions:
  # Pub/Sub: runs once per message.
  order-events:
    build_config:
      entry_point: on_message
      source:
        dir: order-events
    event_trigger:
      pubsub_topic: orders               # or projects/<other-project>/topics/<topic>
      retry_policy: RETRY_POLICY_RETRY
      service_account_email: <trigger-sa>@<project-id>.iam.gserviceaccount.com
    invokers:
      - serviceAccount:<trigger-sa>@<project-id>.iam.gserviceaccount.com

  # Cloud Storage: a file was uploaded to the bucket.
  file-landed:
    build_config:
      entry_point: on_file
      source:
        dir: file-landed
    event_trigger:
      event_type: google.cloud.storage.object.v1.finalized
      trigger_region: europe-west2       # the bucket's location
      event_filters:
        - attribute: bucket
          value: <landing-bucket>
      service_account_email: <trigger-sa>@<project-id>.iam.gserviceaccount.com
    invokers:
      - serviceAccount:<trigger-sa>@<project-id>.iam.gserviceaccount.com

  # Firestore: a document directly under users/ was created, changed or deleted.
  user-changed:
    build_config:
      entry_point: on_user_written
      source:
        dir: user-changed
    event_trigger:
      event_type: google.cloud.firestore.document.v1.written
      trigger_region: eur3               # the database's location
      event_filters:
        - attribute: database
          value: (default)
        - attribute: document
          value: users/{userId}
          operator: match-path-pattern
      service_account_email: <trigger-sa>@<project-id>.iam.gserviceaccount.com
    invokers:
      - serviceAccount:<trigger-sa>@<project-id>.iam.gserviceaccount.com

  # Cloud Audit Logs: someone created a service account key.
  key-created:
    build_config:
      entry_point: on_key_created
      source:
        dir: key-created
    event_trigger:
      event_type: google.cloud.audit.log.v1.written
      trigger_region: global
      event_filters:
        - attribute: serviceName
          value: iam.googleapis.com
        - attribute: methodName
          value: google.iam.admin.v1.CreateServiceAccountKey
      service_account_email: <trigger-sa>@<project-id>.iam.gserviceaccount.com
    invokers:
      - serviceAccount:<trigger-sa>@<project-id>.iam.gserviceaccount.com
```

### Other code sources

```yaml
functions:
  # A ready-made zip, relative to base_path.
  from-zip:
    build_config:
      entry_point: handler
      source:
        zip: dist/from-zip.zip

  # A zip that CI already uploaded to the bucket.
  from-object:
    build_config:
      entry_point: handler
      source:
        object: releases/from-object-1.4.0.zip
        generation: 1767225600000000     # optional: exactly this upload

  # A Cloud Source Repositories repository.
  from-repo:
    build_config:
      entry_point: handler
      source:
        repo:
          repo_name: <repository>
          branch_name: ^main$            # or tag_name: ^v1\.  or commit_sha: <commit>
          dir: functions/from-repo
```

### Networking

Each function uses one option or none. If an organization policy requires VPC egress (the `constraints/run.allowedVPCEgress` error), every function needs one: put it in `defaults.functions.service_config` to cover them all.

```yaml
functions:
  # Direct VPC egress: no connector needed.
  via-direct-vpc:
    build_config:
      entry_point: handler
      source:
        dir: via-direct-vpc
    service_config:
      direct_vpc_network_interface:
        - network: projects/<network-project>/global/networks/<vpc>
          subnetwork: projects/<network-project>/regions/europe-west2/subnetworks/<subnet>
          tags: [<network-tag>]
      direct_vpc_egress: VPC_EGRESS_ALL_TRAFFIC

  # A Serverless VPC Access connector.
  via-connector:
    build_config:
      entry_point: handler
      source:
        dir: via-connector
    service_config:
      vpc_connector: projects/<project-id>/locations/europe-west2/connectors/<connector>
      vpc_connector_egress_settings: ALL_TRAFFIC
```

### Secrets

The runtime service account needs `roles/secretmanager.secretAccessor` on each secret.

```yaml
functions:
  billing:
    build_config:
      entry_point: handler
      source:
        dir: billing
    service_config:
      secret_environment_variables:
        - key: API_KEY                   # the code reads it like any environment variable
          secret: <secret-id>
          version: "3"
        - key: PARTNER_TOKEN
          secret: <secret-id>
          project_id: <secrets-project>  # a secret in another project
      secret_volumes:
        - mount_path: /etc/secrets       # file /etc/secrets/<secret-id>, latest version
          secret: <secret-id>
        - mount_path: /etc/tls
          secret: <secret-id>
          versions:
            - path: current.pem
              version: latest
            - path: previous.pem
              version: "2"
```

### Locked-down function

```yaml
functions:
  payments:
    deletion_policy: PREVENT             # terraform destroy fails instead of deleting it
    kms_key_name: projects/<project-id>/locations/europe-west2/keyRings/<key-ring>/cryptoKeys/<key>
    build_config:
      entry_point: handler
      docker_repository: projects/<project-id>/locations/europe-west2/repositories/<cmek-repository>
      worker_pool: projects/<project-id>/locations/europe-west2/workerPools/<pool>
      source:
        dir: payments
    service_config:
      ingress_settings: ALLOW_INTERNAL_AND_GCLB
      binary_authorization_policy: default
    iam:
      - role: roles/cloudfunctions.viewer
        members: [group:<support-group>@<domain>]
        condition:
          title: until-end-of-2027
          expression: request.time < timestamp("2028-01-01T00:00:00Z")
```

### Switching a function off

```yaml
functions:
  old-report:
    enabled: false                       # checked but not deployed; deleted if it was deployed
    build_config:
      entry_point: handler
      source:
        dir: old-report
```

## Set in the module call, not in the YAML

These go in the Terraform file that calls the module (for example `cloud-functions.tf`):

| Input | What it does |
|---|---|
| `config_file` | Path to the YAML file. |
| `base_path` | Folder that `dir` and `zip` paths are relative to. Defaults to the folder of `config_file`. |
| `project_id` | Project used when the file has no `project_id`. |
| `region` | Region used when the file has no `defaults.region`. |
| `labels` | Labels added to every function; labels in the file win. |
| `template_vars` | Values for `${name}` placeholders in the file. |
| `config_yaml` | The YAML as a string instead of a file (not templated). |
| `archive_output_dir` | Local folder the zips are written to before upload. |
