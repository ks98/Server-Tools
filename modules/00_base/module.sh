#!/usr/bin/env bash
set -euo pipefail

module_base_check() {
  return 0
}

module_base_run() {
  log "TODO(base): package updates, timezone, locale, hostname"
}

register_module "base" "Base" "Common OS baseline" "module_base_run" "module_base_check" "true"
