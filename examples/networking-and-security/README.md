# Networking and security example

Three functions in `europe-west3` with production-grade controls:

- **CMEK**: every function sets `kms_key_name`, and images go to a CMEK-protected Artifact Registry repository (`docker_repository`).
- **Private builds**: a dedicated build service account and a private Cloud Build worker pool.
- **Binary Authorization** (`binary_authorization_policy: default`) and **deletion protection** (`deletion_policy: PREVENT`, overridden by `internal-proxy`).
- **Egress**: `ledger` uses a Serverless VPC Access connector for all traffic; `payments-webhook` and `internal-proxy` use Direct VPC egress with different routing.
- **Ingress**: internal plus load balancer by default; internal only for `internal-proxy`.
- **Secrets**: environment variables (pinned version, cross-project secret) and mounted files (with and without explicit versions).
- **IAM**: a time-bound conditional `roles/cloudfunctions.developer` grant.

Every referenced resource (key ring, repository, worker pool, connector, network, secrets, service accounts) must exist first; the example only deploys the functions. The Cloud Functions and Artifact Registry service agents need `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the key.
