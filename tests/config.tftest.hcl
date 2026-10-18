# Loading the configuration: files, inline YAML, templating, precedence of
# projects, regions and labels, the defaults merge, enabled, paths.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "config_file_is_rendered_with_template_vars" {
  command = plan

  variables {
    config_file   = "tests/fixtures/templated.yaml"
    template_vars = { env = "dev", team = "payments" }
  }

  assert {
    condition     = toset(keys(module.function)) == toset(["api-dev"])
    error_message = "Expected only api-dev (literal is disabled in dev): ${jsonencode(keys(module.function))}"
  }
  assert {
    condition     = module.function["api-dev"].function.description == "API for payments in test-project"
    error_message = "template_vars and project_id were not substituted: ${module.function["api-dev"].function.description}"
  }
  assert {
    condition     = module.function["api-dev"].region == "europe-west1"
    error_message = "The region variable should be available to the template."
  }
  assert {
    condition     = module.function["api-dev"].function.labels == tomap({ environment = "dev" })
    error_message = "defaults.labels were not rendered and applied."
  }
  assert {
    condition     = module.function["api-dev"].invoker_members == tolist(["group:payments@example.com"])
    error_message = "Invokers were not rendered."
  }
  assert {
    condition     = module.function["api-dev"].function.service_config[0].min_instance_count == null
    error_message = "The %%{ if } block must not render in dev."
  }
}

run "template_directives_and_enabled_follow_the_variables" {
  command = plan

  variables {
    config_file   = "tests/fixtures/templated.yaml"
    template_vars = { env = "prod", team = "payments" }
  }

  assert {
    condition     = toset(keys(module.function)) == toset(["api-prod", "literal"])
    error_message = "Expected api-prod and literal in prod: ${jsonencode(keys(module.function))}"
  }
  assert {
    condition     = module.function["api-prod"].function.service_config[0].min_instance_count == 2
    error_message = "The %%{ if } block should render in prod."
  }
  assert {
    condition     = module.function["literal"].function.description == "Costs $${price}"
    error_message = "$$${ in the file must produce a literal $${."
  }
}

run "relative_paths_resolve_against_the_config_file" {
  command = plan

  variables {
    config_file   = "tests/fixtures/templated.yaml"
    template_vars = { env = "dev", team = "payments" }
  }

  assert {
    condition     = local.functions["api-dev"].build_config.source.dir == "tests/fixtures/config/src/app"
    error_message = "source.dir should resolve against the directory of config_file: ${local.functions["api-dev"].build_config.source.dir}"
  }
  assert {
    condition     = startswith(module.function["api-dev"].source.object, "api-dev-") && endswith(module.function["api-dev"].source.object, ".zip")
    error_message = "The directory should be uploaded as api-dev-<md5>.zip: ${module.function["api-dev"].source.object}"
  }
}

run "base_path_overrides_the_config_directory" {
  command = plan

  variables {
    base_path   = "tests/fixtures/src"
    config_yaml = <<-EOT
      functions:
        hello:
          build_config:
            runtime: python312
            source: { dir: hello, bucket: b }
    EOT
  }

  assert {
    condition     = local.functions["hello"].build_config.source.dir == "tests/fixtures/src/hello"
    error_message = "base_path was not used: ${local.functions["hello"].build_config.source.dir}"
  }
}

run "config_yaml_paths_resolve_against_the_root_module" {
  command = plan

  variables {
    config_yaml = <<-EOT
      functions:
        hello:
          build_config:
            runtime: python312
            source: { dir: tests/fixtures/src/hello, zip: null, bucket: b }   # null means unset
    EOT
  }

  assert {
    condition     = local.functions["hello"].build_config.source.dir == "./tests/fixtures/src/hello"
    error_message = "With config_yaml, paths should resolve against path.root: ${local.functions["hello"].build_config.source.dir}"
  }
}

run "absolute_paths_are_kept" {
  command = plan

  variables {
    config_file   = "tests/fixtures/full-path.yaml"
    template_vars = { dir = abspath("tests/fixtures/src/hello") }
  }

  assert {
    condition     = local.functions["absolute"].build_config.source.dir == abspath("tests/fixtures/src/hello")
    error_message = "An absolute source.dir must not be prefixed: ${local.functions["absolute"].build_config.source.dir}"
  }
}

