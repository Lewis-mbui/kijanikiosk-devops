#!/bin/bash

# Expected dirty conditions found in pre-provisioning audit:
#
# - kk-api, kk-payments, and kk-logs service accounts already exist
# - kijanikiosk group already populated and must be reconciled
# - ACLs already present and may drift between runs
# - UFW already active and rules must converge without duplication
# - Package holds already present and must be validated.
# - kk-api.service already exists and must be updated safely
# - journald persistence already configured and must remain idempotent
# - historical logs already exist and must rotate safely

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

####################################################
#######       PHASE1: PROVISION PACKAGES     #######
####################################################
provision_packages() {
  log "=== Phase 1: Package Baseline & Drift Detection ==="

  command -v dpkg >/dev/null || error "dpkg missing"

  ensure_package_version() {
    local pkg="$1"
    local expected="$2"

    if dpkg -s "$pkg" >/dev/null 2>&1
    then
      installed=$(dpkg-query -W -f='${Version}' "$pkg")

      if [[ "$installed" == "$expected" ]]
      then
        success "${pkg} already installed (${installed})"

      else
        error "
          Package drift detected.

          Package: ${pkg}
          Expected: ${expected}
          Found: ${installed}

          Manual intervention required.
        "
      fi

    else
      log "${pkg} not installed"

      DEBIAN_FRONTEND=noninteractive \
      apt-get install -y --no-install-recommends \
      "${pkg}=${expected}"

      success "${pkg} installed (${expected})"
    fi
  }

  log "Refreshing package metadata"

  apt-get update -qq

  success "Package index refreshed"

  log "Installing prerequisites"

  DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends \
  curl \
  gnupg \
  acl \
  ufw \
  logrotate

  success "Prerequisites ready"

  log "Preparing NodeSource repository"

  mkdir -p /etc/apt/keyrings

  if [[ ! -f /etc/apt/keyrings/nodesource.gpg ]]
  then
    curl -fsSL \
      https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor \
      -o /etc/apt/keyrings/nodesource.gpg

    chmod 644 /etc/apt/keyrings/nodesource.gpg

    success "NodeSource key installed"

  else
    success "NodeSource key already present"
  fi

  cat > /etc/apt/sources.list.d/nodesource.list << EOF
deb [signed-by=/etc/apt/keyrings/nodesource.gpg] \
https://deb.nodesource.com/node_${NODE_MAJOR_VERSION}.x \
nodistro main
EOF

  apt-get update -qq

  success "Repository configured"

  log "Validating package versions"

  ensure_package_version nginx "${NGINX_VERSION}"

  ensure_package_version nodejs "${NODE_VERSION}"

  log "Ensuring package holds"

  for pkg in nginx nodejs
  do
    if apt-mark showhold | grep -qx "$pkg"
    then
      success "${pkg} already held"

    else
      apt-mark hold "$pkg"

      success "${pkg} hold applied"
    fi
  done

  success "Phase 1 complete"
}

####################################################
#######       PHASE2: PROVISION USERS        #######
####################################################
provision_users() {
  log "=== Phase 2: Identity & Access Foundation ==="

  log "Ensuring application group exists"

  if getent group "${APP_GROUP}" >/dev/null
  then
    success "Group already exists: ${APP_GROUP}"

  else
    groupadd --system "${APP_GROUP}"

    success "Created group: ${APP_GROUP}"
  fi

  for account in kk-api kk-payments kk-logs
  do
    log "Reconciling account: ${account}"

    if id "${account}" >/dev/null 2>&1
    then
      success "Already exists: ${account}"

    else
      useradd \
        --system \
        --no-create-home \
        --shell /usr/sbin/nologin \
        --home-dir /nonexistent \
        "${account}"

      success "Created: ${account}"
    fi

    current_shell=$(getent passwd "${account}" | cut -d: -f7)
    current_home=$(getent passwd "${account}" | cut -d: -f6)

    if [[ "$current_shell" != "/usr/sbin/nologin" ]]
    then
      usermod -s /usr/sbin/nologin "${account}"

      success "Updated shell: ${account}"
    fi

    if [[ "$current_home" != "/nonexistent" ]]
    then
      usermod -d /nonexistent "${account}"

      success "Updated home: ${account}"
    fi

    if id -nG "${account}" | tr ' ' '\n' | grep -qx "${APP_GROUP}"
    then
      success "${account} already in ${APP_GROUP}"

    else
      usermod -aG "${APP_GROUP}" "${account}"

      success "${account} added to ${APP_GROUP}"
    fi
  done

  if id amina >/dev/null 2>&1
  then
    if id -nG amina | tr ' ' '\n' | grep -qx "${APP_GROUP}"
    then
      success "amina already in ${APP_GROUP}"

    else
      usermod -aG "${APP_GROUP}" amina

      success "amina added to ${APP_GROUP}"
    fi

  else
    log "amina account not present — skipping"
  fi

  success "Phase 2 complete"
}

