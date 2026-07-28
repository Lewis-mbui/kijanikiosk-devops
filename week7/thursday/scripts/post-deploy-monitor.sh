#!/usr/bin/env bash
# scripts/post-deploy-monitor.sh
# Monitors the active environment after a traffic switch.
# Calls rollback.sh automatically if health thresholds are breached.
#
# Usage:
#   sudo bash post-deploy-monitor.sh [confidence_window_seconds]
#
# Default confidence window: 120 seconds (2 minutes)

set -euo pipefail

# Monitoring thresholds
CONFIDENCE_WINDOW="${1:-120}"
POLL_INTERVAL=5
MAX_CONSECUTIVE_FAILURES=3
MAX_ERRORS_PER_WINDOW=2
LATENCY_THRESHOLD=2.0
SLOW_THRESHOLD_COUNT=3

# Runtime paths
ACTIVE_ENV_STATE="/opt/kijanikiosk/.active-env"
PROXY_HEALTH_URL="http://127.0.0.1:80/health"
SCRIPTS_DIR="$(dirname "$0")"

log() {
  echo "[$(date -u +%H:%M:%S)] [MONITOR] $*"
}

log_warn() {
  echo "[$(date -u +%H:%M:%S)] [MONITOR WARN] $*"
}

log_fail() {
  echo "[$(date -u +%H:%M:%S)] [MONITOR FAIL] $*" >&2
}

trigger_rollback() {
  local reason="$1"

  log_fail "ROLLBACK TRIGGERED: ${reason}"
  log_fail "Calling rollback.sh..."

  if bash "${SCRIPTS_DIR}/rollback.sh"; then
    log "Rollback completed successfully."
  else
    local rollback_exit=$?

    log_fail "Rollback script exited with code ${rollback_exit}."
    log_fail "Manual intervention required."
  fi

  # The deployment is still considered failed even when rollback succeeds.
  exit 1
}

main() {
  local active_env
  active_env=$(cat "${ACTIVE_ENV_STATE}" 2>/dev/null || echo "unknown")

  log "=== Post-deployment monitoring: ${active_env} environment ==="
  log "Confidence window: ${CONFIDENCE_WINDOW}s | Poll interval: ${POLL_INTERVAL}s"

  local elapsed=0
  local consecutive_failures=0
  local errors_in_window=0
  local slow_in_last_five=0
  local poll_count=0

  while [ "${elapsed}" -lt "${CONFIDENCE_WINDOW}" ]; do
    poll_count=$((poll_count + 1))

    local http_code
    local response_time

    # Capture HTTP status and response time using one request.
    read -r http_code response_time < <(
      curl -sS \
        --max-time 5 \
        --write-out "%{http_code} %{time_total}" \
        --output /dev/null \
        "${PROXY_HEALTH_URL}" 2>/dev/null ||
        echo "000 0"
    )

    log "Poll ${poll_count}: HTTP ${http_code} | ${response_time}s | elapsed: ${elapsed}s"

    # Check availability and track errors in the current 10-poll window.
    if [ "${http_code}" = "000" ] ||
       [ "${http_code:0:1}" != "2" ]; then

      consecutive_failures=$((consecutive_failures + 1))
      errors_in_window=$((errors_in_window + 1))

      log_warn "Health check failed (consecutive: ${consecutive_failures}, window errors: ${errors_in_window})"
    else
      consecutive_failures=0
    fi

    # Bash cannot compare floating-point numbers, so awk performs the check.
    if echo "${response_time}" |
       awk -v threshold="${LATENCY_THRESHOLD}" \
         '{ exit ($1 > threshold) ? 0 : 1 }'; then

      slow_in_last_five=$((slow_in_last_five + 1))

      log_warn "Slow response: ${response_time}s (slow count in last 5: ${slow_in_last_five})"
    else
      # Decay the counter so it approximates recent slow responses.
      if [ "${slow_in_last_five}" -gt 0 ]; then
        slow_in_last_five=$((slow_in_last_five - 1))
      fi
    fi

    # Evaluate rollback conditions before resetting the error window.
    if [ "${consecutive_failures}" -ge "${MAX_CONSECUTIVE_FAILURES}" ]; then
      trigger_rollback \
        "${consecutive_failures} consecutive health check failures"
    fi

    if [ "${errors_in_window}" -gt "${MAX_ERRORS_PER_WINDOW}" ]; then
      trigger_rollback \
        "error rate exceeded: ${errors_in_window} errors in window"
    fi

    if [ "${slow_in_last_five}" -ge "${SLOW_THRESHOLD_COUNT}" ]; then
      trigger_rollback \
        "latency threshold exceeded: ${slow_in_last_five} slow responses in last 5 polls"
    fi

    # Begin a new error-counting window after every 10 completed polls.
    if [ $((poll_count % 10)) -eq 0 ]; then
      errors_in_window=0
    fi

    sleep "${POLL_INTERVAL}"
    elapsed=$((elapsed + POLL_INTERVAL))
  done

  log "=== Confidence window passed: ${active_env} deployment declared healthy ==="
  exit 0
}

main "$@"