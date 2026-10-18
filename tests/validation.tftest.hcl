# Validation: each run plants several mistakes and compares the complete set
# of messages, so a missing message and a spurious extra one both fail.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "unknown_keys_at_every_level_with_suggestions" {
  command = plan

  variables {
    config_yaml = <<-EOT
      projectid: x
      defaults:
        regions: eu
        functions:
          build_config:
            runtme: python312
      functions:
        api:
          descripton: typo
          build_config:
            runtime: python312
            entrypoint: main
            source:
              bucket: b
              object: x.zip
              objct_prefix: p/
              repo_url: nope
          service_config:
            memory: 256M
            secret_environment_variables:
              - { key: K, secret: s, verison: latest }
            secret_volumes:
              - mount_path: /s
                secret: s
                versions:
                  - { path: p, version: "1", mode: 0444 }
            direct_vpc_network_interface:
              - { network: n, subnet: s }
          event_trigger:
            topic: orders
            pubsub_topic: orders
            event_filters:
              - { attribute: bucket, value: b, op: eq }
          iam:
            - role: roles/viewer
              members: [user:a@example.com]
              conditon: {}
            - role: roles/viewer
              members: [user:a@example.com]
              condition: { title: t, expression: "true", desc: d }
        repo-fn:
          build_config:
            runtime: python312
            source:
              repo: { repo_name: r, tag_name: v1, branch: main }
    EOT
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition = toset(local.validation_errors) == toset([
      "(root): unknown key \"projectid\" (did you mean project_id?)",
      "defaults: unknown key \"regions\" (did you mean region?)",
      "defaults.functions.build_config: unknown key \"runtme\" (did you mean runtime or runtime_update_policy?)",
      "functions.api: unknown key \"descripton\" (did you mean description?)",
      "functions.api.build_config: unknown key \"entrypoint\" (did you mean entry_point?)",
      "functions.api.build_config.source: unknown key \"objct_prefix\" (did you mean object or object_prefix?)",
      "functions.api.build_config.source: unknown key \"repo_url\" (did you mean repo?)",
      "functions.api.service_config: unknown key \"memory\" (did you mean available_memory?)",
      "functions.api.service_config.secret_environment_variables[0]: unknown key \"verison\" (did you mean version?)",
      "functions.api.service_config.secret_volumes[0].versions[0]: unknown key \"mode\"",
      "functions.api.service_config.direct_vpc_network_interface[0]: unknown key \"subnet\" (did you mean subnetwork?)",
      "functions.api.event_trigger: unknown key \"topic\" (did you mean pubsub_topic?)",
      "functions.api.event_trigger.event_filters[0]: unknown key \"op\"",
      "functions.api.iam[0]: unknown key \"conditon\" (did you mean condition?)",
      "functions.api.iam[1].condition: unknown key \"desc\" (did you mean description?)",
      "functions.repo-fn.build_config.source.repo: unknown key \"branch\" (did you mean branch_name?)",
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
  assert {
    condition     = length(module.function) == 0
    error_message = "Nothing may be planned while the configuration is invalid."
  }
}

run "types_enums_ranges_patterns_and_required_keys" {
  command = plan

  variables {
    config_yaml = <<-EOT
      project_id: [not, a, string]
      defaults:
        labels: { team: [a] }
        functions:
          invokers: allUsers
      functions:
        api:
          enabled: maybe
          labels: [a]
          deletion_policy: KEEP
          build_config:
            runtime: python
            environment_variables: { A: { nested: true } }
            runtime_update_policy: weekly
            source:
              bucket: b
              object: x.zip
              generation: latest
              excludes: "*.md"
          service_config:
            timeout_seconds: 0
            min_instance_count: -1
            max_instance_count: 1.5
            max_instance_request_concurrency: 1001
            ingress_settings: ALL
            all_traffic_on_latest_revision: sometimes
            secret_environment_variables:
              - { key: K }
              - just-a-string
            secret_volumes:
              - { secret: s, versions: [{ path: p }] }
          event_trigger:
            pubsub_topic: t
            retry_policy: ALWAYS
            event_filters:
              - { value: b, operator: equals }
          invokers: [bob@example.com, "user:ok@example.com", 42]
          iam:
            - members: []
            - role: roles/viewer
              members: [group:a@example.com]
              condition: { description: missing title and expression }
        not-a-mapping: just a string
    EOT
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition = toset(local.validation_errors) == toset([
      "project_id: must be a string",
      "defaults.labels.team: must be a string",
      "defaults.functions.invokers: must be a list",
      "functions.not-a-mapping: must be a mapping",
      "functions.api.enabled: must be true or false",
      "functions.api.labels: must be a mapping",
      "functions.api.deletion_policy: must be one of DELETE, PREVENT, ABANDON (got \"KEEP\")",
      "functions.api.build_config.runtime: \"python\" is not valid (Runtime ID, e.g. python312, nodejs22, go123, java21, ruby33, php83, dotnet8)",
      "functions.api.build_config.environment_variables.A: must be a string",
      "functions.api.build_config.runtime_update_policy: must be one of AUTOMATIC, ON_DEPLOY (got \"weekly\")",
      "functions.api.build_config.source.generation: must be a whole number",
      "functions.api.build_config.source.excludes: must be a list",
      "functions.api.service_config.timeout_seconds: must be at least 1",
      "functions.api.service_config.min_instance_count: must be at least 0",
      "functions.api.service_config.max_instance_count: must be a whole number",
      "functions.api.service_config.max_instance_request_concurrency: must be at most 1000",
      "functions.api.service_config.ingress_settings: must be one of ALLOW_ALL, ALLOW_INTERNAL_ONLY, ALLOW_INTERNAL_AND_GCLB (got \"ALL\")",
      "functions.api.service_config.all_traffic_on_latest_revision: must be true or false",
      "functions.api.service_config.secret_environment_variables[0]: missing required key \"secret\"",
      "functions.api.service_config.secret_environment_variables[1]: must be a mapping",
      "functions.api.service_config.secret_volumes[0]: missing required key \"mount_path\"",
      "functions.api.service_config.secret_volumes[0].versions[0]: missing required key \"version\"",
      "functions.api.event_trigger.retry_policy: must be one of RETRY_POLICY_RETRY, RETRY_POLICY_DO_NOT_RETRY, RETRY_POLICY_UNSPECIFIED (got \"ALWAYS\")",
      "functions.api.event_trigger.event_filters[0]: missing required key \"attribute\"",
      "functions.api.event_trigger.event_filters[0].operator: must be one of match-path-pattern (got \"equals\")",
      "functions.api.invokers[0]: \"bob@example.com\" is not valid (IAM member: user:, group:, serviceAccount:, domain:, principal://, principalSet://, allUsers or allAuthenticatedUsers)",
      "functions.api.invokers[2]: \"42\" is not valid (IAM member: user:, group:, serviceAccount:, domain:, principal://, principalSet://, allUsers or allAuthenticatedUsers)",
      "functions.api.iam[0]: missing required key \"role\"",
      "functions.api.iam[0].members: must have at least 1 item(s)",
      "functions.api.iam[1].condition: missing required key \"title\"",
      "functions.api.iam[1].condition: missing required key \"expression\"",
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "rules_beyond_the_schema" {
  command = plan

  variables {
    project_id  = null
    region      = null
    config_yaml = <<-EOT
      defaults:
        functions:
          name: shared
          build_config:
            runtime: python312
      functions:
        Bad_Key: {}
        no-build:
          build_config: null
          region: r
          project_id: p
        two-sources:
          region: r
          project_id: p
          build_config:
            source: { dir: tests/fixtures/src/hello, object: x.zip }
        no-source:
          region: r
          project_id: p
          build_config:
            source: {}
        gs-bucket:
          region: r
          project_id: p
          build_config:
            source: { object: x.zip, bucket: gs://b }
        missing-dir:
          region: r
          project_id: p
          build_config:
            source: { dir: does/not/exist, bucket: b }
        missing-zip:
          region: r
          project_id: p
          build_config:
            source: { zip: nope.zip, bucket: b }
        repo-refs:
          region: r
          project_id: p
          build_config:
            source:
              repo: { repo_name: r, tag_name: v1, branch_name: main }
        no-ref:
          region: r
          project_id: p
          build_config:
            source:
              repo: { repo_name: r }
        trigger:
          region: r
          project_id: p
          build_config:
            source: { object: x.zip, bucket: b }
          event_trigger:
            retry_policy: RETRY_POLICY_RETRY
          service_config:
            min_instance_count: 5
            max_instance_count: 2
            vpc_connector: c
            direct_vpc_network_interface: [{ subnetwork: s }]
        egress:
          region: r
          project_id: p
          build_config:
            source: { object: x.zip, bucket: b }
          service_config:
            vpc_connector_egress_settings: ALL_TRAFFIC
            direct_vpc_egress: VPC_EGRESS_ALL_TRAFFIC
        dup-a:
          name: same
          region: r
          project_id: p
          build_config:
            source: { object: x.zip, bucket: b }
        dup-b:
          name: same
          region: r
          project_id: p
          build_config:
            source: { object: x.zip, bucket: b }
        dup-disabled:
          name: same
          enabled: false
          region: r
          project_id: p
          build_config:
            source: { object: x.zip, bucket: b }
    EOT
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition = toset(local.validation_errors) == toset([
      "defaults.functions: \"name\" cannot be a default",
      "functions.Bad_Key: no project_id; set it on the function, at the top level of the file, or in the module's project_id variable",
      "functions.Bad_Key: no region; set it on the function, in defaults.region, or in the module's region variable",
      "functions.Bad_Key: the key is used as the function name but is not a valid one (lowercase letters, digits and hyphens, starting with a letter, at most 63 characters); rename it or set name",
      "functions.Bad_Key.build_config: source is required, here or in defaults.functions",
      "functions.no-build.build_config: source is required, here or in defaults.functions",
      "functions.two-sources.build_config.source: set exactly one of dir, zip, object and repo (found dir, object)",
      "functions.two-sources.build_config.source: bucket is required with dir and object",
      "functions.no-source.build_config.source: set exactly one of dir, zip, object and repo",
      "functions.gs-bucket.build_config.source.bucket: use the bucket name without gs://",
      "functions.missing-dir.build_config.source.dir: \"does/not/exist\" is not a directory with files (resolved to ./does/not/exist)",
      "functions.missing-zip.build_config.source.zip: file \"nope.zip\" does not exist (resolved to ./nope.zip)",
      "functions.repo-refs.build_config.source.repo: set exactly one of branch_name, tag_name and commit_sha",
      "functions.no-ref.build_config.source.repo: set exactly one of branch_name, tag_name and commit_sha",
      "functions.trigger.event_trigger: set event_type (or pubsub_topic, which implies the Pub/Sub event type)",
      "functions.trigger.service_config: min_instance_count (5) is greater than max_instance_count (2)",
      "functions.trigger.service_config: use vpc_connector or direct_vpc_network_interface, not both",
      "functions.egress.service_config: vpc_connector_egress_settings needs vpc_connector",
      "functions.egress.service_config: direct_vpc_egress needs direct_vpc_network_interface",
      "functions: dup-a, dup-b would all create function p/r/same",
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "boolean_looking_keys_are_reported" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: b }
      functions:
        on: {}
        "off": {}
    EOT
  }

  expect_failures = [terraform_data.validation]

  # `on` became "true"; the quoted "off" stays a string and is fine.
  assert {
    condition = toset(local.validation_errors) == toset([
      "functions.true: YAML reads unquoted yes, no, on, off, true and false as booleans; quote the key (e.g. \"on\":) or choose another name",
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "build_config_from_nowhere" {
  command = plan

  variables {
    config_yaml = <<-EOT
      functions:
        nothing: {}
        no-runtime:
          build_config:
            source: { object: x.zip, bucket: b }
    EOT
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition = toset(local.validation_errors) == toset([
      "functions.nothing: build_config (with runtime and source) is required, here or in defaults.functions",
      "functions.no-runtime.build_config: runtime is required, here or in defaults.functions",
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "the_document_and_its_sections_must_be_mappings" {
  command = plan

  variables {
    config_yaml = <<-EOT
      - functions
      - are
      - not
      - a list
    EOT
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition     = local.validation_errors == tolist(["(root): the configuration must be a mapping (key: value pairs)"])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "sections_with_the_wrong_type" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults: [region]
      functions: [hello]
    EOT
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition = toset(local.validation_errors) == toset([
      "defaults: must be a mapping",
      "functions: must be a mapping",
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "config_file_and_config_yaml_are_exclusive" {
  command = plan

  variables {
    config_file = "tests/fixtures/blank.yaml"
    config_yaml = "functions: {}"
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition     = local.validation_errors == tolist(["(module): set config_file or config_yaml, not both"])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "one_of_config_file_and_config_yaml_is_required" {
  command = plan

  expect_failures = [terraform_data.validation]

  assert {
    condition     = local.validation_errors == tolist(["(module): set config_file or config_yaml"])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "config_file_must_exist" {
  command = plan

  variables {
    config_file = "tests/fixtures/missing.yaml"
  }

  expect_failures = [var.config_file]
}

run "a_valid_file_has_no_messages" {
  command = plan

  variables {
    config_file   = "tests/fixtures/templated.yaml"
    template_vars = { env = "prod", team = "core" }
  }

  assert {
    condition     = length(local.validation_errors) == 0 && local.config_valid
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}
