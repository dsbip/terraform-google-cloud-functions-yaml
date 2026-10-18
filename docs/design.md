# Design

## Flow of a configuration

```text
config_file ──templatefile()──┐
config_yaml ──────────────────┴─▶ yamldecode ─▶ local.config_decoded
                                                   │
                     ┌─────────────────────────────┤
                     ▼                             ▼
            validation.tf part 1          main.tf: drop nulls, merge
            walk YAML + JSON Schema       defaults.functions (3 levels),
            (raw values, exact paths)     resolve project/region/labels/paths
                     │                             │
                     │                    validation.tf part 2: rules on the
                     │                    merged functions (defaults applied)
                     ▼                             │
            local.validation_errors ◀──────────────┘
                     │
        config_valid ├──▶ terraform_data.validation (precondition lists all errors)
                     ▼
            functions.tf: module "function" { for_each = valid ? functions : {} }
                     ▼
            modules/function ──▶ modules/source-archive (dir / zip only)
```

## Decisions

**YAML keys follow the provider.** `build_config`, `service_config` and `event_trigger` and the keys inside them are named as in `google_cloudfunctions2_function`, so the provider documentation and existing knowledge apply. The module adds a few conveniences where the provider is awkward: `source` (local directories and zips), `invokers`, short Pub/Sub topic names, an implied Pub/Sub event type, and default projects and versions for secrets. Exception: `region` instead of `location`, matching `gcloud --region` and the other modules in this family.

**The schema is the single source of truth.** `validation.tf` reads allowed keys, types, enumerations, ranges and patterns from `schemas/cloud-functions-config.schema.json` at plan time. Editors use the same file for completion and inline errors. Adding a key to the schema makes it valid everywhere at once; tests check that the schema stays in a shape the Terraform walker understands (closed object definitions, no inline objects, bounded depth).

**Report everything, plan nothing.** A Terraform type error stops at the first problem and points at HCL, not at the YAML. Instead, every lookup in the loading code is wrapped in `try()`, all problems are collected with their YAML paths, and the module's `for_each` is empty until the list is empty. The precondition on `terraform_data.validation` then fails the plan with the complete list.

**Typed submodules.** `modules/function` has strict, typed variables (`optional()` with defaults) and its own validation, so it is useful on its own and its interface documents itself. The root module only loads, merges, validates and calls it. `modules/source-archive` is separate because uploading code is useful without deploying it (one archive for several functions, or for something else).

**Content-addressed uploads.** The object name contains the archive's MD5 hash, so a change in code changes the object, and the function is rebuilt only then. File timestamps never enter the archive and file modes are fixed, so the hash is the same on every machine and every checkout; a test plans the same code twice after changing timestamps and permissions.

**Defaults merge three levels deep.** Shallow merging would lose a default `service_config.service_account_email` as soon as a function sets any `service_config` key. Three levels cover `build_config.source.bucket` and environment variables, which are the common shared settings. Lists are replaced, because concatenating invokers or secrets silently would be surprising.

**Stable addresses.** Functions are keyed by their YAML key (`module.function["api"]`), IAM grants by role and member. Changing a name, region or project replaces the function, but adding or removing other functions never touches it.

## Compatibility rules for the code

- Terraform 1.5: no functions newer than 1.5; `&&` and `||` do not short-circuit before 1.12, so every operand must be safe on its own.
- Conditionals must not mix object types that hold YAML values; the validation walker uses `for ... if` filters instead.
- Never pass a possibly-null value to `contains()`; never let a null reach `${...}` interpolation.
