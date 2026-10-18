# Changelog

All notable changes to this module are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-18

First release.

### Added

- YAML-driven deployment of Cloud Run functions (Cloud Functions 2nd gen): HTTP and event-driven, any number per file.
- Sources from local directories (zipped, uploaded under a content hash, reproducible across machines), local zips, existing Cloud Storage objects with optional generation, and Cloud Source Repositories.
- Every `build_config` and `service_config` setting of `google_cloudfunctions2_function`, including Direct VPC egress, secret environment variables and volumes, CMEK, Binary Authorization, private worker pools and base image update policies.
- Event triggers with filters, path patterns, retry policies, trigger regions and service accounts; Pub/Sub short topic names and implied event type.
- Invokers (`roles/run.invoker` on the function's Cloud Run service) and function IAM with conditions.
- `defaults` for region, labels and every function key, merged three levels deep.
- Templating of `config_file` with `templatefile()`, and `enabled` per function.
- Validation driven by the JSON Schema (unknown keys with suggestions, types, enumerations, ranges, patterns, required keys) plus cross-field rules, all reported at once with YAML paths.
- Standalone submodules `modules/function` and `modules/source-archive`.
- Eight examples, 70+ unit tests with a mocked provider, real-provider plan tests, schema and documentation tests, and a live test.
