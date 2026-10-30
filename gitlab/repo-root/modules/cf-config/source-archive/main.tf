# -----------------------------------------------------------------------------
# Packages function source code and uploads it to Cloud Storage.
#
# A local directory is zipped with archive_file; a local .zip is used as-is.
# The object name contains the archive's MD5 hash, so changed code produces a
# new object, which in turn makes the function rebuild. Unchanged code keeps
# the same object name and nothing is redeployed.
# -----------------------------------------------------------------------------

locals {
  output_dir = coalesce(var.output_dir, "${path.root}/.terraform/cloud-functions-yaml")

  # Distinct per archive key (e.g. project/region/name), directory and
  # exclusions, so two archives are never written to the same local path, not
  # even concurrently during one plan.
  archive_id = substr(sha1(jsonencode([coalesce(var.archive_key, var.name), var.source_dir, sort(var.excludes)])), 0, 10)

  zip_path = var.source_dir != null ? data.archive_file.this[0].output_path : var.source_zip
  zip_md5  = var.source_dir != null ? data.archive_file.this[0].output_md5 : try(filemd5(var.source_zip), null)
}

data "archive_file" "this" {
  count = var.source_dir != null ? 1 : 0

  type        = "zip"
  source_dir  = var.source_dir
  excludes    = var.excludes
  output_path = "${local.output_dir}/${var.name}-${local.archive_id}.zip"

  # File timestamps never enter the archive; fixing the mode as well makes the
  # hash (and so the object name) identical on every machine and checkout.
  output_file_mode = var.file_mode
}

resource "google_storage_bucket_object" "this" {
  bucket       = var.bucket
  name         = "${var.object_prefix}${var.name}-${local.zip_md5}.zip"
  source       = local.zip_path
  content_type = "application/zip"

  lifecycle {
    precondition {
      condition     = (var.source_dir == null) != (var.source_zip == null)
      error_message = "Set exactly one of source_dir and source_zip."
    }
  }
}
