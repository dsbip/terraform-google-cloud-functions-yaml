# -----------------------------------------------------------------------------
# Cloud Run functions (Cloud Functions 2nd gen)
#
# Which functions an environment gets, and their settings, is in
# terraform/<env>/cf.yaml, selected by cf_yaml_config_path in
# terraform/<env>/variables.tfvars. The code is in src/cloud-functions/<dir>/,
# shared by every environment. YAML keys: modules/cloud-functions/docs/functions.md
# -----------------------------------------------------------------------------

module "cloud_functions" {
  source = "../../modules/cloud-functions"

  # No cf_yaml_config_path: no functions in this environment. A path that is set
  # but wrong fails the plan instead of planning to destroy every function.
  count = var.cf_yaml_config_path == null ? 0 : 1

  # cf.yaml carries project_id and defaults.region itself.
  config_file = var.cf_yaml_config_path

  # source.dir in cf.yaml is relative to src/cloud-functions, not to cf.yaml.
  base_path = "${path.module}/../../src/cloud-functions"
}

output "cloud_function_uris" {
  description = "HTTPS URI of every deployed function, keyed by its cf.yaml key."
  value       = one(module.cloud_functions[*].uris)
}
