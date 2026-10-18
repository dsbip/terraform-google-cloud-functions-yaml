terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.42.0, < 9.0.0"
    }
  }
}

provider "google" {}

variable "environments" {
  description = "Environments to deploy, each with its own project and settings."
  type = map(object({
    project_id    = string
    source_bucket = string
    max_instances = number
    alert_topic   = optional(string, "")
  }))
  default = {
    dev = {
      project_id    = "example-dev"
      source_bucket = "example-dev-fn-sources"
      max_instances = 2
    }
    staging = {
      project_id    = "example-staging"
      source_bucket = "example-staging-fn-sources"
      max_instances = 5
    }
    prod = {
      project_id    = "example-prod"
      source_bucket = "example-prod-fn-sources"
      max_instances = 100
      alert_topic   = "projects/example-ops/topics/alerts"
    }
  }
}

module "functions" {
  source   = "../.."
  for_each = var.environments

  project_id  = each.value.project_id
  config_file = "${path.module}/config.yaml"
  template_vars = {
    env           = each.key
    source_bucket = each.value.source_bucket
    max_instances = each.value.max_instances
    alert_topic   = each.value.alert_topic
  }
}

output "uris" {
  value = { for env, m in module.functions : env => m.uris }
}
