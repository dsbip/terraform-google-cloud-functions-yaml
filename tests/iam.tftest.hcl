# Invokers (roles/run.invoker on the function's Cloud Run service) and
# function IAM grants.

mock_provider "google" {
  mock_resource "google_cloudfunctions2_function" {
    defaults = {
      service_config = { service = "mocked-run-service", uri = "https://mocked.a.run.app" }
    }
  }
}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "invokers_and_bindings" {
  command = plan

  variables {
    config_yaml = <<-EOT
      functions:
        api:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: sources }
          invokers:
            - allUsers
            - serviceAccount:caller@test-project.iam.gserviceaccount.com
            - allUsers                                   # duplicates collapse
          iam:
            - role: roles/cloudfunctions.viewer
              members: [group:a@example.com, group:b@example.com]
            - role: roles/cloudfunctions.viewer
              members: [group:a@example.com]             # duplicate grant
            - role: roles/cloudfunctions.developer
              members: [user:dev@example.com]
              condition:
                title: temporary
                expression: request.time < timestamp("2030-01-01T00:00:00Z")
    EOT
  }

  assert {
    condition     = module.function["api"].invoker_members == tolist(["allUsers", "serviceAccount:caller@test-project.iam.gserviceaccount.com"])
    error_message = "Unexpected invokers: ${jsonencode(module.function["api"].invoker_members)}"
  }
  assert {
    condition = module.function["api"].iam_members == tolist([
      "roles/cloudfunctions.developer user:dev@example.com [temporary]",
      "roles/cloudfunctions.viewer group:a@example.com",
      "roles/cloudfunctions.viewer group:b@example.com",
    ])
    error_message = "Unexpected IAM grants: ${jsonencode(module.function["api"].iam_members)}"
  }
}

run "invoker_grants_target_the_functions_cloud_run_service" {
  command = apply

  module {
    source = "./modules/function"
  }

  variables {
    name       = "api"
    project_id = "test-project"
    region     = "europe-west1"
    build_config = {
      runtime = "python312"
      source  = { object = "x.zip", bucket = "sources" }
    }
    invokers = ["allUsers"]
    iam = [{
      role      = "roles/cloudfunctions.developer"
      members   = ["user:dev@example.com"]
      condition = { title = "temporary", expression = "request.time < timestamp(\"2030-01-01T00:00:00Z\")", description = "Ends in 2030." }
    }]
  }

  assert {
    condition = (
      google_cloud_run_v2_service_iam_member.invoker["allUsers"].name == "mocked-run-service" &&
      google_cloud_run_v2_service_iam_member.invoker["allUsers"].role == "roles/run.invoker" &&
      google_cloud_run_v2_service_iam_member.invoker["allUsers"].location == "europe-west1" &&
      google_cloud_run_v2_service_iam_member.invoker["allUsers"].project == "test-project"
    )
    error_message = "The invoker grant should be roles/run.invoker on the function's Cloud Run service."
  }
  assert {
    condition = (
      google_cloudfunctions2_function_iam_member.this["roles/cloudfunctions.developer user:dev@example.com [temporary]"].cloud_function == "api" &&
      google_cloudfunctions2_function_iam_member.this["roles/cloudfunctions.developer user:dev@example.com [temporary]"].condition[0].title == "temporary" &&
      google_cloudfunctions2_function_iam_member.this["roles/cloudfunctions.developer user:dev@example.com [temporary]"].condition[0].description == "Ends in 2030."
    )
    error_message = "The conditional grant is wrong."
  }
  assert {
    condition     = output.service == "mocked-run-service" && output.uri == "https://mocked.a.run.app"
    error_message = "The service and uri outputs should come from the function."
  }
}
