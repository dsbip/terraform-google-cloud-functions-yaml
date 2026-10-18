# Standalone modules example

The YAML layer is optional: [`modules/function`](../../modules/function) and [`modules/source-archive`](../../modules/source-archive) are ordinary modules with typed inputs.

- `module.status` deploys one HTTP function from a local directory.
- `module.fanout` deploys two Pub/Sub-triggered functions with `for_each`.
- `module.shared_archive` uploads one archive that both fan-out functions deploy from.

The YAML root module calls `modules/function` in exactly this way, once per function.
