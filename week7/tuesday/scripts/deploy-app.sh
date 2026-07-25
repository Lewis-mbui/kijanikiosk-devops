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
# Phase 2: Validate
# ---------------------------------------------------------------------------

validate_artifact() {
  log "=== Phase 2: Validate artifact ==="

  local staging_dir="${RELEASES_DIR}/staging-${APP_VERSION}"

  if [ ! -s "${ARTIFACT_PATH}" ]; then
    log_fail "Phase 2 FAILED: Artifact file is missing or empty: ${ARTIFACT_PATH}"
    exit 1
  fi

  log "Artifact exists and is non-empty"

  if [ -s "${CHECKSUM_PATH}" ]; then
    (
      cd "${RELEASES_DIR}"
      sha256sum -c "$(basename "${CHECKSUM_PATH}")"
    ) || {
      log_fail "Phase 2 FAILED: Checksum mismatch on ${ARTIFACT_PATH}"
      exit 1
    }

    log "Checksum validation passed"
  else
    log "No checksum file available; skipping checksum validation"
  fi

  rm -rf "${staging_dir}"
  mkdir -p "${staging_dir}"

  tar xzf "${ARTIFACT_PATH}" -C "${staging_dir}" || {
    rm -rf "${staging_dir}"
    log_fail "Phase 2 FAILED: Could not extract ${ARTIFACT_PATH}"
    exit 1
  }

  if [ ! -f "${staging_dir}/server.js" ]; then
    rm -rf "${staging_dir}"
    log_fail "Phase 2 FAILED: server.js not found in artifact"
    exit 1
  fi

  log "Artifact valid: extraction succeeded and server.js is present"
}

# ---------------------------------------------------------------------------
# Phase 3: Deploy
# ---------------------------------------------------------------------------

deploy_artifact() {
  log "=== Phase 3: Deploy to ${DEPLOY_ENV} ==="

  local target_dir="/opt/kijanikiosk/${DEPLOY_ENV}"
  local app_dir="${target_dir}/app"
  local version_file="${target_dir}/.version"
  local staging_dir="${RELEASES_DIR}/staging-${APP_VERSION}"
  local current_version=""

  if [ -f "${version_file}" ]; then
    current_version=$(<"${version_file}")
  fi

  if [ "${current_version}" = "${APP_VERSION}" ] &&
     [ -f "${app_dir}/server.js" ]; then
    log "${DEPLOY_ENV} already runs ${APP_VERSION}; deployment skipped"
    DEPLOY_CHANGED=false
    return 0
  fi

  if [ ! -f "${staging_dir}/server.js" ]; then
    log_fail "Phase 3 FAILED: Validated staging content is missing"
    exit 1
  fi

  mkdir -p "${target_dir}"

  rm -rf "${app_dir}.new"
  mkdir -p "${app_dir}.new"

  cp -a "${staging_dir}/." "${app_dir}.new/"

  chown -R kk-api:kk-api "${app_dir}.new"

  rm -rf "${app_dir}.previous"

  if [ -d "${app_dir}" ]; then
    mv "${app_dir}" "${app_dir}.previous"
  fi

  mv "${app_dir}.new" "${app_dir}"

  printf '%s\n' "${APP_VERSION}" > "${version_file}"
  chown kk-api:kk-api "${version_file}"
  chmod 0640 "${version_file}"

  rm -rf "${app_dir}.previous"

  DEPLOY_CHANGED=true

  log "Deployed ${APP_VERSION} to ${app_dir}"
}

# ---------------------------------------------------------------------------
# Phase 4: Restart
# ---------------------------------------------------------------------------

restart_service() {
  log "=== Phase 4: Restart ${DEPLOY_ENV} service ==="

  local service_name="kk-api-${DEPLOY_ENV}.service"

  if [ "${DEPLOY_CHANGED}" != "true" ]; then
    log "No deployment change detected; restart skipped"
    return 0
  fi

  systemctl restart "${service_name}" || {
    log_fail "Phase 4 FAILED: Could not restart ${service_name}"
    systemctl status "${service_name}" --no-pager >&2 || true
    exit 1
  }

  if ! systemctl is-active --quiet "${service_name}"; then
    log_fail "Phase 4 FAILED: ${service_name} is not active after restart"
    systemctl status "${service_name}" --no-pager >&2 || true
    exit 1
  fi

  log "Restarted ${service_name} successfully"
}

# ---------------------------------------------------------------------------
# Phase 5: Verify
# ---------------------------------------------------------------------------

verify_service() {
  log "=== Phase 5: Verify ${DEPLOY_ENV} service health ==="

  local port="${BLUE_PORT}"
  local service_name="kk-api-blue.service"

  if [ "${DEPLOY_ENV}" = "green" ]; then
    port="${GREEN_PORT}"
    service_name="kk-api-green.service"
  fi

  local health_url="http://127.0.0.1:${port}/health"
  local retries=0
  local response=""

  while [ "${retries}" -lt 10 ]; do
    if response=$(curl -fsS --max-time 5 "${health_url}" 2>/dev/null); then
      if echo "${response}" |
        grep -q "\"version\":\"${APP_VERSION}\""; then
        log "Health check passed: ${health_url} returned version ${APP_VERSION}"
        return 0
      fi

      log "Health check responded but version did not match: ${response}"
    else
      log "Health check attempt $((retries + 1)) failed"
    fi

    sleep 3
    retries=$((retries + 1))
  done

  log_fail "Phase 5 FAILED: Health check did not pass after $((retries * 3)) seconds"
  log_fail "URL: ${health_url}"
  log_fail "Expected version: ${APP_VERSION}"

  echo >&2
  echo "Recent ${service_name} journal entries:" >&2

  journalctl \
    -u "${service_name}" \
    -n 20 \
    --no-pager >&2 || true

  exit 1
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
  validate_artifact
  deploy_artifact
  restart_service
  verify_service

  echo
  log "Deployment changed: ${DEPLOY_CHANGED}"
  log "Deployment completed successfully"
}

main "$@"