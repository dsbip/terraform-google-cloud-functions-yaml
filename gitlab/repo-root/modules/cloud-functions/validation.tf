# -----------------------------------------------------------------------------
# Validation
#
# Every problem in the configuration is collected into local.validation_errors
# (as "<yaml path>: <problem>") and reported by the precondition at the end of
# this file. While there are problems, the module's for_each is empty
# (local.config_valid), so the plan fails with that list and nothing else.
#
# Part 1 is generic: it walks the YAML alongside the JSON Schema and checks
# keys, types, enumerations, ranges, patterns and required keys. Part 2 holds
# the rules a schema cannot express (exactly-one-of, files that must exist,
# duplicates, values that come from defaults).
#
# Rules for code in this file:
# - && and || do not short-circuit in Terraform < 1.12, so every operand must
#   be safe to evaluate on its own; lookups that may fail are wrapped in try().
# - Conditional expressions must not mix object types; filters (`if`) are used
#   instead of `cond ? [] : [obj]` wherever the objects hold YAML values.
# -----------------------------------------------------------------------------

locals {
  # ---------------------------------------------------------------------------
  # Part 1: schema-driven checks
  # ---------------------------------------------------------------------------

  ref_prefix      = "#/definitions/"
  placeholder_ref = "#/definitions/template_placeholder"

  # "root" is the top level of the file; every other name is a definition.
  schema_defs = merge(local.schema.definitions, { root = local.schema })

  # Every alternative a property allows: the property schema itself, its anyOf
  # and allOf members, and the definitions their $refs point to (plus those
  # definitions' anyOf members). ${...} placeholders are not alternatives here:
  # templatefile() has replaced them before the YAML is parsed.
  schema_options = {
    for dname, d in local.schema_defs : dname => {
      for pname, p in try(d.properties, {}) : pname => flatten([
        for o in concat([p], try(p.anyOf, []), try(p.allOf, [])) : [
          for r in concat(
            [try(local.schema.definitions[trimprefix(o["$ref"], local.ref_prefix)], o)],
            try(local.schema.definitions[trimprefix(o["$ref"], local.ref_prefix)].anyOf, []),
          ) : r if try(r["$ref"], "") != local.placeholder_ref
        ] if try(o["$ref"], "") != local.placeholder_ref
      ])
    }
  }

  # The same for list items (`items`) and mapping values (`additionalProperties`).
  schema_item_options = {
    for dname, props in local.schema_options : dname => {
      for pname, opts in props : pname => flatten([
        for o in opts : [
          for r in concat(
            [try(local.schema.definitions[trimprefix(o.items["$ref"], local.ref_prefix)], o.items)],
            try(local.schema.definitions[trimprefix(o.items["$ref"], local.ref_prefix)].anyOf, []),
          ) : r if try(r["$ref"], "") != local.placeholder_ref
        ] if can(o.items.type) || can(o.items["$ref"])
      ])
    }
  }

  schema_value_options = {
    for dname, props in local.schema_options : dname => {
      for pname, opts in props : pname => flatten([
        for o in opts : [
          for r in concat(
            [try(local.schema.definitions[trimprefix(o.additionalProperties["$ref"], local.ref_prefix)], o.additionalProperties)],
            try(local.schema.definitions[trimprefix(o.additionalProperties["$ref"], local.ref_prefix)].anyOf, []),
          ) : r if try(r["$ref"], "") != local.placeholder_ref
        ] if can(o.additionalProperties.type) || can(o.additionalProperties["$ref"])
      ])
    }
  }

  # Definition that a property's value, each of its items, or each of its
  # mapping values must satisfy (null: not an object definition).
  schema_refs = {
    for dname, d in local.schema_defs : dname => {
      for pname, p in try(d.properties, {}) : pname => {
        object = try(one(distinct([
          for o in concat([p], try(p.anyOf, []), try(p.allOf, [])) : trimprefix(o["$ref"], local.ref_prefix)
          if can(local.schema.definitions[trimprefix(o["$ref"], local.ref_prefix)].properties)
        ])), null)
        items = try(one(distinct([
          for o in concat([try(p.items, null)], try(p.items.anyOf, [])) : trimprefix(o["$ref"], local.ref_prefix)
          if can(local.schema.definitions[trimprefix(o["$ref"], local.ref_prefix)].properties)
        ])), null)
        values = try(one(distinct([
          for o in concat([try(p.additionalProperties, null)], try(p.additionalProperties.anyOf, [])) : trimprefix(o["$ref"], local.ref_prefix)
          if can(local.schema.definitions[trimprefix(o["$ref"], local.ref_prefix)].properties)
        ])), null)
      }
    }
  }

  # Allowed keys of each definition, for unknown-key checks.
  schema_keys = { for dname, d in local.schema_defs : dname => keys(try(d.properties, {})) }

  type_phrases = {
    string  = "a string"
    integer = "a whole number"
    number  = "a number"
    boolean = "true or false"
    array   = "a list"
    object  = "a mapping"
  }

  # Walk the YAML along the schema: every mapping that a definition describes,
  # with its YAML path. Six levels cover the deepest nesting of the schema
  # (defaults.functions.build_config.source.repo); tests/python/test_schema.py
  # fails if the schema ever grows deeper.
  walk_0 = [{ path = "", value = local.config_decoded, def = "root" }]

  walk_1 = flatten([
    for c in local.walk_0 : [
      for k, v in try(merge({}, c.value), {}) : concat(
        [for x in [v] : { path = "${c.path}${c.path == "" ? "" : "."}${k}", value = x, def = local.schema_refs[c.def][k].object } if try(local.schema_refs[c.def][k].object, null) != null],
        [for i, x in try(concat(v, []), []) : { path = "${c.path}${c.path == "" ? "" : "."}${k}[${i}]", value = x, def = local.schema_refs[c.def][k].items } if try(local.schema_refs[c.def][k].items, null) != null],
        [for k2, x in try(merge({}, v), {}) : { path = "${c.path}${c.path == "" ? "" : "."}${k}.${k2}", value = x, def = local.schema_refs[c.def][k].values } if try(local.schema_refs[c.def][k].values, null) != null],
      ) if v != null
    ]
  ])

  walk_2 = flatten([
    for c in local.walk_1 : [
      for k, v in try(merge({}, c.value), {}) : concat(
        [for x in [v] : { path = "${c.path}.${k}", value = x, def = local.schema_refs[c.def][k].object } if try(local.schema_refs[c.def][k].object, null) != null],
        [for i, x in try(concat(v, []), []) : { path = "${c.path}.${k}[${i}]", value = x, def = local.schema_refs[c.def][k].items } if try(local.schema_refs[c.def][k].items, null) != null],
        [for k2, x in try(merge({}, v), {}) : { path = "${c.path}.${k}.${k2}", value = x, def = local.schema_refs[c.def][k].values } if try(local.schema_refs[c.def][k].values, null) != null],
      ) if v != null
    ]
  ])

  walk_3 = flatten([
    for c in local.walk_2 : [
      for k, v in try(merge({}, c.value), {}) : concat(
        [for x in [v] : { path = "${c.path}.${k}", value = x, def = local.schema_refs[c.def][k].object } if try(local.schema_refs[c.def][k].object, null) != null],
        [for i, x in try(concat(v, []), []) : { path = "${c.path}.${k}[${i}]", value = x, def = local.schema_refs[c.def][k].items } if try(local.schema_refs[c.def][k].items, null) != null],
        [for k2, x in try(merge({}, v), {}) : { path = "${c.path}.${k}.${k2}", value = x, def = local.schema_refs[c.def][k].values } if try(local.schema_refs[c.def][k].values, null) != null],
      ) if v != null
    ]
  ])

  walk_4 = flatten([
    for c in local.walk_3 : [
      for k, v in try(merge({}, c.value), {}) : concat(
        [for x in [v] : { path = "${c.path}.${k}", value = x, def = local.schema_refs[c.def][k].object } if try(local.schema_refs[c.def][k].object, null) != null],
        [for i, x in try(concat(v, []), []) : { path = "${c.path}.${k}[${i}]", value = x, def = local.schema_refs[c.def][k].items } if try(local.schema_refs[c.def][k].items, null) != null],
        [for k2, x in try(merge({}, v), {}) : { path = "${c.path}.${k}.${k2}", value = x, def = local.schema_refs[c.def][k].values } if try(local.schema_refs[c.def][k].values, null) != null],
      ) if v != null
    ]
  ])

  walk_5 = flatten([
    for c in local.walk_4 : [
      for k, v in try(merge({}, c.value), {}) : concat(
        [for x in [v] : { path = "${c.path}.${k}", value = x, def = local.schema_refs[c.def][k].object } if try(local.schema_refs[c.def][k].object, null) != null],
        [for i, x in try(concat(v, []), []) : { path = "${c.path}.${k}[${i}]", value = x, def = local.schema_refs[c.def][k].items } if try(local.schema_refs[c.def][k].items, null) != null],
        [for k2, x in try(merge({}, v), {}) : { path = "${c.path}.${k}.${k2}", value = x, def = local.schema_refs[c.def][k].values } if try(local.schema_refs[c.def][k].values, null) != null],
      ) if v != null
    ]
  ])

  # Mappings found by the walk (non-mappings are reported by their parent's type check).
  schema_nodes = [
    for c in concat(local.walk_0, local.walk_1, local.walk_2, local.walk_3, local.walk_4, local.walk_5) : c
    if can(keys(c.value))
  ]

  # One entry per key present in a mapping, with what the schema allows there.
  key_checks = flatten([
    for c in local.schema_nodes : [
      for k, v in c.value : {
        parent    = c.path == "" ? "(root)" : c.path
        path      = c.path == "" ? k : "${c.path}.${k}"
        key       = k
        value     = v
        is_string = try(startswith(jsonencode(v), "\""), false)
        known     = contains(local.schema_keys[c.def], k)
        # Likely intended keys: the same first three letters or the same
        # letters in another order; only if there are none, the same last
        # three letters.
        suggestions = length(k) < 3 ? [] : try(coalescelist(
          [for a in local.schema_keys[c.def] : a if length(a) >= 3 && (substr(a, 0, 3) == substr(k, 0, 3) || join("", sort(split("", a))) == join("", sort(split("", k))))],
          [for a in local.schema_keys[c.def] : a if length(a) >= 3 && substr(a, length(a) - 3, 3) == substr(k, length(k) - 3, 3)],
        ), [])
        types         = distinct(flatten([for o in try(local.schema_options[c.def][k], []) : try(flatten([o.type]), [])]))
        enums         = distinct(flatten([for o in try(local.schema_options[c.def][k], []) : try(o.enum, [])]))
        patterns      = distinct([for o in try(local.schema_options[c.def][k], []) : o.pattern if can(o.pattern)])
        minimum       = try(max([for o in try(local.schema_options[c.def][k], []) : o.minimum if can(o.minimum)]...), null)
        maximum       = try(min([for o in try(local.schema_options[c.def][k], []) : o.maximum if can(o.maximum)]...), null)
        min_items     = try(max([for o in try(local.schema_options[c.def][k], []) : o.minItems if can(o.minItems)]...), null)
        description   = try([for o in try(local.schema_options[c.def][k], []) : o.description if can(o.description)][0], "")
        item_types    = distinct(flatten([for o in try(local.schema_item_options[c.def][k], []) : try(flatten([o.type]), [])]))
        item_enums    = distinct(flatten([for o in try(local.schema_item_options[c.def][k], []) : try(o.enum, [])]))
        item_patterns = distinct([for o in try(local.schema_item_options[c.def][k], []) : o.pattern if can(o.pattern)])
        item_desc     = try([for o in try(local.schema_item_options[c.def][k], []) : o.description if can(o.description)][0], "")
        value_types   = distinct(flatten([for o in try(local.schema_value_options[c.def][k], []) : try(flatten([o.type]), [])]))
      } if v != null
    ]
  ])

  # List items and mapping values, checked against the item/value schema.
  element_checks = concat(
    flatten([
      for kc in local.key_checks : [
        for i, x in try(concat(kc.value, []), []) : {
          path = "${kc.path}[${i}]", value = x, is_string = try(startswith(jsonencode(x), "\""), false), types = kc.item_types, enums = kc.item_enums, patterns = kc.item_patterns, description = kc.item_desc
        }
      ] if length(kc.item_types) > 0
    ]),
    flatten([
      for kc in local.key_checks : [
        for k2, x in try(merge({}, kc.value), {}) : {
          path = "${kc.path}.${k2}", value = x, is_string = try(startswith(jsonencode(x), "\""), false), types = kc.value_types, enums = [], patterns = [], description = ""
        } if x != null
      ] if length(kc.value_types) > 0
    ]),
  )

  value_checks = concat(
    [for kc in local.key_checks : { path = kc.path, value = kc.value, is_string = kc.is_string, types = kc.types, enums = kc.enums, patterns = kc.patterns, description = kc.description } if kc.known],
    local.element_checks,
  )

  unknown_key_errors = [
    for kc in local.key_checks : "${kc.parent}: unknown key \"${kc.key}\"${length(kc.suggestions) == 0 ? "" : " (did you mean ${join(" or ", slice(kc.suggestions, 0, min(3, length(kc.suggestions))))}?)"}"
    if !kc.known
  ]

  type_errors = [
    for vc in local.value_checks : "${vc.path}: must be ${join(" or ", distinct([
      for t in vc.types : local.type_phrases[contains(vc.types, "string") && contains(["number", "integer", "boolean"], t) ? "string" : t] if t != "null"
    ]))}"
    if length(vc.types) > 0 && !anytrue([
      for t in vc.types :
      t == "string" ? can(tostring(vc.value)) :
      t == "integer" ? try(floor(tonumber(vc.value)) == tonumber(vc.value), false) :
      t == "number" ? can(tonumber(vc.value)) :
      t == "boolean" ? can(tobool(vc.value)) :
      t == "array" ? can(concat(vc.value, [])) :
      t == "object" ? can(keys(vc.value)) :
      t == "null" ? vc.value == null :
      false
    ])
  ]

  enum_errors = [
    for vc in local.value_checks : "${vc.path}: must be one of ${join(", ", vc.enums)} (got \"${vc.value}\")"
    if length(vc.enums) > 0 && can(tostring(vc.value)) && !contains([for e in vc.enums : tostring(e)], try(coalesce(tostring(vc.value)), ""))
  ]

  # A pattern belongs to the string alternative: values of another allowed
  # type (e.g. the number in "number or octal string") are not matched.
  pattern_errors = [
    for vc in local.value_checks : "${vc.path}: \"${vc.value}\" is not valid${vc.description == "" ? "" : " (${trimsuffix(vc.description, ".")})"}"
    if length(vc.patterns) == 1 && can(tostring(vc.value)) && (vc.is_string || !anytrue([for t in vc.types : t != "string"])) && length(regexall(try(vc.patterns[0], "^"), try(tostring(vc.value), ""))) == 0
  ]

  # Ranges belong to the numeric alternative: strings are not compared when
  # strings are allowed too.
  range_errors = concat(
    [for kc in local.key_checks : "${kc.path}: must be at least ${kc.minimum}" if try(tonumber(kc.value) < kc.minimum, false) && !(kc.is_string && contains(kc.types, "string"))],
    [for kc in local.key_checks : "${kc.path}: must be at most ${kc.maximum}" if try(tonumber(kc.value) > kc.maximum, false) && !(kc.is_string && contains(kc.types, "string"))],
    [for kc in local.key_checks : "${kc.path}: must have at least ${kc.min_items} item(s)" if try(length(concat(kc.value, [])) < kc.min_items, false)],
  )

  required_errors = flatten([
    for c in local.schema_nodes : [
      for r in try(local.schema_defs[c.def].required, []) : "${c.path == "" ? "(root)" : c.path}: missing required key \"${r}\""
      if try(c.value[r], null) == null
    ]
  ])

  schema_errors = concat(
    local.config_decoded == null || can(keys(local.config_decoded)) ? [] : ["(root): the configuration must be a mapping (key: value pairs)"],
    local.unknown_key_errors,
    local.type_errors,
    local.enum_errors,
    local.pattern_errors,
    local.range_errors,
    local.required_errors,
  )

  # ---------------------------------------------------------------------------
  # Part 2: rules beyond the schema
  # ---------------------------------------------------------------------------

  input_errors = concat(
    var.config_file != null && var.config_yaml != null ? ["(module): set config_file or config_yaml, not both"] : [],
    var.config_file == null && var.config_yaml == null ? ["(module): set config_file or config_yaml"] : [],
    [for k in keys(try(merge({}, local.defaults.functions), {})) : "defaults.functions: \"${k}\" cannot be a default" if contains(local.defaults_forbidden_keys, k)],
  )

  # Rules run on the merged function (defaults applied), and only for entries
  # that are mappings: anything else already has a type error.
  function_errors = flatten([
    for key, f in local.functions_merged : concat(
      local.functions[key].project_id == null ? ["functions.${key}: no project_id; set it on the function, at the top level of the file, or in the module's project_id variable"] : [],
      local.functions[key].region == null ? ["functions.${key}: no region; set it on the function, in defaults.region, or in the module's region variable"] : [],
      contains(["true", "false"], key) ? [
        "functions.${key}: YAML reads unquoted yes, no, on, off, true and false as booleans; quote the key (e.g. \"on\":) or choose another name"
      ] : [],
      try(f.name, null) != null || length(regexall("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", key)) > 0 ? [] : [
        "functions.${key}: the key is used as the function name but is not a valid one (lowercase letters, digits and hyphens, starting with a letter, at most 63 characters); rename it or set name"
      ],
      try(f.build_config, null) != null ? [] : ["functions.${key}: build_config (with runtime and source) is required, here or in defaults.functions"],
      !can(keys(f.build_config)) || try(f.build_config.runtime, null) != null ? [] : ["functions.${key}.build_config: runtime is required, here or in defaults.functions"],
      !can(keys(f.build_config)) || try(f.build_config.source, null) != null ? [] : ["functions.${key}.build_config: source is required, here or in defaults.functions"],

      # Source
      !can(keys(f.build_config.source)) ? [] : concat(
        length(local.source_kinds[key]) == 1 ? [] : [
          "functions.${key}.build_config.source: set exactly one of dir, zip, object and repo${length(local.source_kinds[key]) == 0 ? "" : " (found ${join(", ", local.source_kinds[key])})"}"
        ],
        length(setintersection(local.source_kinds[key], ["dir", "zip", "object"])) == 0 || try(f.build_config.source.bucket, null) != null ? [] : [
          "functions.${key}.build_config.source: bucket is required with ${join(" and ", setintersection(local.source_kinds[key], ["dir", "zip", "object"]))}"
        ],
        startswith(try(tostring(f.build_config.source.bucket), ""), "gs://") ? ["functions.${key}.build_config.source.bucket: use the bucket name without gs://"] : [],
        local.source_paths[key].dir == null || try(length(fileset(local.source_paths[key].dir, "**")) > 0, false) ? [] : [
          "functions.${key}.build_config.source.dir: \"${try(f.build_config.source.dir, "")}\" is not a directory with files (resolved to ${try(local.source_paths[key].dir, "")})"
        ],
        local.source_paths[key].zip == null || try(fileexists(local.source_paths[key].zip), false) ? [] : [
          "functions.${key}.build_config.source.zip: file \"${try(f.build_config.source.zip, "")}\" does not exist (resolved to ${try(local.source_paths[key].zip, "")})"
        ],
        !can(keys(f.build_config.source.repo)) || length([for r in ["branch_name", "tag_name", "commit_sha"] : r if try(f.build_config.source.repo[r], null) != null]) == 1 ? [] : [
          "functions.${key}.build_config.source.repo: set exactly one of branch_name, tag_name and commit_sha"
        ],
      ),

      # Event trigger
      !can(keys(f.event_trigger)) || try(f.event_trigger.event_type, null) != null || try(f.event_trigger.pubsub_topic, null) != null ? [] : [
        "functions.${key}.event_trigger: set event_type (or pubsub_topic, which implies the Pub/Sub event type)"
      ],

      # Scaling and networking
      try(tonumber(f.service_config.min_instance_count) > tonumber(f.service_config.max_instance_count), false) ? [
        "functions.${key}.service_config: min_instance_count (${f.service_config.min_instance_count}) is greater than max_instance_count (${f.service_config.max_instance_count})"
      ] : [],
      try(f.service_config.vpc_connector, null) != null && try(length(f.service_config.direct_vpc_network_interface) > 0, false) ? [
        "functions.${key}.service_config: use vpc_connector or direct_vpc_network_interface, not both"
      ] : [],
      try(f.service_config.vpc_connector_egress_settings, null) != null && try(f.service_config.vpc_connector, null) == null ? [
        "functions.${key}.service_config: vpc_connector_egress_settings needs vpc_connector"
      ] : [],
      try(f.service_config.direct_vpc_egress, null) != null && !try(length(f.service_config.direct_vpc_network_interface) > 0, false) ? [
        "functions.${key}.service_config: direct_vpc_egress needs direct_vpc_network_interface"
      ] : [],
    )
    if local.functions_input[key] == null || can(keys(local.functions_input[key]))
  ])

  # Kinds of source each function sets (only valid when the source is a mapping).
  source_kinds = {
    for key, f in local.functions_merged : key => [for kind in ["dir", "zip", "object", "repo"] : kind if try(f.build_config.source[kind], null) != null]
  }

  # Two enabled functions with the same name in the same project and region.
  function_ids = {
    for key, f in local.functions : key => "${f.project_id}/${f.region}/${f.name}"
    if f.enabled && f.project_id != null && f.region != null
  }
  duplicate_errors = [
    for id, ks in { for key, id in local.function_ids : id => key... } :
    "functions: ${join(", ", ks)} would all create function ${id}"
    if length(ks) > 1
  ]

  validation_errors = distinct(concat(
    local.input_errors,
    local.schema_errors,
    local.function_errors,
    local.duplicate_errors,
  ))

  # The module's for_each is empty while the configuration is invalid. The
  # provider validates each planned instance before any precondition runs, so
  # without this an invalid file would fail with type or provider errors
  # instead of the message below.
  config_valid = length(local.validation_errors) == 0
}

resource "terraform_data" "validation" {
  lifecycle {
    precondition {
      condition     = length(local.validation_errors) == 0
      error_message = "The Cloud Functions YAML configuration has ${length(local.validation_errors)} problem(s):\n  - ${join("\n  - ", local.validation_errors)}"
    }
  }
}
