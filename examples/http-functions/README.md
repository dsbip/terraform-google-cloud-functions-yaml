# HTTP functions example

Four HTTP functions in four runtimes (Python, Node.js, Go, Java) that share one set of defaults:

| Function | Shows |
|---|---|
| `greeter` | public function, scale to zero, environment variable merged with a default |
| `orders-api` | warm instances, 1 CPU with 40 concurrent requests, Secret Manager environment variable, authenticated invokers, extra label |
| `pricing` | internal-only ingress, `ON_DEPLOY` base image updates instead of the default `AUTOMATIC` |
| `daily-report` | 2 CPUs / 2 GiB, 30 minute timeout, build-time environment variable, viewer IAM grant |

The defaults put every archive under `http-functions/` in the source bucket, run every function as `storefront-fns@PROJECT.iam.gserviceaccount.com`, and add `LOG_LEVEL=info`. Each function only states what differs.

Before applying, create the runtime service account, the `checkout` service account and the `orders-api-key` secret, and grant the runtime service account `roles/secretmanager.secretAccessor` on the secret.

```bash
terraform apply -var project_id=my-project -var source_bucket=my-function-sources
```
