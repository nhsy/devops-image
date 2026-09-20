#!/bin/bash
set -euo pipefail

AQUA_FILE="${1:-aqua.yaml}"

fetch_latest_tag() {
  local repo=$1
  local tag

  # Unauthenticated, so no token or setup is needed to run this. That caps it at
  # 60 requests/hour per IP and this makes eight, which is ample for a script
  # someone runs by hand. If the cap is ever hit the check below turns it into a
  # clear failure to retry, not a corrupted file.
  tag=$(curl -sL "https://api.github.com/repos/${repo}/releases/latest" \
    | jq -r '.tag_name // empty')

  # Anything that is not a release tag - a rate-limit body, an error, a network
  # failure - arrives here as empty or as junk. Refuse it. jq exits 0 on an
  # error object, so `set -o pipefail` does not catch this on its own, and
  # without the check the caller's sed writes the literal string "null" into
  # aqua.yaml as a version.
  if [[ ! "$tag" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: no valid release tag for ${repo} (got: '${tag:-<empty>}')" >&2
    return 1
  fi

  printf '%s\n' "$tag"
}

update_package() {
  local package=$1
  local gh_repo=$2
  local tag
  tag=$(fetch_latest_tag "${gh_repo}")
  echo "  ${package}: ${tag}"
  sed -i "s|name: ${package}@.*|name: ${package}@${tag}|" "${AQUA_FILE}"
}

update_registry_ref() {
  local tag
  tag=$(fetch_latest_tag "aquaproj/aqua-registry")
  echo "  registry ref: ${tag}"
  sed -i "s|ref: v[0-9]*\.[0-9]*\.[0-9]*|ref: ${tag}|" "${AQUA_FILE}"
}

echo "Updating ${AQUA_FILE}..."

update_registry_ref
update_package "hashicorp/terraform"        "hashicorp/terraform"
update_package "gruntwork-io/terragrunt"    "gruntwork-io/terragrunt"
update_package "terraform-linters/tflint"   "terraform-linters/tflint"
update_package "hashicorp/packer"           "hashicorp/packer"
update_package "kubernetes/kubectl"         "kubernetes/kubernetes"
update_package "terraform-docs/terraform-docs" "terraform-docs/terraform-docs"
update_package "go-task/task"              "go-task/task"

echo "Done."
