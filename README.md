# Server-Tools

Modularer Server-Setup in Bash. Ziel: einfache Ausfuehrung per one-liner und klare Module fuer Shell, Tools, Sicherheit, SSH, Monitoring, Mail.

## Struktur
- `run.sh` bootstrapped lokal oder remote und startet `core/cli.sh`
- `core/` enthaelt CLI, Module-Registry, UI
- `modules/` enthaelt einzelne Module
- `config/` enthaelt Default- und lokale Einstellungen

## Quickstart
Lokal:
```
./run.sh --menu
```

Remote (Argumente nach `--`):
```
bash -c "$(wget -O - https://example.com/your/run.sh)" -- --menu
```

Nicht-interaktiv:
```
./run.sh --select base,tools,ssh
./run.sh --all
```

## Konfiguration
- `config/defaults.env` ist der Basis-Defaultsatz
- lege `config/local.env` an und ueberschreibe Werte

## Module
Module liegen in `modules/<order>_<name>/module.sh`. Jedes Modul registriert sich:

```
module_example_run() {
  log "TODO(example): implement"
}

register_module "example" "Example" "Example module" "module_example_run" "" "true"
```

Die Reihenfolge kommt aus `modules/modules.list`.

## Hinweise
- `--menu` nutzt `whiptail` oder `dialog` falls installiert, sonst Text-Prompt.
- `--dry-run` zeigt nur die Auswahl.
- `run.sh` enthaelt Platzhalter-URL, bitte an dein Repo anpassen.