####################################################
#######       PHASE3: PROVISION DIRECTORIES  #######
####################################################
provision_dirs() {
  log "=== Phase 3: Directory Model & ACL Convergence ==="

  log "Ensuring directory structure"

  mkdir -p \
    "${APP_BASE}/api" \
    "${APP_BASE}/payments" \
    "${APP_BASE}/logs" \
    "${APP_BASE}/config" \
    "${APP_BASE}/scripts" \
    "${APP_BASE}/shared/logs" \
    "${APP_BASE}/health"

  success "Directory structure ready"

  log "Applying ownership model"

  chown kk-api:kk-api \
    "${APP_BASE}/api"

  chown kk-payments:kk-payments \
    "${APP_BASE}/payments"

  chown kk-logs:kk-logs \
    "${APP_BASE}/logs"

  chown root:${APP_GROUP} \
    "${APP_BASE}/config"

  chown kk-logs:${APP_GROUP} \
    "${APP_BASE}/shared/logs"

  chown kk-logs:${APP_GROUP} \
    "${APP_BASE}/health"

  success "Ownership applied"

  log "Applying permissions"

  chmod 750 "${APP_BASE}/api"
  chmod 750 "${APP_BASE}/payments"
  chmod 750 "${APP_BASE}/logs"

  chmod 750 "${APP_BASE}/config"

  chmod 750 "${APP_BASE}/health"

  chmod 2770 "${APP_BASE}/shared/logs"

  success "Permissions applied"

  log "Reconciling ACLs for shared logs"

  setfacl -b "${APP_BASE}/shared/logs"

  setfacl \
    -m u:kk-api:rwx \
    -m u:kk-payments:r-x \
    -m u:lewis:r-x \
    "${APP_BASE}/shared/logs"

  setfacl \
    -d -m u:kk-api:rwx \
    -d -m u:kk-payments:r-x \
    -d -m u:lewis:r-x \
    "${APP_BASE}/shared/logs"

  success "Shared log ACLs converged"

  log "Applying health directory ACL"

  setfacl -b "${APP_BASE}/health"

  setfacl \
    -m u:kk-logs:rwx \
    -m g:${APP_GROUP}:r-x \
    "${APP_BASE}/health"

  setfacl \
    -d -m u:kk-logs:rwx \
    -d -m g:${APP_GROUP}:r-x \
    "${APP_BASE}/health"

  success "Health ACL configured"

  log "Verifying ACL inheritance"

  touch "${APP_BASE}/shared/logs/.acl-test"

  if getfacl "${APP_BASE}/shared/logs/.acl-test" \
    | grep -q "user:kk-api:rwx"
  then
    success "Default ACL inheritance verified"

  else
    rm -f "${APP_BASE}/shared/logs/.acl-test"

    error "ACL inheritance verification failed"
  fi

  rm -f "${APP_BASE}/shared/logs/.acl-test"

  success "Phase 3 complete"
}

