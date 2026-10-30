# modules/source-archive

Packages function source code and uploads it to Cloud Storage under a content hash: `<object_prefix><name>-<md5>.zip`.

- `source_dir`: the directory is zipped with `archive_file`. File timestamps never enter the archive and file modes are fixed (`file_mode`, default `0644`), so the hash is the same on every machine and checkout.
- `source_zip`: the file is uploaded as-is.

Changed code produces a new object name, which makes anything deployed from it update; unchanged code plans no changes.

```hcl
module "archive" {
  source = "github.com/dsbip/terraform-google-cloud-functions-yaml//modules/source-archive?ref=v1.0.0"

  name          = "shared-handlers"
  bucket        = "my-function-sources"
  source_dir    = "${path.module}/src/handlers"
  excludes      = ["tests/**", "**/__pycache__/**"]
  object_prefix = "shared/"
}

# module.archive.bucket / module.archive.object can feed any number of
# functions (build_config.source = { bucket = ..., object = ... }).
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | Base name of the archive and the object. |
| `bucket` | `string` | | Existing bucket, without `gs://`. |
| `source_dir` | `string` | `null` | Directory to zip. Exactly one of `source_dir` and `source_zip`. |
| `source_zip` | `string` | `null` | Zip to upload as-is. |
| `excludes` | `list(string)` | `[]` | Glob patterns (relative to `source_dir`) to leave out. |
| `object_prefix` | `string` | `""` | Prefix of the object name. |
| `file_mode` | `string` | `"0644"` | Mode of every file in an archive built from `source_dir`. |
| `archive_key` | `string` | `null` | Keeps local archive files of equally named archives apart (default: `name`). |
| `output_dir` | `string` | `null` | Local directory for the zip (default `.terraform/cloud-functions-yaml` in the root module). |

## Outputs

| Name | Description |
|---|---|
| `bucket` | Bucket of the uploaded object. |
| `object` | Object name. |
| `md5` | MD5 (hex) of the archive. |
| `local_path` | Local path of the archive. |
