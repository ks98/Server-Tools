#!/usr/bin/env bash
set -euo pipefail

ui_choose_modules() {
  if command -v whiptail >/dev/null 2>&1; then
    ui_choose_modules_whiptail
  elif command -v dialog >/dev/null 2>&1; then
    ui_choose_modules_dialog
  else
    ui_choose_modules_prompt
  fi
}

ui_choose_modules_whiptail() {
  local -a choices=()
  local id
  for id in "${MODULE_ORDER[@]}"; do
    choices+=("$id" "${MODULE_NAME[$id]} - ${MODULE_DESC[$id]}" "OFF")
  done

  local selection
  selection=$(whiptail --title "Module selection" --checklist "Select modules to run" 20 78 12 "${choices[@]}" 3>&1 1>&2 2>&3) || return 1

  local -a selected=()
  if [[ -n "$selection" ]]; then
    # whiptail returns quoted strings
    eval "selected=($selection)"
  fi

  printf '%s\n' "${selected[@]}"
}

ui_choose_modules_dialog() {
  local -a choices=()
  local id
  for id in "${MODULE_ORDER[@]}"; do
    choices+=("$id" "${MODULE_NAME[$id]} - ${MODULE_DESC[$id]}" "off")
  done

  local selection
  selection=$(dialog --stdout --title "Module selection" --checklist "Select modules to run" 20 78 12 "${choices[@]}") || return 1

  local -a selected=()
  if [[ -n "$selection" ]]; then
    eval "selected=($selection)"
  fi

  printf '%s\n' "${selected[@]}"
}

ui_choose_modules_prompt() {
  local i=1
  local id

  echo "Available modules:"
  for id in "${MODULE_ORDER[@]}"; do
    printf '[%s] %s - %s\n' "$i" "${MODULE_NAME[$id]}" "${MODULE_DESC[$id]}"
    i=$((i + 1))
  done

  echo "Enter numbers separated by comma (e.g. 1,3,4):"
  local input
  read -r input

  input="${input//,/ }"
  local -a selected=()
  local token
  for token in $input; do
    if [[ "$token" =~ ^[0-9]+$ ]] && (( token >= 1 && token <= ${#MODULE_ORDER[@]} )); then
      selected+=("${MODULE_ORDER[$((token - 1))]}")
    else
      warn "Invalid selection: $token"
    fi
  done

  if [[ ${#selected[@]} -eq 0 ]]; then
    return 1
  fi

  printf '%s\n' "${selected[@]}"
}
