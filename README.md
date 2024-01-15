# Bitwarden CLI Backup Helper

Dieses Bash-Skript bietet eine einfache Möglichkeit, Backups von einem Bitwarden-Konto zu erstellen und zu konfigurieren.

## Roadmap

- Voraussetzungen abfragen (jq, bw)
- Restore Funktionalilät einbauen
- die Flags überschreiben die einstellung im config.json (attachments_option)

## Installation

1. **Voraussetzungen:**
   - Bash (UNIX Shell)
   - OpenSSL
   - jq (JSON Query Tool)
   - bitwarden-cli (bw)
   - 7za
   - Zip
   - GPG (optional zur Verschlüsslung)

2. **Installiere die Abhängigkeiten:**

   - Unter Debian/Ubuntu:

     ```bash
     sudo apt-get update
     sudo apt-get install bash openssl jq
     ```

   - Unter CentOS/RHEL:

     ```bash
     sudo yum install bash openssl jq
     ```

   - Unter macOS (mit Homebrew):

     ```bash
     brew install bash openssl jq
     ```

   - Unter Windows:

     - Installiere [Git Bash](https://gitforwindows.org/) für Bash.
     - Installiere OpenSSL: [Win64 OpenSSL](https://slproweb.com/products/Win32OpenSSL.html)
     - Installiere [jq](https://stedolan.github.io/jq/download/).

3. **Skript herunterladen:**

   ```bash
   curl -O https://example.com/path/to/bash-programm.sh
   chmod +x bash-programm.sh

## Verwendung

```bash
./bash-programm.sh <subcommand> <opts>

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
1. Führe das Backup aus:

```bash
./bash-programm.sh backup -c myconfig.json -o backup.tar.gz
```
2. Gib die erforderlichen Informationen ein, wenn du dazu aufgefordert wirst.

### Konfigurationsdatei generieren
1. Generiere eine Konfigurationsdatei:

```bash
./bash-programm.sh generate -c myconfig.json
```
2. Beantworte die Fragen im interaktiven Dialog.






