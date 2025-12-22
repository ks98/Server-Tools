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
  for f in /etc/apt/sources.list.d/*.sources; do
    [[ -e "$f" ]] || continue
    files+=("$f")
  done

  printf '%s\n' "${files[@]}"
}

proxmox_deb822_write_stanza_disable_enterprise() {
  local tmp="$1"
  shift
  local -a stanza=("$@")
  local has_enterprise=0
  local has_enabled=0
  local types_index=-1
  local types_indent=""
  local enabled_indent=""
  local i line

  for i in "${!stanza[@]}"; do
    line="${stanza[$i]}"
    if [[ "$line" =~ enterprise\.proxmox\.com ]]; then
      has_enterprise=1
    fi
    if [[ "$line" =~ ^([[:space:]]*)Enabled: ]]; then
      has_enabled=1
      enabled_indent="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ ^([[:space:]]*)Types: ]]; then
      types_index=$i
      types_indent="${BASH_REMATCH[1]}"
    fi
  done

  if [[ $has_enterprise -eq 0 ]]; then
    printf '%s\n' "${stanza[@]}" >> "$tmp"
    return 0
  fi

  PROXMOX_DEB822_FOUND=1

  local -a out=()
  if [[ $has_enabled -eq 1 ]]; then
    for line in "${stanza[@]}"; do
      if [[ "$line" =~ ^[[:space:]]*Enabled: ]]; then
        out+=("${enabled_indent}Enabled: no")
      else
        out+=("$line")
      fi
    done
  else
    if [[ $types_index -ge 0 ]]; then
      for i in "${!stanza[@]}"; do
        out+=("${stanza[$i]}")
        if [[ $i -eq $types_index ]]; then
          out+=("${types_indent}Enabled: no")
        fi
      done
    else
      out+=("Enabled: no")
      out+=("${stanza[@]}")
    fi
  fi

  printf '%s\n' "${out[@]}" >> "$tmp"
}

proxmox_disable_enterprise_deb822_file() {
  local file="$1"

  if ! grep -q "enterprise.proxmox.com" "$file"; then
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  local -a stanza=()
  local line trimmed
  PROXMOX_DEB822_FOUND=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(trim "$line")"
    if [[ -z "$trimmed" ]]; then
      if [[ ${#stanza[@]} -gt 0 ]]; then
        proxmox_deb822_write_stanza_disable_enterprise "$tmp" "${stanza[@]}"
        stanza=()
      fi
      printf '\n' >> "$tmp"
      continue
    fi
    stanza+=("$line")
  done < "$file"

  if [[ ${#stanza[@]} -gt 0 ]]; then
    proxmox_deb822_write_stanza_disable_enterprise "$tmp" "${stanza[@]}"
  fi

  if [[ $PROXMOX_DEB822_FOUND -eq 1 ]]; then
    if ! cmp -s "$tmp" "$file"; then
      install -m 0644 "$tmp" "$file"
      log "Disabled enterprise repo in $file"
    fi
  fi
  rm -f "$tmp"
}

proxmox_disable_enterprise_repos() {
  local file
  while IFS= read -r file; do
    if [[ "$file" == *.sources ]]; then
      proxmox_disable_enterprise_deb822_file "$file"
      continue
    fi
    if grep -qE '^[[:space:]]*(deb|deb-src)[[:space:]].*enterprise\.proxmox\.com' "$file"; then
      sed -i -E 's|^([[:space:]]*(deb|deb-src)[[:space:]].*enterprise\.proxmox\.com.*)|# \1|' "$file"
      log "Disabled enterprise repo in $file"
    fi
  done < <(proxmox_list_apt_files)
}

proxmox_collect_ceph_from_deb822_stanza() {
  local -a stanza=("$@")
  local -a uris=()
  local -a suites=()
  local line trimmed rest

  for line in "${stanza[@]}"; do
    trimmed="$(trim "$line")"
    case "$trimmed" in
      URIs:*)
        rest="${trimmed#URIs:}"
        rest="$(trim "$rest")"
        read -r -a uris <<< "$rest"
        ;;
      Suites:*)
        rest="${trimmed#Suites:}"
        rest="$(trim "$rest")"
        read -r -a suites <<< "$rest"
        ;;
    esac
  done

  if [[ ${#uris[@]} -eq 0 || ${#suites[@]} -eq 0 ]]; then
    return 0
  fi

  local uri suite repo
  for uri in "${uris[@]}"; do
    if [[ "$uri" == *"enterprise.proxmox.com/debian/ceph-"* ]]; then
      repo="${uri##*/}"
      for suite in "${suites[@]}"; do
        printf '%s\n' "deb http://download.proxmox.com/debian/$repo $suite no-subscription"
      done
    fi
  done
}

proxmox_collect_ceph_from_deb822() {
  local file="$1"
  local line trimmed
  local -a stanza=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(trim "$line")"
    if [[ -z "$trimmed" ]]; then
      if [[ ${#stanza[@]} -gt 0 ]]; then
        proxmox_collect_ceph_from_deb822_stanza "${stanza[@]}"
        stanza=()
      fi
      continue
    fi
    stanza+=("$line")
  done < "$file"

  if [[ ${#stanza[@]} -gt 0 ]]; then
    proxmox_collect_ceph_from_deb822_stanza "${stanza[@]}"
  fi
}

proxmox_collect_ceph_nosub_lines() {
  local file line url dist repo
  local -A seen=()

  while IFS= read -r file; do
    if [[ "$file" == *.sources ]]; then
      while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        if [[ -z "${seen[$line]:-}" ]]; then
          seen["$line"]=1
          printf '%s\n' "$line"
        fi
      done < <(proxmox_collect_ceph_from_deb822 "$file")
      continue
    fi
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
