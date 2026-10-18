# The submodules work without YAML. modules/function deploys one function
# (packaging local source with modules/source-archive internally), and
# modules/source-archive can be used on its own, e.g. to upload an archive
# that something else deploys.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.42.0, < 9.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

variable "project_id" {
  description = "Project to deploy to."
  type        = string
}

variable "source_bucket" {
  description = "Existing bucket for source archives."
  type        = string
}

# A function from a local directory, plain HCL.
module "status" {
  source = "../../modules/function"

  name       = "status"
  project_id = var.project_id
  region     = "europe-west1"
  labels     = { app = "status" }

  build_config = {
    runtime     = "python312"
    entry_point = "status"
    source = {
      dir    = "${path.module}/src/status"
      bucket = var.source_bucket
    }
  }

  service_config = {
    available_memory   = "256M"
    max_instance_count = 2
  }

  invokers = ["allUsers"]
}

# Several functions from a map with for_each.
locals {
  topics = {
    "audit-fanout"   = "audit-events"
    "billing-fanout" = "billing-events"
  }
}

module "fanout" {
  source   = "../../modules/function"
  for_each = local.topics

  name       = each.key
  project_id = var.project_id
  region     = "europe-west1"

  build_config = {
    runtime     = "python312"
    entry_point = "status"
    source = {
      object = module.shared_archive.object
      bucket = module.shared_archive.bucket
    }
  }

  event_trigger = {
    pubsub_topic = each.value
    retry_policy = "RETRY_POLICY_RETRY"
  }
}

# One upload shared by the fan-out functions above.
module "shared_archive" {
  source = "../../modules/source-archive"

  name          = "fanout"
  bucket        = var.source_bucket
  source_dir    = "${path.module}/src/status"
  object_prefix = "shared/"
}

output "status_uri" {
  value = module.status.uri
}

output "fanout_functions" {
  value = { for k, m in module.fanout : k => m.id }
}
