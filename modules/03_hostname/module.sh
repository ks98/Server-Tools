#!/usr/bin/env bash
set -euo pipefail

hostname_prompt_default() {
  local prompt="$1"
  local default="$2"
  local value=""

  if ! is_tty; then
    printf '%s' "$default"
    return
  fi

  read -r -p "$prompt [$default] " value
  value="$(trim "$value")"
  if [[ -z "$value" ]]; then
    value="$default"
  fi

  printf '%s' "$value"
}

module_hostname_run() {
  require_root

  local current_short current_fqdn
  current_short="$(hostname -s 2>/dev/null || hostname)"
  current_fqdn="$(hostname -f 2>/dev/null || true)"

  if [[ "$current_fqdn" == "$current_short" ]]; then
    current_fqdn=""
  fi
  if [[ "$current_fqdn" == "localhost" || "$current_fqdn" == "localhost.localdomain" ]]; then
    current_fqdn=""
  fi

  local hostname_default fqdn_default hostname fqdn
  hostname_default="${HOSTNAME_DEFAULT:-$current_short}"
  fqdn_default="${FQDN_DEFAULT:-$current_fqdn}"

  hostname="$(hostname_prompt_default "Hostname" "$hostname_default")"
  fqdn="$(hostname_prompt_default "FQDN (optional)" "$fqdn_default")"

  if [[ -z "$hostname" ]]; then
    die "Hostname cannot be empty."
  fi

  local target="$hostname"
  if [[ -n "$fqdn" ]]; then
    target="$fqdn"
  fi

  if command -v hostnamectl >/dev/null 2>&1; then
    if ! hostnamectl set-hostname "$target"; then
      warn "hostnamectl failed; falling back to /etc/hostname."
      printf '%s\n' "$target" > /etc/hostname
      if command -v hostname >/dev/null 2>&1; then
        hostname "$target" || warn "hostname command failed."
      fi
    fi
  else
    printf '%s\n' "$target" > /etc/hostname
    if command -v hostname >/dev/null 2>&1; then
      hostname "$target" || warn "hostname command failed."
    fi
  fi

  local hosts_entry="$hostname"
  if [[ -n "$fqdn" ]]; then
    if [[ "$fqdn" == "$hostname" ]]; then
      hosts_entry="$hostname"
    else
      hosts_entry="$fqdn $hostname"
    fi
  fi

  local hosts_file="/etc/hosts"
  if [[ -f "$hosts_file" ]]; then
    if grep -qE '^\s*127\.0\.1\.1\s+' "$hosts_file"; then
      sed -i -E "s|^\s*127\.0\.1\.1\s+.*|127.0.1.1 $hosts_entry|" "$hosts_file"
    else
      printf '\n127.0.1.1 %s\n' "$hosts_entry" >> "$hosts_file"
    fi
  else
    printf '127.0.0.1 localhost\n127.0.1.1 %s\n' "$hosts_entry" > "$hosts_file"
  fi

  log "Set hostname to $target"
}

register_module "hostname" "Hostname" "Hostname and FQDN" "module_hostname_run" "" "true"
