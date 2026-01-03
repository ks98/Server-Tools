#!/usr/bin/env bash
set -euo pipefail

time_prompt_default() {
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

module_time_run() {
  require_root

  local tz_default ntp_default tz ntp
  tz_default="${TIMEZONE_DEFAULT:-Europe/Berlin}"
  ntp_default="${NTP_SERVER_DEFAULT:-de.pool.ntp.org}"

  tz="$(time_prompt_default "Timezone" "$tz_default")"
  ntp="$(time_prompt_default "NTP server" "$ntp_default")"

  if [[ -n "$tz" ]]; then
    if [[ -f "/usr/share/zoneinfo/$tz" ]]; then
      if command -v timedatectl >/dev/null 2>&1; then
        if timedatectl set-timezone "$tz"; then
          log "Set timezone to $tz"
        else
          warn "timedatectl failed; falling back to /etc/localtime."
          ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime
          printf '%s\n' "$tz" > /etc/timezone
          log "Set timezone to $tz"
        fi
      else
        ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime
        printf '%s\n' "$tz" > /etc/timezone
        log "Set timezone to $tz"
      fi
    else
      warn "Timezone not found: $tz (skipping)."
    fi
  fi

  if [[ -n "$ntp" ]]; then
    if command -v systemctl >/dev/null 2>&1; then
      local conf_dir="/etc/systemd/timesyncd.conf.d"
      local conf_file="$conf_dir/99-server-tools.conf"

      install -d -m 0755 "$conf_dir"
      cat > "$conf_file" <<CONF
# Managed by Server-Tools
[Time]
NTP=$ntp
CONF

      if command -v timedatectl >/dev/null 2>&1; then
        timedatectl set-ntp true || warn "Could not enable NTP via timedatectl."
      fi

      systemctl restart systemd-timesyncd 2>/dev/null || warn "Could not restart systemd-timesyncd."
      log "Configured NTP server: $ntp"
    else
      warn "systemctl not found; skipping NTP server configuration."
    fi
  fi
}

register_module "time" "Time" "Timezone and NTP settings" "module_time_run" "" "true"
