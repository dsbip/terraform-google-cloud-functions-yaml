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
  description = "Project to deploy the functions to."
  type        = string
}

variable "artifact_bucket" {
  description = "Bucket that CI uploads function archives to."
  type        = string
  default     = "example-ci-artifacts"
}

variable "release" {
  description = "Release to deploy, e.g. 2.4.1."
  type        = string
  default     = "2.4.1"
}

variable "fx_rates_generation" {
  description = "Object generation of the fx-rates archive to deploy."
  type        = number
  default     = 1767225600000000
}

module "functions" {
  source = "../.."

  project_id  = var.project_id
  config_file = "${path.module}/config.yaml"
  template_vars = {
    artifact_bucket     = var.artifact_bucket
    release             = var.release
    fx_rates_generation = var.fx_rates_generation
  }
}

output "sources" {
  value = { for k, f in module.functions.functions : k => f.source }
}
