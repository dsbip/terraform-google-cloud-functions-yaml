# Every example configuration, planned with a mocked provider. Each run checks
# the behaviour the example's README describes. (tests/python plans the same
# examples with the real provider.)

mock_provider "google" {}

variables {
  project_id = "example-project"
}

run "basic" {
  command = plan

  variables {
    region        = "europe-west1"
    config_file   = "examples/basic/config.yaml"
    template_vars = { source_bucket = "example-src" }
  }

  assert {
    condition     = toset(keys(module.function)) == toset(["hello"]) && module.function["hello"].invoker_members == tolist(["allUsers"])
    error_message = "basic: one public function expected."
  }
  assert {
    condition     = module.function["hello"].source.bucket == "example-src" && startswith(module.function["hello"].source.object, "hello-")
    error_message = "basic: the directory should be uploaded to the bucket."
  }
}

run "http_functions" {
  command = plan

  variables {
    config_file   = "examples/http-functions/config.yaml"
    template_vars = { region = "us-central1", source_bucket = "example-src" }
    labels        = { managed-by = "terraform" }
  }

  assert {
    condition     = toset(keys(module.function)) == toset(["greeter", "orders-api", "pricing", "daily-report"])
    error_message = "http-functions: four functions expected."
  }
  assert {
    condition = alltrue([
      for k, f in module.function : f.function.build_config[0].runtime == { greeter = "python312", orders-api = "nodejs22", pricing = "go123", daily-report = "java21" }[k]
    ])
    error_message = "http-functions: one runtime per function."
  }
  assert {
    condition     = module.function["greeter"].function.service_config[0].environment_variables == tomap({ LOG_LEVEL = "info", GREETING_LANGUAGE = "de" })
    error_message = "http-functions: greeter should merge its variable with the LOG_LEVEL default."
  }
  assert {
    condition     = module.function["orders-api"].function.labels == tomap({ managed-by = "terraform", team = "storefront", cost-center = "cc-1234", tier = "critical" })
    error_message = "http-functions: unexpected orders-api labels ${jsonencode(module.function["orders-api"].function.labels)}"
  }
  assert {
    condition     = module.function["orders-api"].function.service_config[0].secret_environment_variables[0].project_id == "example-project"
    error_message = "http-functions: the secret should default to the function's project."
  }
  assert {
    condition = (
      length(module.function["pricing"].function.build_config[0].on_deploy_update_policy) == 1 &&
      length(module.function["greeter"].function.build_config[0].automatic_update_policy) == 1
    )
    error_message = "http-functions: pricing overrides the AUTOMATIC default with ON_DEPLOY."
  }
  assert {
    condition     = alltrue([for f in values(module.function) : startswith(f.source.object, "http-functions/")])
    error_message = "http-functions: every archive should use the default object prefix."
  }
}

run "event_driven" {
  command = plan

  variables {
    region        = "us-central1"
    config_file   = "examples/event-driven/config.yaml"
    template_vars = { source_bucket = "example-src" }
  }

  assert {
    condition     = length(module.function) == 5 && alltrue([for f in values(module.function) : length(f.function.event_trigger) == 1])
    error_message = "event-driven: five event-driven functions expected."
  }
  assert {
    condition     = module.function["order-events"].function.event_trigger[0].pubsub_topic == "projects/example-project/topics/orders"
    error_message = "event-driven: short topic name not expanded."
  }
  assert {
    condition = (
      module.function["partner-feed"].function.event_trigger[0].retry_policy == "RETRY_POLICY_DO_NOT_RETRY" &&
      module.function["order-events"].function.event_trigger[0].retry_policy == "RETRY_POLICY_RETRY"
    )
    error_message = "event-driven: partner-feed overrides the retry default."
  }
  assert {
    condition     = alltrue([for f in values(module.function) : f.invoker_members == tolist(["serviceAccount:events-trigger@example-project.iam.gserviceaccount.com"])])
    error_message = "event-driven: the trigger service account must be able to invoke every function."
  }
  assert {
    condition     = module.function["audit-watch"].function.event_trigger[0].trigger_region == "global"
    error_message = "event-driven: audit-watch has a global trigger."
  }
}

