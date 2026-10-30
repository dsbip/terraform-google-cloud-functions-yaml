output "id" {
  description = "Function ID (projects/P/locations/R/functions/NAME)."
  value       = google_cloudfunctions2_function.this.id
}

output "name" {
  description = "Function name."
  value       = google_cloudfunctions2_function.this.name
}

output "project_id" {
  description = "Project of the function."
  value       = var.project_id
}

output "region" {
  description = "Region of the function."
  value       = var.region
}

output "uri" {
  description = "HTTPS URI of the function's Cloud Run service."
  value       = google_cloudfunctions2_function.this.service_config[0].uri
}

output "url" {
  description = "Deterministic cloudfunctions.net URL of the function."
  value       = google_cloudfunctions2_function.this.url
}

output "service" {
  description = "Name of the Cloud Run service that runs the function."
  value       = google_cloudfunctions2_function.this.service_config[0].service
}

output "service_account_email" {
  description = "Runtime service account of the function."
  value       = google_cloudfunctions2_function.this.service_config[0].service_account_email
}

output "state" {
  description = "Function state, e.g. ACTIVE."
  value       = google_cloudfunctions2_function.this.state
}

output "event_trigger" {
  description = "Eventarc trigger name of an event-driven function, else null."
  value       = try(google_cloudfunctions2_function.this.event_trigger[0].trigger, null)
}

output "source" {
  description = "Where the function's source is read from: { bucket, object } or { repo }."
  value = local.storage_source != null ? {
    bucket = local.storage_source.bucket
    object = local.storage_source.object
    repo   = null
    } : {
    bucket = null
    object = null
    repo   = try(local.source.repo.repo_name, null)
  }
}

output "function" {
  description = "The google_cloudfunctions2_function resource, for attributes not exposed above."
  value       = google_cloudfunctions2_function.this
}

output "invoker_members" {
  description = "Members granted roles/run.invoker on the function's Cloud Run service."
  value       = sort(keys(google_cloud_run_v2_service_iam_member.invoker))
}

output "iam_members" {
  description = "Function IAM grants as \"ROLE MEMBER\" (with \" [CONDITION TITLE]\" for conditional grants)."
  value       = sort(keys(google_cloudfunctions2_function_iam_member.this))
}
