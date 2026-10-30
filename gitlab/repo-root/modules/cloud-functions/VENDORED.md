# Vendored module: terraform-google-cloud-functions-yaml

This directory and `modules/cf-config/` are a copy of the upstream module, kept in this repository so that the pipeline needs no access to GitHub and every change to the module goes through a merge request here.

| | |
|---|---|
| Upstream | https://github.com/dsbip/terraform-google-cloud-functions-yaml |
| Version | 1.0.0 (see `CHANGELOG.md`), copied from commit `a7c4c65` |
| Local changes | `functions.tf`: `source = "../cf-config/function"` instead of `"./modules/function"` (the repository's layout, below) |

## Layout

The repository keeps a YAML-driven module in `modules/<name>/` and its submodules in `modules/<name>-config/`, so the upstream directories are split:

| Upstream | Here |
|---|---|
| `*.tf`, `schemas/`, `docs/`, `README.md`, `CHANGELOG.md`, `LICENSE` | `modules/cloud-functions/` |
| `modules/function/` | `modules/cf-config/function/` |
| `modules/source-archive/` | `modules/cf-config/source-archive/` |

The files find each other by relative path:

- `modules/cloud-functions/functions.tf` calls `../cf-config/function` (the local change).
- `modules/cf-config/function/main.tf` calls `../source-archive`, so `function/` and `source-archive/` stay side by side.
- `modules/cloud-functions/main.tf` reads `schemas/cloud-functions-config.schema.json` on every plan; the YAML validation depends on it.

Paths in the documentation (`README.md`, `docs/`, the submodule READMEs) describe the upstream layout, so links from the submodule READMEs to `../../docs/` don't resolve here: the documents are in `modules/cloud-functions/docs/`.

Not copied (see upstream): `examples/`, `tests/`, `scripts/`, `.github/`, `docs/testing.md`, `CONTRIBUTING.md`.

## Rules

- Don't edit the files beyond the local change above. Change the module upstream, where its tests run, and copy the new version in. If another local patch can't be avoided, add it to the table so the next upgrade keeps it.
- `LICENSE` (Apache 2.0) has to stay with the code.

## Upgrading

1. Read the upstream `CHANGELOG.md` from the version above to the new one.
2. Replace the files according to the Layout table. Keep this file and update the version.
3. Apply the local change to the new `functions.tf` again.
4. Run the plan for every environment. It should show no changes unless the changelog says otherwise.
