#!/bin/bash
set -euo pipefail

# Cleanup old image tags from Docker Hub (keeps N most recent)
# Usage: ./cleanup-docker-hub.sh [NAMESPACE] [REPO] [KEEP_COUNT]
# Environment: DOCKERHUB_USERNAME, DOCKERHUB_TOKEN required

NAMESPACE="${1:-}"
REPO="${2:-}"
KEEP_COUNT="${3:-5}"

if [[ -z "$NAMESPACE" ]] || [[ -z "$REPO" ]]; then
  echo "Usage: $0 <namespace> <repository> [keep_count]"
  echo "Keep count defaults to 5 (keeps 5 most recent tags)"
  echo "Environment variables required: DOCKERHUB_USERNAME, DOCKERHUB_TOKEN"
  exit 1
fi

if [[ -z "${DOCKERHUB_USERNAME:-}" ]] || [[ -z "${DOCKERHUB_TOKEN:-}" ]]; then
  echo "Error: DOCKERHUB_USERNAME and DOCKERHUB_TOKEN environment variables not set"
  exit 1
fi

# Get auth token
AUTH_TOKEN=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$DOCKERHUB_USERNAME\", \"password\": \"$DOCKERHUB_TOKEN\"}" \
  "https://hub.docker.com/v2/users/login" | jq -r '.token')

if [[ -z "$AUTH_TOKEN" ]] || [[ "$AUTH_TOKEN" == "null" ]]; then
  echo "Error: Failed to authenticate with Docker Hub"
  exit 1
fi

echo "Authenticated with Docker Hub"
echo "Removing old tags from $NAMESPACE/$REPO (keeping $KEEP_COUNT most recent)"

DELETED_COUNT=0

# Fetch all tags, sort by date, skip the keep_count most recent and 'latest' tag
TAGS=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" \
  "https://hub.docker.com/v2/repositories/$NAMESPACE/$REPO/tags/?page_size=100" | \
  jq -r '.results | sort_by(.last_updated) | reverse | .[].name')

TAG_COUNT=0
for TAG in $TAGS; do
  # Skip 'latest' tag
  if [[ "$TAG" == "latest" ]]; then
    continue
  fi

  TAG_COUNT=$((TAG_COUNT + 1))

  # Delete if we've kept enough
  if [[ $TAG_COUNT -gt $KEEP_COUNT ]]; then
    echo "Deleting tag: $TAG"

    DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE \
      -H "Authorization: Bearer $AUTH_TOKEN" \
      "https://hub.docker.com/v2/repositories/$NAMESPACE/$REPO/tags/$TAG/")

    HTTP_CODE=$(echo "$DELETE_RESPONSE" | tail -n 1)

    if [[ "$HTTP_CODE" == "204" ]]; then
      ((DELETED_COUNT++))
    else
      echo "  ⚠ Failed to delete tag (HTTP $HTTP_CODE)"
    fi
  fi
done

echo "Successfully deleted $DELETED_COUNT tag(s)"
