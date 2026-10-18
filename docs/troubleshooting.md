# Troubleshooting

## The plan fails with "The Cloud Functions YAML configuration has N problem(s)"

That is the module's validation: each line starts with the YAML path of the problem. Nothing is planned until all of them are fixed. See [configuration.md](configuration.md#validation) for what is checked.

## A function key turned into `true` or `false`

Terraform's YAML parser reads unquoted `yes`, `no`, `on`, `off`, `true` and `false` as booleans, also as mapping keys. Quote the key (`"on":`) or pick another name. The module reports keys that became `true` or `false`.

## `Invalid template interpolation value` or `vars map does not contain key`

`config_file` is rendered with `templatefile()`. Every `${name}` needs a value in `template_vars` (`project_id` and `region` are always provided, but they are null if the module variables are unset). For a literal `${`, write `$${`.

## The function redeploys on every apply

The object name of a local `dir` contains the archive's hash, which only depends on file names, contents and the excludes. If it still changes, a build step probably writes into the directory (e.g. `node_modules/`, `__pycache__/`, `target/`); exclude it with `excludes`.

## `Error 403 ... iam.serviceAccounts.actAs`

The identity running Terraform needs `roles/iam.serviceAccountUser` on the runtime service account (`service_config.service_account_email`), the build service account and the trigger service account.

## Event-driven function receives nothing

- The trigger service account must be able to invoke the function: list it in `invokers`.
- It also needs `roles/eventarc.eventReceiver` in the project.
- Cloud Storage triggers: `trigger_region` must match the bucket's location, and the Cloud Storage service agent needs `roles/pubsub.publisher`.
- Audit Log triggers: Data Access audit logs must be enabled for the service.

## `allUsers` cannot be granted

The *Domain restricted sharing* organization policy (`iam.allowedPolicyMemberDomains`) blocks public members. Use authenticated invokers, or put the function behind a load balancer with IAP.

## Build fails with `Permission denied` on the source object

The Cloud Build service account (or `build_config.service_account`) must be able to read the source bucket (`roles/storage.objectViewer`).