run "networking_and_security" {
  command = plan

  variables {
    config_file = "examples/networking-and-security/config.yaml"
  }

  assert {
    condition     = alltrue([for f in values(module.function) : f.region == "europe-west3" && f.function.kms_key_name != null])
    error_message = "networking-and-security: every function is CMEK-protected in europe-west3."
  }
  assert {
    condition = (
      module.function["ledger"].function.deletion_policy == "PREVENT" &&
      module.function["internal-proxy"].function.deletion_policy == "DELETE"
    )
    error_message = "networking-and-security: internal-proxy overrides the PREVENT default."
  }
  assert {
    condition = (
      module.function["ledger"].function.service_config[0].vpc_connector_egress_settings == "ALL_TRAFFIC" &&
      module.function["payments-webhook"].function.service_config[0].direct_vpc_egress == "VPC_EGRESS_PRIVATE_RANGES_ONLY" &&
      module.function["internal-proxy"].function.service_config[0].ingress_settings == "ALLOW_INTERNAL_ONLY"
    )
    error_message = "networking-and-security: wrong egress or ingress."
  }
  assert {
    condition     = module.function["ledger"].function.service_config[0].secret_environment_variables[1].project_id == "security-shared"
    error_message = "networking-and-security: cross-project secret expected."
  }
  assert {
    condition     = module.function["internal-proxy"].iam_members == tolist(["roles/cloudfunctions.developer group:migration-team@example.com [until-end-of-migration]"])
    error_message = "networking-and-security: conditional grant expected."
  }
}

run "prebuilt_artifacts" {
  command = plan

  variables {
    config_file = "examples/prebuilt-artifacts/config.yaml"
    template_vars = {
      artifact_bucket     = "example-ci-artifacts"
      release             = "2.4.1"
      fx_rates_generation = 1767225600000000
    }
  }

  assert {
    condition     = module.function["invoice-renderer"].source.object == "releases/invoice-renderer-${filemd5("examples/prebuilt-artifacts/dist/invoice-renderer.zip")}.zip"
    error_message = "prebuilt-artifacts: the zip should be uploaded under its hash."
  }
  assert {
    condition = (
      module.function["tax-calculator"].source.object == "tax-calculator/v2.4.1.zip" &&
      module.function["fx-rates"].function.build_config[0].source[0].storage_source[0].generation == 1767225600000000
    )
    error_message = "prebuilt-artifacts: existing objects expected."
  }
  assert {
    condition = (
      module.function["legacy-export"].function.build_config[0].source[0].repo_source[0].tag_name == "v2.4.1" &&
      module.function["legacy-import"].function.build_config[0].source[0].repo_source[0].project_id == "shared-code"
    )
    error_message = "prebuilt-artifacts: repository sources expected."
  }
  assert {
    condition     = alltrue([for f in values(module.function) : f.function.labels["release"] == "v2.4.1"])
    error_message = "prebuilt-artifacts: release label expected."
  }
}

run "multi_environment_dev" {
  command = plan

  variables {
    config_file   = "examples/multi-environment/config.yaml"
    template_vars = { env = "dev", source_bucket = "dev-src", max_instances = 2, alert_topic = "" }
  }

  assert {
    condition     = toset(keys(module.function)) == toset(["api", "worker", "debug-echo"])
    error_message = "multi-environment: dev deploys api, worker and debug-echo: ${jsonencode(keys(module.function))}"
  }
  assert {
    condition = (
      module.function["api"].invoker_members == tolist(["allUsers"]) &&
      module.function["api"].function.service_config[0].available_memory == "256M" &&
      module.function["api"].function.service_config[0].min_instance_count == null
    )
    error_message = "multi-environment: dev api is public and small."
  }
}

