# Basic example

One public HTTP function (Python) built from the local [`src/hello`](src/hello) directory.

- The module zips `src/hello`, uploads it to `source_bucket` as `hello-<md5>.zip`, and deploys the function from that object. Changing the code changes the hash, which redeploys the function; an unchanged directory plans no changes.
- `invokers: [allUsers]` grants `roles/run.invoker` on the function's Cloud Run service, which makes the URL public.

```bash
terraform init
terraform apply -var project_id=my-project -var source_bucket=my-function-sources
curl "$(terraform output -json uris | jq -r .hello)?name=Ada"
```

Needs the Cloud Functions, Cloud Build, Cloud Run, Artifact Registry and Cloud Storage APIs, and an existing bucket.
