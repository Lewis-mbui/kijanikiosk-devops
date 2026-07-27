#!/usr/bin/env bash
# Rolls traffic back to the previously active environment.
#
# Usage:
#   sudo bash rollback.sh
#
# The script reads /opt/kijanikiosk/.previous-env and calls switch-env.sh
# with that environment as the target.

set -euo pipefail

ACTIVE_ENV_STATE="/opt/kijanikiosk/.active-env"
PREVIOUS_ENV_STATE="/opt/kijanikiosk/.previous-env"
SWITCH_SCRIPT="$(dirname "$0")/switch-env.sh"

log() {
  echo "[$(date -u +%H:%M:%S)] [ROLLBACK] $*"
}

log_fail() {
  echo "[$(date -u +%H:%M:%S)] [ROLLBACK FAIL] $*" >&2
}

# ---------------------------------------------------------------------------
# Determine rollback target
# ---------------------------------------------------------------------------

if [ -f "${PREVIOUS_ENV_STATE}" ]; then
  ROLLBACK_TARGET=$(<"${PREVIOUS_ENV_STATE}")
  log "Rolling back to previous environment: ${ROLLBACK_TARGET}"

elif [ -f "${ACTIVE_ENV_STATE}" ]; then
  CURRENT_ENV=$(<"${ACTIVE_ENV_STATE}")

  case "${CURRENT_ENV}" in
    blue)
      ROLLBACK_TARGET="green"
      ;;
    green)
      ROLLBACK_TARGET="blue"
      ;;
    *)
      log_fail "Invalid active environment state: ${CURRENT_ENV}"
      exit 1
      ;;
  esac

  log "No previous environment record found"
  log "Inferred rollback target: ${ROLLBACK_TARGET}"

else
  log_fail "Cannot determine rollback target: no state files found"
  exit 1
fi

# ---------------------------------------------------------------------------
# Validate rollback target
# ---------------------------------------------------------------------------

case "${ROLLBACK_TARGET}" in
  blue|green)
    ;;
  *)
    log_fail "Invalid rollback target: ${ROLLBACK_TARGET}"
    exit 1
    ;;
esac

if [ ! -f "${SWITCH_SCRIPT}" ]; then
  log_fail "Switch script not found: ${SWITCH_SCRIPT}"
  exit 1
fi

# ---------------------------------------------------------------------------
# Execute rollback
# ---------------------------------------------------------------------------

log "Calling switch-env.sh ${ROLLBACK_TARGET}..."

set +e
bash "${SWITCH_SCRIPT}" "${ROLLBACK_TARGET}"
SWITCH_EXIT=$?
set -e

case "${SWITCH_EXIT}" in
  0)
    log "Rollback to ${ROLLBACK_TARGET} successful."
    ;;
  1)
    log_fail "Rollback failed: pre-condition check failed."
    log_fail "Manual intervention is required."
    ;;
  2)
    log_fail "Rollback failed: nginx validation or reload failed."
    log_fail "Manual intervention is required."
    ;;
  3)
    log_fail "Rollback switch completed but could not be verified."
    log_fail "Check nginx and ${ROLLBACK_TARGET} service status."
    ;;
  *)
    log_fail "Rollback failed with unexpected exit code ${SWITCH_EXIT}."
    ;;
esac

exit "${SWITCH_EXIT}"