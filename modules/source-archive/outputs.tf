output "bucket" {
  description = "Bucket holding the uploaded archive."
  value       = google_storage_bucket_object.this.bucket
}

output "object" {
  description = "Name of the uploaded object."
  value       = google_storage_bucket_object.this.name
}

output "md5" {
  description = "MD5 hash (hex) of the archive."
  value       = local.zip_md5
}

output "local_path" {
  description = "Local path of the archive."
  value       = local.zip_path
}
