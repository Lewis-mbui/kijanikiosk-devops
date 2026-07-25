#!/usr/bin/env bash
# Deploys a versioned kk-api artifact to the blue or green environment.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

APP_VERSION="${APP_VERSION:?APP_VERSION environment variable is required}"
DEPLOY_ENV="${DEPLOY_ENV:?DEPLOY_ENV environment variable is required}"
ARTIFACT_BASE_URL="${ARTIFACT_BASE_URL:?ARTIFACT_BASE_URL environment variable is required}"

BLUE_PORT="${BLUE_PORT:-3000}"
GREEN_PORT="${GREEN_PORT:-3001}"

case "${DEPLOY_ENV}" in
  blue|green)
    ;;
  *)
    echo "ERROR: DEPLOY_ENV must be 'blue' or 'green', got '${DEPLOY_ENV}'" >&2
    exit 1
    ;;
esac

RELEASES_DIR="/opt/kijanikiosk/releases"
ARTIFACT_NAME="kk-api-${APP_VERSION}.tar.gz"
ARTIFACT_PATH="${RELEASES_DIR}/${ARTIFACT_NAME}"
CHECKSUM_PATH="${ARTIFACT_PATH}.sha256"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

SCRIPT_START=$(date +%s)

log() {
  local elapsed
  elapsed=$(( $(date +%s) - SCRIPT_START ))

  echo "[$(date -u +%H:%M:%S)] [+${elapsed}s] $*"
}

log_fail() {
  echo "[$(date -u +%H:%M:%S)] [FAIL] $*" >&2
}

# ---------------------------------------------------------------------------
# Phase 1: Fetch
# ---------------------------------------------------------------------------

fetch_artifact() {
  log "=== Phase 1: Fetch artifact ==="

  local artifact_url="${ARTIFACT_BASE_URL}/${ARTIFACT_NAME}"
  local checksum_url="${artifact_url}.sha256"

  mkdir -p "${RELEASES_DIR}"

  if [ -s "${ARTIFACT_PATH}" ]; then
    log "Artifact already downloaded: ${ARTIFACT_PATH}"
  else
    curl -fsSL --max-time 60 \
      "${artifact_url}" \
      -o "${ARTIFACT_PATH}" || {
        rm -f "${ARTIFACT_PATH}"
        log_fail "Phase 1 FAILED: Could not fetch ${artifact_url}"
        exit 1
      }

    log "Fetched artifact: ${ARTIFACT_PATH}"
  fi

  if [ -s "${CHECKSUM_PATH}" ]; then
    log "Checksum already downloaded: ${CHECKSUM_PATH}"
  else
    curl -fsSL --max-time 30 \
      "${checksum_url}" \
      -o "${CHECKSUM_PATH}" || {
        rm -f "${CHECKSUM_PATH}"
        log "Checksum file not available; Phase 2 will continue without checksum validation"
      }

    if [ -s "${CHECKSUM_PATH}" ]; then
      log "Fetched checksum: ${CHECKSUM_PATH}"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  log "=== kk-api Deployment Script ==="
  log "Version: ${APP_VERSION}"
  log "Target: ${DEPLOY_ENV}"
  log "Artifact: ${ARTIFACT_BASE_URL}/${ARTIFACT_NAME}"
  echo

  fetch_artifact

  echo
  log "Phase 1 test complete"
}

main "$@"