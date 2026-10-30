variable "name" {
  description = "Function name: lowercase letters, digits and hyphens, starting with a letter, at most 63 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.name))
    error_message = "The name must start with a lowercase letter, contain only lowercase letters, digits and hyphens, not end with a hyphen, and be at most 63 characters long."
  }
}

variable "project_id" {
  description = "Project the function is created in. Also the default project of Pub/Sub topic short names and Secret Manager references."
  type        = string
}

variable "region" {
  description = "Region of the function, e.g. europe-west1."
  type        = string
}

variable "description" {
  description = "Human-readable description."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels of the function."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "kms_key_name" {
  description = "Cloud KMS key (projects/P/locations/L/keyRings/R/cryptoKeys/K) that encrypts the function's source and image (CMEK)."
  type        = string
  default     = null
}

variable "deletion_policy" {
  description = "Provider-level deletion policy: DELETE (default), PREVENT (terraform destroy fails) or ABANDON (removed from state, left in Google Cloud)."
  type        = string
  default     = null

  validation {
    condition     = var.deletion_policy == null || contains(["DELETE", "PREVENT", "ABANDON"], coalesce(var.deletion_policy, "DELETE"))
    error_message = "The deletion_policy must be DELETE, PREVENT or ABANDON."
  }
}

variable "build_config" {
  description = <<-EOT
    How the function is built. `source` takes exactly one of:
      - dir:    local directory, zipped and uploaded to `bucket` (optionally under object_prefix, minus excludes)
      - zip:    local .zip file, uploaded to `bucket`
      - object: existing object in `bucket` (optionally pinned to a generation)
      - repo:   Cloud Source Repositories reference
    runtime_update_policy is AUTOMATIC or ON_DEPLOY (base image security updates).
  EOT
  type = object({
    runtime               = string
    entry_point           = optional(string)
    environment_variables = optional(map(string))
    docker_repository     = optional(string)
    service_account       = optional(string)
    worker_pool           = optional(string)
    runtime_update_policy = optional(string)
    source = object({
      dir           = optional(string)
      zip           = optional(string)
      excludes      = optional(list(string), [])
      bucket        = optional(string)
      object_prefix = optional(string, "")
      object        = optional(string)
      generation    = optional(number)
      repo = optional(object({
        project_id   = optional(string)
        repo_name    = string
        branch_name  = optional(string)
        tag_name     = optional(string)
        commit_sha   = optional(string)
        dir          = optional(string)
        invert_regex = optional(bool)
      }))
    })
  })

  validation {
    condition     = can(regex("^(nodejs|python|go|java|ruby|php|dotnet)[0-9]+$", var.build_config.runtime))
    error_message = "The build_config.runtime must be a Cloud Functions runtime ID such as python312, nodejs22, go123, java21, ruby33, php83 or dotnet8."
  }

  validation {
    condition = length([
      for s in [var.build_config.source.dir, var.build_config.source.zip, var.build_config.source.object, var.build_config.source.repo] : s if s != null
    ]) == 1
    error_message = "The build_config.source must set exactly one of dir, zip, object and repo."
  }

  validation {
    condition     = var.build_config.source.repo != null || var.build_config.source.bucket != null
    error_message = "The build_config.source.bucket is required with dir, zip and object."
  }

  validation {
    condition     = var.build_config.runtime_update_policy == null || contains(["AUTOMATIC", "ON_DEPLOY"], coalesce(var.build_config.runtime_update_policy, "AUTOMATIC"))
    error_message = "The build_config.runtime_update_policy must be AUTOMATIC or ON_DEPLOY."
  }
}