run "config_yaml_is_used_verbatim" {
  command = plan

  variables {
    config_yaml = <<-EOT
      functions:
        hello:
          description: "Uses $${literal} placeholders"
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: b }
    EOT
  }

  assert {
    condition     = module.function["hello"].function.description == "Uses $${literal} placeholders"
    error_message = "config_yaml must not be template-rendered."
  }
}

run "yamlencode_output_works_as_config_yaml" {
  command = plan

  variables {
    config_yaml = yamlencode({
      functions = {
        hello = {
          build_config = { runtime = "go123", source = { object = "x.zip", bucket = "b" } }
        }
      }
    })
  }

  assert {
    condition     = module.function["hello"].function.build_config[0].runtime == "go123"
    error_message = "yamlencode() output was not accepted."
  }
}

run "blank_or_comment_only_file_creates_nothing" {
  command = plan

  variables {
    config_file = "tests/fixtures/blank.yaml"
  }

  assert {
    condition     = length(module.function) == 0 && length(local.validation_errors) == 0
    error_message = "A comment-only file should be valid and create nothing."
  }
}

run "project_precedence" {
  command = plan

  variables {
    project_id  = "var-project"
    config_yaml = <<-EOT
      project_id: yaml-project
      defaults:
        functions:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: b }
      functions:
        from-yaml: {}
        own:
          project_id: own-project
    EOT
  }

  assert {
    condition     = module.function["from-yaml"].project_id == "yaml-project"
    error_message = "The top-level project_id should override the variable."
  }
  assert {
    condition     = module.function["own"].project_id == "own-project"
    error_message = "A function's project_id should override the top-level one."
  }
}

run "project_falls_back_to_the_variable" {
  command = plan

  variables {
    project_id  = "var-project"
    config_yaml = <<-EOT
      functions:
        hello:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: b }
    EOT
  }

  assert {
    condition     = module.function["hello"].project_id == "var-project"
    error_message = "Without a YAML project_id, the variable should be used."
  }
}

run "region_precedence" {
  command = plan

  variables {
    region      = "var-region"
    config_yaml = <<-EOT
      defaults:
        region: defaults-region
        functions:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: b }
      functions:
        from-defaults: {}
        own:
          region: own-region
    EOT
  }

  assert {
    condition     = module.function["from-defaults"].region == "defaults-region"
    error_message = "defaults.region should override the variable."
  }
  assert {
    condition     = module.function["own"].region == "own-region"
    error_message = "A function's region should override defaults.region."
  }
}

run "region_from_defaults_functions_and_variable" {
  command = plan

  variables {
    region      = "var-region"
    config_yaml = <<-EOT
      defaults:
        functions:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: b }
      functions:
        from-var: {}
    EOT
  }

  assert {
    condition     = module.function["from-var"].region == "var-region"
    error_message = "Without YAML regions, the variable should be used."
  }
}

run "labels_are_merged_in_order" {
  command = plan

  variables {
    labels      = { managed-by = "terraform", layer = "var" }
    config_yaml = <<-EOT
      defaults:
        labels:
          layer: defaults
          team: core
          version: 3
        functions:
          labels:
            layer: defaults-functions
            tier: standard
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: b }
      functions:
        hello:
          labels:
            tier: critical
            canary: true
    EOT
  }

  assert {
    condition = module.function["hello"].function.labels == tomap({
      managed-by = "terraform"
      layer      = "defaults-functions"
      team       = "core"
      version    = "3"
      tier       = "critical"
      canary     = "true"
    })
    error_message = "Unexpected labels: ${jsonencode(module.function["hello"].function.labels)}"
  }
}

