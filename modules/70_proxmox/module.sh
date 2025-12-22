#!/usr/bin/env bash
set -euo pipefail

proxmox_get_os_codename() {
  local codename=""
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    codename="${VERSION_CODENAME:-${DEBIAN_CODENAME:-}}"
  fi
  printf '%s' "$codename"
}

proxmox_get_pve_major() {
  local version=""
  if command -v pveversion >/dev/null 2>&1; then
    version="$(pveversion 2>/dev/null | awk -F'/' 'NR==1 {print $2}')"
  fi

  if [[ -z "$version" ]] && command -v dpkg-query >/dev/null 2>&1; then
    version="$(dpkg-query -W -f='${Version}' pve-manager 2>/dev/null || true)"
  fi

  if [[ -n "$version" ]]; then
    printf '%s' "${version%%.*}"
  fi
}

proxmox_map_codename() {
  case "$1" in
    8) printf '%s' "bookworm" ;;
    7) printf '%s' "bullseye" ;;
    6) printf '%s' "buster" ;;
    5) printf '%s' "stretch" ;;
    4) printf '%s' "jessie" ;;
    *) printf '%s' "" ;;
  esac
}

module_proxmox_repos_check() {
  if [[ -d /etc/pve ]] || command -v pveversion >/dev/null 2>&1; then
    return 0
  fi

  warn "Proxmox not detected; skipping."
  return 1
}

module_proxmox_repos_run() {
  require_root

  local os_codename
  local pve_major
  local target_codename

  os_codename="$(proxmox_get_os_codename)"
  pve_major="$(proxmox_get_pve_major || true)"

  if [[ -n "$pve_major" ]]; then
    target_codename="$(proxmox_map_codename "$pve_major")"
  fi

  if [[ -z "$target_codename" ]]; then
    target_codename="$os_codename"
  fi

  if [[ -z "$target_codename" ]]; then
    die "Unable to determine Debian codename for Proxmox repo."
  fi

  if [[ -n "$os_codename" && "$os_codename" != "$target_codename" ]]; then
    warn "OS codename ($os_codename) differs from PVE mapping ($target_codename). Using $target_codename."
  fi

  local enterprise_file="/etc/apt/sources.list.d/pve-enterprise.list"
  if [[ -f "$enterprise_file" ]]; then
    if grep -qE '^[[:space:]]*deb[[:space:]].*enterprise\.proxmox\.com/debian/pve' "$enterprise_file"; then
      sed -i -E 's|^([[:space:]]*deb[[:space:]].*enterprise\.proxmox\.com/debian/pve.*)|# \1|' "$enterprise_file"
      log "Disabled enterprise repo in $enterprise_file"
    fi
  fi

  local nosub_file="/etc/apt/sources.list.d/pve-no-subscription.list"
  local nosub_line="deb http://download.proxmox.com/debian/pve $target_codename pve-no-subscription"

  if [[ -f "$nosub_file" ]] && grep -qF "$nosub_line" "$nosub_file"; then
    log "No-subscription repo already configured in $nosub_file"
  else
    cat <<EOF_NOSUB > "$nosub_file"
# Managed by Server-Tools
$nosub_line
EOF_NOSUB
    log "Wrote no-subscription repo to $nosub_file"
  fi
}

register_module "proxmox-repos" "Proxmox Repos" "Switch enterprise to no-subscription" "module_proxmox_repos_run" "module_proxmox_repos_check" "true"
