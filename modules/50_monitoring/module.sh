#!/usr/bin/env bash
set -euo pipefail

module_monitoring_run() {
  log "TODO(monitoring): install agent, configure alerts"
}

register_module "monitoring" "Monitoring" "Monitoring agent setup" "module_monitoring_run" "" "true"
