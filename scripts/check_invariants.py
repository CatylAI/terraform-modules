#!/usr/bin/env python3
"""Enforces the [gate] rules of docs/spec/module-standard.md that no off-the-shelf tool checks.

Standard library only. Exit 0 when every rule holds, 1 when any is broken. Each failure names
the rule id, the file and what is wrong, never a value that could be sensitive.

    python3 scripts/check_invariants.py                  # check
    python3 scripts/check_invariants.py --write-digests  # refresh every module's .context-digest

PLATFORM_LIBS_DIR, when set, points at a lib-platform checkout; the environment contract is then
also held equal to its source (ADR-0002).
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODULES = ROOT / "modules"
INTERNAL = MODULES / "_internal"
CONTEXT_MODULE = INTERNAL / "context"
PROVIDERS = ("gcp", "github", "gws", "aws")
REQUIRED_FILES = ("versions.tf", "variables.tf", "outputs.tf", "README.md")
REQUIRED_PUBLIC = ("examples/minimal", "examples/complete", ".context-digest")
LEADING_INPUTS = ("context", "name", "enabled")
CONTEXT_TYPE = (
    "object({ tenant = string environment = string component = string repo = string "
    "labels = optional(map(string), {}) allowed_environments = optional(list(string)) "
    "name_prefix = optional(string) })"
)
# MS-15.1: no organisation-specific value in anything a stranger would copy. The repository's own
# source URL is the one allowed mention.
ORG_STRINGS = re.compile(r"catyl|pimpmynines", re.IGNORECASE)
OWN_SOURCE = "github.com/CatylAI/terraform-modules"
PUBLIC_SUFFIXES = (".tf", ".hcl", ".tfvars", ".tfbackend", ".sh")
# MS-15.1, repository-wide: this repository is public (ADR-0014), so no file may carry the owning
# organisation's infrastructure identifiers. Naming the organisation as owner (CatylAI in a URL, in
# CODEOWNERS or as an ADR's decider) and lib-platform as the contract source are allowed.
INTERNAL_IDS = re.compile(
    r"catylai-[a-z0-9]|gcp-infra|web-catylai|\bcortex\b|homelab|arc-catylai|\bpmn-|pimpmynines"
    r"|state_stacks|aft-networking|ct-management|catyl\.ai",
    re.IGNORECASE,
)
SECRET_NAME = re.compile(r"(password|passwd|secret|token|private_key)", re.IGNORECASE)

failures: list[str] = []


def fail(rule: str, path: Path | str, message: str) -> None:
    rel = path.relative_to(ROOT) if isinstance(path, Path) else path
    failures.append(f"{rule:<8} {rel}: {message}")


# --- a deliberately small HCL reader -------------------------------------------------------------


def strip_comments(text: str) -> str:
    """Removes # and // line comments and /* */ blocks, leaving string contents intact."""
    out, i, n = [], 0, len(text)
    in_str = False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
        elif c == "#" or text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end == -1 else end + 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def blocks(text: str, kind: str) -> list[tuple[str, str]]:
    """Returns (label, body) for every top-level `kind "label" {` block, braces matched."""
    found = []
    for m in re.finditer(rf'(?m)^{kind}\s+"([^"]+)"\s*(?:"[^"]+"\s*)?\{{', text):
        depth, i = 1, m.end()
        while i < len(text) and depth:
            depth += {"{": 1, "}": -1}.get(text[i], 0)
            i += 1
        found.append((m.group(1), text[m.end() : i - 1]))
    return found


def attr_present(body: str, name: str) -> bool:
    return re.search(rf"(?m)^\s*{name}\s*=", body) is not None


def type_expr(body: str) -> str:
    m = re.search(r"(?m)^\s*type\s*=\s*", body)
    if not m:
        return ""
    i, depth, out = m.end(), 0, []
    while i < len(body):
        c = body[i]
        if c in "({[":
            depth += 1
        elif c in ")}]":
            depth -= 1
        if c == "\n" and depth == 0:
            break
        out.append(c)
        i += 1
    return " ".join("".join(out).split())


