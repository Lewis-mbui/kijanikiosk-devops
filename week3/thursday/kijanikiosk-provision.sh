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

  log "Creting directory structure"

  mkdir -p "${APP_BASE}"/{api,payments,logs,config,scripts,shared/logs}
  success "Directoryies created"

  log "Applying ownership"
  chown kk-api:kk-api "${APP_BASE}/api"
  chown kk-payments:kk-payments "${APP_BASE}/payments"
  chown kk-logs:kk-logs "${APP_BASE}/logs"

  chown root:${APP_GROUP} "${APP_BASE}/config"

  chown kk-logs:kk-logs "${APP_BASE}/shared/logs"

  log "Applying permissions"
  chmod 750 "${APP_BASE}/api"
  chmod 750 "${APP_BASE}/payments"
  chmod 750 "${APP_BASE}/logs"

  chmod 750 "${APP_BASE}/config"

  chmod 2770 "${APP_BASE}/shared/logs"
  success "Permissions applied"

  log "Applying ACLs"
  setfacl -m u:kk-api:rwx \
  "${APP_BASE}/shared/logs"

  setfacl -m u:kk-payments:r-x \
  "${APP_BASE}/shared/logs"

  setfacl -d -m u:kk-api:rwx \
  "${APP_BASE}/shared/logs"

  setfacl -d -m u:kk-payments:r-x \
  "${APP_BASE}/shared/logs"
  success "ACLs configured"
}

provision_services() {
  log "=== Phase 4: systemd Units ==="

  log "Creating environment files"

  # mkdir -p "${APP_BASE}/config"

  cat > "${APP_BASE}/config/db.env" << EOF
DB_HOST=localhost
DB_PORT=5432
EOF

  cat > "${APP_BASE}/config/api.env" << EOF
PORT=3000
EOF

  chmod 640 "${APP_BASE}/config/"*.env
  chown root:${APP_GROUP} "${APP_BASE}/config/"*.env

  success "Environment files ready"

  log "Writing kk-api.service"

  cat > /etc/systemd/system/kk-api.service << 'UNIT'
[Unit]
Description=KijaniKiosk API Service
Documentation=https://github.com/kijanikiosk/api/blob/main/README.md
After=network-online.target kk-payments.service
Wants=network-online.target

[Service]
Type=simple

User=kk-api
Group=kk-api

WorkingDirectory=/opt/kijanikiosk/api

ExecStart=/usr/bin/node /opt/kijanikiosk/api/server.js

ExecReload=/bin/kill -HUP $MAINPID

Restart=on-failure
RestartSec=5s

StartLimitBurst=3
StartLimitIntervalSec=60s

TimeoutStartSec=30s
TimeoutStopSec=30s

EnvironmentFile=/opt/kijanikiosk/config/db.env
EnvironmentFile=/opt/kijanikiosk/config/api.env

Environment="NODE_ENV=production"
Environment="PORT=3000"

StandardOutput=journal
StandardError=journal
SyslogIdentifier=kk-api

NoNewPrivileges=true
PrivateTmp=true

ProtectSystem=strict
ReadWritePaths=/opt/kijanikiosk/shared/logs

ProtectHome=true

CapabilityBoundingSet=

[Install]
WantedBy=multi-user.target
UNIT

  success "Unit file written"

  log "Reloading systemd"

  systemctl daemon-reload

  success "systemd reloaded"

  log "Enabling service"

  systemctl enable kk-api.service

  success "kk-api enabled (not started)"
}

provision_firewall() {
  # Do not deny port 3001.
  # Monitoring and health checks require access to validate backend availability.
  log "=== Phase 5: Firewall ==="

  command -v ufw >/dev/null 2>&1 || \
  error "ufw is not installed"

  log "Resetting firewall"

  ufw --force reset

  success "Firewall reset"

  log "Applying default policies"

  ufw default deny incoming

  ufw default allow outgoing

  success "Default policies applied"

  log "Allowing SSH"

  ufw allow 22/tcp

  success "SSH allowed"

  log "Allowing HTTP"

  ufw allow 80/tcp

  success "HTTP allowed"

  log "Enabling firewall"

  ufw --force enable

  success "Firewall enabled"

  log "Verifying rules"

  ufw status verbose

  success "Firewall configured"
}

verify_state() {
  log "=== Phase 6: Post-Provision Verification ==="

  local failed=0

  log "Verifying service accounts"

  for account in kk-api kk-payments kk-logs
  do
    if id "${account}" >/dev/null 2>&1
    then
      success "Account exists: ${account}"
    else
      error_msg="Account missing: ${account}"
      echo "$error_msg"

      ((failed++))
    fi
  done

  log "Verifying directories"

  for dir in \
    api \
    payments \
    logs \
    config \
    scripts \
    shared/logs
  do

    if [[ -d "${APP_BASE}/${dir}" ]]
    then
      success "Directory exists: ${dir}"
    else
      echo "Missing directory: ${dir}"

      ((failed++))
    fi

  done

  log "Checking SUID files"

  if find "${APP_BASE}" -perm /4000 | grep . >/dev/null
  then
    echo "Unexpected SUID files found"

    ((failed++))
  else
    success "No SUID files present"
  fi

  log "Checking package holds"

  if apt-mark showhold | grep -q "^nginx$"
  then
    success "nginx held"
  else
    echo "nginx hold missing"

    ((failed++))
  fi

  if apt-mark showhold | grep -q "^nodejs$"
  then
    success "nodejs held"
  else
    echo "nodejs hold missing"

    ((failed++))
  fi

  log "Checking service enablement"

  if systemctl is-enabled kk-api.service >/dev/null 2>&1
  then
    success "kk-api enabled"
  else
    echo "kk-api not enabled"

    ((failed++))
  fi

  if [[ "$failed" -gt 0 ]]
  then
    error "Verification failed (${failed} issue(s))"
  fi

  success "Verification passed"
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
