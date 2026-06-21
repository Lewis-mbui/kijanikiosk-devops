#!/bin/bash

set -euo pipefail

readonly NODE_MAJOR_VERSION=22
readonly NGINX_VERSION=""
readonly APP_BASE="/opt/kijanikiosk"
readonly APP_GROUP="kijanikiosk"

# LOGGING
log() { echo "[$(date +%FT%T)] INFO  $*"; }
success() { echo "[$(date +%FT%T)] OK    $*"; }
error()   { echo "[$(date +%FT%T)] ERROR $*" >&2; exit 1; }

# REQUIRE ROOT
[[ $EUID -ne 0 ]] && error "Must run as root or with sudo"

#REQUIRE UBUNTU
grep -qi ubuntu /etc/os-release || error "Designed for Ubuntu only"

# PHASES
provision_packages() {
  log "=== Phase 1: Packages ==="
}

provision_users() {
  log "=== Phase 2: Service Accounts ==="
}

provision_dirs() {
  log "=== Phase 3: Directories ==="
}

provision_services() {
  log "=== Phase 4: systemd units ==="
}

provision_firewall() {
  log "=== Phase 5: Firewall ==="
}

verify_state() {
  log "=== Phase 6: Verification ==="
}

#ENTRY
main() {
  provision_packages
  provision_users
  provision_dirs
  provision_services
  provision_firewall
  verify_state

  success "Provisioning complete. Server is in known state."
}

main "$@"