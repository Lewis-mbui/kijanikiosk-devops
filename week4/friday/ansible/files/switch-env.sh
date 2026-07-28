#!/usr/bin/env bash
# Switches nginx traffic between the blue and green environments.
#
# Usage:
#   sudo bash switch-env.sh <blue|green>
#
# Exit codes:
#   0 - Switch successful and confirmed
#   1 - Invalid argument or pre-condition failure
#   2 - nginx validation or reload failure
#   3 - Switch completed, but post-switch verification failed

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

TARGET_ENV="${1:?Usage: switch-env.sh <blue|green>}"

ACTIVE_ENV_CONF="/etc/nginx/kijanikiosk-active-env.conf"
ACTIVE_ENV_STATE="/opt/kijanikiosk/.active-env"
PREVIOUS_ENV_STATE="/opt/kijanikiosk/.previous-env"

BLUE_PORT=3000
GREEN_PORT=3001

LOCK_FILE="/tmp/kijanikiosk-switch.lock"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

log() {
  echo "[$(date -u +%H:%M:%S)] $*"
}

log_fail() {
  echo "[$(date -u +%H:%M:%S)] [FAIL] $*" >&2
}

# ---------------------------------------------------------------------------
# Prevent concurrent switches
# ---------------------------------------------------------------------------

exec 9>"${LOCK_FILE}"

if ! flock -n 9; then
  log_fail "Another environment switch is already in progress"
  exit 2
fi

# ---------------------------------------------------------------------------
# Validate target argument
# ---------------------------------------------------------------------------

case "${TARGET_ENV}" in
  blue|green)
    ;;
  *)
    log_fail "TARGET_ENV must be 'blue' or 'green', got '${TARGET_ENV}'"
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Determine current environment
# ---------------------------------------------------------------------------

CURRENT_ENV="unknown"

if [ -f "${ACTIVE_ENV_STATE}" ]; then
  CURRENT_ENV=$(<"${ACTIVE_ENV_STATE}")
fi

# Recovery fallback: inspect nginx configuration
if [ "${CURRENT_ENV}" != "blue" ] &&
   [ "${CURRENT_ENV}" != "green" ]; then

  if grep -q "kk-api-blue" "${ACTIVE_ENV_CONF}" 2>/dev/null; then
    CURRENT_ENV="blue"
  elif grep -q "kk-api-green" "${ACTIVE_ENV_CONF}" 2>/dev/null; then
    CURRENT_ENV="green"
  else
    log_fail "Could not determine the currently active environment"
    exit 1
  fi
fi

log "Current environment: ${CURRENT_ENV}"
log "Target environment:  ${TARGET_ENV}"

# ---------------------------------------------------------------------------
# Idempotency
# ---------------------------------------------------------------------------

if [ "${CURRENT_ENV}" = "${TARGET_ENV}" ]; then
  log "Already on ${TARGET_ENV}. No switch needed."
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 1: Verify target environment health
# ---------------------------------------------------------------------------

TARGET_PORT="${BLUE_PORT}"

if [ "${TARGET_ENV}" = "green" ]; then
  TARGET_PORT="${GREEN_PORT}"
fi

log "Step 1: Verifying ${TARGET_ENV} is healthy on port ${TARGET_PORT}..."

if ! curl -sf \
    --max-time 5 \
    "http://127.0.0.1:${TARGET_PORT}/health" \
    >/dev/null; then

  log_fail "Pre-switch health check FAILED: ${TARGET_ENV} (port ${TARGET_PORT}) is not responding"
  log_fail "Refusing to switch. Run the deployment script first."
  exit 1
fi

log "Pre-switch health check passed: ${TARGET_ENV} is healthy"

# ---------------------------------------------------------------------------
# Step 2: Generate new nginx active environment configuration
# ---------------------------------------------------------------------------

log "Step 2: Writing new nginx active-env configuration..."

cat > "${ACTIVE_ENV_CONF}.new" <<EOF
location / {
    proxy_pass         http://kk-api-${TARGET_ENV};
    proxy_http_version 1.1;
    proxy_set_header   Host \$host;
    proxy_cache_bypass \$http_upgrade;
}

location /health {
    proxy_pass http://kk-api-${TARGET_ENV};
}
EOF

# ---------------------------------------------------------------------------
# Step 3: Install and validate the new nginx configuration
# ---------------------------------------------------------------------------

log "Step 3: Validating nginx configuration..."

if [ ! -f "${ACTIVE_ENV_CONF}" ]; then
  rm -f "${ACTIVE_ENV_CONF}.new"
  log_fail "Active nginx environment file does not exist: ${ACTIVE_ENV_CONF}"
  exit 2
fi

cp "${ACTIVE_ENV_CONF}" "${ACTIVE_ENV_CONF}.bak"
mv "${ACTIVE_ENV_CONF}.new" "${ACTIVE_ENV_CONF}"

if ! nginx -t; then
  log_fail "nginx configuration validation FAILED"

  mv "${ACTIVE_ENV_CONF}.bak" "${ACTIVE_ENV_CONF}"

  log "Previous nginx configuration restored"
  exit 2
fi

log "nginx configuration validation passed"

# ---------------------------------------------------------------------------
# Record previous environment before switching
# ---------------------------------------------------------------------------

printf '%s\n' "${CURRENT_ENV}" > "${PREVIOUS_ENV_STATE}.new"
mv "${PREVIOUS_ENV_STATE}.new" "${PREVIOUS_ENV_STATE}"

log "Recorded previous environment: ${CURRENT_ENV}"

# ---------------------------------------------------------------------------
# Step 4: Reload nginx
# ---------------------------------------------------------------------------

log "Step 4: Reloading nginx..."

if ! nginx -s reload; then
  log_fail "nginx reload FAILED"

  mv "${ACTIVE_ENV_CONF}.bak" "${ACTIVE_ENV_CONF}"

  if nginx -t; then
    nginx -s reload || true
  fi

  log_fail "Previous nginx configuration restored"
  exit 2
fi

printf '%s\n' "${TARGET_ENV}" > "${ACTIVE_ENV_STATE}.new"
mv "${ACTIVE_ENV_STATE}.new" "${ACTIVE_ENV_STATE}"

rm -f "${ACTIVE_ENV_CONF}.bak"

log "nginx reloaded. Traffic now routing to ${TARGET_ENV}."

# ---------------------------------------------------------------------------
# Step 5: Verify switch through nginx proxy
# ---------------------------------------------------------------------------

log "Step 5: Confirming switch via proxy health check..."

sleep 2

retries=0
response=""

while [ "${retries}" -lt 5 ]; do
  if response=$(curl -sf \
      --max-time 5 \
      "http://127.0.0.1:80/health" \
      2>/dev/null); then

    if echo "${response}" |
       grep -q "\"port\":${TARGET_PORT}"; then

      log "Post-switch confirmation passed: proxy is routing to ${TARGET_ENV} (port ${TARGET_PORT})"
      log "=== Switch to ${TARGET_ENV} complete ==="
      exit 0
    fi

    log "Proxy responded but not yet routing to ${TARGET_ENV}: ${response}"
  else
    log "Proxy health check attempt $((retries + 1)) failed"
  fi

  sleep 2
  retries=$((retries + 1))
done

log_fail "Post-switch health check FAILED: proxy did not confirm ${TARGET_ENV} within 10 seconds"
log_fail "nginx was reloaded, but the switch could not be verified"
exit 3