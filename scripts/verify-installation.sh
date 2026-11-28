#!/bin/sh
# The single source of truth for "are the tools in this image actually there".
# Runs during the image build (Dockerfile layer 6), from the CI verify job, and
# from `task test:base` / `test:gcp` / `test:aws`, so all four check the same
# list instead of drifting apart. Stage-specific tools (gcloud, aws) are checked
# by the caller, since they do not exist in the base stage.
set -eu

echo "Running Unit Tests..."
echo "Shell: ${SHELL:-not set}"

# devops must be UID/GID 1000 to match the host user in bind mounts.
devops_uid="$(id -u devops)"
devops_gid="$(id -g devops)"
echo "devops uid/gid: ${devops_uid}/${devops_gid}"
if [ "$devops_uid" != 1000 ] || [ "$devops_gid" != 1000 ]; then
  echo "devops user must be UID/GID 1000" >&2
  exit 1
fi

# devops must own the aqua root (cache, timestamps, a project's own aqua.yaml
# packages) and terraform's plugin cache, all the way down: one root-owned
# file, such as aqua's registry cache, is enough to break it.
for dir in "${AQUA_ROOT_DIR:?}" "${TF_PLUGIN_CACHE_DIR:?}"; do
  not_owned="$(find "$dir" ! -user devops -print -quit)"
  if [ -n "$not_owned" ]; then
    echo "not owned by devops: $not_owned" >&2
    exit 1
  fi
  echo "owned by devops: $dir"
done

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
