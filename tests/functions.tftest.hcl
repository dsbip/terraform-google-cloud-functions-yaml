# Function attributes, from YAML through modules/function to the planned
# google_cloudfunctions2_function.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "http_function_with_every_build_and_service_setting" {
  command = plan

  variables {
    config_yaml = <<-EOT
      functions:
        api:
          description: The API.
          labels: { app: api }
          kms_key_name: projects/test-project/locations/europe-west1/keyRings/r/cryptoKeys/k
          deletion_policy: PREVENT
          build_config:
            runtime: nodejs22
            entry_point: handler
            environment_variables: { NPM_CONFIG_PRODUCTION: "true", RETRIES: 3 }
            docker_repository: projects/test-project/locations/europe-west1/repositories/fns
            service_account: projects/test-project/serviceAccounts/builder@test-project.iam.gserviceaccount.com
            worker_pool: projects/test-project/locations/europe-west1/workerPools/pool
            source: { object: api.zip, bucket: sources }
          service_config:
            available_memory: 2Gi
            available_cpu: "2"
            timeout_seconds: 300
            min_instance_count: 1
            max_instance_count: 20
            max_instance_request_concurrency: 80
            environment_variables: { MODE: prod, WORKERS: 4, DEBUG: false }
            ingress_settings: ALLOW_INTERNAL_AND_GCLB
            all_traffic_on_latest_revision: false
            service_account_email: api@test-project.iam.gserviceaccount.com
            binary_authorization_policy: default
    EOT
  }

  assert {
    condition     = module.function["api"].function.name == "api" && module.function["api"].function.location == "europe-west1" && module.function["api"].function.project == "test-project"
    error_message = "Wrong name, location or project."
  }
  assert {
    condition     = module.function["api"].function.description == "The API." && module.function["api"].function.labels == tomap({ app = "api" })
    error_message = "Wrong description or labels."
  }
  assert {
    condition     = module.function["api"].function.kms_key_name == "projects/test-project/locations/europe-west1/keyRings/r/cryptoKeys/k" && module.function["api"].function.deletion_policy == "PREVENT"
    error_message = "Wrong kms_key_name or deletion_policy."
  }
  assert {
    condition = (
      module.function["api"].function.build_config[0].runtime == "nodejs22" &&
      module.function["api"].function.build_config[0].entry_point == "handler" &&
      module.function["api"].function.build_config[0].docker_repository == "projects/test-project/locations/europe-west1/repositories/fns" &&
      module.function["api"].function.build_config[0].service_account == "projects/test-project/serviceAccounts/builder@test-project.iam.gserviceaccount.com" &&
      module.function["api"].function.build_config[0].worker_pool == "projects/test-project/locations/europe-west1/workerPools/pool"
    )
    error_message = "Wrong build_config attributes."
  }
  assert {
    condition     = module.function["api"].function.build_config[0].environment_variables == tomap({ NPM_CONFIG_PRODUCTION = "true", RETRIES = "3" })
    error_message = "Build environment variables should be strings: ${jsonencode(module.function["api"].function.build_config[0].environment_variables)}"
  }
  assert {
    condition = (
      module.function["api"].function.service_config[0].available_memory == "2Gi" &&
      module.function["api"].function.service_config[0].available_cpu == "2" &&
      module.function["api"].function.service_config[0].timeout_seconds == 300 &&
      module.function["api"].function.service_config[0].min_instance_count == 1 &&
      module.function["api"].function.service_config[0].max_instance_count == 20 &&
      module.function["api"].function.service_config[0].max_instance_request_concurrency == 80
    )
    error_message = "Wrong sizing or scaling."
  }
  assert {
    condition     = module.function["api"].function.service_config[0].environment_variables == tomap({ MODE = "prod", WORKERS = "4", DEBUG = "false" })
    error_message = "Runtime environment variables should be strings: ${jsonencode(module.function["api"].function.service_config[0].environment_variables)}"
  }
  assert {
    condition = (
      module.function["api"].function.service_config[0].ingress_settings == "ALLOW_INTERNAL_AND_GCLB" &&
      module.function["api"].function.service_config[0].all_traffic_on_latest_revision == false &&
      module.function["api"].function.service_config[0].service_account_email == "api@test-project.iam.gserviceaccount.com" &&
      module.function["api"].function.service_config[0].binary_authorization_policy == "default"
    )
    error_message = "Wrong ingress, traffic, service account or Binary Authorization."
  }
  assert {
    condition     = length(module.function["api"].function.event_trigger) == 0
    error_message = "A function without event_trigger is an HTTP function."
  }
}

run "minimal_function_leaves_optional_settings_to_the_provider" {
  command = plan

  variables {
    config_yaml = <<-EOT
      functions:
        tiny:
          build_config:
            runtime: python312
            source: { object: tiny.zip, bucket: sources }
    EOT
  }

  assert {
    condition = (
      module.function["tiny"].function.build_config[0].entry_point == null &&
      module.function["tiny"].function.description == null &&
      module.function["tiny"].function.kms_key_name == null &&
      module.function["tiny"].function.service_config[0].min_instance_count == null &&
      module.function["tiny"].function.service_config[0].vpc_connector == null
    )
    error_message = "Unset keys must stay unset."
  }
  assert {
    condition = (
      length(module.function["tiny"].function.build_config[0].automatic_update_policy) == 0 &&
      length(module.function["tiny"].function.build_config[0].on_deploy_update_policy) == 0
    )
    error_message = "Without runtime_update_policy no update policy block should be set."
  }
  assert {
    condition     = length(module.function["tiny"].invoker_members) == 0 && length(module.function["tiny"].iam_members) == 0
    error_message = "No IAM should be granted by default."
  }
}