def tf_files(directory: Path, recursive: bool = False) -> list[Path]:
    pattern = "**/*.tf" if recursive else "*.tf"
    return sorted(p for p in directory.glob(pattern) if ".terraform" not in p.parts)


def read(path: Path) -> str:
    return strip_comments(path.read_text(encoding="utf-8"))


# --- discovery ------------------------------------------------------------------------------------


def public_modules() -> list[Path]:
    found = []
    for provider in PROVIDERS:
        base = MODULES / provider
        if base.is_dir():
            found += sorted(d for d in base.iterdir() if d.is_dir() and tf_files(d))
    return found


def module_id(module: Path) -> str:
    return f"{module.parent.name}-{module.name}"


# --- digests (MS-10.4, ADR-0012) -----------------------------------------------------------------


def context_digest() -> str:
    h = hashlib.sha256()
    for f in tf_files(CONTEXT_MODULE):
        h.update(f.relative_to(CONTEXT_MODULE).as_posix().encode() + b"\0")
        h.update(f.read_bytes() + b"\0")
    return h.hexdigest()


def write_digests() -> None:
    digest = context_digest() + "\n"
    for module in public_modules():
        (module / ".context-digest").write_text(digest, encoding="utf-8")
        print(f"wrote {(module / '.context-digest').relative_to(ROOT)}")


# --- checks ---------------------------------------------------------------------------------------


def check_structure(module: Path, public: bool) -> None:
    for name in REQUIRED_FILES:
        if not (module / name).exists():
            fail("MS-1.4", module, f"missing {name}")
    if not list((module / "tests").glob("*.tftest.hcl")):
        fail("MS-1.4", module, "missing tests/*.tftest.hcl")
    if public:
        for name in REQUIRED_PUBLIC:
            if not (module / name).exists():
                fail("MS-1.4", module, f"missing {name}")


def check_module_code(module: Path, public: bool) -> None:
    files = tf_files(module)
    text = {f: read(f) for f in files}

    for f, body in text.items():
        if re.search(r'(?m)^\s*provider\s+"', body):
            fail("MS-6.5", f, "provider block in a module")
        if re.search(r'(?m)^\s*backend\s+"', body):
            fail("MS-1.1", f, "backend block in a module")
        if "google_service_account_key" in body:
            fail("MS-6.1", f, "creates a service-account key")
        # Strings are stripped first: a description may mention context.environment; code may not.
        if public and re.search(r"\bcontext\.environment\b", re.sub(r'"(?:[^"\\]|\\.)*"', '""', body)):
            fail("MS-3.5", f, "branches on context.environment")

        for name, vbody in blocks(body, "variable"):
            t = type_expr(vbody)
            if not t:
                fail("MS-2.1", f, f"variable {name} has no type")
            elif re.search(r"(^|[(,\s])any($|[),\s])", t):
                fail("MS-2.1", f, f"variable {name} uses any")
            if not attr_present(vbody, "description"):
                fail("MS-2.1", f, f"variable {name} has no description")
            if SECRET_NAME.search(name) and not (
                attr_present(vbody, "ephemeral") or "Secret Manager reference" in vbody
            ):
                fail("MS-6.2", f, f"variable {name} looks like a secret value; take a Secret Manager reference or make it ephemeral")

        for name, obody in blocks(body, "output"):
            if not attr_present(obody, "description"):
                fail("MS-8.1", f, f"output {name} has no description")

    if not public:
        return

    variables_tf = module / "variables.tf"
    if variables_tf.exists():
        declared = blocks(read(variables_tf), "variable")
        names = [n for n, _ in declared]
        if tuple(names[:3]) != LEADING_INPUTS:
            fail("MS-2.2", variables_tf, f"first inputs must be {', '.join(LEADING_INPUTS)}; found {', '.join(names[:3])}")
        ctx = dict(declared).get("context")
        if ctx is not None and type_expr(ctx) != CONTEXT_TYPE:
            fail("MS-2.2", variables_tf, "context type differs from the standard shape")

    calls = [
        (f, b)
        for f, body in text.items()
        for name, b in blocks(body, "module")
        if name == "context"
    ]
    if len(calls) != 1 or '"../../_internal/context"' not in calls[0][1]:
        fail("MS-3.1", module, 'must call module "context" exactly once from ../../_internal/context')
    elif f'"{module_id(module)}"' not in calls[0][1]:
        fail("MS-3.1", module, f'module "context" must pass module = "{module_id(module)}"')

    digest_file = module / ".context-digest"
    if digest_file.exists() and digest_file.read_text(encoding="utf-8").strip() != context_digest():
        fail("MS-10.4", digest_file, "stale; run python3 scripts/check_invariants.py --write-digests")


