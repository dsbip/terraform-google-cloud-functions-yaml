# Source code: local directories and zips (uploaded by modules/source-archive),
# existing objects and Cloud Source Repositories.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "directory_is_zipped_and_uploaded_under_its_hash" {
  command = plan

  variables {
    config_yaml = <<-EOT
      functions:
        hello:
          build_config:
            runtime: python312
            source:
              dir: tests/fixtures/src/hello
              bucket: sources
              object_prefix: fns/
    EOT
  }

  assert {
    condition     = can(regex("^fns/hello-[0-9a-f]{32}\\.zip$", module.function["hello"].source.object))
    error_message = "Expected fns/hello-<md5>.zip, got ${module.function["hello"].source.object}"
  }
  assert {
    condition     = module.function["hello"].function.build_config[0].source[0].storage_source[0].bucket == "sources"
    error_message = "The function should be built from the uploaded object's bucket."
  }
  assert {
    condition     = module.function["hello"].function.build_config[0].source[0].storage_source[0].object == module.function["hello"].source.object
    error_message = "The function should be built from the uploaded object."
  }
  assert {
    condition     = length(module.function["hello"].function.build_config[0].source[0].repo_source) == 0
    error_message = "No repo_source expected."
  }
}

run "same_code_gives_the_same_hash_and_excludes_change_it" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          build_config:
            runtime: python312
            source: { bucket: sources }
      functions:
        first:
          build_config:
            source: { dir: tests/fixtures/src/hello }
        second:
          build_config:
            source: { dir: tests/fixtures/src/hello }
        with-tests:
          build_config:
            source: { dir: tests/fixtures/src/with-tests }
        without-tests:
          build_config:
            source:
              dir: tests/fixtures/src/with-tests
              excludes: [tests/**]
    EOT
  }

  assert {
    condition     = trimprefix(module.function["first"].source.object, "first-") == trimprefix(module.function["second"].source.object, "second-")
    error_message = "The same directory must produce the same hash: ${module.function["first"].source.object} vs ${module.function["second"].source.object}"
  }
  assert {
    condition     = trimprefix(module.function["with-tests"].source.object, "with-tests-") != trimprefix(module.function["without-tests"].source.object, "without-tests-")
    error_message = "excludes should change the archive and so its hash."
  }
}

run "local_zip_is_uploaded_under_its_hash" {
  command = plan

  variables {
    config_yaml = <<-EOT
      functions:
        zipped:
          build_config:
            runtime: nodejs22
            source:
              zip: tests/fixtures/dist/fn.zip
              bucket: sources
    EOT
  }

  assert {
    condition     = module.function["zipped"].source.object == "zipped-${filemd5("tests/fixtures/dist/fn.zip")}.zip"
    error_message = "Expected zipped-<md5 of the file>.zip, got ${module.function["zipped"].source.object}"
  }
}

run "existing_object_with_and_without_generation" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          build_config:
            runtime: python312
            source: { bucket: artifacts }
      functions:
        latest:
          build_config:
            source: { object: releases/latest.zip }
        pinned:
          build_config:
            source: { object: releases/pinned.zip, generation: 1767225600000000 }
    EOT
  }

  assert {
    condition = (
      module.function["latest"].function.build_config[0].source[0].storage_source[0].bucket == "artifacts" &&
      module.function["latest"].function.build_config[0].source[0].storage_source[0].object == "releases/latest.zip"
    )
    error_message = "The existing object should be used as-is."
  }
  assert {
    condition     = module.function["pinned"].function.build_config[0].source[0].storage_source[0].generation == 1767225600000000
    error_message = "The generation should be pinned."
  }
}

run "repository_source_defaults_to_the_function_project" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        functions:
          build_config:
            runtime: python312
      functions:
        from-tag:
          build_config:
            source:
              repo: { repo_name: app, tag_name: v1.2.3, dir: fn }
        from-branch:
          build_config:
            source:
              repo: { project_id: shared, repo_name: lib, branch_name: ^main$, invert_regex: true }
        from-commit:
          build_config:
            source:
              repo: { repo_name: app, commit_sha: 0123456789abcdef0123456789abcdef01234567 }
    EOT
  }

  assert {
    condition = (
      module.function["from-tag"].function.build_config[0].source[0].repo_source[0].project_id == "test-project" &&
      module.function["from-tag"].function.build_config[0].source[0].repo_source[0].repo_name == "app" &&
      module.function["from-tag"].function.build_config[0].source[0].repo_source[0].tag_name == "v1.2.3" &&
      module.function["from-tag"].function.build_config[0].source[0].repo_source[0].dir == "fn"
    )
    error_message = "Wrong repo_source for the tag."
  }
  assert {
    condition = (
      module.function["from-branch"].function.build_config[0].source[0].repo_source[0].project_id == "shared" &&
      module.function["from-branch"].function.build_config[0].source[0].repo_source[0].branch_name == "^main$" &&
      module.function["from-branch"].function.build_config[0].source[0].repo_source[0].invert_regex == true
    )
    error_message = "Wrong repo_source for the branch."
  }
  assert {
    condition     = module.function["from-commit"].function.build_config[0].source[0].repo_source[0].commit_sha == "0123456789abcdef0123456789abcdef01234567"
    error_message = "Wrong repo_source for the commit."
  }
  assert {
    condition     = length(module.function["from-tag"].function.build_config[0].source[0].storage_source) == 0 && module.function["from-tag"].source.repo == "app"
    error_message = "A repository source has no storage source."
  }
}
