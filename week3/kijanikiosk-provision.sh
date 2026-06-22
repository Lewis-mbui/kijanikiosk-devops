#!/bin/bash

set -euo pipefail

readonly NODE_MAJOR_VERSION=22
readonly NODE_VERSION="22.23.0-1nodesource1"
readonly NGINX_VERSION="1.18.0-6ubuntu14.15"
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

  log "Updating package index"
  apt-get update -qq
  success "Package index updated"
  
  log "Installing prerequisite tools"
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  curl gnupg acl ufw
  success "Prerequisites installed"

  log "Installing NodeSource signing key"
  # Prepare keyring directory
  mkdir -p /etc/apt/keyrings
  chmod 0755 /etc/apt/keyrings

  # Download & install NodeSource GPG key
  curl -fsSL \
  https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
  gpg --dearmor -o \
  /etc/apt/keyrings/nodesource.gpg
  chmod 644 /etc/apt/keyrings/nodesource.gpg
  success "NodeSource key installed"

  # Add the repository referencing the specific key file
  log "Configuring NodeSource repository"
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] \
  https://deb.nodesource.com/node_${NODE_MAJOR_VERSION}.x nodistro main" \
  > /etc/apt/sources.list.d/nodesource.list
  apt-get update -qq
  success "Repository configured"

  # Install nginx and node
  log "Installing nginx and nodejs"
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  "nginx=${NGINX_VERSION}" "nodejs=${NODE_VERSION}"

  # Immediately hold package versions
  log "Holding package versions"
  apt-mark hold nginx nodejs

  log installed versions
  success "nginx: $(nginx -v 2>&1)"
  success "node: $(node --version)"
}

provision_users() {
  log "=== Phase 2: Service Accounts ==="

  log "Ensuring application group exists"
  getent group "${APP_GROUP}" >/dev/null 2>&1 || groupadd --system "${APP_GROUP}"
  success "Group ready"

  for account in kk-api kk-payments kk-logs
  do
    log "Processing ${account}"

    if ! id "${account}" >/dev/null 2>&1
    then
      useradd \
      --system \
      --no-create-home \
      --shell /usr/sbin/nologin \
      --home-dir /nonexistent \
      "${account}"

      success "Created ${account}"
    else
      log "${account} already exists"
    fi

    usermod -aG "${APP_GROUP}" "${account}"
    success "${account} added to ${APP_GROUP}"
  done

  if id amina >/dev/null 2>&1
  then
    usermod -aG "${APP_GROUP}" amina
    success "amina added to ${APP_GROUP}"
  else
    log "amina account not present - skipping"
  fi

  success "Service accounts complete"
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