# Outputs after an apply with the mocked provider (computed values filled in).

mock_provider "google" {
  mock_resource "google_cloudfunctions2_function" {
    defaults = {
      url            = "https://europe-west1-test-project.cloudfunctions.net/mocked"
      state          = "ACTIVE"
      service_config = { service = "mocked-service", uri = "https://mocked-uc.a.run.app", service_account_email = "runtime@test-project.iam.gserviceaccount.com" }
    }
  }
}

variables {
  project_id  = "test-project"
  region      = "europe-west1"
  config_yaml = <<-EOT
    defaults:
      functions:
        build_config:
          runtime: python312
          source: { bucket: sources }
    functions:
      http:
        build_config:
          source: { dir: tests/fixtures/src/hello }
      events:
        build_config:
          source: { object: events.zip }
        event_trigger: { pubsub_topic: t }
      retired:
        enabled: false
        build_config:
          source: { object: off.zip }
  EOT
}

run "outputs_cover_every_enabled_function" {
  command = apply

  assert {
    condition     = toset(keys(output.functions)) == toset(["http", "events"]) && toset(keys(output.uris)) == toset(["http", "events"])
    error_message = "Outputs should list the enabled functions only."
  }
  assert {
    condition     = output.uris["http"] == "https://mocked-uc.a.run.app" && output.functions["http"].service == "mocked-service"
    error_message = "uri and service should come from the function's service_config."
  }
  assert {
    condition = (
      output.functions["http"].url == "https://europe-west1-test-project.cloudfunctions.net/mocked" &&
      output.functions["http"].state == "ACTIVE" &&
      output.functions["http"].service_account_email == "runtime@test-project.iam.gserviceaccount.com" &&
      output.functions["http"].project_id == "test-project" &&
      output.functions["http"].region == "europe-west1"
    )
    error_message = "Unexpected function output: ${jsonencode(output.functions["http"])}"
  }
  assert {
    condition     = output.functions["events"].source.object == "events.zip" && startswith(output.functions["http"].source.object, "http-")
    error_message = "The source output should name the deployed object."
  }
  assert {
    condition     = output.functions["http"].event_trigger == null
    error_message = "An HTTP function has no event trigger."
  }
  assert {
    condition     = toset(keys(output.ids)) == toset(["http", "events"])
    error_message = "ids should list the enabled functions."
  }
  assert {
    condition     = output.config["retired"].enabled == false && output.config["http"].name == "http"
    error_message = "config should include disabled functions."
  }
}
