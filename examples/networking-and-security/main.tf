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
  description = "Project to deploy the functions to (also used for the network, keys and secrets in this example)."
  type        = string
}

# The project comes from the YAML (project_id: ${project_id}), which the module
# renders with the project_id variable.
module "functions" {
  source = "../.."

  project_id  = var.project_id
  config_file = "${path.module}/config.yaml"
}

output "functions" {
  value = module.functions.functions
}
