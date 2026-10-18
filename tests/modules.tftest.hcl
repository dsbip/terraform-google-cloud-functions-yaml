# The submodules on their own, without the YAML layer: typed inputs, their
# defaults and their input validation.

mock_provider "google" {}

variables {
  name       = "standalone"
  project_id = "test-project"
  region     = "europe-west1"
  build_config = {
    runtime = "python312"
    source  = { dir = "tests/fixtures/src/hello", bucket = "sources" }
  }
}

run "function_module_with_a_local_directory" {
  command = plan

  module {
    source = "./modules/function"
  }

  assert {
    condition     = google_cloudfunctions2_function.this.name == "standalone" && google_cloudfunctions2_function.this.location == "europe-west1"
    error_message = "Wrong name or location."
  }
  assert {
    condition     = length(module.source_archive) == 1 && can(regex("^standalone-[0-9a-f]{32}\\.zip$", module.source_archive[0].object))
    error_message = "A local directory should be packaged by source-archive."
  }
  assert {
    condition     = google_cloudfunctions2_function.this.service_config[0].all_traffic_on_latest_revision == null
    error_message = "service_config defaults to an empty object: nothing set."
  }
  assert {
    condition     = length(google_cloudfunctions2_function.this.event_trigger) == 0 && length(google_cloud_run_v2_service_iam_member.invoker) == 0
    error_message = "HTTP function without invokers expected."
  }
}

run "function_module_with_an_existing_object_creates_no_upload" {
  command = plan

  module {
    source = "./modules/function"
  }

  variables {
    build_config = {
      runtime     = "go123"
      entry_point = "Main"
      source      = { object = "code.zip", bucket = "sources", generation = 5 }
    }
    event_trigger  = { pubsub_topic = "topic" }
    service_config = null # null is treated like {}
  }

  assert {
    condition     = length(module.source_archive) == 0
    error_message = "No upload expected for an existing object."
  }
  assert {
    condition     = google_cloudfunctions2_function.this.build_config[0].source[0].storage_source[0].generation == 5
    error_message = "The generation should be passed through."
  }
  assert {
    condition     = google_cloudfunctions2_function.this.event_trigger[0].pubsub_topic == "projects/test-project/topics/topic"
    error_message = "Short topic names should be expanded in the submodule too."
  }
}

run "function_name_is_validated" {
  command = plan

  module {
    source = "./modules/function"
  }

  variables {
    name = "Not_Valid"
  }

  expect_failures = [var.name]
}

run "function_runtime_and_source_are_validated" {
  command = plan

  module {
    source = "./modules/function"
  }

  variables {
    build_config = {
      runtime = "cobol85"
      source  = { dir = "tests/fixtures/src/hello", object = "x.zip" }
    }
  }

  # Three build_config rules fail: runtime, exactly one source, bucket.
  expect_failures = [var.build_config]
}

run "function_service_config_is_validated" {
  command = plan

  module {
    source = "./modules/function"
  }

  variables {
    service_config = {
      ingress_settings             = "EVERYONE"
      vpc_connector                = "c"
      direct_vpc_network_interface = [{ subnetwork = "s" }]
      min_instance_count           = 3
      max_instance_count           = 1
    }
  }

  expect_failures = [var.service_config]
}

run "function_event_trigger_is_validated" {
  command = plan

  module {
    source = "./modules/function"
  }

  variables {
    event_trigger = { retry_policy = "SOMETIMES" }
  }

  expect_failures = [var.event_trigger]
}

run "function_deletion_policy_is_validated" {
  command = plan

  module {
    source = "./modules/function"
  }

  variables {
    deletion_policy = "KEEP"
  }

  expect_failures = [var.deletion_policy]
}

run "source_archive_zips_a_directory" {
  command = plan

  module {
    source = "./modules/source-archive"
  }

  variables {
    name          = "packed"
    bucket        = "sources"
    source_dir    = "tests/fixtures/src/with-tests"
    excludes      = ["tests/**"]
    object_prefix = "a/b/"
    output_dir    = ".terraform/test-archives"
  }

  assert {
    condition     = google_storage_bucket_object.this.name == "a/b/packed-${data.archive_file.this[0].output_md5}.zip"
    error_message = "The object name should be prefix + name + md5."
  }
  assert {
    condition     = startswith(data.archive_file.this[0].output_path, ".terraform/test-archives/packed-") && data.archive_file.this[0].output_file_mode == "0644"
    error_message = "The archive should be written to output_dir with a fixed file mode."
  }
  assert {
    condition     = google_storage_bucket_object.this.content_type == "application/zip" && google_storage_bucket_object.this.bucket == "sources"
    error_message = "Wrong content type or bucket."
  }
  assert {
    condition     = output.md5 == data.archive_file.this[0].output_md5
    error_message = "The md5 output should be the archive hash."
  }
}

run "source_archive_uploads_a_zip_as_is" {
  command = plan

  module {
    source = "./modules/source-archive"
  }

  variables {
    name       = "prebuilt"
    bucket     = "sources"
    source_zip = "tests/fixtures/dist/fn.zip"
  }

  assert {
    condition     = length(data.archive_file.this) == 0 && google_storage_bucket_object.this.source == "tests/fixtures/dist/fn.zip"
    error_message = "A zip must be uploaded without repackaging."
  }
  assert {
    condition     = google_storage_bucket_object.this.name == "prebuilt-${filemd5("tests/fixtures/dist/fn.zip")}.zip"
    error_message = "The object name should contain the zip's md5."
  }
}

run "source_archive_needs_exactly_one_source" {
  command = plan

  module {
    source = "./modules/source-archive"
  }

  variables {
    name       = "both"
    bucket     = "sources"
    source_dir = "tests/fixtures/src/hello"
    source_zip = "tests/fixtures/dist/fn.zip"
  }

  expect_failures = [google_storage_bucket_object.this]
}

run "source_archive_rejects_gs_urls_and_bad_modes" {
  command = plan

  module {
    source = "./modules/source-archive"
  }

  variables {
    name       = "bad"
    bucket     = "gs://sources"
    source_zip = "tests/fixtures/dist/fn.zip"
    file_mode  = "rwxr-xr-x"
  }

  expect_failures = [var.bucket, var.file_mode]
}

run "source_archive_local_path_depends_on_the_archive_key" {
  command = plan

  module {
    source = "./modules/source-archive"
  }

  variables {
    name        = "same-name"
    bucket      = "sources"
    source_dir  = "tests/fixtures/src/hello"
    archive_key = "project-a/europe-west1/same-name"
  }

  # The object name only depends on the content; the local file on the key.
  assert {
    condition     = endswith(data.archive_file.this[0].output_path, "/.terraform/cloud-functions-yaml/same-name-${substr(sha1(jsonencode(["project-a/europe-west1/same-name", "tests/fixtures/src/hello", []])), 0, 10)}.zip")
    error_message = "Unexpected local path: ${data.archive_file.this[0].output_path}"
  }
}

run "equally_named_functions_in_two_regions_get_separate_archives" {
  command = plan

  module {
    source = "./modules/source-archive"
  }

  variables {
    name        = "same-name"
    bucket      = "sources"
    source_dir  = "tests/fixtures/src/hello"
    archive_key = "project-a/us-central1/same-name"
  }

  assert {
    condition     = data.archive_file.this[0].output_path != run.source_archive_local_path_depends_on_the_archive_key.local_path
    error_message = "Different archive keys must give different local paths."
  }
  assert {
    condition     = output.object == run.source_archive_local_path_depends_on_the_archive_key.object
    error_message = "The same content must give the same object name."
  }
}
