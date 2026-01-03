#!/usr/bin/env bash
set -euo pipefail

locale_prompt_default() {
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

module_locale_run() {
  require_root

  local locale_default locale
  locale_default="${LOCALE_DEFAULT:-de_DE.UTF-8}"
  locale="$(locale_prompt_default "Locale" "$locale_default")"

  if [[ -z "$locale" ]]; then
    warn "Empty locale; skipping."
    return
  fi

  if [[ -f /etc/locale.gen ]]; then
    if grep -qE "^\s*#?\s*${locale}\s+UTF-8" /etc/locale.gen; then
      sed -i -E "s/^\s*#\s*(${locale}\s+UTF-8)/\1/" /etc/locale.gen
    else
      printf '\n%s UTF-8\n' "$locale" >> /etc/locale.gen
    fi
  fi

  if command -v locale-gen >/dev/null 2>&1; then
    if ! locale-gen "$locale"; then
      warn "locale-gen failed for $locale."
    fi
  else
    warn "locale-gen not found; skipping locale generation."
  fi

  if command -v localectl >/dev/null 2>&1; then
    if ! localectl set-locale "LANG=$locale"; then
      warn "localectl failed to set LANG=$locale."
    fi
  fi

  local locale_file="/etc/default/locale"
  if [[ -f "$locale_file" ]]; then
    if grep -qE '^LANG=' "$locale_file"; then
      sed -i -E "s/^LANG=.*/LANG=$locale/" "$locale_file"
    else
      printf '\nLANG=%s\n' "$locale" >> "$locale_file"
    fi
  else
    printf 'LANG=%s\n' "$locale" > "$locale_file"
  fi

  log "Set locale to $locale"
}

register_module "locale" "Locale" "System locale settings" "module_locale_run" "" "true"
