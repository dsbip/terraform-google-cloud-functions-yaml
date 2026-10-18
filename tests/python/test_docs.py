"""Documentation checks: every configuration key is documented on its page,
and every relative link in the markdown files points to a file that exists."""
import json
import re

import pytest

from conftest import REPO, SCHEMA_PATH, object_definitions

SCHEMA = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))

PAGES = {"configuration": "docs/configuration.md", "functions": "docs/functions.md"}

# Definitions documented on docs/configuration.md; everything else is on docs/functions.md.
CONFIGURATION_DEFINITIONS = {"defaults"}


def documented_in(definition):
    return PAGES["configuration"] if definition in CONFIGURATION_DEFINITIONS else PAGES["functions"]


@pytest.mark.parametrize("definition", sorted(object_definitions(SCHEMA)))
def test_every_key_is_documented(schema, definition):
    page = documented_in(definition)
    text = (REPO / page).read_text(encoding="utf-8")
    keys = schema["definitions"][definition]["properties"]
    missing = [k for k in keys if not re.search(rf"`{re.escape(k)}`", text)]
    assert not missing, f"{page} does not mention {definition} keys: {missing}"


def test_top_level_keys_are_documented(schema):
    text = (REPO / PAGES["configuration"]).read_text(encoding="utf-8")
    missing = [k for k in schema["properties"] if f"`{k}`" not in text]
    assert not missing, missing


def test_readme_lists_every_example():
    text = (REPO / "README.md").read_text(encoding="utf-8")
    examples = sorted(p.name for p in (REPO / "examples").iterdir() if p.is_dir())
    missing = [e for e in examples if f"(examples/{e})" not in text]
    assert not missing, f"README.md does not link examples: {missing}"


def test_readme_lists_every_variable_and_output():
    text = (REPO / "README.md").read_text(encoding="utf-8")
    names = re.findall(r'^(?:variable|output) "([^"]+)"', (REPO / "variables.tf").read_text() + (REPO / "outputs.tf").read_text(), re.M)
    missing = [n for n in names if f"`{n}`" not in text]
    assert not missing, f"README.md does not document: {missing}"


def markdown_files():
    return sorted(
        p for p in REPO.rglob("*.md")
        if not any(part.startswith(".terraform") or part == ".pytest_cache" for part in p.parts)
    )


@pytest.mark.parametrize("path", markdown_files(), ids=lambda p: str(p.relative_to(REPO)))
def test_relative_links_resolve(path):
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"```.*?```", "", text, flags=re.S)  # code blocks hold HCL/YAML, not links
    broken = []
    for target in re.findall(r"\]\(([^)\s]+)\)", text):
        if re.match(r"^(https?:|mailto:|#)", target):
            continue
        if not (path.parent / target.split("#", 1)[0]).exists():
            broken.append(target)
    assert not broken, f"broken links in {path.relative_to(REPO)}: {broken}"
