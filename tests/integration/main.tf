# Live-test fixture (see docs/testing.md). Creates a source bucket and a topic,
# then deploys two functions through the module.

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
  description = "Project to test in."
  type        = string
}

variable "region" {
  description = "Region to test in."
  type        = string
  default     = "europe-west1"
}

variable "suffix" {
  description = "Random suffix that keeps names of concurrent runs apart."
  type        = string
}

variable "revision" {
  description = "Changes descriptions and an environment variable (in-place update test)."
  type        = number
  default     = 1
}

variable "test_member" {
  description = "Optional IAM member granted invoker and viewer roles, e.g. user:me@example.com."
  type        = string
  default     = ""
}

resource "google_storage_bucket" "sources" {
  name                        = "cfyaml-${var.suffix}-${var.project_id}-src"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  labels                      = { purpose = "terraform-module-test" }
}

resource "google_pubsub_topic" "events" {
  name   = "cfyaml-${var.suffix}-events"
  labels = { purpose = "terraform-module-test" }
}

module "functions" {
  source = "../.."

  project_id  = var.project_id
  region      = var.region
  config_file = "${path.module}/functions.yaml"
  template_vars = {
    suffix      = var.suffix
    revision    = var.revision
    bucket      = google_storage_bucket.sources.name
    topic       = google_pubsub_topic.events.name
    test_member = var.test_member
  }
}

output "functions" {
  value = module.functions.functions
}
