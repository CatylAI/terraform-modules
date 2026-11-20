#!/usr/bin/env bash
# The one test command (module-standard MS-9). CI runs exactly this script; run it before pushing.
#
#   scripts/gate.sh          check everything
#   scripts/gate.sh --fix    apply fmt, regenerate README docs and .context-digest files, then check
#
# Every step runs even after a failure, so one run reports every problem. A missing tool fails
# the gate: a check that cannot run is not a check that passed.
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo"

failed=()
step() { # <name> <command...>
  local name="$1"
  shift
  printf '\n== %s\n' "$name"
  if "$@"; then
    printf -- '-- %s: ok\n' "$name"
  else
    printf -- '-- %s: FAILED\n' "$name"
    failed+=("$name")
  fi
}

modules=()
while IFS= read -r d; do modules+=("$d"); done < <(
  find modules -mindepth 2 -maxdepth 2 -type d ! -path '*/.terraform*' | sort |
    while read -r d; do ls "$d"/*.tf >/dev/null 2>&1 && echo "$d"; done
)
examples=()
while IFS= read -r d; do examples+=("$d"); done < <(find modules -path '*/examples/*' -mindepth 4 -maxdepth 4 -type d ! -path '*/.terraform*' | sort)

export TF_IN_AUTOMATION=1
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

tools() {
  local ok=0 want got
  for t in terraform tflint trivy terraform-docs python3; do
    command -v "$t" >/dev/null || {
      echo "missing tool: $t (CI installs pinned versions with scripts/install-tools.sh)"
      ok=1
    }
  done
  want="$(cat .terraform-version)"
  got="$(terraform version -json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["terraform_version"])' 2>/dev/null || true)"
  if [[ "$got" != "$want" ]]; then
    echo "terraform $got does not match .terraform-version $want"
    ok=1
  fi
  return $ok
}

fix() {
  terraform fmt -recursive modules templates
  for m in ${modules[@]+"${modules[@]}"}; do terraform-docs -c .terraform-docs.yml "$m" >/dev/null; done
  python3 scripts/check_invariants.py --write-digests
}

fmt() { terraform fmt -check -recursive -diff modules templates; }

module_tests() {
  local rc=0 m out
  for m in ${modules[@]+"${modules[@]}"}; do
    echo "-- $m"
    out="$(cd "$m" && {
      terraform init -backend=false -input=false -no-color >/dev/null &&
        terraform validate -no-color >/dev/null &&
        terraform test -no-color
    } 2>&1)" || rc=1
    # Show only what did not pass, plus the verdict line.
    printf '%s\n' "$out" | grep -E 'run "|Success!|Failure!|Error' | grep -vE '\.\.\. pass$' || true
    # Command substitution reads the whole pipe; `| grep -q` would exit at the first match and
    # can SIGPIPE `tail` under pipefail.
    [[ "$(printf '%s\n' "$out" | tail -1)" == Success!* ]] || rc=1
  done
  return $rc
}

examples_validate() {
  local rc=0 e
  for e in ${examples[@]+"${examples[@]}"}; do
    (cd "$e" && terraform init -backend=false -input=false -no-color >/dev/null &&
      terraform validate -no-color >/dev/null && echo "ok    $e") || {
      echo "FAIL  $e"
      rc=1
    }
  done
  return $rc
}

# The template sources modules by git tag; validate it against this checkout's modules instead,
# so a template change and a module change are tested together. The copy must sit inside the
# repository and use a relative path: an absolute path makes Terraform treat the module directory
# as its own package, and then `../../_internal/context` "escapes the module package". A real
# git::...//modules/<p>/<m>?ref= source downloads the whole repository as the package.
template_validate() {
  local tmp="$repo/.gate-tmp/root-gcp" rc=0
  rm -rf "$repo/.gate-tmp" # claude-allow-rm-rf: gate scratch dir, gitignored
  mkdir -p "$tmp"
  cp -R templates/root-gcp/. "$tmp/"
  sed -i.bak -E 's#git::https://github.com/CatylAI/terraform-modules.git//(modules/[^?"]+)\?ref=[^"]+#../../\1#' "$tmp"/*.tf
  (cd "$tmp" && terraform init -backend=false -input=false -no-color >/dev/null && terraform validate -no-color) || rc=1
  rm -rf "$repo/.gate-tmp" # claude-allow-rm-rf: gate scratch dir, gitignored
  return $rc
}

lint() {
  tflint --init --config="$repo/.tflint.hcl" >/dev/null || return 1
  local rc=0 d
  for d in ${modules[@]+"${modules[@]}"} ${examples[@]+"${examples[@]}"}; do
    tflint --chdir="$d" --config="$repo/.tflint.hcl" --format=compact --minimum-failure-severity=warning || rc=1
  done
  return $rc
}

scan() {
  # trivy takes one target; scan the repository and skip what is not Terraform we ship.
  trivy config --quiet --exit-code 1 --ignorefile .trivyignore.yaml \
    --skip-dirs '**/.terraform' --skip-dirs docs --skip-dirs contracts --skip-dirs .gate-tmp .
}

docs() {
  local rc=0 m
  for m in ${modules[@]+"${modules[@]}"}; do
    terraform-docs -c .terraform-docs.yml --output-check "$m" >/dev/null || {
      echo "README drift in $m; run scripts/gate.sh --fix"
      rc=1
    }
  done
  return $rc
}

if [[ "${1:-}" == "--fix" ]]; then
  step "fix" fix
fi
step "tools" tools
step "fmt" fmt
step "invariants" python3 scripts/check_invariants.py
step "tf.sh tests" bash scripts/test_tf_sh.sh
step "module validate + test" module_tests
step "examples validate" examples_validate
step "template validate" template_validate
step "tflint" lint
step "trivy" scan
step "docs" docs

if ((${#failed[@]})); then
  printf '\ngate: FAILED (%s)\n' "${failed[*]}"
  exit 1
fi
printf '\ngate: ok\n'
