# -----------------------------------------------------------------------------
# Configuration loading
#
# The YAML is decoded into plain objects, merged with its defaults and passed
# to one modules/function instance per function (functions.tf). Loading never
# fails on bad input: every lookup is wrapped in try() so that validation.tf
# can report all problems at once with YAML paths instead of Terraform errors.
# -----------------------------------------------------------------------------

locals {
  # JSON Schema of the configuration file. validation.tf reads allowed keys,
  # types, enumerations, ranges and patterns from it, so IDE validation and the
  # module cannot disagree.
  schema = jsondecode(file("${path.module}/schemas/cloud-functions-config.schema.json"))

  config_template_vars = try(
    merge({ project_id = var.project_id, region = var.region }, var.template_vars),
    { project_id = var.project_id, region = var.region },
  )

  config_text = (
    var.config_yaml != null ? var.config_yaml :
    var.config_file != null ? templatefile(var.config_file, local.config_template_vars) :
    ""
  )

  # yamldecode() rejects documents that are empty or contain only comments.
  config_is_blank = length(regexall("(?m)^[ \\t]*[^#\\s]", local.config_text)) == 0
  config_decoded  = local.config_is_blank ? null : yamldecode(local.config_text)
  config          = try(merge({}, local.config_decoded), {})

  project_id = try(coalesce(try(tostring(local.config.project_id), null), var.project_id), null)
  defaults   = try(merge({}, local.config.defaults), {})
  region     = try(coalesce(try(tostring(local.defaults.region), null), var.region), null)
  labels     = merge(var.labels, try({ for k, v in local.defaults.labels : k => tostring(v) if v != null }, {}))

  # Relative source paths inside the YAML are resolved against this directory.
  base_path = coalesce(var.base_path, var.config_file != null ? dirname(var.config_file) : path.root)

  archive_output_dir = coalesce(var.archive_output_dir, "${path.root}/.terraform/cloud-functions-yaml")

  # ---------------------------------------------------------------------------
  # Defaults
  #
  # defaults.functions is merged underneath every function, three levels deep:
  #   level 1  function keys            (description, build_config, ...)
  #   level 2  keys of nested mappings  (build_config.runtime, service_config.*)
  #   level 3  keys of mappings inside  (build_config.source.bucket,
  #            those                     service_config.environment_variables.*)
  # Lists and scalars are replaced, never concatenated. Explicit nulls are
  # dropped first, so an empty `key:` line never overrides a default.
  # ---------------------------------------------------------------------------

  defaults_forbidden_keys = try(local.schema.definitions.defaults.properties.functions.allOf[1].propertyNames.not.enum, [])

  function_defaults = {
    for k, v in try(merge({}, local.defaults.functions), {}) : k => v
    if v != null && !contains(local.defaults_forbidden_keys, k)
  }

  functions_input = try(merge({}, local.config.functions), {})

  functions_clean = {
    for key, f in local.functions_input : key => { for k, v in try(merge({}, f), {}) : k => v if v != null }
  }

  functions_merged = {
    for key, f in local.functions_clean : key => {
      for k in setunion(keys(local.function_defaults), keys(f)) : k => try(
        {
          for k2 in setunion(keys(local.function_defaults[k]), keys(f[k])) : k2 => try(
            merge(local.function_defaults[k][k2], f[k][k2]),
            [for v in [f[k][k2]] : v if v != null][0],
            local.function_defaults[k][k2],
          )
        },
        f[k],
        local.function_defaults[k],
      )
    }
  }

  # ---------------------------------------------------------------------------
  # Normalised functions: exactly the inputs of modules/function.
  # ---------------------------------------------------------------------------

  # Local source paths resolved against base_path (absolute paths are kept).
  source_paths = {
    for key, f in local.functions_merged : key => {
      for attr in ["dir", "zip"] : attr => try(
        startswith(tostring(f.build_config.source[attr]), "/") || length(regexall("^[A-Za-z]:[\\\\/]", tostring(f.build_config.source[attr]))) > 0
        ? tostring(f.build_config.source[attr])
        : "${local.base_path}/${tostring(f.build_config.source[attr])}",
        null,
      )
    }
  }

  functions = {
    for key, f in local.functions_merged : key => {
      enabled         = try(tobool(f.enabled), true)
      name            = try(tostring(f.name), key)
      project_id      = try(coalesce(try(tostring(f.project_id), null), local.project_id), null)
      region          = try(coalesce(try(tostring(f.region), null), local.region), null)
      description     = try(tostring(f.description), null)
      labels          = merge(local.labels, try({ for k, v in f.labels : k => tostring(v) if v != null }, {}))
      kms_key_name    = try(tostring(f.kms_key_name), null)
      deletion_policy = try(tostring(f.deletion_policy), null)
      build_config = try(
        merge(f.build_config, { source = merge(f.build_config.source, local.source_paths[key]) }),
        try(f.build_config, null),
      )
      service_config = try(f.service_config, null)
      event_trigger  = try(f.event_trigger, null)
      invokers       = try(f.invokers, [])
      iam            = try(f.iam, [])
    }
  }
}