run "runtime_update_policies" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: sources }
      functions:
        automatic:
          build_config: { runtime_update_policy: AUTOMATIC }
        on-deploy:
          build_config: { runtime_update_policy: ON_DEPLOY }
    EOT
  }

  assert {
    condition = (
      length(module.function["automatic"].function.build_config[0].automatic_update_policy) == 1 &&
      length(module.function["automatic"].function.build_config[0].on_deploy_update_policy) == 0
    )
    error_message = "AUTOMATIC should set automatic_update_policy only."
  }
  assert {
    condition = (
      length(module.function["on-deploy"].function.build_config[0].on_deploy_update_policy) == 1 &&
      length(module.function["on-deploy"].function.build_config[0].automatic_update_policy) == 0
    )
    error_message = "ON_DEPLOY should set on_deploy_update_policy only."
  }
}

run "secrets_default_to_the_function_project_and_latest" {
  command = plan

  variables {
    config_yaml = <<-EOT
      functions:
        secretive:
          project_id: app-project
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: sources }
          service_config:
            secret_environment_variables:
              - { key: API_KEY, secret: api-key }
              - { key: DB_PASSWORD, secret: db-password, version: 7, project_id: vault-project }
            secret_volumes:
              - mount_path: /etc/tls
                secret: tls
              - mount_path: /etc/creds
                secret: creds
                project_id: vault-project
                versions:
                  - { path: current.json, version: latest }
                  - { path: previous.json, version: 2 }
    EOT
  }

  assert {
    condition = module.function["secretive"].function.service_config[0].secret_environment_variables == tolist([
      { key = "API_KEY", secret = "api-key", version = "latest", project_id = "app-project" },
      { key = "DB_PASSWORD", secret = "db-password", version = "7", project_id = "vault-project" },
    ])
    error_message = "Unexpected secret environment variables: ${jsonencode(module.function["secretive"].function.service_config[0].secret_environment_variables)}"
  }
  assert {
    condition = (
      module.function["secretive"].function.service_config[0].secret_volumes[0].project_id == "app-project" &&
      length(module.function["secretive"].function.service_config[0].secret_volumes[0].versions) == 0
    )
    error_message = "A secret volume without versions should use the function project and no explicit versions."
  }
  assert {
    condition = (
      module.function["secretive"].function.service_config[0].secret_volumes[1].project_id == "vault-project" &&
      module.function["secretive"].function.service_config[0].secret_volumes[1].versions == tolist([
        { path = "current.json", version = "latest" },
        { path = "previous.json", version = "2" },
      ])
    )
    error_message = "Unexpected secret volume: ${jsonencode(module.function["secretive"].function.service_config[0].secret_volumes[1])}"
  }
}

run "vpc_connector" {
  command = plan

  variables {
    config_yaml = <<-EOT
      functions:
        private:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: sources }
          service_config:
            vpc_connector: projects/test-project/locations/europe-west1/connectors/c
            vpc_connector_egress_settings: ALL_TRAFFIC
    EOT
  }

  assert {
    condition = (
      module.function["private"].function.service_config[0].vpc_connector == "projects/test-project/locations/europe-west1/connectors/c" &&
      module.function["private"].function.service_config[0].vpc_connector_egress_settings == "ALL_TRAFFIC" &&
      length(module.function["private"].function.service_config[0].direct_vpc_network_interface) == 0
    )
    error_message = "Connector settings were not applied."
  }
}

run "direct_vpc_egress" {
  command = plan

  variables {
    config_yaml = <<-EOT
      functions:
        direct:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: sources }
          service_config:
            direct_vpc_network_interface:
              - network: vpc
                subnetwork: subnet
                tags: [a, b]
              - subnetwork: other-subnet
            direct_vpc_egress: VPC_EGRESS_ALL_TRAFFIC
    EOT
  }

  assert {
    condition = jsonencode(module.function["direct"].function.service_config[0].direct_vpc_network_interface) == jsonencode([
      { network = "vpc", subnetwork = "subnet", tags = ["a", "b"] },
      { network = null, subnetwork = "other-subnet", tags = null },
    ])
    error_message = "Unexpected interfaces: ${jsonencode(module.function["direct"].function.service_config[0].direct_vpc_network_interface)}"
  }
  assert {
    condition     = module.function["direct"].function.service_config[0].direct_vpc_egress == "VPC_EGRESS_ALL_TRAFFIC"
    error_message = "direct_vpc_egress was not applied."
  }
}

run "many_functions_in_several_projects_and_regions" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: sources }
      functions:
        a: {}
        b: { region: us-central1 }
        c: { project_id: other-project }
        same-name-eu: { name: shared }
        same-name-us: { name: shared, region: us-east1 }
    EOT
  }

  assert {
    condition     = length(module.function) == 5
    error_message = "Expected five functions."
  }
  assert {
    condition = (
      module.function["b"].region == "us-central1" &&
      module.function["c"].project_id == "other-project" &&
      module.function["same-name-eu"].name == "shared" &&
      module.function["same-name-us"].name == "shared"
    )
    error_message = "The same name in different regions must be allowed."
  }
}