def env_literal(path: Path, pattern: str) -> list[str] | None:
    m = re.search(pattern, path.read_text(encoding="utf-8"))
    if not m:
        return None
    return re.findall(r'"([^"]+)"', m.group(1)) or m.group(1).replace("|", " ").split()


def check_contracts() -> None:
    contracts = sorted((ROOT / "contracts").glob("*.json"))
    for c in contracts:
        raw = c.read_text(encoding="utf-8")
        canonical = json.dumps(json.loads(raw), indent=2, sort_keys=True, ensure_ascii=False) + "\n"
        if raw != canonical:
            fail("contract", c, "not in canonical byte form (two-space, sorted keys, one trailing newline)")

    env_contract = json.loads((ROOT / "contracts/environments.v1.json").read_text(encoding="utf-8"))
    envs = env_contract["environments"]

    holders = {
        CONTEXT_MODULE / "variables.tf": r"coalesce\(var\.context\.allowed_environments,\s*\[([^\]]+)\]\),\s*var\.context\.environment\)",
        ROOT / "templates/root-gcp/variables.tf": r"contains\(\[([^\]]+)\],\s*var\.environment\)",
        ROOT / "templates/root-gcp/scripts/tf.sh": r"\n\s*([a-z| ]+)\)\s*;;\n",
    }
    for path, pattern in holders.items():
        found = env_literal(path, pattern)
        if found != envs:
            fail("ADR-0002", path, f"environment list {found} differs from contracts/environments.v1.json {envs}")

    libs = os.environ.get("PLATFORM_LIBS_DIR")
    if libs:
        source = Path(libs) / env_contract["source"]["path"]
        upstream = json.loads(source.read_text(encoding="utf-8"))
        for key in ("environments", "strict_environments"):
            if upstream.get(key) != env_contract[key]:
                fail("ADR-0002", "contracts/environments.v1.json", f"{key} differs from lib-platform {env_contract['source']['path']}")


def check_public_ready() -> None:
    for base in (MODULES, ROOT / "templates"):
        for f in sorted(base.rglob("*")):
            if not f.is_file() or ".terraform" in f.parts or f.suffix not in PUBLIC_SUFFIXES:
                continue
            for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
                if ORG_STRINGS.search(line.replace(OWN_SOURCE, "")):
                    fail("MS-15.1", f, f"line {n} names the organisation; use a neutral value (acme, example.com)")


def check_no_internal_identifiers() -> None:
    this_file = Path(__file__).resolve()
    for f in sorted(ROOT.rglob("*")):
        if not f.is_file() or f.resolve() == this_file:
            continue
        if any(part in (".git", ".terraform", ".gate-tmp") for part in f.parts):
            continue
        try:
            text = f.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for n, line in enumerate(text.splitlines(), 1):
            m = INTERNAL_IDS.search(line)
            if m:
                fail("MS-15.1", f, f"line {n} carries an internal identifier ({m.group(0)!r}); keep it in the private docs repository")


# MS-5.4 / ADR-0011: resources whose provider destroy writes back to a live singleton keep a
# literal prevent_destroy. terraform test can't assert a prevent_destroy refusal (expect_failures
# doesn't catch it), so the gate checks the configuration instead.
REQUIRE_PREVENT_DESTROY = {
    "modules/github/org-settings": (
        "github_organization_settings",
        "github_actions_organization_permissions",
        "github_actions_organization_workflow_permissions",
    ),
}


