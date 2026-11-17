#!/usr/bin/env bash
# Tests templates/root-gcp/scripts/tf.sh against a stub `terraform` that records its arguments.
# Each case copies the template into a fresh temp dir, so cases cannot leak state into each other.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT # claude-allow-rm-rf: a mktemp dir this script created

stub_bin="$work/bin"
mkdir -p "$stub_bin"
cat >"$stub_bin/terraform" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TF_STUB_LOG"
STUB
chmod +x "$stub_bin/terraform"

failures=0

# Called as $(fresh_root), i.e. in a subshell, so it must not rely on a counter: mktemp gives every
# case its own directory.
fresh_root() {
  local dir
  dir="$(mktemp -d "$work/case.XXXXXX")"
  cp -R "$repo/templates/root-gcp/." "$dir/"
  echo "$dir"
}

expect_exit() { # <description> <expected-exit> <root> <args...>
  local desc="$1" want="$2" root="$3"
  shift 3
  local log="$root/stub.log" got=0
  : >"$log"
  (cd "$root" && PATH="$stub_bin:$PATH" TF_STUB_LOG="$log" CI="${CI_OVERRIDE:-}" \
    TF_BACKEND_IMPERSONATE_SA="${SA_OVERRIDE:-}" scripts/tf.sh "$@") >/dev/null 2>&1 || got=$?
  if [[ "$got" == "$want" ]]; then
    echo "ok    $desc"
  else
    echo "FAIL  $desc: exit $got, want $want"
    failures=$((failures + 1))
  fi
}

expect_log() { # <description> <root> <pattern>
  local desc="$1" root="$2" pattern="$3"
  if grep -qE -- "$pattern" "$root/stub.log"; then
    echo "ok    $desc"
  else
    echo "FAIL  $desc: no stub call matching /$pattern/ in:"
    sed 's/^/        /' "$root/stub.log"
    failures=$((failures + 1))
  fi
}

r="$(fresh_root)"
expect_exit "rejects an environment outside the contract" 64 "$r" production plan
expect_exit "rejects a missing env file" 64 "$r" dev plan
expect_exit "rejects an unknown command" 64 "$r" uat destroy

r="$(fresh_root)"
expect_exit "plan succeeds for uat" 0 "$r" uat plan
expect_log "plan inits with the uat backend file" "$r" '^init -reconfigure -input=false -backend-config=envs/uat\.gcs\.tfbackend$'
expect_log "plan passes common, env and environment var" "$r" '^plan -input=false -var-file=envs/common\.tfvars -var-file=envs/uat\.tfvars -var=environment=uat -out=uat\.tfplan$'

r="$(fresh_root)"
touch "$r/terraform.tfstate"
expect_exit "refuses when local state exists" 78 "$r" uat plan

r="$(fresh_root)"
sed -i.bak 's#example-repo/example/uat#example-repo/example/prod#' "$r/envs/uat.gcs.tfbackend"
expect_exit "refuses a backend prefix for another environment" 78 "$r" uat plan

r="$(fresh_root)"
echo 'environment = "prod"' >>"$r/envs/uat.tfvars"
expect_exit "refuses environment set in tfvars" 78 "$r" uat plan

r="$(fresh_root)"
touch "$r/uat.tfplan"
CI_OVERRIDE="" expect_exit "refuses apply outside CI" 77 "$r" uat apply
CI_OVERRIDE="true" expect_exit "apply runs in CI with a saved plan" 0 "$r" uat apply
expect_log "apply uses the saved plan" "$r" '^apply -input=false uat\.tfplan$'

r="$(fresh_root)"
CI_OVERRIDE="true" expect_exit "refuses apply without a saved plan" 77 "$r" uat apply

r="$(fresh_root)"
touch "$r/custom.tfplan"
CI_OVERRIDE="true" expect_exit "apply accepts an explicit plan file" 0 "$r" uat apply custom.tfplan
expect_log "apply uses the explicit plan file and no var files" "$r" '^apply -input=false custom\.tfplan$'
CI_OVERRIDE="true" expect_exit "apply rejects extra arguments" 64 "$r" uat apply custom.tfplan -auto-approve

r="$(fresh_root)"
expect_exit "plan honours a caller -out" 0 "$r" uat plan -out=ci.tfplan -detailed-exitcode
expect_log "plan uses the caller -out only" "$r" '^plan -input=false -var-file=envs/common\.tfvars -var-file=envs/uat\.tfvars -var=environment=uat -out=ci\.tfplan -detailed-exitcode$'

r="$(fresh_root)"
SA_OVERRIDE="terraform-orders@acme-tf-seed.iam.gserviceaccount.com" expect_exit "init with a CI service account" 0 "$r" uat init
expect_log "init overrides the backend SA when TF_BACKEND_IMPERSONATE_SA is set" "$r" '^init -reconfigure -input=false -backend-config=envs/uat\.gcs\.tfbackend -backend-config=impersonate_service_account=terraform-orders@acme-tf-seed\.iam\.gserviceaccount\.com$'

r="$(fresh_root)"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"$TF_STUB_LOG"\n[[ "$1" == plan ]] && exit 2\nexit 0\n' >"$stub_bin/terraform"
expect_exit "plan passes terraform's exit code through (-detailed-exitcode 2 = changes)" 2 "$r" uat plan -detailed-exitcode

if [[ "$failures" -gt 0 ]]; then
  echo "tf.sh tests: $failures failed"
  exit 1
fi
echo "tf.sh tests: all passed"
