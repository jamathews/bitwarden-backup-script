# Bitwarden CLI Backup Helper

Dieses Bash-Skript bietet eine einfache Möglichkeit, Backups von einem Bitwarden-Konto zu erstellen und zu konfigurieren.

## Installation

1. **Voraussetzungen:**
   - Bash (UNIX Shell)
   - OpenSSL
   - jq (JSON Query Tool)
   - [bitwarden-cli](https://bitwarden.com/de-DE/help/cli/#tab-nativ-ausf%C3%BChrbar-bI3gMs3A3z4pl0fwvRie9)
   - tar
   - GPG (optional zur Verschlüsslung)

2. **Installiere die Abhängigkeiten:**

   - Unter Debian/Ubuntu:

     ```bash
     sudo apt-get update
     sudo apt-get install bash openssl jq zip gpg
     ```

3. **Skript herunterladen:**

   ```bash
   curl -O https://gitlab.com/silkeackermann/bitwarden-backup-script/-/raw/main/bitwarden-backup-script.sh
   chmod +x bitwarden-backup-script.sh
   ```

## Verwendung

```bash
./bash-programm.sh <subcommand> <opts>

Subcommand:

- backup: Erstellt ein Backup des Bitwarden-Kontos.
- generate: Generiert eine Konfigurationsdatei.

Optionen:

-a, --attachments: Fügt Anhänge zum Backup hinzu.
-c, --config <file>: Legt die Konfigurationsdatei fest (Standard: config.json).
-o, --output <file>: Legt die Ausgabedatei fest (Standard: bitwarden_backup_<timestamp>.tar.gz).
-q, --quiet: Unterdrückt die Ausgabe.
Global:

-h, --help: Zeigt diese Hilfe an.
```

## Tutorial

### Backup erstellen

```bash
./bash-programm.sh backup -c myconfig.json -o backup.tar.gz
```

### Konfigurationsdatei generieren

```bash
./bash-programm.sh generate -c myconfig.json
```






