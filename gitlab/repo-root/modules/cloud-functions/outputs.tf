output "functions" {
  description = "Deployed functions keyed by YAML key: id, name, project_id, region, uri, url, service, service_account_email, state, event_trigger and source."
  value = {
    for k, m in module.function : k => {
      id                    = m.id
      name                  = m.name
      project_id            = m.project_id
      region                = m.region
      uri                   = m.uri
      url                   = m.url
      service               = m.service
      service_account_email = m.service_account_email
      state                 = m.state
      event_trigger         = m.event_trigger
      source                = m.source
    }
  }
}

output "uris" {
  description = "HTTPS URI of every function, keyed by YAML key."
  value       = { for k, m in module.function : k => m.uri }
}

output "ids" {
  description = "Function IDs (projects/P/locations/R/functions/NAME), keyed by YAML key."
  value       = { for k, m in module.function : k => m.id }
}

output "config" {
  description = "The normalised configuration of every function (after defaults and path resolution), keyed by YAML key. Disabled functions are included with enabled = false."
  value       = local.functions
}
