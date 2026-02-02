#!/bin/sh
set -e
echo "Running Unit Tests..."
echo "Shell: $SHELL"
ansible --version
kubectl version --client
python3 --version
terraform version
terraform-docs version
terragrunt -version
tflint --version
packer version
echo "All tests passed!"