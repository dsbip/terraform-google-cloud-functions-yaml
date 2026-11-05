# YAML reference

Every key of the configuration file (for example `dataflow.yaml`) on one page, nested the way you write it, with what it does, its default and its allowed values. [configuration.md](configuration.md) explains how defaults merge and how the file is templated; [jobs.md](jobs.md) and [pipelines.md](pipelines.md) have more detail on single keys.

| Tag | Meaning |
|---|---|
| `[Required]` | Must be set: on the entry, or once for every entry in `defaults`. |
| `[Optional]` | Can be left out. *Defaults to* says what happens then. |
| `[Choose one]` | Set exactly one of the keys tagged this way in the same block. |
| `[Required if]` | Must be set in the situation named. |
| `(Flex only)`, `(Classic only)` | Only for that template type. Set on an entry of the other type, it is an error; set in `defaults`, it is skipped for entries of the other type. |
| `(Batch only)` | Only for batch pipelines. It is an error on a streaming pipeline, also when it comes from `defaults`. |
| `(Streaming)` | Only has an effect on streaming jobs (not checked). |

Names in square brackets, such as `[JOB KEY]`, are yours to choose, and `- ` starts a list item. In paths such as `projects/P/locations/L/...`, replace the capital letters with your project, location and resource names.

## What kind of entry

The template key decides whether a job or pipeline is a Flex or a classic one:

| You set | The entry is |
|---|---|
| `google_template: { name: NAME }` | Flex, from a template Google provides |
| `google_template: { name: NAME, type: classic }` | classic, from a template Google provides |
| `container_spec_gcs_path: gs://BUCKET/PATH.json` | Flex, from your own Flex Template |
| `template_gcs_path: gs://BUCKET/PATH` | classic, from your own classic template |

All four work under `jobs` and under `pipelines`. A job is streaming or batch depending on its template. A pipeline is also batch or streaming:

| You set | The pipeline |
|---|---|
| `schedule` (`type` defaults to `BATCH`) | starts a new job on every scheduled run |
| `type: BATCH` and no `schedule` | starts a new job only when you start a run (console or API) |
| no `schedule` (`type` defaults to `STREAMING`) | keeps one job running |

## Every key