####################################################
#######       PHASE4: PROVISION SERVICES     #######
####################################################
provision_services() {
  log "=== Phase 4: systemd Services ==="

  log "Creating environment files"

  mkdir -p "${APP_BASE}/config"

  cat > "${APP_BASE}/config/api.env" << EOF
PORT=3000
NODE_ENV=production
EOF

  cat > "${APP_BASE}/config/payments-api.env" << EOF
PORT=3001
PAYMENTS_MODE=production
EOF

  cat > "${APP_BASE}/config/logging.env" << EOF
LOG_LEVEL=info
EOF

  chown root:${APP_GROUP} "${APP_BASE}/config/"*.env
  chmod 640 "${APP_BASE}/config/"*.env

  success "Environment files created"

  log "Verifying EnvironmentFile readability"

  sudo -u kk-api \
    cat "${APP_BASE}/config/api.env" >/dev/null

  sudo -u kk-payments \
    cat "${APP_BASE}/config/payments-api.env" >/dev/null

  sudo -u kk-logs \
    cat "${APP_BASE}/config/logging.env" >/dev/null

  success "Environment files readable"

  log "Writing kk-api.service"

cat > /etc/systemd/system/kk-api.service << 'UNIT'
[Unit]
Description=KijaniKiosk API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

User=kk-api
Group=kk-api

WorkingDirectory=/opt/kijanikiosk/api

EnvironmentFile=/opt/kijanikiosk/config/api.env

ExecStart=/usr/bin/bash -c 'sleep infinity'

Restart=on-failure
RestartSec=5

NoNewPrivileges=true

PrivateTmp=true

ProtectSystem=strict

ProtectHome=true

ReadOnlyPaths=/opt/kijanikiosk/config

ReadWritePaths=/opt/kijanikiosk/shared/logs

CapabilityBoundingSet=

RestrictSUIDSGID=true

LockPersonality=true

MemoryDenyWriteExecute=true

UMask=0027

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

success "kk-api.service written"

log "Writing kk-payments.service"

cat > /etc/systemd/system/kk-payments.service << 'UNIT'
[Unit]
Description=KijaniKiosk Payments
After=kk-api.service
Wants=kk-api.service

[Service]
Type=simple

User=kk-payments
Group=kk-payments

WorkingDirectory=/opt/kijanikiosk/payments

EnvironmentFile=/opt/kijanikiosk/config/payments-api.env

ExecStart=/usr/bin/bash -c 'sleep infinity'

Restart=on-failure

NoNewPrivileges=true

PrivateTmp=true

ProtectSystem=strict

ProtectHome=true

ReadOnlyPaths=/opt/kijanikiosk/config

ReadWritePaths=/opt/kijanikiosk/shared/logs

CapabilityBoundingSet=

RestrictSUIDSGID=true

LockPersonality=true

MemoryDenyWriteExecute=true

ProtectKernelTunables=true

ProtectControlGroups=true

ProtectKernelModules=true

ProtectClock=true

UMask=0027

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

success "kk-payments.service written"

log "Writing kk-logs.service"

cat > /etc/systemd/system/kk-logs.service << 'UNIT'
[Unit]
Description=KijaniKiosk Logging

[Service]
Type=simple

User=kk-logs
Group=kk-logs

WorkingDirectory=/opt/kijanikiosk/logs

EnvironmentFile=/opt/kijanikiosk/config/logging.env

ExecStart=/usr/bin/bash -c 'sleep infinity'

Restart=always

NoNewPrivileges=true

PrivateTmp=true

ProtectSystem=strict

ProtectHome=true

ReadWritePaths=/opt/kijanikiosk/shared/logs

CapabilityBoundingSet=

RestrictSUIDSGID=true

LockPersonality=true

UMask=0027

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

success "kk-logs.service written"

log "Reloading systemd"

systemctl daemon-reload

success "systemd reloaded"

log "Enabling units"

systemctl enable kk-api.service
systemctl enable kk-payments.service
systemctl enable kk-logs.service

success "Units enabled"

log "Validating units"

systemctl cat kk-api.service >/dev/null
systemctl cat kk-payments.service >/dev/null
systemctl cat kk-logs.service >/dev/null

success "Phase 4 complete"
}

####################################################
#######       PHASE5: PROVISION FIREWALL     #######
####################################################
provision_firewall() {
  # Do not deny port 3001.
  # Monitoring and health checks require access to validate backend availability.
  log "=== Phase 5: Firewall Intent Model ==="

  command -v ufw >/dev/null \
    || error "ufw not installed"

  log "Resetting firewall state"

  ufw --force reset

  success "Firewall reset"

  log "Applying default policy"

  ufw default deny incoming

  ufw default allow outgoing

  success "Defaults applied"

  log "Allowing SSH"

  ufw allow 22/tcp comment 'Remote administration'

  success "SSH rule applied"

  log "Allowing HTTP"

  ufw allow 80/tcp comment 'Public web traffic'

  success "HTTP rule applied"

  log "Allow monitoring subnet access"

  ufw allow from 10.0.1.0/24 to any port 3001 \
    comment 'Payments health monitoring'

  success "Monitoring access rule applied"

  log "Denying external access to payments"

  ufw deny 3001/tcp \
    comment 'Payments internal only'

  success "External deny applied"

  log "Enabling firewall"

  ufw --force enable

  success "Firewall enabled"

  log "Verifying rules"

  ufw status verbose

  success "Phase 5 complete"
}

