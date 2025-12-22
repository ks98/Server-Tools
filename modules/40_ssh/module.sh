#!/usr/bin/env bash
set -euo pipefail

ssh_normalize_bool() {
  case "${1:-}" in
    y|Y|yes|YES|true|TRUE|1) return 0 ;;
    *) return 1 ;;
  esac
}

ssh_prompt_yes_no() {
  local prompt="$1"
  local default="${2:-yes}"

  if ! is_tty; then
    if ssh_normalize_bool "$default"; then
      return 0
    fi
    return 1
  fi

  local hint="y/N"
  if ssh_normalize_bool "$default"; then
    hint="Y/n"
  fi

  local answer=""
  while true; do
    read -r -p "$prompt [$hint] " answer
    answer="$(trim "$answer")"
    if [[ -z "$answer" ]]; then
      answer="$default"
    fi
    case "$answer" in
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO) return 1 ;;
      *) warn "Please answer yes or no." ;;
    esac
  done
}

ssh_sanitize_key_file() {
  local src="$1"
  local dest="$2"

  : > "$dest"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue
    printf '%s\n' "$line" >> "$dest"
  done < "$src"
}

ssh_apply_authorized_keys() {
  local add_file="$1"
  local remove_file="$2"
  local auth_file="/root/.ssh/authorized_keys"

  install -d -m 0700 /root/.ssh
  touch "$auth_file"
  chmod 0600 "$auth_file"

  if [[ -n "$add_file" && -f "$add_file" ]]; then
    local add_tmp
    add_tmp="$(mktemp)"
    ssh_sanitize_key_file "$add_file" "$add_tmp"
    if [[ -s "$add_tmp" ]]; then
      while IFS= read -r line || [[ -n "$line" ]]; do
        if ! grep -Fxq "$line" "$auth_file"; then
          printf '%s\n' "$line" >> "$auth_file"
          log "Added root authorized key."
        fi
      done < "$add_tmp"
    fi
    rm -f "$add_tmp"
  elif [[ -n "$add_file" ]]; then
    warn "Add keys file not found: $add_file"
  fi

  if [[ -n "$remove_file" && -f "$remove_file" ]]; then
    local remove_tmp
    remove_tmp="$(mktemp)"
    ssh_sanitize_key_file "$remove_file" "$remove_tmp"
    if [[ -s "$remove_tmp" ]]; then
      local filtered
      filtered="$(mktemp)"
      if grep -Fvx -f "$remove_tmp" "$auth_file" > "$filtered"; then
        if ! cmp -s "$filtered" "$auth_file"; then
          install -m 0600 "$filtered" "$auth_file"
          log "Removed keys from root authorized_keys."
        fi
      fi
      rm -f "$filtered"
    fi
    rm -f "$remove_tmp"
  elif [[ -n "$remove_file" ]]; then
    warn "Remove keys file not found: $remove_file"
  fi
}

ssh_configure_sshd() {
  local prompt_enabled="${SSH_SSHD_PROMPT:-yes}"
  local disable_root_password="${SSH_DISABLE_ROOT_PASSWORD:-yes}"
  local allow_only_root="${SSH_ALLOW_ONLY_ROOT:-yes}"

  if ssh_normalize_bool "$prompt_enabled"; then
    if ssh_prompt_yes_no "Disable root SSH password login?" "$disable_root_password"; then
      disable_root_password="yes"
    else
      disable_root_password="no"
    fi

    if ssh_prompt_yes_no "Allow SSH login only for root?" "$allow_only_root"; then
      allow_only_root="yes"
    else
      allow_only_root="no"
    fi
  fi

  local conf_dir="/etc/ssh/sshd_config.d"
  local conf_file="$conf_dir/99-server-tools.conf"
  local legacy_conf_file="$conf_dir/99-basic-setup.conf"
  local tmp
  tmp="$(mktemp)"

  printf '%s\n' "# Managed by Server-Tools" > "$tmp"
  if ssh_normalize_bool "$disable_root_password"; then
    printf '%s\n' "PermitRootLogin prohibit-password" >> "$tmp"
  fi
  if ssh_normalize_bool "$allow_only_root"; then
    printf '%s\n' "AllowUsers root" >> "$tmp"
  fi

  install -d -m 0755 "$conf_dir"
  install -m 0644 "$tmp" "$conf_file"
  rm -f "$tmp"
  if [[ -f "$legacy_conf_file" && "$legacy_conf_file" != "$conf_file" ]]; then
    if grep -q "Managed by basic-setup" "$legacy_conf_file"; then
      rm -f "$legacy_conf_file"
      log "Removed legacy sshd config $legacy_conf_file"
    fi
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || warn "Could not reload ssh service."
  elif command -v service >/dev/null 2>&1; then
    service ssh reload 2>/dev/null || service sshd reload 2>/dev/null || warn "Could not reload ssh service."
  else
    warn "No service manager found to reload SSH."
  fi
}

module_ssh_run() {
  require_root

  local root_dir
  root_dir="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)}"

  local add_file
  local remove_file
  add_file="${SSH_AUTH_KEYS_ADD_FILE:-${SSH_AUTH_KEYS_FILE:-$root_dir/config/ssh/authorized_keys.add}}"
  remove_file="${SSH_AUTH_KEYS_REMOVE_FILE:-$root_dir/config/ssh/authorized_keys.remove}"

  ssh_apply_authorized_keys "$add_file" "$remove_file"
  ssh_configure_sshd
}

register_module "ssh" "SSH" "SSH keys and sshd config" "module_ssh_run" "" "true"
