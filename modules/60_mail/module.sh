#!/usr/bin/env bash
set -euo pipefail

module_mail_run() {
  log "TODO(mail): SMTP relay or local MTA for notifications"
}

register_module "mail" "Mail" "Outbound mail setup" "module_mail_run" "" "true"