run "defaults_merge_three_levels_deep" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          description: default description
          build_config:
            runtime: python312
            entry_point: main
            environment_variables: { A: "1", B: "1" }
            source:
              bucket: default-bucket
              object_prefix: default/
          service_config:
            available_memory: 256M
            max_instance_count: 5
            environment_variables: { LOG_LEVEL: info, REGION: eu }
            secret_environment_variables:
              - { key: DEFAULT_SECRET, secret: default }
          invokers: [allUsers]
      functions:
        hello:
          build_config:
            entry_point: hello                  # level 2 override
            environment_variables: { B: "2" }   # level 3 merge
            source:
              object: code.zip                  # level 3 merge with bucket
          service_config:
            available_memory: 1Gi
            environment_variables: { LOG_LEVEL: debug }
            secret_environment_variables:       # lists replace
              - { key: OWN_SECRET, secret: own }
          invokers: [group:devs@example.com]    # lists replace
    EOT
  }

  assert {
    condition     = module.function["hello"].function.description == "default description"
    error_message = "Level 1 defaults were not applied."
  }
  assert {
    condition     = module.function["hello"].function.build_config[0].runtime == "python312" && module.function["hello"].function.build_config[0].entry_point == "hello"
    error_message = "Level 2: runtime should come from defaults, entry_point from the function."
  }
  assert {
    condition     = module.function["hello"].function.build_config[0].environment_variables == tomap({ A = "1", B = "2" })
    error_message = "Level 3: build environment variables should be merged: ${jsonencode(module.function["hello"].function.build_config[0].environment_variables)}"
  }
  assert {
    condition     = module.function["hello"].source.bucket == "default-bucket" && module.function["hello"].source.object == "code.zip"
    error_message = "Level 3: source.bucket should be merged with the function's source.object: ${jsonencode(module.function["hello"].source)}"
  }
  assert {
    condition     = module.function["hello"].function.service_config[0].environment_variables == tomap({ LOG_LEVEL = "debug", REGION = "eu" })
    error_message = "Level 3: runtime environment variables should be merged."
  }
  assert {
    condition     = module.function["hello"].function.service_config[0].available_memory == "1Gi" && module.function["hello"].function.service_config[0].max_instance_count == 5
    error_message = "Level 2: service_config keys should be merged."
  }
  assert {
    condition     = [for s in module.function["hello"].function.service_config[0].secret_environment_variables : s.key] == ["OWN_SECRET"]
    error_message = "Lists must replace the default, not be concatenated."
  }
  assert {
    condition     = module.function["hello"].invoker_members == tolist(["group:devs@example.com"])
    error_message = "invokers must replace the default list."
  }
}

run "explicit_nulls_never_override_defaults" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          description: from defaults
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: b }
          service_config:
            max_instance_count: 7
      functions:
        hello:
          description:
          service_config:
            max_instance_count:
    EOT
  }

  assert {
    condition     = module.function["hello"].function.description == "from defaults"
    error_message = "An empty key must not override a level 1 default."
  }
  assert {
    condition     = module.function["hello"].function.service_config[0].max_instance_count == 7
    error_message = "An empty key must not override a level 2 default."
  }
}

run "an_empty_function_entry_uses_only_defaults" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: b }
      functions:
        bare:
    EOT
  }

  assert {
    condition     = module.function["bare"].name == "bare" && module.function["bare"].function.build_config[0].runtime == "python312"
    error_message = "A null entry should become a function made of defaults."
  }
}

run "name_defaults_to_the_key" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: b }
      functions:
        from-key: {}
        renamed:
          name: actual-name
    EOT
  }

  assert {
    condition     = module.function["from-key"].name == "from-key" && module.function["renamed"].name == "actual-name"
    error_message = "The key should be the default name, and name should override it."
  }
}

run "disabled_functions_are_validated_but_not_deployed" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          build_config:
            runtime: python312
            source: { object: x.zip, bucket: b }
      functions:
        active: {}
        inactive:
          enabled: false
        inactive-as-string:
          enabled: "false"
    EOT
  }

  assert {
    condition     = toset(keys(module.function)) == toset(["active"])
    error_message = "Only enabled functions should be deployed: ${jsonencode(keys(module.function))}"
  }
  assert {
    condition     = local.functions["inactive"].enabled == false && local.functions["inactive-as-string"].enabled == false
    error_message = "enabled should accept booleans and the strings templatefile() produces."
  }
}

run "archive_output_dir_defaults_under_dot_terraform" {
  command = plan

  variables {
    config_file = "tests/fixtures/blank.yaml"
  }

  assert {
    condition     = local.archive_output_dir == "./.terraform/cloud-functions-yaml"
    error_message = "Unexpected default archive_output_dir: ${local.archive_output_dir}"
  }
}

run "archive_output_dir_can_be_overridden" {
  command = plan

  variables {
    config_file        = "tests/fixtures/blank.yaml"
    archive_output_dir = "build/archives"
  }

  assert {
    condition     = local.archive_output_dir == "build/archives"
    error_message = "archive_output_dir was not used."
  }
}
