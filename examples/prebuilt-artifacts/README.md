# Prebuilt artifacts example

Deploys code that CI built, in the three ways the module supports besides a local directory:

| Function | Source | Behaviour |
|---|---|---|
| `invoice-renderer` | `zip: dist/invoice-renderer.zip` | uploaded as `releases/invoice-renderer-<md5>.zip`; a new archive redeploys |
| `tax-calculator` | `object: tax-calculator/v2.4.1.zip` | existing object, latest generation |
| `fx-rates` | `object` + `generation` | existing object, pinned generation |
| `legacy-export` | `repo` with `tag_name` | Cloud Source Repositories tag in the function's project |
| `legacy-import` | `repo` with `branch_name` | branch of a repository in another project |

`release` is a template variable used in object names, tags and a label, so a release is promoted by changing one value:

```bash
terraform apply -var project_id=my-project -var release=2.5.0 -var fx_rates_generation=1767312000000000
```
