variable "name" {
  description = "Base name of the archive and of the uploaded object, usually the function name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.name))
    error_message = "The name must start with a letter or digit and contain only letters, digits, '.', '_' and '-'."
  }
}

variable "bucket" {
  description = "Existing Cloud Storage bucket the archive is uploaded to (name only, without gs://)."
  type        = string

  validation {
    condition     = !startswith(var.bucket, "gs://") && length(var.bucket) > 0
    error_message = "The bucket must be a bucket name without the gs:// prefix."
  }
}

variable "source_dir" {
  description = "Local directory to zip. Exactly one of source_dir and source_zip must be set."
  type        = string
  default     = null
}

variable "source_zip" {
  description = "Local .zip file to upload as-is. Exactly one of source_dir and source_zip must be set."
  type        = string
  default     = null

  validation {
    condition     = var.source_zip == null || try(fileexists(var.source_zip), false)
    error_message = "The source_zip file does not exist."
  }
}

variable "excludes" {
  description = "Glob patterns, relative to source_dir, of files to leave out of the archive."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "object_prefix" {
  description = "Prefix for the object name, e.g. \"functions/\"."
  type        = string
  default     = ""
  nullable    = false
}

variable "file_mode" {
  description = "Mode of every file in an archive built from source_dir, so the archive hash does not depend on local permissions or umask."
  type        = string
  default     = "0644"
  nullable    = false

  validation {
    condition     = can(regex("^0?[0-7]{3}$", var.file_mode))
    error_message = "The file_mode must be an octal mode such as 0644."
  }
}

variable "archive_key" {
  description = "Identifies the archive among all archives written to output_dir (default: name). modules/function passes project/region/name, so equally named functions in different regions or projects never share a local file."
  type        = string
  default     = null
}

variable "output_dir" {
  description = "Local directory the zip is written to. Defaults to .terraform/cloud-functions-yaml in the root module."
  type        = string
  default     = null
}