```yaml
project_id:                              [Required] Project the jobs and pipelines run in, e.g. my-project. Not needed
                                         when every entry sets its own project_id, or when the module call passes
                                         project_id.

defaults:                                [Optional] Settings shared by every entry in this file.
  region:                                [Required] Region the jobs and pipelines run in, e.g. europe-west2. Not needed
                                         when every entry sets its own region, or when the module call passes region.
  labels:                                [Optional] Labels on every job, and on every job a pipeline starts. Defaults
                                         to {}.
    [LABEL KEY]:                         Label value. Numbers and true/false are turned into strings.
  jobs:                                  [Optional] Starting values for every job: any key listed under [JOB KEY]
                                         below, except name. A job's own value wins. Mappings merge (parameters,
                                         labels); lists such as additional_experiments are replaced, not combined.
  pipelines:                             [Optional] Starting values for every pipeline: any key listed under
                                         [PIPELINE KEY] below, except name and job_name. To reuse the job defaults,
                                         write jobs: &workers above and <<: *workers here.

jobs:                                    [Optional] Dataflow jobs, one entry per job. terraform apply launches them.
  [JOB KEY]:                             [Required] Your key for the job, e.g. orders-stream. It is also the job's name
                                         unless name is set. Renaming the key replaces the job.
    enabled:                             [Optional] false keeps the job in the file (still checked) but does not
                                         launch it; a running job is stopped as on_delete says. Defaults to true.
    name:                                [Optional] Job name in Dataflow: lowercase letters, digits and hyphens,
                                         starting with a letter. Defaults to the key.
    project_id:                          [Optional] Project of this job. Defaults to the top-level project_id.
    region:                              [Optional] Region of this job. Defaults to defaults.region.

    template_gcs_path:                   [Choose one] Your own classic template, gs://BUCKET/PATH. Makes it a classic
                                         job.
    container_spec_gcs_path:             [Choose one] Your own Flex Template: the spec file that gcloud dataflow
                                         flex-template build wrote, gs://BUCKET/PATH.json. Makes it a Flex job.
    google_template:                     [Choose one] A template Google provides, by name.
      name:                              [Required] Template name, e.g. PubSub_to_BigQuery_Flex,
                                         GCS_Text_to_BigQuery_Flex, BigQuery_to_Parquet (Flex) or Word_Count,
                                         Bulk_Compress_GCS_Files (classic).
      type:                              [Optional] flex or classic; must match the template. Defaults to flex.
      version:                           [Optional] A fixed release, e.g. 2026-09-15-00_RC00, for repeatable
                                         deployments. Defaults to latest.
    parameters:                          [Optional] The template's inputs, named as in the template's documentation.
                                         Defaults to {}.
      [PARAMETER NAME]:                  Value. Numbers and true/false are turned into strings.
    labels:                              [Optional] Labels of this job, added to defaults.labels (for the same key,
                                         this one wins). Defaults to {}.
      [LABEL KEY]:                       Label value.

    temp_location:                       [Required if] the job is classic. gs:// folder for temporary files, e.g.
                                         gs://BUCKET/tmp. Usually set once in defaults.jobs.
    staging_location:                    [Optional] (Flex only) gs:// folder for the job's staged files.
    service_account_email:               [Optional] Service account the workers run as (just the email). It needs
                                         roles/dataflow.worker and access to the job's sources and sinks. Defaults to
                                         the Compute Engine default service account, so set your own.
    network:                             [Optional] VPC network of the workers, by name. Defaults to the network named
                                         default.
    subnetwork:                          [Optional] Subnet of the workers: regions/R/subnetworks/S, or for Shared VPC
                                         https://www.googleapis.com/compute/v1/projects/HOST/regions/R/subnetworks/S.
    ip_configuration:                    [Optional] WORKER_IP_PRIVATE (no public IPs; the subnet needs Private Google
                                         Access) or WORKER_IP_PUBLIC. Defaults to public IPs.
    zone:                                [Optional] (Classic only) Zone of the workers, e.g. europe-west2-a. Defaults
                                         to a zone Dataflow picks.
    machine_type:                        [Optional] Machine type of each worker, e.g. n2-standard-4. Defaults to one
                                         Dataflow picks.
    num_workers:                         [Optional] (Flex only) Workers to start with, 1 to 4000; not more than
                                         max_workers.
    max_workers:                         [Optional] Most workers autoscaling may use, 1 to 4000.
    autoscaling_algorithm:               [Optional] (Flex only) AUTOSCALING_ALGORITHM_BASIC (scale between num_workers
                                         and max_workers) or AUTOSCALING_ALGORITHM_NONE (always num_workers).
    launcher_machine_type:               [Optional] (Flex only) Machine type of the VM that starts the job. Defaults
                                         to n1-standard-1.
    sdk_container_image:                 [Optional] (Flex only) Your own container image for the workers.
    kms_key_name:                        [Optional] Cloud KMS key that encrypts the job's data (CMEK):
                                         projects/P/locations/L/keyRings/R/cryptoKeys/K. Defaults to Google-managed
                                         encryption.
    enable_streaming_engine:             [Optional] (Streaming) true keeps streaming state in Dataflow's backend
                                         instead of on the workers.
    additional_experiments:              [Optional] Dataflow experiments. Defaults to [].
      - [EXPERIMENT]                     e.g. enable_prime, use_runner_v2.
    additional_pipeline_options:         [Optional] (Flex only) Extra Beam pipeline options. Defaults to [].
      - [OPTION]                         e.g. numberOfWorkerHarnessThreads=12.

    transform_name_mapping:              [Optional] (Streaming) Steps renamed since the running job started, so that
                                         it can be updated in place.
      [OLD STEP NAME]:                   New step name.
    create_ignore_already_exists:        [Optional] (Flex only) true takes over a running job with the same name
                                         instead of failing. Defaults to false.
    on_delete:                           [Optional] What happens to the running job when it is removed, disabled or
                                         replaced: drain (finish the data in flight, then stop) or cancel (stop at
                                         once). Defaults to drain for classic jobs and cancel for Flex jobs.
    skip_wait_on_job_termination:        [Optional] true: don't wait for the drain or cancel to finish. A new job must
                                         then use another name. Defaults to false.
    deletion_policy:                     [Optional] What terraform destroy does: DELETE, PREVENT (destroy fails) or
                                         ABANDON (Terraform forgets the job, it keeps running). Defaults to DELETE.

pipelines:                               [Optional] Data Pipelines, one entry per pipeline. It needs Cloud Scheduler,
                                         so only App Engine regions work.
  [PIPELINE KEY]:                        [Required] Your key for the pipeline, e.g. daily-load. It is also the
                                         pipeline ID unless name is set. Renaming the key replaces the pipeline.
    enabled:                             [Optional] false keeps the pipeline in the file (still checked) but does not
                                         create it; an existing one is deleted. Defaults to true.
    name:                                [Optional] Pipeline ID: letters, digits, hyphens and underscores, at most 63
                                         characters. Defaults to the key.
    display_name:                        [Optional] Name shown in the console: letters, digits, hyphens and
                                         underscores. Defaults to the pipeline ID.
    project_id:                          [Optional] Project of this pipeline and its jobs. Defaults to the top-level
                                         project_id.
    region:                              [Optional] Region of this pipeline and its jobs. Defaults to
                                         defaults.region.

    type:                                [Optional] BATCH (a new job on every run) or STREAMING (one job that keeps
                                         running). Defaults to BATCH with a schedule and STREAMING without.
    state:                               [Optional] ACTIVE or PAUSED (the pipeline exists but starts nothing).
                                         Defaults to ACTIVE.
    schedule:                            [Optional] (Batch only) Cron schedule, e.g. "0 2 * * *" (every day at
                                         02:00). Without it, a batch pipeline runs only when you start a run.
    time_zone:                           [Optional] Time zone of the schedule, e.g. Europe/London. Needs schedule; a
                                         default time_zone is unused by pipelines without one. Defaults to UTC.
    scheduler_service_account_email:     [Optional] Service account Cloud Scheduler starts the runs as. Defaults to
                                         the Compute Engine default service account.
    job_name:                            [Optional] Name of the jobs the pipeline starts. Defaults to the pipeline ID
                                         in lowercase with _ as - (Daily_Load gives daily-load).
    pipeline_sources:                    [Optional] Free-form notes on where the pipeline comes from. Defaults to {}.
      [KEY]:                             Value.

    template_gcs_path:                   [Choose one] Your own classic template, gs://BUCKET/PATH. Makes it a classic
                                         pipeline.
    container_spec_gcs_path:             [Choose one] Your own Flex Template spec file, gs://BUCKET/PATH.json. Makes
                                         it a Flex pipeline.
    google_template:                     [Choose one] A template Google provides, by name.
      name:                              [Required] Template name, e.g. GCS_Text_to_BigQuery_Flex.
      type:                              [Optional] flex or classic; must match the template. Defaults to flex.
      version:                           [Optional] A fixed release, e.g. 2026-09-15-00_RC00. Defaults to latest.
    parameters:                          [Optional] The template's inputs. Defaults to {}.
      [PARAMETER NAME]:                  Value. Numbers and true/false are turned into strings.
    launch_options:                      [Optional] (Flex only) Flex launch settings that are not template inputs.
                                         Defaults to {}.
      [OPTION]:                          Value, e.g. enableLauncherVmSerialPortLogging: "true".
    labels:                              [Optional] Labels on every job the pipeline starts, added to
                                         defaults.labels. Defaults to {}.
      [LABEL KEY]:                       Label value.

    temp_location:                       [Optional] gs:// folder for temporary files, e.g. gs://BUCKET/tmp.
    bypass_temp_dir_validation:          [Optional] (Classic only) true skips checking temp_location before a run.
                                         Defaults to false.
    service_account_email:               [Optional] Service account the workers run as, as for jobs.
    network:                             [Optional] VPC network of the workers, as for jobs.
    subnetwork:                          [Optional] Subnet of the workers, as for jobs.
    ip_configuration:                    [Optional] WORKER_IP_PRIVATE or WORKER_IP_PUBLIC, as for jobs.
    worker_region:                       [Optional] Region the workers run in, if not the pipeline's (e.g. close to
                                         the data). Use worker_region or worker_zone, not both.
    worker_zone:                         [Optional] Zone the workers run in, e.g. europe-west2-a.
    zone:                                [Optional] Zone of the workers; the older form of worker_zone.
    machine_type:                        [Optional] Machine type of each worker, e.g. n2-standard-4.
    num_workers:                         [Optional] Workers to start with, 1 to 4000; not more than max_workers.
    max_workers:                         [Optional] Most workers autoscaling may use, 1 to 4000.
    kms_key_name:                        [Optional] Cloud KMS key that encrypts the jobs' data (CMEK).
    enable_streaming_engine:             [Optional] (Streaming) true keeps streaming state in Dataflow's backend.
    additional_experiments:              [Optional] Dataflow experiments. Defaults to [].
      - [EXPERIMENT]                     e.g. use_runner_v2.
    flexrs_goal:                         [Optional] (Flex only) (Batch only) FLEXRS_COST_OPTIMIZED (cheaper; a run
                                         may start later) or FLEXRS_SPEED_OPTIMIZED.

    update:                              [Optional] (Streaming) true updates the running job in place instead of
                                         starting a new one.
    transform_name_mapping:              [Optional] (Streaming) Steps renamed since the running job started; used
                                         with update.
      [OLD STEP NAME]:                   New step name.
    validate_only:                       [Optional] true only checks the launch request; no job is started. Defaults
                                         to false.
    deletion_policy:                     [Optional] What terraform destroy does: DELETE, PREVENT or ABANDON. Defaults
                                         to DELETE.
```