def check_prevent_destroy() -> None:
    for module, resource_types in REQUIRE_PREVENT_DESTROY.items():
        text = "".join(read(f) for f in tf_files(ROOT / module))
        for rtype in resource_types:
            bodies = [b for name, b in blocks(text, "resource") if name == rtype]
            if not bodies:
                fail("MS-5.4", module, f"{rtype} not found")
            elif not all(re.search(r"\bprevent_destroy\s*=\s*true\b", b) for b in bodies):
                fail("MS-5.4", module, f"{rtype} must keep a literal prevent_destroy = true (ADR-0011)")


def check_release_config() -> None:
    config = json.loads((ROOT / "release-please-config.json").read_text(encoding="utf-8"))
    manifest = json.loads((ROOT / ".release-please-manifest.json").read_text(encoding="utf-8"))
    packages = config.get("packages", {})
    for module in public_modules():
        key = module.relative_to(ROOT).as_posix()
        if packages.get(key, {}).get("component") != module_id(module):
            fail("MS-10.1", "release-please-config.json", f'{key} needs a package with component "{module_id(module)}"')
        if key not in manifest:
            fail("MS-10.1", ".release-please-manifest.json", f"{key} missing")
    for key in packages:
        if not (ROOT / key).is_dir() or key.startswith("modules/_internal"):
            fail("MS-10.1", "release-please-config.json", f"{key} is not a releasable module")


def check_trivyignore() -> None:
    """MS-9.4: every suppression is path-scoped and carries a statement. Parsed without a YAML
    library: each `- id:` entry must be followed, before the next entry, by `paths:` and
    `statement:` keys."""
    path = ROOT / ".trivyignore.yaml"
    if (ROOT / ".trivyignore").exists():
        fail("MS-9.4", ROOT / ".trivyignore", "use .trivyignore.yaml so each suppression is path-scoped")
    if not path.exists():
        return
    entries = re.split(r"(?m)^\s*- id:", path.read_text(encoding="utf-8"))[1:]
    for entry in entries:
        rule = entry.split("\n", 1)[0].strip()
        if not re.search(r"(?m)^\s+paths:\s*$\n\s+- \S", entry):
            fail("MS-9.4", path, f"{rule} is not scoped to paths")
        if not re.search(r"(?m)^\s+statement:\s*\S", entry):
            fail("MS-9.4", path, f"{rule} has no statement")


def check_adr_index() -> None:
    adr_dir = ROOT / "docs/adr"
    index = (adr_dir / "README.md").read_text(encoding="utf-8")
    for f in sorted(adr_dir.glob("[0-9][0-9][0-9][0-9]-*.md")):
        status = re.search(r"(?m)^Status: (.+)$", f.read_text(encoding="utf-8"))
        row = re.search(rf"(?m)^\| \[{f.name[:4]}\]\({re.escape(f.name)}\) \| .* \| (.+) \|$", index)
        if not row:
            fail("ADR", f, "has no row in docs/adr/README.md")
        elif not status or status.group(1).strip() != row.group(1).strip():
            fail("ADR", f, "status line differs from its index row")


def main() -> int:
    if "--write-digests" in sys.argv[1:]:
        write_digests()
        return 0

    check_structure(CONTEXT_MODULE, public=False)
    check_module_code(CONTEXT_MODULE, public=False)
    for module in public_modules():
        check_structure(module, public=True)
        check_module_code(module, public=True)
    check_contracts()
    check_public_ready()
    check_no_internal_identifiers()
    check_prevent_destroy()
    check_release_config()
    check_trivyignore()
    check_adr_index()

    if failures:
        print("\n".join(failures))
        print(f"\ninvariants: {len(failures)} failed")
        return 1
    print(f"invariants: ok ({len(public_modules())} public module(s), contracts, release config, ADR index)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