run "multi_environment_prod" {
  command = plan

  variables {
    config_file   = "examples/multi-environment/config.yaml"
    template_vars = { env = "prod", source_bucket = "prod-src", max_instances = 100, alert_topic = "projects/example-ops/topics/alerts" }
  }

  assert {
    condition     = toset(keys(module.function)) == toset(["api", "worker", "alert-forwarder"])
    error_message = "multi-environment: prod deploys api, worker and alert-forwarder: ${jsonencode(keys(module.function))}"
  }
  assert {
    condition = (
      module.function["api"].invoker_members == tolist(["serviceAccount:api-gateway@example-project.iam.gserviceaccount.com"]) &&
      module.function["api"].function.service_config[0].available_memory == "1Gi" &&
      module.function["api"].function.service_config[0].min_instance_count == 1 &&
      module.function["api"].function.service_config[0].ingress_settings == "ALLOW_INTERNAL_AND_GCLB" &&
      module.function["api"].function.service_config[0].max_instance_count == 100
    )
    error_message = "multi-environment: prod api settings are wrong."
  }
  assert {
    condition = (
      module.function["worker"].function.event_trigger[0].retry_policy == "RETRY_POLICY_RETRY" &&
      module.function["worker"].function.event_trigger[0].pubsub_topic == "projects/example-project/topics/jobs-prod" &&
      module.function["alert-forwarder"].function.event_trigger[0].pubsub_topic == "projects/example-ops/topics/alerts"
    )
    error_message = "multi-environment: prod triggers are wrong."
  }
  assert {
    condition     = local.functions["debug-echo"].enabled == false
    error_message = "multi-environment: debug-echo is validated but disabled in prod."
  }
}

run "complete" {
  command = plan

  variables {
    config_file = "examples/complete/config.yaml"
    labels      = { managed-by = "terraform", repo = "shop-infra" }
  }

  assert {
    condition     = toset(keys(module.function)) == toset(["checkout", "inventory-sync", "webhooks", "receipts", "tax-rates", "cleanup", "user-events"])
    error_message = "complete: seven enabled functions expected: ${jsonencode(keys(module.function))}"
  }
  assert {
    condition     = module.function["checkout"].name == "shop-checkout" && module.function["inventory-sync"].region == "us-east1"
    error_message = "complete: name and region overrides."
  }
  assert {
    condition     = module.function["checkout"].function.labels == tomap({ managed-by = "terraform", repo = "shop-infra", app = "shop", owner = "platform", tier = "critical" })
    error_message = "complete: unexpected checkout labels ${jsonencode(module.function["checkout"].function.labels)}"
  }
  assert {
    condition     = module.function["checkout"].function.service_config[0].environment_variables == tomap({ LOG_LEVEL = "info", PROJECT_ID = "example-project", PAYMENT_PROVIDER = "stripe" })
    error_message = "complete: environment variables should be merged."
  }
  assert {
    condition     = module.function["receipts"].function.build_config[0].environment_variables == tomap({ PIP_INDEX_URL = "https://us-python.pkg.dev/example-project/pypi-remote/simple/", NPM_CONFIG_REGISTRY = "https://us-npm.pkg.dev/example-project/npm-remote/" })
    error_message = "complete: build environment variables should be merged."
  }
  assert {
    condition = (
      module.function["webhooks"].function.deletion_policy == "PREVENT" &&
      module.function["webhooks"].function.service_config[0].vpc_connector != null &&
      module.function["inventory-sync"].function.service_config[0].direct_vpc_egress == "VPC_EGRESS_ALL_TRAFFIC"
    )
    error_message = "complete: networking and deletion settings."
  }
  assert {
    condition     = module.function["cleanup"].function.build_config[0].source[0].repo_source[0].commit_sha == "4f1c2a9e0b7d3c5a8e6f1b2d9c0a7e3f5b8d1c4a"
    error_message = "complete: cleanup builds from a commit."
  }
  assert {
    condition     = module.function["tax-rates"].project_id == "shop-shared-services" && module.function["checkout"].function.service_config[0].secret_environment_variables[2].project_id == "shared-secrets"
    error_message = "complete: project overrides."
  }
}
