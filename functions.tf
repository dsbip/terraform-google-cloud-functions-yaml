# One modules/function instance per enabled function. The map is empty while
# the configuration has problems, so the plan fails with validation.tf's
# messages instead of type or provider errors.
module "function" {
  source   = "./modules/function"
  for_each = { for k, f in local.functions : k => f if f.enabled && local.config_valid }

  name               = each.value.name
  project_id         = each.value.project_id
  region             = each.value.region
  description        = each.value.description
  labels             = each.value.labels
  kms_key_name       = each.value.kms_key_name
  deletion_policy    = each.value.deletion_policy
  build_config       = each.value.build_config
  service_config     = each.value.service_config
  event_trigger      = each.value.event_trigger
  invokers           = each.value.invokers
  iam                = each.value.iam
  archive_output_dir = local.archive_output_dir
}
