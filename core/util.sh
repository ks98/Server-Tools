#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '%s\n' "[INFO] $*"
}

warn() {
  printf '%s\n' "[WARN] $*" >&2
}

die() {
  printf '%s\n' "[ERROR] $*" >&2
  exit 1
}

is_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

require_root() {
  if ! is_root; then
    die "This module requires root. Re-run with sudo."
  fi
}

is_tty() {
  [[ -t 0 && -t 1 ]]
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}
