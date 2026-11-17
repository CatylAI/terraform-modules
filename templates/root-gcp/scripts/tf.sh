#!/usr/bin/env bash
# The only entry point to this root (module-standard MS-11, ADR-0003).
#
#   scripts/tf.sh <env> init [args]
#   scripts/tf.sh <env> validate [args]
#   scripts/tf.sh <env> plan [args]          writes <env>.tfplan unless args give -out; exit code
#                                            passes through, so -detailed-exitcode works
#   scripts/tf.sh <env> apply [planfile]     default <env>.tfplan; no var files (a saved plan
#                                            carries them)
#   scripts/tf.sh <env> output [args]
#
# It always passes envs/common.tfvars, envs/<env>.tfvars, -var environment=<env> and
# envs/<env>.gcs.tfbackend. TF_BACKEND_IMPERSONATE_SA, when set, overrides the backend's
# impersonated service account (CI sets it to the stack's own SA). It refuses the cases that
# quietly do damage:
#   64  usage: unknown environment, missing file, unknown command, extra apply arguments
#   78  unsafe configuration: local state present, backend prefix not ending in /<env>,
#       `environment` set in a tfvars file
#   77  apply refused: outside CI without TF_BREAK_GLASS=1, or no saved plan
# These are sysexits.h codes, chosen because Terraform never uses them: with -detailed-exitcode,
# Terraform's 0, 1 and 2 (no changes, error, changes) pass through unchanged.
set -euo pipefail

usage() {
  echo "usage: scripts/tf.sh <env> <init|validate|plan|apply|output> [terraform args]" >&2
  exit 64
}
[[ $# -ge 2 ]] || usage
env="$1"
cmd="$2"
shift 2

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

case "$env" in
  local | test | dev | uat | staging | prod) ;;
  *)
    echo "tf.sh: unknown environment '$env'; expected local, test, dev, uat, staging or prod" >&2
    exit 64
    ;;
esac

backend="envs/${env}.gcs.tfbackend"
env_vars="envs/${env}.tfvars"
for f in envs/common.tfvars "$env_vars" "$backend"; do
  [[ -f "$f" ]] || {
    echo "tf.sh: missing $f" >&2
    exit 64
  }
done

if [[ -f terraform.tfstate ]]; then
  echo "tf.sh: refusing to run: terraform.tfstate exists here, so an earlier init fell back to" >&2
  echo "       local state. Move it aside, then run: scripts/tf.sh $env init" >&2
  exit 78
fi

prefix="$(sed -nE 's/^[[:space:]]*prefix[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$backend")"
if [[ "$prefix" != */"$env" ]]; then
  echo "tf.sh: $backend has prefix '$prefix'; it must end in /$env" >&2
  exit 78
fi

if grep -qE '^[[:space:]]*environment[[:space:]]*=' envs/common.tfvars "$env_vars"; then
  echo "tf.sh: 'environment' is set in a tfvars file; it comes from the command line only (MS-11.2)" >&2
  exit 78
fi

var_args=("-var-file=envs/common.tfvars" "-var-file=$env_vars" "-var=environment=$env")
plan_file="${env}.tfplan"

init() {
  local sa_arg=()
  [[ -n "${TF_BACKEND_IMPERSONATE_SA:-}" ]] && sa_arg=("-backend-config=impersonate_service_account=$TF_BACKEND_IMPERSONATE_SA")
  terraform init -reconfigure -input=false "-backend-config=$backend" ${sa_arg[@]+"${sa_arg[@]}"} "$@"
}

case "$cmd" in
  init) init "$@" ;;
  validate) terraform validate "$@" ;;
  plan)
    init >/dev/null
    out_arg=("-out=$plan_file")
    for a in "$@"; do [[ "$a" == -out=* ]] && out_arg=(); done
    terraform plan -input=false "${var_args[@]}" ${out_arg[@]+"${out_arg[@]}"} "$@"
    ;;
  apply)
    if [[ "${CI:-}" != "true" && "${TF_BREAK_GLASS:-}" != "1" ]]; then
      echo "tf.sh: apply runs in CI. A break-glass apply needs TF_BREAK_GLASS=1 and a record of why." >&2
      exit 77
    fi
    [[ $# -le 1 ]] || {
      echo "tf.sh: apply takes at most one argument, the plan file" >&2
      exit 64
    }
    plan_file="${1:-$plan_file}"
    [[ -f "$plan_file" ]] || {
      echo "tf.sh: no $plan_file; run: scripts/tf.sh $env plan" >&2
      exit 77
    }
    init >/dev/null
    terraform apply -input=false "$plan_file"
    ;;
  output)
    init >/dev/null
    terraform output "$@"
    ;;
  *) usage ;;
esac
