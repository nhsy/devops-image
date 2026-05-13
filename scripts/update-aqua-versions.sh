#!/bin/bash
set -euo pipefail

AQUA_FILE="${1:-aqua.yaml}"

fetch_latest_tag() {
  local repo=$1
  curl -sL "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name'
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
