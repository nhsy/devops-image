#!/bin/sh
# The single source of truth for "are the tools in this image actually there".
# Runs during the image build (Dockerfile layer 5), from the CI verify job, and
# from `task test:base` / `test:gcp` / `test:aws`, so all four check the same
# list instead of drifting apart. Stage-specific tools (gcloud, aws) are checked
# by the caller, since they do not exist in the base stage.
set -eu

echo "Running Unit Tests..."
echo "Shell: ${SHELL:-not set}"

git --version
python3 --version
kubectl version --client
terraform version
terraform-docs version
terragrunt -version
tflint --version
packer version
task --version

echo "All tests passed!"
