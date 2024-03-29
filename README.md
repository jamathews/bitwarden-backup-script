# Bitwarden CLI Backup Helper

This bash script provides an easy way to create and configure backups from a Bitwarden account. 

## Features

- add attachments to the export
- export multiple accounts at once
- direct encryption of the export with gpg (symmetric)
- use of a config file to simplify repeated input of credentials (encrypted of course)
- support for organizations
- executable as cronjob
- works without user interaction (if needed)

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
./bitwarden-backup-script.sh <subcommand> <opts>

Commands:
  backup                       do a backup of the bitwarden instance
  generate                     generates a config file

Options:
  -a --attachments                 Adds attachments to the backup
  -c --config <file>               Set the config file (default: config.json)
  -o --output <file>               Set the output file (default: bitwarden_backup_<timestamp>.tar.gz)
  -q --quiet                       Suppress output
  -p --passphrase <passphrase>     Set the passphrase for encryption/decryption of the config file (only recommended in secure environments)
  -g --gpg                         Encrypt the backup using GPG (symmetric encryption)
  -s --gpg-passphrase <passphrase> Set the passphrase for GPG encryption
  -n --non-interactive             Run in non-interactive mode (useful for cron jobs)

Global Options:
  -h --help                        Show this help message
```

## Tutorial

### Create backup

```bash
./bitwarden-backup-script.sh backup -c myconfig.json -o example-backup
```

### Generate configuration file

```bash
./bitwarden-backup-script.sh generate -c myconfig.json
```

### Example usage in a cronjob

```bash
5 4 * * * /opt/bitwarden-backup-script.sh backup -c /opt/myconfig.json -o "/opt/bw-backup-$(date +'\%d_\%m_\%Y_\%H_\%M')" -n --gpg --gpg-passphrase "YourPassphrase" -p "DecryptConfigPassword"
```
_Note:_ To interpret the date expression $(date +'\%d_\%m_\%Y_\%H_\%M') correctly in a Crontab file, escape all percent signs (%) with a backslash (\\). This prevents them from being interpreted as special characters.

### Decrypting and Extracting backup with GPG

```bash
gpg --decrypt --output decrypted_backup.tar.gz encrypted_backup.tar.gz.gpg
tar -xzf decrypted_backup.tar.gz
```
_Note:_ By default, the extracted files will be placed in the current directory under `.bw_backup`. 

## Troubleshooting

### Error while encrypting the backup with GPG

If you encounter the following error message while encrypting the backup with GPG:

```bash
gpg: problem with the agent: Inappropriate ioctl for device
gpg: error creating passphrase: Operation cancelled
gpg: symmetric encryption of '[stdin]' failed: Operation cancelled
```

**Cause**: This error often occurs when GPG is unable to interact with the user because it expects a graphical environment but none is available. This can happen when running GPG in a non-interactive session without a GUI, such as in a script or over SSH.

**Solution**: To resolve this issue, use the `--non-interactive` option in combination with the `--gpg` option to activate GPG. Additionally, you have to specify the GPG passphrase using the `--gpg-passphrase` option to set the passhrase for encryption.

**Example command for non-interactive session:**

```bash
./bitwarden-backup-script.sh backup --gpg --gpg-passphrase "YourPassphrase" --non-interactive --passphrase "DecryptConfigPassword" ...
```

### `bw` command not found when running via Crontab

If you encounter an issue where the `bw` (Bitwarden CLI) command, or any other dependency such as `jq`, is not found when running your script via Crontab, this is likely due to the limited environment provided by Cron, which may not include the necessary paths for locating these commands.

**Cause**: Cron jobs run with a minimal environment, and may not include the same settings as your interactive shell, such as the `PATH` variable.

**Solution**: To resolve this issue, explicitly set the `PATH` variable in your Cron job to include the directory where the `bw` command is located. You can do this by specifying the full `PATH` value at the beginning of your Cron job command or script.

**Example crontab file:**
```bash
# Edit your Crontab
crontab -e

# Add the following line to explicitly set the PATH variable
PATH=/usr/local/bin:/usr/bin:/bin:/path/to/bitwarden-cli-directory:/path/to/jq-directory

# Your Cron job command or script follows...
5 4 * * * /path/to/your/bitwarden-backup-script.sh
```