#!/usr/bin/env bash
set -euo pipefail

module_updates_check() {
  if command -v apt-get >/dev/null 2>&1; then
    return 0
  fi

  warn "apt-get not found; skipping updates."
  return 1
}

module_updates_run() {
  require_root

  export DEBIAN_FRONTEND=noninteractive

  log "Running apt-get update"
  apt-get update

  log "Running apt-get dist-upgrade"
  apt-get -y dist-upgrade

  log "Running apt-get autoremove"
  apt-get -y autoremove

  log "Running apt-get autoclean"
  apt-get -y autoclean
}

register_module "updates" "Updates" "apt update, dist-upgrade, autoremove, autoclean" "module_updates_run" "module_updates_check" "true"
