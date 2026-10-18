# Multi-environment example

One [`config.yaml`](config.yaml) deploys dev, staging and prod into separate projects. [`main.tf`](main.tf) calls the module once per environment with different template variables.

| | dev | staging | prod |
|---|---|---|---|
| `api` | public, 256M | public, 256M | gateway service account only, 1Gi, one warm instance, internal + load balancer ingress |
| `worker` | no retries | no retries | retries |
| `debug-echo` | deployed | validated, not deployed (`enabled: false`) | validated, not deployed |
| `alert-forwarder` | – | – | deployed (only prod sets `alert_topic`) |

Techniques used:

- `${env}` and other placeholders, including expressions such as `${env == "prod" ? "1Gi" : "256M"}`;
- `%{ if } ... %{ endif }` directives that add or remove whole blocks;
- `enabled: ${env == "dev"}`, which keeps a function in the file (and validated) without deploying it.

The example plans 8 functions in total: 3 in dev, 2 in staging and 3 in prod (with `alert-forwarder`), plus their source uploads and IAM grants.
