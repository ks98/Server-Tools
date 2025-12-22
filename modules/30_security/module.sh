#!/usr/bin/env bash
set -euo pipefail

module_security_run() {
  log "TODO(security): firewall, fail2ban, sysctl hardening"
}

register_module "security" "Security" "Hardening and firewall" "module_security_run" "" "true"
