#!/usr/bin/env bash
# ==============================================================================
# Script: sync-internal-mirror.sh
# Purpose: Synchronize public github.com/ibm-mas/gitops to internal IBM GHE
#          (github.ibm.com/automation-paas-cd-pipeline/mas-gitops) using
#          native Git ref mirroring (pull model).
#
# Usage:
#   ./sync-internal-mirror.sh [OPTIONS]
#
# Options:
#   --dry-run              Run git push with --dry-run
#   --source <repo>        Source repo (default: ibm-mas/gitops)
#   --target <repo>        Target repo (default: automation-paas-cd-pipeline/mas-gitops)
#   --ghe-host <host>      GHE host (default: github.ibm.com)
#   --ghe-token <token>    GHE token (can also be set via GHE_TOKEN env var)
#   --public-token <token> GitHub token (can also be set via PUBLIC_TOKEN env var)
#   -h, --help             Show this help message
#
# Environment variables:
#   SOURCE_REPO  (default: "ibm-mas/gitops")
#   TARGET_REPO  (default: "automation-paas-cd-pipeline/mas-gitops")
#   GHE_HOST     (default: "github.ibm.com")
#   GHE_TOKEN    (required: PAT or Functional ID token with repo & workflow scope)
#   PUBLIC_TOKEN (optional: token for public GitHub, unauthenticated if not set)
# ==============================================================================

set -euo pipefail

SOURCE_REPO="${SOURCE_REPO:-ibm-mas/gitops}"
TARGET_REPO="${TARGET_REPO:-automation-paas-cd-pipeline/mas-gitops}"
GHE_HOST="${GHE_HOST:-github.ibm.com}"
PUBLIC_TOKEN="${PUBLIC_TOKEN:-}"
GHE_TOKEN="${GHE_TOKEN:-}"
DRY_RUN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN="--dry-run"
      shift
      ;;
    --source)
      SOURCE_REPO="$2"
      shift 2
      ;;
    --target)
      TARGET_REPO="$2"
      shift 2
      ;;
    --ghe-host)
      GHE_HOST="$2"
      shift 2
      ;;
    --ghe-token)
      GHE_TOKEN="$2"
      shift 2
      ;;
    --public-token)
      PUBLIC_TOKEN="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,24p' "$0" | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${GHE_TOKEN}" ]]; then
  echo "ERROR: GHE_TOKEN environment variable or --ghe-token argument is required to authenticate against ${GHE_HOST}." >&2
  exit 1
fi

# Configure temporary working directory
WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

cd "${WORK_DIR}"

# Build source clone URL (public GitHub or direct path/URL)
if [[ "${SOURCE_REPO}" =~ ^(https?://|/|\.) ]]; then
  SOURCE_URL="${SOURCE_REPO}"
elif [[ -n "${PUBLIC_TOKEN}" ]]; then
  SOURCE_URL="https://x-access-token:${PUBLIC_TOKEN}@github.com/${SOURCE_REPO}.git"
else
  SOURCE_URL="https://github.com/${SOURCE_REPO}.git"
fi

# Build target URL (internal GHE or direct path/URL)
if [[ "${TARGET_REPO}" =~ ^(https?://|/|\.) ]]; then
  TARGET_URL="${TARGET_REPO}"
else
  TARGET_URL="https://x-access-token:${GHE_TOKEN}@${GHE_HOST}/${TARGET_REPO}.git"
fi

echo "=== Internal Mirror Sync Started ==="
echo "Timestamp : $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Source    : https://github.com/${SOURCE_REPO}"
echo "Target    : https://${GHE_HOST}/${TARGET_REPO}"
if [[ -n "${DRY_RUN}" ]]; then
  echo "Mode      : DRY RUN"
fi

echo "Cloning source repository (bare)..."
git clone --bare "${SOURCE_URL}" repo.git
cd repo.git

echo "Pushing refs/heads/* and refs/tags/* to target repository..."
# Explicitly push heads and tags; avoid pushing internal GitHub pull-request refs (refs/pull/*)
if [[ -n "${DRY_RUN}" ]]; then
  git push --dry-run --prune --force "${TARGET_URL}" "refs/heads/*:refs/heads/*" "refs/tags/*:refs/tags/*"
else
  git push --prune --force "${TARGET_URL}" "refs/heads/*:refs/heads/*" "refs/tags/*:refs/tags/*"
fi

echo "=== Internal Mirror Sync Completed Successfully ==="
