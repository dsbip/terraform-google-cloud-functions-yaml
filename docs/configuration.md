# Configuration file

The configuration is one YAML mapping with three top-level keys, all optional:

```yaml
project_id: my-project        # default project of every function

defaults:                     # applied underneath every function
  region: europe-west1
  labels: { team: payments }
  functions:                  # any function key except name
    build_config: { runtime: python312 }

functions:                    # one entry per function, keyed by a logical key
  api: { ... }
  worker: { ... }
```

| Key | Description |
|---|---|
| `project_id` | Default project for every function in the file. Overrides the module's `project_id` variable; a function's own `project_id` overrides it. |
| `defaults` | Values every function inherits, see [Defaults](#defaults). |
| `functions` | Functions keyed by logical key. The key is the default function name, the key of every output, and part of every Terraform address, so renaming a key replaces the function. See [functions.md](functions.md) for the keys of a function. |

Every `functions` entry may be empty (`hello:`), in which case it consists of defaults only.

## Templating

`config_file` is rendered with Terraform's [`templatefile()`](https://developer.hashicorp.com/terraform/language/functions/templatefile) before it is parsed:

- `${name}` is replaced with a value from `template_vars`. `project_id` and `region` (the module variables) are always available.
- Expressions work: `${env == "prod" ? "1Gi" : "256M"}`, `${upper(team)}`.
- `%{ if cond ~}` ... `%{ else ~}` ... `%{ endif ~}` and `%{ for x in list ~}` add or remove whole blocks. The `~` strips the line break so the YAML stays well-formed.
- `$${` produces a literal `${`.

`config_yaml` is used as-is. To template inline YAML, call `templatefile()` yourself, or use `yamlencode()` on an HCL object.

Values must be known at plan time. Names of resources defined in the same configuration (e.g. `google_storage_bucket.sources.name`) are fine; generated IDs are not.

To keep a templated file valid YAML *before* rendering (so editors and the JSON Schema can check it), quote placeholders that contain `: `, quotes or braces, and don't put `${...}` inside flow collections (`[ ... ]`, `{ ... }`) unquoted:

```yaml
available_memory: '${env == "prod" ? "1Gi" : "256M"}'
invokers: ["serviceAccount:caller@${project_id}.iam.gserviceaccount.com"]
```

## Defaults

```yaml
defaults:
  region: europe-west1                # default region
  labels: { cost-center: cc-42 }      # added to every function
  functions:                          # merged underneath every function
    build_config:
      runtime: python312
      source: { bucket: fn-sources }
    service_config:
      max_instance_count: 10
      environment_variables: { LOG_LEVEL: info }
```

| Key | Description |
|---|---|
| `region` | Default region. Overrides the module's `region` variable; a function's `region` (or `defaults.functions.region`) overrides it. |
| `labels` | Labels added to every function, over the module's `labels` variable. |
| `functions` | Any function key except `name` (which would make every function collide). |

### How defaults merge

`defaults.functions` is merged underneath each function, **three levels deep**:

| Level | Example | Rule |
|---|---|---|
| 1: function keys | `description`, `invokers`, `build_config` | the function's value wins; mappings merge one level down |
| 2: keys of a nested mapping | `build_config.runtime`, `service_config.max_instance_count` | the function's value wins; mappings merge one level down |
| 3: keys of a mapping inside that | `build_config.source.bucket`, `service_config.environment_variables.LOG_LEVEL` | the function's value wins; nothing deeper merges |

In the example above, a function with

```yaml
build_config:
  entry_point: main
  source: { dir: src/main }
service_config:
  environment_variables: { MODE: fast }
```

ends up with `runtime: python312`, `source: { bucket: fn-sources, dir: src/main }`, `max_instance_count: 10` and `environment_variables: { LOG_LEVEL: info, MODE: fast }`.

- **Lists are replaced**, never concatenated (`invokers`, `iam`, `secret_environment_variables`, `event_filters`, ...).
- **Empty keys never override**: `description:` with no value is the same as leaving the key out, so it can't unset a default.
- A default `event_trigger` makes *every* function event-driven; put triggers on the functions instead.
- Labels merge in this order, later wins: module `labels` → `defaults.labels` → `defaults.functions.labels` → function `labels`.

## Precedence

| Setting | Highest → lowest |
|---|---|
| project | function `project_id` → `defaults.functions.project_id` → top-level `project_id` → module `project_id` |
| region | function `region` → `defaults.functions.region` → `defaults.region` → module `region` |
| name | function `name` → YAML key |

A function whose project or region cannot be determined is a validation error.

## Paths

`build_config.source.dir` and `build_config.source.zip` are resolved against the directory of `config_file` (with `config_yaml`: the root module), or against the `base_path` variable when set. Absolute paths are used as-is.

## Enabling and disabling

`enabled: false` keeps a function in the file without deploying it. It is still validated, so a disabled function cannot rot. With templating:

```yaml
debug-endpoint:
  enabled: ${env == "dev"}
```

## Validation

Before anything is planned, the module checks the whole file and reports every problem at once, each prefixed with its YAML path. While there are problems, no function is planned, so the error list is the only output.

Checks driven by the [JSON Schema](../schemas/cloud-functions-config.schema.json):

- unknown keys, with suggestions for likely typos;
- types (string, whole number, number, true/false, list, mapping);
- enumerations (`ingress_settings`, `retry_policy`, `deletion_policy`, ...);
- ranges (`timeout_seconds` 1–3600, `max_instance_request_concurrency` 1–1000, ...) and minimum list lengths;
- patterns (`runtime`, function names, IAM members);
- required keys of list items (`iam[*].role`, `event_filters[*].value`, `secret_volumes[*].mount_path`, ...).

Rules beyond the schema, checked after defaults are merged:

- a project and a region must be determinable; the key must be a valid name unless `name` is set;
- `build_config` with `runtime` and `source` must be present;
- `source`: exactly one of `dir`, `zip`, `object`, `repo`; `bucket` with `dir`/`zip`/`object`; no `gs://` prefix; `dir` must contain files and `zip` must exist; `repo` needs exactly one of `branch_name`, `tag_name`, `commit_sha`;
- `event_trigger` needs `event_type` or `pubsub_topic`;
- `min_instance_count` ≤ `max_instance_count`; not both `vpc_connector` and `direct_vpc_network_interface`; egress settings only with their network option;
- no two enabled functions with the same project, region and name;
- `name` cannot be a default; keys that YAML read as booleans are reported.

The submodules validate their own inputs too, so they fail early when used without YAML.

## YAML gotchas

- Terraform's `yamldecode()` reads unquoted `yes`, `no`, `on`, `off`, `true` and `false` as booleans, also as keys. The module reports a function key that became `true` or `false`; quote such keys (`"on":`).
- Version numbers and similar values that look like numbers (`version: 1.10`) become numbers; quote them when the exact text matters (`"1.10"`).
- Environment variable values may be numbers or booleans; they are converted to strings.