####################################################
#######       PHASE6: PROVISION LOGGING     #######
####################################################
provision_logging() {
  log "=== Phase 6: Journal Persistence & Log Rotation ==="

  log "Configuring persistent journal"

  mkdir -p /var/log/journal

  mkdir -p /etc/systemd/journald.conf.d

cat > /etc/systemd/journald.conf.d/kijanikiosk.conf << 'CONF'
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=500M
SystemMaxFileSize=50M
CONF

  systemd-tmpfiles --create --prefix /var/log/journal

  systemctl restart systemd-journald

  success "Persistent journal configured"

  log "Writing logrotate policy"

cat > /etc/logrotate.d/kijanikiosk << 'ROTATE'
/opt/kijanikiosk/shared/logs/*.log {

daily

rotate 14

compress

delaycompress

missingok

notifempty

sharedscripts

su kk-logs kijanikiosk

create 0640 kk-logs kijanikiosk

postrotate
systemctl try-restart kk-logs.service >/dev/null 2>&1 || true
endscript

}
ROTATE

  chmod 644 /etc/logrotate.d/kijanikiosk

  success "Logrotate configuration written"

  log "Validating logrotate"

  if logrotate --debug /etc/logrotate.d/kijanikiosk >/dev/null
  then
    success "logrotate debug passed"

  else
    error "logrotate validation failed"
  fi

  log "Creating verification log"

  mkdir -p "${APP_BASE}/shared/logs"

  touch "${APP_BASE}/shared/logs/verification.log"

  chown kk-logs:${APP_GROUP} \
    "${APP_BASE}/shared/logs/verification.log"

  chmod 640 \
    "${APP_BASE}/shared/logs/verification.log"

  success "Verification log created"

  log "Forcing rotation"

  logrotate --force \
    /etc/logrotate.d/kijanikiosk

  success "Rotation executed"

  log "Verifying ACL survival"

  sudo -u kk-api \
    touch \
    "${APP_BASE}/shared/logs/test-write.tmp"

  if [[ -f "${APP_BASE}/shared/logs/test-write.tmp" ]]
  then
    success "PASS kk-api can write after rotation"

  else
    error "FAIL kk-api lost write access"
  fi

  rm -f \
    "${APP_BASE}/shared/logs/test-write.tmp"

  log "Checking journal size"

  usage=$(journalctl --disk-usage)

  success "${usage}"

  success "Phase 6 complete"
}

####################################################
########   PHASE7: PROVISION HEALTH CHECKS  ########
####################################################
provision_health_checks() {
  log "=== Phase 7: Monitoring Health Checks ==="

  log "Preparing health directory"

  mkdir -p \
    "${APP_BASE}/health"

  chown \
    kk-logs:${APP_GROUP} \
    "${APP_BASE}/health"

  chmod 750 \
    "${APP_BASE}/health"

  success "Health directory ready"

  check_port() {

    local port="$1"

    if timeout 2 \
      bash -c \
      "echo >/dev/tcp/127.0.0.1/${port}" \
      2>/dev/null
    then
      echo '"ok"'

    else
      echo '"down"'
    fi
  }

  log "Checking service ports"

  api_status=$(check_port 3000)

  payments_status=$(check_port 3001)

  success "API status: ${api_status}"

  success "Payments status: ${payments_status}"

  log "Writing health JSON"

  printf \
'{"timestamp":"%s","kk-api":%s,"kk-payments":%s}\n' \
"$(date -Is)" \
"${api_status}" \
"${payments_status}" \
> "${APP_BASE}/health/last-provision.json"

  chown \
    kk-logs:${APP_GROUP} \
    "${APP_BASE}/health/last-provision.json"

  chmod 640 \
    "${APP_BASE}/health/last-provision.json"

  success "Health JSON written"

  log "Verifying health artifact"

  if [[ ! -f \
    "${APP_BASE}/health/last-provision.json" ]]
  then
    error "Health JSON missing"
  fi

  if sudo -u kk-api \
    cat \
    "${APP_BASE}/health/last-provision.json" \
    >/dev/null
  then
    success "Health file readable"

  else
    error "Health file unreadable"
  fi

  success "Phase 7 complete"
}

####################################################
#######       PHASE8: STATE VERIFICATION     #######
####################################################
verify_state() {
  log "=== Phase 8: Full Provision Verification ==="

  local failed=0
  local passed=0

  pass() {
    success "PASS $1"
    ((passed+=1))
  }

  fail() {
    echo "FAIL $1"
    ((failed+=1))
  }

  check() {
    local description="$1"

    if eval "$2"
    then
      pass "$description"

    else
      fail "$description"
    fi
  }

  log "Verifying package state"

  check \
  "nginx hold active" \
  "apt-mark showhold | grep -qx nginx"

  check \
  "nodejs hold active" \
  "apt-mark showhold | grep -qx nodejs"

  log "Verifying users"

  for user in \
    kk-api \
    kk-payments \
    kk-logs
  do
    check \
    "${user} exists" \
    "id ${user} >/dev/null 2>&1"
  done

  log "Verifying directories"

  for dir in \
    api \
    payments \
    logs \
    config \
    scripts \
    shared/logs \
    health
  do

    check \
    "directory ${dir}" \
    "[[ -d ${APP_BASE}/${dir} ]]"
  done

  log "Verifying ACL"

  check \
  "kk-api ACL exists" \
  "getfacl ${APP_BASE}/shared/logs | grep -q 'user:kk-api:rwx'"

  check \
  "kk-payments ACL exists" \
  "getfacl ${APP_BASE}/shared/logs | grep -q 'user:kk-payments:r-x'"

  log "Verifying environment readability"

  check \
  "api env readable" \
  "sudo -u kk-api cat ${APP_BASE}/config/api.env >/dev/null"

  check \
  "payments env readable" \
  "sudo -u kk-payments cat ${APP_BASE}/config/payments-api.env >/dev/null"

  check \
  "logging env readable" \
  "sudo -u kk-logs cat ${APP_BASE}/config/logging.env >/dev/null"

  log "Verifying systemd"

  check \
  "kk-api enabled" \
  "systemctl is-enabled kk-api.service >/dev/null"

  check \
  "kk-payments enabled" \
  "systemctl is-enabled kk-payments.service >/dev/null"

  check \
  "kk-logs enabled" \
  "systemctl is-enabled kk-logs.service >/dev/null"

  log "Verifying journal"

  check \
  "journal persistent configured" \
  "[[ -f /etc/systemd/journald.conf.d/kijanikiosk.conf ]]"

  log "Verifying logrotate"

  check \
  "logrotate config exists" \
  "[[ -f /etc/logrotate.d/kijanikiosk ]]"

  check \
  "logrotate debug passes" \
  "logrotate --debug /etc/logrotate.d/kijanikiosk >/dev/null"

  log "Verifying firewall"

  fw=$(ufw status)

  echo "$fw" | grep -q "22/tcp"

  [[ $? -eq 0 ]] \
    && pass "ssh allowed" \
    || fail "ssh rule"

  echo "$fw" | grep -q "80/tcp"

  [[ $? -eq 0 ]] \
    && pass "http allowed" \
    || fail "http rule"

  echo "$fw" | grep -q "3001"

  [[ $? -eq 0 ]] \
    && pass "payments rule present" \
    || fail "payments rule"

  log "Verifying health"

  check \
  "health json exists" \
  "[[ -f ${APP_BASE}/health/last-provision.json ]]"

  check \
  "health readable" \
  "sudo -u kk-api cat ${APP_BASE}/health/last-provision.json >/dev/null"

  echo

  success "Verification summary"

  echo "Passed: ${passed}"
  echo "Failed: ${failed}"

  if [[ "$failed" -gt 0 ]]
  then
    error "Verification failed"
  fi

  success "Phase 8 complete"
}


main() {
  provision_packages
  provision_users
  provision_dirs
  provision_services
  provision_firewall
  provision_logging
  provision_health_checks
  verify_state
  success "Provisioning complete"
}

main "$@"