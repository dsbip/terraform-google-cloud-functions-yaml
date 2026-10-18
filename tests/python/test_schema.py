"""The JSON Schema: is it valid, do the examples conform to it, and does it
stay in a shape that validation.tf can read?"""
import re

import pytest
from jsonschema import Draft7Validator

from conftest import REPO, example_configs, fixture_configs, load_yaml, object_definitions, ref_names, walk

# validation.tf walks the YAML this many levels deep (walk_0 ... walk_5).
WALK_LEVELS = 6


def test_schema_is_valid_draft7(schema):
    Draft7Validator.check_schema(schema)


@pytest.mark.parametrize("path", example_configs() + fixture_configs(), ids=lambda p: str(p.relative_to(REPO)))
def test_configuration_conforms_to_schema(schema, path):
    errors = sorted(Draft7Validator(schema).iter_errors(load_yaml(path)), key=lambda e: list(e.path))
    assert not errors, "\n".join(f"{'/'.join(map(str, e.path))}: {e.message}" for e in errors)


def test_object_definitions_are_closed(schema):
    """Unknown-key checks rely on every object definition listing its keys."""
    for name, d in object_definitions(schema).items():
        assert d.get("type") == "object", f"{name} needs type: object"
        assert d.get("additionalProperties") is False, f"{name} needs additionalProperties: false"


def test_nested_objects_are_named_definitions(schema):
    """validation.tf only follows $refs, so an inline object with properties
    would never be checked."""
    def inline_objects(node, where):
        if isinstance(node, dict):
            if "properties" in node and where.count("/") > 1:
                yield where
            for k, v in node.items():
                yield from inline_objects(v, f"{where}/{k}")
        elif isinstance(node, list):
            for i, v in enumerate(node):
                yield from inline_objects(v, f"{where}/{i}")

    offenders = []
    for name, d in schema["definitions"].items():
        for prop, p in d.get("properties", {}).items():
            offenders += list(inline_objects(p, f"definitions/{name}/{prop}"))
    for prop, p in schema["properties"].items():
        offenders += list(inline_objects(p, f"properties/{prop}"))
    assert not offenders, offenders


def test_schema_depth_fits_the_validation_walk(schema):
    defs = schema["definitions"]

    def depth(name, seen=()):
        node = schema if name == "root" else defs[name]
        best = 0
        for prop in node.get("properties", {}).values():
            children = [n for n in ref_names(prop) if "properties" in defs[n]]
            for key in ("items", "additionalProperties"):
                if isinstance(prop.get(key), dict):
                    children += [n for n in ref_names(prop[key]) if "properties" in defs[n]]
            for child in children:
                if child not in seen:
                    best = max(best, 1 + depth(child, seen + (child,)))
        return best

    assert depth("root") < WALK_LEVELS, f"schema is {depth('root')} levels deep; add walk levels to validation.tf"


def test_patterns_are_re2_compatible(schema):
    """Terraform evaluates the patterns with RE2: no lookaround or backreferences."""
    patterns = re.findall(r'"pattern":\s*"((?:[^"\\]|\\.)*)"', (REPO / "schemas" / "cloud-functions-config.schema.json").read_text(encoding="utf-8"))
    assert patterns
    for p in patterns:
        assert not re.search(r"\(\?[=!<]|\\[1-9]", p), p


def test_defaults_forbid_identity_keys(schema):
    all_of = schema["definitions"]["defaults"]["properties"]["functions"]["allOf"]
    forbidden = all_of[1]["propertyNames"]["not"]["enum"]
    assert forbidden == ["name"]
    assert set(forbidden) <= set(schema["definitions"]["function"]["properties"])


def test_complete_example_uses_every_key(schema):
    """examples/complete is documented as using every configuration key."""
    used = {(d, k) for d, k, _ in walk(schema, load_yaml(REPO / "examples" / "complete" / "config.yaml"), "root")}
    expected = {(name, key) for name, d in object_definitions(schema).items() for key in d["properties"]}
    expected |= {("root", key) for key in schema["properties"]}
    missing = sorted(f"{d}.{k}" for d, k in expected - used)
    assert not missing, f"examples/complete/config.yaml does not use: {missing}"


INVALID = [
    ("unknown top-level key", {"function": {}}),
    ("unknown function key", {"functions": {"a": {"descripton": "x"}}}),
    ("functions as a list", {"functions": [{"name": "a"}]}),
    ("bad runtime", {"functions": {"a": {"build_config": {"runtime": "python"}}}}),
    ("bad name", {"functions": {"a": {"name": "Not_Valid"}}}),
    ("bad ingress", {"functions": {"a": {"service_config": {"ingress_settings": "OPEN"}}}}),
    ("timeout too long", {"functions": {"a": {"service_config": {"timeout_seconds": 3601}}}}),
    ("bad member", {"functions": {"a": {"invokers": ["someone@example.com"]}}}),
    ("binding without members", {"functions": {"a": {"iam": [{"role": "roles/viewer", "members": []}]}}}),
    ("filter without value", {"functions": {"a": {"event_trigger": {"event_filters": [{"attribute": "bucket"}]}}}}),
    ("secret without key", {"functions": {"a": {"service_config": {"secret_environment_variables": [{"secret": "s"}]}}}}),
    ("repo without name", {"functions": {"a": {"build_config": {"source": {"repo": {"tag_name": "v1"}}}}}}),
    ("name as a default", {"defaults": {"functions": {"name": "x"}}}),
    ("boolean that is not a placeholder", {"functions": {"a": {"enabled": "yes please"}}}),
]


@pytest.mark.parametrize("name,config", INVALID, ids=[n for n, _ in INVALID])
def test_invalid_configuration_is_rejected(schema, name, config):
    assert list(Draft7Validator(schema).iter_errors(config)), f"schema accepted: {name}"


def test_placeholders_are_accepted_in_typed_fields(schema):
    config = {
        "functions": {
            "a": {
                "enabled": "${env == \"dev\"}",
                "name": "api-${env}",
                "deletion_policy": "${policy}",
                "build_config": {"runtime": "${runtime}", "runtime_update_policy": "${updates}"},
                "service_config": {"max_instance_count": "${max}", "ingress_settings": "${ingress}"},
                "invokers": ["${member}"],
            }
        }
    }
    errors = list(Draft7Validator(schema).iter_errors(config))
    assert not errors, [e.message for e in errors]
