# Bitwarden CLI Backup Helper

This bash script provides an easy way to create and configure backups from a Bitwarden account. 

## Installation

1. **Requirements:**
   - Bash (UNIX Shell)
   - OpenSSL
   - jq (JSON Query Tool)
   - [bitwarden-cli](https://bitwarden.com/help/cli/#tab-native-executable-bI3gMs3A3z4pl0fwvRie9)
   - tar
   - gpg (Optional for encryption)

2. **Install the dependencies:**

   - Debian/Ubuntu:

     ```bash
     sudo apt-get update
     sudo apt-get install jq gpg
     ```

3. **Download script:**

   ```bash
   curl -O https://gitlab.com/silkeackermann/bitwarden-backup-script/-/raw/main/bitwarden-backup-script.sh
   chmod +x bitwarden-backup-script.sh
   ```

## Usage

```bash
./bash-programm.sh <subcommand> <opts>

Commands:
  backup                       do a backup of the bitwarden instance
  generate                     generates a config file

Options:
  -a --attachments             Adds attachments to the backup
  -c --config <file>           Set the config file (default: config.json)
  -o --output <file>           Set the output file (default: bitwarden_backup_<timestamp>.tar.gz)
  -q --quiet                   Suppress output
  -p --passphrase <passphrase> Set the passphrase for encryption/decryption of the config file (only recommended in secure environments)

Global Options:
  -h --help                    Show this help message
```

## Tutorial

### Create backup

```bash
./bash-programm.sh backup -c myconfig.json -o example-backup
```

### Generate configuration file

```bash
./bash-programm.sh generate -c myconfig.json
```






