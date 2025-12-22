#!/usr/bin/env bash
set -euo pipefail

MODULE_ORDER=()
declare -A MODULE_NAME=()
declare -A MODULE_DESC=()
declare -A MODULE_RUN=()
declare -A MODULE_CHECK=()
declare -A MODULE_NEEDS_ROOT=()

register_module() {
  local id="$1"
  local name="$2"
  local desc="$3"
  local run_fn="$4"
  local check_fn="${5:-}"
  local needs_root="${6:-false}"

  if [[ -n "${MODULE_NAME[$id]:-}" ]]; then
    die "Duplicate module id: $id"
  fi

  MODULE_ORDER+=("$id")
  MODULE_NAME["$id"]="$name"
  MODULE_DESC["$id"]="$desc"
  MODULE_RUN["$id"]="$run_fn"
  MODULE_CHECK["$id"]="$check_fn"
  MODULE_NEEDS_ROOT["$id"]="$needs_root"
}

load_modules() {
  local modules_dir="$1"
  local list_file="$modules_dir/modules.list"

  if [[ -f "$list_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%#*}"
      line="$(trim "$line")"
      [[ -z "$line" ]] && continue
      if [[ -f "$modules_dir/$line/module.sh" ]]; then
        # shellcheck source=/dev/null
        source "$modules_dir/$line/module.sh"
      else
        warn "Missing module: $line"
      fi
    done < "$list_file"
  else
    local module_file
    while IFS= read -r module_file; do
      [[ -z "$module_file" ]] && continue
      # shellcheck source=/dev/null
      source "$module_file"
    done < <(find "$modules_dir" -mindepth 2 -maxdepth 2 -name module.sh | sort)
  fi
}

list_modules() {
  local id
  for id in "${MODULE_ORDER[@]}"; do
    printf '%s\t%s\t%s\n' "$id" "${MODULE_NAME[$id]}" "${MODULE_DESC[$id]}"
  done
}

validate_module_ids() {
  local id
  for id in "$@"; do
    if [[ -z "${MODULE_NAME[$id]:-}" ]]; then
      die "Unknown module id: $id"
    fi
  done
}

run_modules() {
  local id
  validate_module_ids "$@"

  for id in "$@"; do
    log "Running module: $id - ${MODULE_NAME[$id]}"

    if [[ "${MODULE_NEEDS_ROOT[$id]}" == "true" ]]; then
      require_root
    fi

    local check_fn="${MODULE_CHECK[$id]}"
    if [[ -n "$check_fn" ]]; then
      if ! "$check_fn"; then
        warn "Skipping module (check failed): $id"
        continue
      fi
    fi

    local run_fn="${MODULE_RUN[$id]}"
    if [[ -z "$run_fn" ]]; then
      die "No run function for module: $id"
    fi

    "$run_fn"
  done
}