variable "service_config" {
  description = "Runtime settings of the function (memory, scaling, environment, secrets, networking). Mirrors the provider's service_config block; secret project_id values default to project_id and secret versions to \"latest\"."
  type = object({
    available_memory                 = optional(string)
    available_cpu                    = optional(string)
    timeout_seconds                  = optional(number)
    min_instance_count               = optional(number)
    max_instance_count               = optional(number)
    max_instance_request_concurrency = optional(number)
    environment_variables            = optional(map(string))
    ingress_settings                 = optional(string)
    all_traffic_on_latest_revision   = optional(bool)
    service_account_email            = optional(string)
    vpc_connector                    = optional(string)
    vpc_connector_egress_settings    = optional(string)
    direct_vpc_egress                = optional(string)
    direct_vpc_network_interface = optional(list(object({
      network    = optional(string)
      subnetwork = optional(string)
      tags       = optional(list(string))
    })), [])
    binary_authorization_policy = optional(string)
    secret_environment_variables = optional(list(object({
      key        = string
      secret     = string
      version    = optional(string, "latest")
      project_id = optional(string)
    })), [])
    secret_volumes = optional(list(object({
      mount_path = string
      secret     = string
      project_id = optional(string)
      versions = optional(list(object({
        path    = string
        version = string
      })), [])
    })), [])
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.service_config.ingress_settings == null || contains(["ALLOW_ALL", "ALLOW_INTERNAL_ONLY", "ALLOW_INTERNAL_AND_GCLB"], coalesce(var.service_config.ingress_settings, "ALLOW_ALL"))
    error_message = "The service_config.ingress_settings must be ALLOW_ALL, ALLOW_INTERNAL_ONLY or ALLOW_INTERNAL_AND_GCLB."
  }

  validation {
    condition     = var.service_config.vpc_connector == null || length(var.service_config.direct_vpc_network_interface) == 0
    error_message = "Use either service_config.vpc_connector or service_config.direct_vpc_network_interface, not both."
  }

  validation {
    condition     = try(var.service_config.min_instance_count <= var.service_config.max_instance_count, true)
    error_message = "The service_config.min_instance_count must not exceed max_instance_count."
  }
}

variable "event_trigger" {
  description = <<-EOT
    Makes the function event-driven (Eventarc); null means an HTTP function.
    pubsub_topic may be a short topic name (expanded to projects/<project_id>/topics/<name>);
    event_type defaults to google.cloud.pubsub.topic.v1.messagePublished when pubsub_topic is set.
  EOT
  type = object({
    event_type            = optional(string)
    pubsub_topic          = optional(string)
    trigger_region        = optional(string)
    retry_policy          = optional(string)
    service_account_email = optional(string)
    event_filters = optional(list(object({
      attribute = string
      value     = string
      operator  = optional(string)
    })), [])
  })
  default = null

  validation {
    condition     = var.event_trigger == null || try(var.event_trigger.event_type != null || var.event_trigger.pubsub_topic != null, false)
    error_message = "The event_trigger needs an event_type (or a pubsub_topic, which implies the Pub/Sub event type)."
  }

  validation {
    condition     = try(var.event_trigger.retry_policy == null || contains(["RETRY_POLICY_RETRY", "RETRY_POLICY_DO_NOT_RETRY", "RETRY_POLICY_UNSPECIFIED"], var.event_trigger.retry_policy), true)
    error_message = "The event_trigger.retry_policy must be RETRY_POLICY_RETRY, RETRY_POLICY_DO_NOT_RETRY or RETRY_POLICY_UNSPECIFIED."
  }
}

variable "invokers" {
  description = "Members granted roles/run.invoker on the function's Cloud Run service, i.e. allowed to call it. Use allUsers for a public HTTP function; event-driven functions need their trigger service account here."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "iam" {
  description = "Additional IAM grants on the function (google_cloudfunctions2_function_iam_member, non-authoritative)."
  type = list(object({
    role    = string
    members = list(string)
    condition = optional(object({
      title       = string
      expression  = string
      description = optional(string)
    }))
  }))
  default  = []
  nullable = false
}

variable "archive_output_dir" {
  description = "Local directory for zipped source directories. Defaults to .terraform/cloud-functions-yaml in the root module."
  type        = string
  default     = null
}
