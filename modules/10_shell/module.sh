#!/usr/bin/env bash
set -euo pipefail

module_shell_check() {
  return 0
}

module_shell_run() {
  require_root

  local root_dir
  root_dir="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)}"

  local src
  src="${ROOT_BASHRC_TEMPLATE:-$root_dir/config/root.bashrc}"

  if [[ ! -f "$src" ]]; then
    die "Root bashrc template not found: $src"
  fi

  local dest="/root/.bashrc"
  if [[ -f "$dest" ]] && ! cmp -s "$src" "$dest"; then
    local ts
    ts="$(date +%Y%m%d%H%M%S)"
    cp -a "$dest" "${dest}.bak.${ts}"
    log "Backed up existing root bashrc to ${dest}.bak.${ts}"
  fi

  install -m 0644 "$src" "$dest"
  log "Installed root bashrc from $src"
}

register_module "shell" "Shell" "Root bashrc template" "module_shell_run" "module_shell_check" "true"
