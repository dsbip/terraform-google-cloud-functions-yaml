# Vendored module: terraform-google-dataflow-yaml

This directory and `modules/dataflow-config/` are a copy of the upstream module, kept in this repository so that the pipeline needs no access to GitHub and every change to the module goes through a merge request here.

| | |
|---|---|
| Upstream | https://github.com/dsbip/terraform-google-dataflow-yaml |
| Version | 1.0.0 (see `CHANGELOG.md`), copied from commit `704a027` |
| Local changes | `jobs.tf` and `pipelines.tf`: `source = "../dataflow-config/<name>"` instead of `"./modules/<name>"` (the repository's layout, below), three lines, each file with a comment saying so. `README.md`: written for this repository, because upstream's links into `examples/` and `tests/` don't resolve here. |

## Layout

The repository keeps a YAML-driven module in `modules/<name>/` and its submodules in `modules/<name>-config/`, so the upstream directories are split:

| Upstream | Here |
|---|---|
| `*.tf`, `schemas/`, `docs/` (without `testing.md`), `CHANGELOG.md`, `LICENSE` | `modules/dataflow/` |
| `modules/classic-job/*.tf` | `modules/dataflow-config/classic-job/` |
| `modules/flex-job/*.tf` | `modules/dataflow-config/flex-job/` |
| `modules/pipeline/*.tf` | `modules/dataflow-config/pipeline/` |

The files find each other by relative path:

- `modules/dataflow/jobs.tf` calls `../dataflow-config/classic-job` and `../dataflow-config/flex-job`, and `modules/dataflow/pipelines.tf` calls `../dataflow-config/pipeline` (the local changes).
- `modules/dataflow/main.tf` reads `schemas/dataflow-config.schema.json` on every plan; the YAML validation depends on it.
- The submodules call no other module, so their folder names are free.

Not copied (see upstream): `examples/`, `tests/`, `scripts/`, `.github/`, `docs/testing.md`, `CONTRIBUTING.md`, upstream's `README.md` and the submodule READMEs (their links point into upstream's layout).

## Rules

- Don't edit the files beyond the local changes above. Change the module upstream, where its tests run, and copy the new version in. If another local patch can't be avoided, add it to the table so the next upgrade keeps it.
- `LICENSE` (Apache 2.0) has to stay with the code.

## Upgrading

1. Read the upstream `CHANGELOG.md` from the version above to the new one.
2. Replace the files according to the Layout table. Keep this file and `README.md`, and update the version.
3. Apply the local changes to the new `jobs.tf` and `pipelines.tf` again.
4. Run the plan for every environment. It should show no changes unless the changelog says otherwise.

Steps 2 and 3 from the repository root, with the new version checked out next to it:

```bash
UPSTREAM=../terraform-google-dataflow-yaml
cp "$UPSTREAM"/{main,validation,jobs,pipelines,variables,outputs,versions}.tf modules/dataflow/
cp "$UPSTREAM"/schemas/dataflow-config.schema.json modules/dataflow/schemas/
cp "$UPSTREAM"/docs/{configuration,jobs,pipelines,design,troubleshooting}.md modules/dataflow/docs/
cp "$UPSTREAM"/CHANGELOG.md "$UPSTREAM"/LICENSE modules/dataflow/
for m in classic-job flex-job pipeline; do cp "$UPSTREAM"/modules/$m/*.tf modules/dataflow-config/$m/; done
sed -i 's#"./modules/#"../dataflow-config/#' modules/dataflow/jobs.tf modules/dataflow/pipelines.tf
git diff modules/dataflow/jobs.tf modules/dataflow/pipelines.tf   # restore the two "Local change" comments
```
