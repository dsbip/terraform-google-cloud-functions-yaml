# Event triggers: Pub/Sub shortcuts, filters, retries, regions, accounts.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "pubsub_short_name_and_implied_event_type" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: sources }
      functions:
        short:
          event_trigger: { pubsub_topic: orders }
        full:
          event_trigger: { pubsub_topic: projects/other/topics/feed }
        other-project:
          project_id: app-project
          event_trigger: { pubsub_topic: jobs }
        explicit-type:
          event_trigger:
            pubsub_topic: orders
            event_type: google.cloud.pubsub.topic.v1.messagePublished
    EOT
  }

  assert {
    condition     = module.function["short"].function.event_trigger[0].pubsub_topic == "projects/test-project/topics/orders"
    error_message = "A short topic name should be expanded in the function's project: ${module.function["short"].function.event_trigger[0].pubsub_topic}"
  }
  assert {
    condition     = module.function["short"].function.event_trigger[0].event_type == "google.cloud.pubsub.topic.v1.messagePublished"
    error_message = "pubsub_topic should imply the Pub/Sub event type."
  }
  assert {
    condition     = module.function["full"].function.event_trigger[0].pubsub_topic == "projects/other/topics/feed"
    error_message = "A full topic name must be kept."
  }
  assert {
    condition     = module.function["other-project"].function.event_trigger[0].pubsub_topic == "projects/app-project/topics/jobs"
    error_message = "Short names should use the function's own project."
  }
  assert {
    condition     = module.function["explicit-type"].function.event_trigger[0].event_type == "google.cloud.pubsub.topic.v1.messagePublished"
    error_message = "An explicit event_type must be kept."
  }
}

run "storage_trigger_with_filters_region_retry_and_account" {
  command = plan

  variables {
    config_yaml = <<-EOT
      functions:
        thumbnails:
          build_config:
            runtime: nodejs22
            source: { object: x.zip, bucket: sources }
          event_trigger:
            event_type: google.cloud.storage.object.v1.finalized
            trigger_region: us
            retry_policy: RETRY_POLICY_RETRY
            service_account_email: trigger@test-project.iam.gserviceaccount.com
            event_filters:
              - { attribute: bucket, value: uploads }
    EOT
  }

  assert {
    condition = (
      module.function["thumbnails"].function.event_trigger[0].event_type == "google.cloud.storage.object.v1.finalized" &&
      module.function["thumbnails"].function.event_trigger[0].trigger_region == "us" &&
      module.function["thumbnails"].function.event_trigger[0].retry_policy == "RETRY_POLICY_RETRY" &&
      module.function["thumbnails"].function.event_trigger[0].service_account_email == "trigger@test-project.iam.gserviceaccount.com"
    )
    error_message = "Wrong event trigger attributes."
  }
  assert {
    condition     = jsonencode(module.function["thumbnails"].function.event_trigger[0].event_filters) == jsonencode([{ attribute = "bucket", operator = null, value = "uploads" }])
    error_message = "Unexpected filters: ${jsonencode(module.function["thumbnails"].function.event_trigger[0].event_filters)}"
  }
}

run "firestore_path_pattern_filter" {
  command = plan

  variables {
    config_yaml = <<-EOT
      functions:
        profile-sync:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: sources }
          event_trigger:
            event_type: google.cloud.firestore.document.v1.written
            event_filters:
              - { attribute: database, value: (default) }
              - { attribute: document, value: "users/{userId}", operator: match-path-pattern }
    EOT
  }

  assert {
    condition = toset([for f in module.function["profile-sync"].function.event_trigger[0].event_filters : "${f.attribute}=${f.value}|${coalesce(f.operator, "-")}"]) == toset([
      "database=(default)|-",
      "document=users/{userId}|match-path-pattern",
    ])
    error_message = "Unexpected filters: ${jsonencode(module.function["profile-sync"].function.event_trigger[0].event_filters)}"
  }
}

run "audit_log_trigger_inherits_defaults" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: sources }
          event_trigger:
            service_account_email: trigger@test-project.iam.gserviceaccount.com
            retry_policy: RETRY_POLICY_RETRY
      functions:
        audit:
          event_trigger:
            event_type: google.cloud.audit.log.v1.written
            trigger_region: global
            retry_policy: RETRY_POLICY_DO_NOT_RETRY
            event_filters:
              - { attribute: serviceName, value: iam.googleapis.com }
              - { attribute: methodName, value: google.iam.admin.v1.CreateServiceAccountKey }
    EOT
  }

  assert {
    condition     = module.function["audit"].function.event_trigger[0].service_account_email == "trigger@test-project.iam.gserviceaccount.com"
    error_message = "The trigger service account should come from defaults."
  }
  assert {
    condition     = module.function["audit"].function.event_trigger[0].retry_policy == "RETRY_POLICY_DO_NOT_RETRY"
    error_message = "The function's retry_policy should override the default."
  }
  assert {
    condition     = length(module.function["audit"].function.event_trigger[0].event_filters) == 2
    error_message = "Both filters should be set."
  }
}

run "a_default_event_trigger_does_not_turn_http_functions_into_event_functions" {
  command = plan

  # Defaults only apply to keys a function sets or inherits: a default
  # event_trigger is inherited by every function, so it would make every
  # function event-driven. This test documents that behaviour.
  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: sources }
      functions:
        http: {}
        events:
          event_trigger: { pubsub_topic: t }
    EOT
  }

  assert {
    condition     = length(module.function["http"].function.event_trigger) == 0 && length(module.function["events"].function.event_trigger) == 1
    error_message = "Only the function with an event_trigger should be event-driven."
  }
}
