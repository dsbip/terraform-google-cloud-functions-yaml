# -----------------------------------------------------------------------------
# One Cloud Run function (Cloud Functions 2nd gen) with its source upload,
# invoker grants and IAM. Usable on its own; the YAML root module calls it once
# per configured function.
# -----------------------------------------------------------------------------

locals {
  source = var.build_config.source
  upload = local.source.dir != null || local.source.zip != null

  storage_source = (
    local.upload ? {
      bucket     = module.source_archive[0].bucket
      object     = module.source_archive[0].object
      generation = null
    } :
    local.source.object != null ? {
      bucket     = local.source.bucket
      object     = local.source.object
      generation = local.source.generation
    } :
    null
  )

  # Short topic names are expanded so that `pubsub_topic: orders` works.
  pubsub_topic = try(
    strcontains(var.event_trigger.pubsub_topic, "/") ? var.event_trigger.pubsub_topic : "projects/${var.project_id}/topics/${var.event_trigger.pubsub_topic}",
    null,
  )

  event_type = try(coalesce(
    var.event_trigger.event_type,
    var.event_trigger.pubsub_topic != null ? "google.cloud.pubsub.topic.v1.messagePublished" : null,
  ), null)

  # One grant per (role, member, condition). Duplicates in the input collapse.
  iam_members = {
    for key, grants in {
      for g in flatten([
        for b in var.iam : [
          for m in b.members : { role = b.role, member = m, condition = b.condition }
        ]
      ]) : "${g.role} ${g.member}${g.condition == null ? "" : " [${g.condition.title}]"}" => g...
    } : key => grants[0]
  }
}

module "source_archive" {
  source = "../source-archive"
  count  = local.upload ? 1 : 0

  name          = var.name
  archive_key   = "${var.project_id}/${var.region}/${var.name}"
  bucket        = local.source.bucket
  source_dir    = local.source.dir
  source_zip    = local.source.zip
  excludes      = local.source.excludes
  object_prefix = local.source.object_prefix
  output_dir    = var.archive_output_dir
}

resource "google_cloudfunctions2_function" "this" {
  name            = var.name
  project         = var.project_id
  location        = var.region
  description     = var.description
  labels          = var.labels
  kms_key_name    = var.kms_key_name
  deletion_policy = var.deletion_policy

  build_config {
    runtime               = var.build_config.runtime
    entry_point           = var.build_config.entry_point
    environment_variables = var.build_config.environment_variables
    docker_repository     = var.build_config.docker_repository
    service_account       = var.build_config.service_account
    worker_pool           = var.build_config.worker_pool

    source {
      dynamic "storage_source" {
        for_each = local.storage_source == null ? [] : [local.storage_source]
        content {
          bucket     = storage_source.value.bucket
          object     = storage_source.value.object
          generation = storage_source.value.generation
        }
      }

      dynamic "repo_source" {
        for_each = local.source.repo == null ? [] : [local.source.repo]
        content {
          project_id   = coalesce(repo_source.value.project_id, var.project_id)
          repo_name    = repo_source.value.repo_name
          branch_name  = repo_source.value.branch_name
          tag_name     = repo_source.value.tag_name
          commit_sha   = repo_source.value.commit_sha
          dir          = repo_source.value.dir
          invert_regex = repo_source.value.invert_regex
        }
      }
    }

    dynamic "automatic_update_policy" {
      for_each = var.build_config.runtime_update_policy == "AUTOMATIC" ? [1] : []
      content {}
    }

    dynamic "on_deploy_update_policy" {
      for_each = var.build_config.runtime_update_policy == "ON_DEPLOY" ? [1] : []
      content {}
    }
  }

  service_config {
    available_memory                 = var.service_config.available_memory
    available_cpu                    = var.service_config.available_cpu
    timeout_seconds                  = var.service_config.timeout_seconds
    min_instance_count               = var.service_config.min_instance_count
    max_instance_count               = var.service_config.max_instance_count
    max_instance_request_concurrency = var.service_config.max_instance_request_concurrency
    environment_variables            = var.service_config.environment_variables
    ingress_settings                 = var.service_config.ingress_settings
    all_traffic_on_latest_revision   = var.service_config.all_traffic_on_latest_revision
    service_account_email            = var.service_config.service_account_email
    vpc_connector                    = var.service_config.vpc_connector
    vpc_connector_egress_settings    = var.service_config.vpc_connector_egress_settings
    direct_vpc_egress                = var.service_config.direct_vpc_egress
    binary_authorization_policy      = var.service_config.binary_authorization_policy

    dynamic "direct_vpc_network_interface" {
      for_each = var.service_config.direct_vpc_network_interface
      content {
        network    = direct_vpc_network_interface.value.network
        subnetwork = direct_vpc_network_interface.value.subnetwork
        tags       = direct_vpc_network_interface.value.tags
      }
    }

    dynamic "secret_environment_variables" {
      for_each = var.service_config.secret_environment_variables
      content {
        key        = secret_environment_variables.value.key
        secret     = secret_environment_variables.value.secret
        version    = secret_environment_variables.value.version
        project_id = coalesce(secret_environment_variables.value.project_id, var.project_id)
      }
    }

    dynamic "secret_volumes" {
      for_each = var.service_config.secret_volumes
      content {
        mount_path = secret_volumes.value.mount_path
        secret     = secret_volumes.value.secret
        project_id = coalesce(secret_volumes.value.project_id, var.project_id)

        dynamic "versions" {
          for_each = secret_volumes.value.versions
          content {
            path    = versions.value.path
            version = versions.value.version
          }
        }
      }
    }
  }

  dynamic "event_trigger" {
    for_each = var.event_trigger == null ? [] : [var.event_trigger]
    content {
      event_type            = local.event_type
      pubsub_topic          = local.pubsub_topic
      trigger_region        = event_trigger.value.trigger_region
      retry_policy          = event_trigger.value.retry_policy
      service_account_email = event_trigger.value.service_account_email

      dynamic "event_filters" {
        for_each = event_trigger.value.event_filters
        content {
          attribute = event_filters.value.attribute
          value     = event_filters.value.value
          operator  = event_filters.value.operator
        }
      }
    }
  }
}

# Calling a 2nd gen function is authorised on its Cloud Run service.
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = toset(var.invokers)

  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.this.service_config[0].service
  role     = "roles/run.invoker"
  member   = each.value
}

resource "google_cloudfunctions2_function_iam_member" "this" {
  for_each = local.iam_members

  project        = var.project_id
  location       = var.region
  cloud_function = google_cloudfunctions2_function.this.name
  role           = each.value.role
  member         = each.value.member

  dynamic "condition" {
    for_each = each.value.condition == null ? [] : [each.value.condition]
    content {
      title       = condition.value.title
      expression  = condition.value.expression
      description = condition.value.description
    }
  }
}
