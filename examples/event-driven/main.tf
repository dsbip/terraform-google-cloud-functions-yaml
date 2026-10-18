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

variable "region" {
  description = "Region of the functions."
  type        = string
  default     = "us-central1"
}

variable "source_bucket" {
  description = "Existing bucket that function source archives are uploaded to."
  type        = string
}

module "functions" {
  source = "../.."

  project_id  = var.project_id
  region      = var.region
  config_file = "${path.module}/config.yaml"
  template_vars = {
    source_bucket = var.source_bucket
  }
}

output "functions" {
  value = module.functions.functions
}