Pipelines don't take the job-only keys `on_delete`, `skip_wait_on_job_termination`, `staging_location`, `launcher_machine_type`, `sdk_container_image`, `autoscaling_algorithm`, `additional_pipeline_options` and `create_ignore_already_exists`.

## Which value wins

| Setting | The first one that is set wins |
|---|---|
| Project | the entry's `project_id`, `project_id` in `defaults.jobs` / `defaults.pipelines`, the top-level `project_id`, the module's `project_id` |
| Region | the entry's `region`, `region` in `defaults.jobs` / `defaults.pipelines`, `defaults.region`, the module's `region` |
| Labels | all are combined; for the same key, later wins: the module's `labels`, `defaults.labels`, `labels` in `defaults.jobs` / `defaults.pipelines`, the entry's `labels` |
| Anything else | the entry's value, then `defaults.jobs` / `defaults.pipelines` |

## Rules the module checks

Before anything is planned, the module checks the whole file, disabled entries included, and lists every problem with its YAML path:

- Each entry needs a project and a region (see [Which value wins](#which-value-wins)).
- An entry's key must be a valid name (see `name`), unless `name` is set. Unquoted `yes`, `no`, `on`, `off`, `true` and `false` are not accepted as keys.
- Each entry takes exactly one of `template_gcs_path`, `container_spec_gcs_path` and `google_template`; `google_template` needs `name`.
- Keys of the other template type are errors: for example `num_workers` on a classic job, `zone` on a Flex job, `launch_options` on a classic pipeline.
- Classic jobs need `temp_location`.
- `num_workers` can't be more than `max_workers`.
- `schedule` and `flexrs_goal` are only for batch pipelines, and `time_zone` needs `schedule`. If the job name derived from a pipeline ID is not a valid job name, set `job_name`.
- Two enabled jobs can't have the same name in the same project and region (classic and Flex jobs share the names), and neither can two pipelines.
- `name` can't be set in `defaults.jobs`, and neither `name` nor `job_name` in `defaults.pipelines`.
- Unknown keys (typos get a suggestion), wrong types, values outside the allowed lists, numbers out of range and paths without `gs://` are errors.

## Things to watch

- **Batch jobs run again on every apply.** The provider removes a finished batch job from the state, so the next `terraform apply` launches it again. Put recurring batch work under `pipelines`, and use `jobs` for streaming.
- **Set `on_delete` on streaming jobs.** Classic jobs default to `drain`, but Flex jobs default to `cancel`, which drops the data in flight when the job is removed or replaced.
- **Renaming a key, or changing `name`, replaces the job or pipeline.** A running job is stopped as `on_delete` says and a new one is launched.
- **`enabled: false` removes an entry that is deployed** on the next apply, unless `deletion_policy` is `PREVENT` (the apply fails) or `ABANDON`.
- **Mappings merge, lists are replaced.** An entry's own value wins over `defaults.jobs` / `defaults.pipelines`. Mappings such as `parameters` and `labels` are combined key by key, but a list such as `additional_experiments` replaces the default list as a whole. An empty `key:` doesn't remove a default.
- **No `${` or `%{` anywhere in the file, not even in comments**, unless you mean a placeholder. The module reads the file with Terraform's `templatefile()`: `${project_id}` and `${region}` only work when the module call sets `project_id` and `region`, other names need `template_vars`. Write `$${` for a literal `${`.
- **Quote what YAML could misread**: `yes`, `no`, `on`, `off` (also as keys), numbers whose exact text matters (`version: "1.10"`), and BigQuery table specs inside `{ }` (`{ table: "my-project:sales.orders" }`).
- **`worker_region` and `worker_zone` can't be combined.** Dataflow rejects the run; the plan doesn't check it.

## Combinations

Starting points to copy. Replace every `<...>`. Every block below assumes the shared settings are at the top of the file, so an entry lists only what is specific to it.

### Shared settings

```yaml
project_id: <project-id>

defaults:
  region: europe-west2
  labels:
    managed-by: terraform
  jobs: &workers                         # worker settings of every job...
    service_account_email: <worker-sa>@<project-id>.iam.gserviceaccount.com
    temp_location: gs://<dataflow-bucket>/tmp
    subnetwork: regions/europe-west2/subnetworks/<subnet>
    ip_configuration: WORKER_IP_PRIVATE
  pipelines:                             # ...and of every pipeline
    <<: *workers
    scheduler_service_account_email: <scheduler-sa>@<project-id>.iam.gserviceaccount.com
    time_zone: Europe/London

jobs:
  # the jobs from the blocks below go here

pipelines:
  # the pipelines from the blocks below go here
```

### Jobs

`terraform apply` launches each job. A streaming job keeps running until it is removed; a batch job is launched again by every apply.

```yaml
jobs:
  # Flex, from a template Google provides. Streaming.
  events-to-bigquery:
    google_template:
      name: PubSub_to_BigQuery_Flex      # type: flex is the default
    parameters:
      inputSubscription: projects/<project-id>/subscriptions/<subscription>
      outputTableSpec: <project-id>:<dataset>.<table>
    enable_streaming_engine: true
    on_delete: drain                     # finish the data in flight when the job is removed

  # Flex, from your own Flex Template.
  orders-enrich:
    container_spec_gcs_path: gs://<templates-bucket>/flex/orders-enrich.json
    parameters:
      <parameter>: <value>               # your template's own inputs
    num_workers: 2                       # Flex only
    max_workers: 10

  # Classic, from a template Google provides. Batch: every apply runs it again.
  word-count:
    google_template:
      name: Word_Count
      type: classic
    parameters:
      inputFile: gs://dataflow-samples/shakespeare/kinglear.txt
      output: gs://<dataflow-bucket>/wordcount/out
    # temp_location, required for classic jobs, comes from defaults.jobs

  # Classic, from your own classic template.
  dedupe:
    template_gcs_path: gs://<templates-bucket>/classic/dedupe
    zone: europe-west2-b                 # classic only
```

### Pipelines

Once a pipeline exists, Data Pipelines starts its jobs; `terraform apply` doesn't.

```yaml
pipelines:
  # Batch on a schedule, Flex template Google provides.
  daily-files-to-bigquery:
    schedule: "0 2 * * *"                # every day at 02:00, London time (from defaults)
    google_template:
      name: GCS_Text_to_BigQuery_Flex
    parameters:
      inputFilePattern: gs://<landing-bucket>/daily/*.json
      JSONPath: gs://<dataflow-bucket>/schemas/daily.json
      outputTable: <project-id>:<dataset>.daily
      bigQueryLoadingTemporaryDirectory: gs://<dataflow-bucket>/bq-tmp
    flexrs_goal: FLEXRS_COST_OPTIMIZED   # Flex and batch only: cheaper, may start later

  # Batch on a schedule, classic template Google provides.
  monthly-compress:
    schedule: "0 5 1 * *"                # 05:00 on the 1st of every month
    google_template:
      name: Bulk_Compress_GCS_Files
      type: classic
    parameters:
      inputFilePattern: gs://<logs-bucket>/*.log
      outputDirectory: gs://<archive-bucket>/
      outputFailureFile: gs://<archive-bucket>/failures.csv
      compression: GZIP

  # Batch without a schedule: a job starts only when you start a run.
  backfill:
    type: BATCH                          # without a schedule it would be STREAMING
    container_spec_gcs_path: gs://<templates-bucket>/flex/backfill.json
    parameters:
      <parameter>: <value>

  # Streaming, Flex template Google provides: keeps one job running.
  events-stream:
    google_template:
      name: PubSub_to_BigQuery_Flex
    parameters:
      inputSubscription: projects/<project-id>/subscriptions/<other-subscription>
      outputTableSpec: <project-id>:<dataset>.<other-table>
    enable_streaming_engine: true
    # later, update: true changes the running job in place

  # Streaming, your own classic template.
  clicks-stream:
    type: STREAMING                      # also the default without a schedule
    template_gcs_path: gs://<templates-bucket>/classic/clicks
```

### Paused and switched-off entries

```yaml
pipelines:
  weekly-report:
    schedule: "0 7 * * 1"                # Mondays at 07:00
    state: PAUSED                        # exists, but starts nothing until ACTIVE
    template_gcs_path: gs://<templates-bucket>/classic/weekly-report

jobs:
  old-export:
    enabled: false                       # checked but not launched; stopped if it was running
    google_template:
      name: Word_Count
      type: classic
```

## Set in the module call, not in the YAML

These go in the Terraform file that calls the module (for example `dataflow.tf`):

| Input | What it does |
|---|---|
| `config_file` | Path to the YAML file. |
| `config_yaml` | The YAML as a string instead of a file (not templated). Set `config_file` or `config_yaml`, not both. |
| `project_id` | Project used when the file has no `project_id`. |
| `region` | Region used when the file has no `defaults.region`. |
| `labels` | Labels added to every job; labels in the file win. |
| `template_vars` | Values for `${name}` placeholders in the file. |
