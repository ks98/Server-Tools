#!/usr/bin/env bash
set -euo pipefail

module_tools_check() {
  if command -v apt-get >/dev/null 2>&1; then
    return 0
  fi

  warn "apt-get not found; skipping tools install."
  return 1
}

module_tools_run() {
  require_root

  local packages
  packages="${BASIC_TOOLS_PACKAGES:-}"
  if [[ -z "$packages" ]]; then
    die "BASIC_TOOLS_PACKAGES is empty."
  fi

  log "Installing packages: $packages"
  apt-get -y install $packages
}

register_module "tools" "Tools" "Basic CLI tools" "module_tools_run" "module_tools_check" "true"
