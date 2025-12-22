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
    9) printf '%s' "trixie" ;;
    8) printf '%s' "bookworm" ;;
    7) printf '%s' "bullseye" ;;
    6) printf '%s' "buster" ;;
    5) printf '%s' "stretch" ;;
    4) printf '%s' "jessie" ;;
    *) printf '%s' "" ;;
  esac
}

proxmox_list_apt_files() {
  local files=()
  if [[ -f /etc/apt/sources.list ]]; then
    files+=("/etc/apt/sources.list")
  fi

  local f
  for f in /etc/apt/sources.list.d/*.list; do
    [[ -e "$f" ]] || continue
    files+=("$f")
  done

  printf '%s\n' "${files[@]}"
}

proxmox_disable_enterprise_repos() {
  local file
  while IFS= read -r file; do
    if grep -qE '^[[:space:]]*(deb|deb-src)[[:space:]].*enterprise\.proxmox\.com' "$file"; then
      sed -i -E 's|^([[:space:]]*(deb|deb-src)[[:space:]].*enterprise\.proxmox\.com.*)|# \1|' "$file"
      log "Disabled enterprise repo in $file"
    fi
  done < <(proxmox_list_apt_files)
}

proxmox_collect_ceph_nosub_lines() {
  local file line url dist repo
  local -A seen=()

  while IFS= read -r file; do
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="$(trim "$line")"
      [[ -z "$line" ]] && continue
      if [[ "$line" == \#* ]]; then
        line="${line#\#}"
        line="$(trim "$line")"
      fi
      case "$line" in
        deb\ *|deb-src\ *) ;;
        *) continue ;;
      esac

      url=""
      dist=""
      local -a parts=()
      read -r -a parts <<< "$line"
      local i
      for i in "${!parts[@]}"; do
        if [[ "${parts[$i]}" =~ ^https?:// ]]; then
          url="${parts[$i]}"
          dist="${parts[$((i + 1))]:-}"
          break
        fi
      done
      if [[ "$url" == *"enterprise.proxmox.com/debian/ceph-"* ]]; then
        repo="${url##*/}"
        if [[ -n "$repo" && -n "$dist" ]]; then
          local nosub_line
          nosub_line="deb http://download.proxmox.com/debian/$repo $dist no-subscription"
          if [[ -z "${seen[$nosub_line]:-}" ]]; then
            seen["$nosub_line"]=1
            printf '%s\n' "$nosub_line"
          fi
        fi
      fi
    done < "$file"
  done < <(proxmox_list_apt_files)
}

proxmox_write_ceph_nosub_file() {
  local -a lines=("$@")
  local file="/etc/apt/sources.list.d/ceph-no-subscription.list"

  if [[ ${#lines[@]} -eq 0 ]]; then
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  printf '%s\n' "# Managed by Server-Tools" > "$tmp"
  local line
  for line in "${lines[@]}"; do
    printf '%s\n' "$line" >> "$tmp"
  done

  install -m 0644 "$tmp" "$file"
  rm -f "$tmp"
  log "Wrote no-subscription repo to $file"
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

  proxmox_disable_enterprise_repos

  local nosub_file="/etc/apt/sources.list.d/pve-no-subscription.list"
  local nosub_line="deb http://download.proxmox.com/debian/pve $target_codename pve-no-subscription"

  cat <<EOF_NOSUB > "$nosub_file"
# Managed by Server-Tools
$nosub_line
EOF_NOSUB
  log "Wrote no-subscription repo to $nosub_file"

  local -a ceph_lines=()
  mapfile -t ceph_lines < <(proxmox_collect_ceph_nosub_lines)
  proxmox_write_ceph_nosub_file "${ceph_lines[@]}"
}

register_module "proxmox-repos" "Proxmox Repos" "Switch enterprise to no-subscription" "module_proxmox_repos_run" "module_proxmox_repos_check" "true"
