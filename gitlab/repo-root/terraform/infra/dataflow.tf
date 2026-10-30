# -----------------------------------------------------------------------------
# Dataflow jobs and Data Pipelines from terraform/<env>/dataflow.yaml.
#
# Opt-in per environment: an environment whose variables.tfvars doesn't set
# dataflow_yaml_config_path gets no Dataflow resources. This is deliberately
# not a fileexists() check: a renamed or misspelled file would then plan to
# destroy every job of the environment instead of failing the plan.
#
# The module reads project_id and defaults.region from the YAML and validates
# the whole file before anything is planned (modules/dataflow/README.md).
# -----------------------------------------------------------------------------

module "dataflow" {
  source = "../../modules/dataflow"
  count  = var.dataflow_yaml_config_path == null ? 0 : 1

  config_file = var.dataflow_yaml_config_path

  # Optional inputs:
  #   project_id    = var.project_id   # fallback for the YAML's project_id; enables ${project_id} in the YAML
  #   region        = var.region       # fallback for defaults.region; enables ${region}
  #   template_vars = { env = "dev" }  # values for other ${...} placeholders in the YAML
  #   labels        = { managed-by = "terraform" }

  # The YAML names buckets, service accounts and subnetworks as plain strings,
  # so Terraform can't see that jobs depend on them. If they are created in this
  # configuration too, make sure they exist before the first job is launched
  # (use your module names):
  #   depends_on = [module.gcs, module.service_accounts, module.iam_bindings]
}

output "dataflow_jobs" {
  description = "Dataflow jobs from dataflow.yaml, keyed by YAML key: job_id, name, region, state, type, template_type, template."
  value       = one(module.dataflow[*].jobs)
}

output "dataflow_pipelines" {
  description = "Data Pipelines from dataflow.yaml, keyed by YAML key: id, job_name, type, state, template, next_job_time."
  value       = one(module.dataflow[*].pipelines)
}
