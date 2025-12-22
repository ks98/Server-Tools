#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# shellcheck source=/dev/null
source "$ROOT_DIR/core/util.sh"
# shellcheck source=/dev/null
source "$ROOT_DIR/core/module.sh"
# shellcheck source=/dev/null
source "$ROOT_DIR/core/ui.sh"

if [[ -f "$ROOT_DIR/config/defaults.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/config/defaults.env"
fi
if [[ -f "$ROOT_DIR/config/local.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/config/local.env"
fi

usage() {
  cat <<'USAGE'
Usage: ./run.sh [options]

Options:
  --list                 List modules
  --menu                 Interactive selection
  --select <id1,id2>      Select modules by id
  --all                  Run all modules
  --dry-run              Print what would run
  -h, --help             Show help

Examples:
  ./run.sh --menu
  ./run.sh --select base,tools,ssh
  ./run.sh --all --dry-run
  bash -c "$(wget -O - https://raw.githubusercontent.com/ks98/Server-Tools/main/run.sh)" -- --menu
USAGE
}

action=""
dynamic_select=""
dry_run="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      action="list"
      ;;
    --menu)
      action="menu"
      ;;
    --all)
      action="all"
      ;;
    --select)
      shift
      [[ $# -gt 0 ]] || die "--select requires a value"
      dynamic_select="$1"
      action="select"
      ;;
    --select=*)
      dynamic_select="${1#*=}"
      action="select"
      ;;
    --dry-run)
      dry_run="true"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
  shift
done

load_modules "$ROOT_DIR/modules"

if [[ "$action" == "list" ]]; then
  list_modules
  exit 0
fi

selected=()
case "$action" in
  all)
    selected=("${MODULE_ORDER[@]}")
    ;;
  select)
    IFS=',' read -r -a selected <<< "$dynamic_select"
    ;;
  menu|"")
    if ! is_tty; then
      die "No TTY available. Use --select or --all."
    fi
    mapfile -t selected < <(ui_choose_modules)
    ;;
esac

if [[ ${#selected[@]} -eq 0 ]]; then
  die "No modules selected."
fi

validate_module_ids "${selected[@]}"

if [[ "$dry_run" == "true" ]]; then
  log "Dry run. Selected modules: ${selected[*]}"
  exit 0
fi

run_modules "${selected[@]}"
