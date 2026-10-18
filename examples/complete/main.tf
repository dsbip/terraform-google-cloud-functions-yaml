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

module "functions" {
  source = "../.."

  project_id  = var.project_id
  config_file = "${path.module}/config.yaml"
  labels = {
    managed-by = "terraform"
    repo       = "shop-infra"
  }
}

output "functions" {
  value = module.functions.functions
}

output "uris" {
  value = module.functions.uris
}
