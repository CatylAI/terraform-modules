#!/usr/bin/env bash
# Installs the gate's tools at pinned versions, verified against the upstream SHA-256 checksums,
# into $1 (default ~/.local/bin). Linux amd64 and arm64 only; used by CI. Each pin is at least
# two weeks old when chosen, to stay clear of freshly published releases.
# Terraform comes from hashicorp/setup-terraform in CI and from tfenv locally.
set -euo pipefail

dest="${1:-$HOME/.local/bin}"
mkdir -p "$dest"
case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) echo "install-tools: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac

TFLINT_VERSION=0.65.0
TRIVY_VERSION=0.76.1
TFDOCS_VERSION=0.24.0
declare -A SUM=(
  [tflint-amd64]=d4c545ed2e29d6338604b586f34f544f380f70f243aa72f7b484713835eaec61
  [tflint-arm64]=843017c47a98be1de4d88fa038daa293770fe25cd01656c4f08b2e30d1d3b3a0
  [trivy-amd64]=c7cbe3137fb8a48a17574bede3dd6beb16742d1e9772929940fc90082c39d9c0
  [trivy-arm64]=e174dff2a6dba5e3ae41f8d0537a6324405bd08132497340304c6b20e0f16a1f
  [tfdocs-amd64]=9005daf969de0b50134493a2c00078b49f5f5b39d021cda7c89bf4d4f3d776d3
  [tfdocs-arm64]=d12bd7b73c1fc9c64efc79f8157dd713dabd559f1ecf3cfc0f42e32279a155fd
)
trivy_arch=$([[ $arch == amd64 ]] && echo 64bit || echo ARM64)

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT # claude-allow-rm-rf: mktemp dir created above

fetch() { # <key> <url> <file>
  curl -fsSL --retry 3 -o "$work/$3" "$2"
  echo "${SUM[$1]}  $work/$3" | sha256sum -c - >/dev/null
  echo "verified $3"
}

fetch "tflint-$arch" "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${arch}.zip" tflint.zip
unzip -oq "$work/tflint.zip" tflint -d "$work" && install -m 0755 "$work/tflint" "$dest/tflint"

fetch "trivy-$arch" "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${trivy_arch}.tar.gz" trivy.tgz
tar -xzf "$work/trivy.tgz" -C "$work" trivy && install -m 0755 "$work/trivy" "$dest/trivy"

fetch "tfdocs-$arch" "https://github.com/terraform-docs/terraform-docs/releases/download/v${TFDOCS_VERSION}/terraform-docs-v${TFDOCS_VERSION}-linux-${arch}.tar.gz" tfdocs.tgz
tar -xzf "$work/tfdocs.tgz" -C "$work" terraform-docs && install -m 0755 "$work/terraform-docs" "$dest/terraform-docs"

"$dest/tflint" --version | head -1
"$dest/trivy" --version | head -1
"$dest/terraform-docs" --version
