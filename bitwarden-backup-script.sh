#!/bin/bash

# Speichere den absoluten Pfad des Skripts
script_path=$(realpath "$0")
temp_dir=".bw_backup"

# Standardwerte für Optionen
attachments=false
config_file="config.json"
output_file="bitwarden_backup_$(date +"%d_%m_%Y_%H_%M")"
quiet=false

# Funktion für die Anzeige der Hilfe
show_help() {
  cat << EOT
  Version: 0.1
  Author: Jensberger90

  Usage: $0 <subcommand> <opts>
  Bitwarden CLI backup helper

  Commands:
    backup                    do a backup of the bitwarden instance
    generate                  generates a config file

  Options:
    -a --attachments          Adds attachments to the backup
    -c --config <file>        Set the config file (default: config.json)
    -o --output <file>        Set the output file (default: bitwarden_backup_<timestamp>.tar.gz)
    -q --quiet                Suppress output

  Global Options:
    -h --help                 Show this help message
EOT
}

# Bitwarden Logout beim Beenden des Skripts, falls angemeldet.
on_exit() {
    local exit_code=$?

    bw login --check > /dev/null 2>&1
    logged_in=$?

    if test $logged_in -eq 0
    then    
        bw logout
        echo "Logged out from Bitwarden."
    fi

    # Überprüfen, ob der temporäre Ordner existiert, bevor er gelöscht wird
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir" && echo "Temporary files cleaned up successfully."
    fi

    exit $exit_code
}

# Funktion zum Überprüfen der Passworteingabe
check_password_match() {
  local pass1="$1"
  local pass2="$2"

  if [ "$pass1" != "$pass2" ]; then
    echo "Error: Passwords do not match. Please try again."
    exit 1
  fi
}

# Funktion, die den echo-Befehl ersetzt und bei Bedarf keine Ausgaben macht
log() {
    if [ "$quiet" = true ]; then
        return 0  # Quiet-Modus aktiviert, keine Ausgabe
    else
        echo "$@"
    fi
}

debug_global_options() {
  # Hier kommt die spezifische Logik für das 'backup'-Subcommand
  echo "Executing export_data command"
  echo "Attachments option: $attachments"
  echo "Config file option: $config_file"
  echo "Ouput file option: $output_file"
  echo "Quiet option: $quiet"
  echo "-------------------------------"
  echo
}

# Funktion zum Verschlüsseln eines Passworts und Erstellen des Hashes
encrypt_password() {
    local password="$1"
    local passphrase="$2"

    local encrypted_password=$(echo "$password" | openssl enc -aes-256-cbc -md sha512  -pbkdf2 -iter 100000 -salt -pass pass:"$passphrase" | base64 -w 0 2> /dev/null) 

    echo -n "$encrypted_password"
}

# Funktion zum Entschlüsseln eines verschlüsselten Passworts
decrypt_password() {
    local encrypted_password="$1"
    local passphrase="$2"

    echo "$encrypted_password" | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:"$passphrase" 2> /dev/null
}

export_data() {
  local server="$1"
  local email="$2"
  local password="$3"
  local organization_id="$4"
  local organization_name="$5"

  debug_global_options

  # Login in Bitwarden Tresor
  key=$(bw login "$email" "$password" --raw)
  export BW_SESSION="$key"

  # Prüfen ob Login erfolgreich
  if bw login --check > /dev/null 2>&1; then
    if [ -n "$organization_id" ]; then
      echo "Logged on $server with $email as Organization."
    else
      echo "Logged in on $server with $email."
    fi
  else
    echo "Login failed. Exiting."
    exit 1
  fi

  # Bestimme den Dateinamen für den Export
  if [ -n "$organization_id" ]; then
    export_dir="./$temp_dir/${email}_orga_${organization_name}"
  else
    export_dir="./$temp_dir/$email"
  fi

  # Export des Tresors
  bw export $password --output "$export_dir/bitwarden.json" --format json "${organization_id:+ --organizationid $organization_id}"
  bw export $password --output "$export_dir/bitwarden.csv" --format csv "${organization_id:+ --organizationid $organization_id}"

  # Erstelle das Verzeichnis für den Export von Anhängen
  if [ "$attachments" = "true" ]; then
    # Ordner für die Anhänge erstellen
    mkdir -p "$export_dir/attachments"

    # Anhänge herunterladen
    bash <(bw list items --organizationid "${organization_id:-null}" | jq -r '.[] | select(.attachments != null) | . as $parent | .attachments[] | "bw get attachment \(.id) --itemid \($parent.id) --output \"'$export_dir'/attachments/\($parent.id)/\(.fileName)\""')
    #bw list items --organizationid "${organization_id:-null}" | jq -r '.[] | select(.attachments != null) | . as $parent | .attachments[] | "bw get attachment \(.id) --itemid \($parent.id) --output \"$export_dir/attachments/\($parent.id)/\(.fileName)\"" | bash'

  fi

  bw logout
}

# Funktion für das Backup-Subcommand
backup_command() {

  # Überprüfe, ob der Benutzer bei Bitwarden eingeloggt ist
  bw login --check > /dev/null 2>&1
  logged_in=$?

  if test $logged_in -eq 0; then
    # Benutzer ist eingeloggt, führe Logout durch
    bw logout
    echo "Logged out from Bitwarden."
  fi

  debug_global_options

  # Prüfe, ob die Konfigurationsdatei existiert
  if [ ! -e "$config_file" ]; then
    echo "Error: Configuration file not found: $config_file"
    exit 1
  fi

  # Lese die Daten aus der Konfigurationsdatei
  attachments=$(jq -r '.attachments' "$config_file")
  encryption_passphrase=$(jq -r '.passphrase' "$config_file")
  bitwarden_server=$(jq -r '.url' "$config_file")
  accounts=($(jq -c '.accounts[]' "$config_file"))

  # Prüfe, ob die encryption-passphrase korrekt ist
  echo "Enter decryption passphrase for backup:"
  read -s passphrase

  # Prüfe, ob die encryption-passphrase korrekt ist
  if [[ $(decrypt_password "$encryption_passphrase" "$passphrase") != "$passphrase" ]]; then
      echo "Incorrect passphrase. Exiting."
      exit 1
  fi

  # Überprüfe, ob der temporäre Ordner existiert
  if [ ! -d "$temp_dir" ]; then
      # Erstelle den Ordner, falls er nicht existiert
      mkdir -p "$temp_dir" && echo "Temporary folder created successfully."
  else
      # Lösche den Inhalt, falls der Ordner bereits existiert
      rm -rf "$temp_dir"/* && echo "Cleared existing content in the temporary folder."
  fi

  #TODO prüfen ob config File korrektes json

  # Konfiguriere Bitwarden mit dem ausgelesenen Server
  bw config server "$bitwarden_server"

  # Loop über Accounts und rufe export_data für jeden auf
  for account in "${accounts[@]}"; do
      email=$(jq -r '.email' <<< "$account")
      password_hash=$(jq -r '.password' <<< "$account")
      password=$(decrypt_password "$password_hash" "$passphrase")
      organisation=$(jq -r '.organisation' <<< "$account")
 
      if [ "$organisation" == "true" ]; then
          organisation_id=$(jq -r '.organisation_id' <<< "$account")
          organisation_name=$(jq -r '.organisation_name' <<< "$account")
          export_data "$bitwarden_server" "$email" "$password" "$organisation_id" "$organisation_name"
      else
          export_data "$bitwarden_server" "$email" "$password"
      fi
  done

  # Beispiel: Füge hier den Code für das Backup hinzu

  # Archiv erstellen und direkt verschlüsseln
  #tar -cpf "archiv.tar" $temp_dir
  cd $temp_dir
  zip -r "$output_file.zip" *

  # Frage den Benutzer, ob er die Zip-Datei mit GPG verschlüsseln möchte
  # read -p "Do you want to encrypt the ZIP file with GPG? (yes/no): " encrypt_with_gpg
  # encrypt_with_gpg="${encrypt_with_gpg:-yes}"  # Wenn encrypt_with_gpg leer ist, setze den Standardwert

  # case "$encrypt_with_gpg" in
  #     [yY]|[yY][eE][sS])
  #         # Benutzer möchte die Zip-Datei mit GPG verschlüsseln
  #         # read -s -p "Enter GPG passphrase: " gpg_passphrase
  #         # echo

  #         # Füge hier den Code zum Verschlüsseln der Zip-Datei mit GPG hinzu
  #         zip_file="$output_file.zip"
  #         tar -cpf - $temp_dir | 7za a -si -t7z -m0=lzma2 -mx=6 -mfb=64 -md=32m -ms=on -mhe=on -so | gpg --symmetric --cipher-algo AES256 --output "$zip_file.gpg"

  #         echo "ZIP file encrypted with GPG: $zip_file.gpg"
  #         ;;
  #     *)
  #         # Benutzer möchte die Zip-Datei nicht mit GPG verschlüsseln
  #         zip_file="$output_file.zip"
  #         tar -cpf - $temp_dir | 7za a -si -t7z -m0=lzma2 -mx=6 -mfb=64 -md=32m -ms=on -mhe=on -bd "$zip_file"

  #         echo "ZIP file created: $zip_file"
  #         ;;
  # esac

}

# Funktion für das Generate-Subcommand
generate_command() {

    # Funktion zum interaktiven Erstellen der config.json-Datei
    create_config_file() {
      echo "Generating config.json..."

      read -p "Add attachments to the backup? (true/false): " -r attachments
      attachments="${attachments:-true}"  # Wenn attachments leer ist, setze den Standardwert

      read -p "Enter Bitwarden URL (default: https://vault.bitwarden.com): " -r url
      url="${url:-https://vault.bitwarden.com}"  # Wenn url leer ist, setze den Standardwert

      read -p "Enter encryption passphrase for password encryption: " -s encryption_passphrase
      echo
      read -p "Confirm encryption passphrase: " -s confirm_passphrase
      echo

      # Überprüfe, ob die Passwörter übereinstimmen
      check_password_match "$encryption_passphrase" "$confirm_passphrase"

      # Verschlüsselung und Hashing des Passworts
      encrypted_password_hash=$(encrypt_password "$encryption_passphrase" "$encryption_passphrase")

      # Array für Benutzerkonten
      accounts=()

      while true; do
          read -p "Enter email address (leave empty to finish): " -r email
          if [ -z "$email" ]; then
              break
          fi

          read -p "Enter password: " -s password
          echo

          # Verschlüsselung und Hashing des Passworts
          encrypted_password=$(encrypt_password "$password" "$encryption_passphrase")

          read -p "Is this account part of an organization? (true/false): " -r organisation
          organisation="${organisation:-false}" #Wenn organisation leer ist, setzte den Standardwert

          # Wenn das Konto Teil einer Organisation ist, zusätzliche Informationen abfragen
          if [ "$organisation" == "true" ]; then
              read -p "Enter organization ID: " -r organisation_id
              read -p "Enter organization name: " -r organisation_name
          fi

          # Konto zur Liste hinzufügen
          accounts+=("{\"email\":\"$email\",\"password\":\"$encrypted_password\",\"organisation\":$organisation")
          
          # Wenn das Konto Teil einer Organisation ist, füge zusätzliche Informationen hinzu
          if [ "$organisation" == "true" ]; then
              accounts+=(",\"organisation_id\":\"$organisation_id\",\"organisation_name\":\"$organisation_name\"")
          fi

          accounts+=("},")

          echo "Account added."
      done

      # Überprüfe, ob das Array accounts nicht leer ist
      if [ ${#accounts[@]} -gt 0 ]; then
          # Hole das letzte Element
          last_element="${accounts[-1]}"

          # Entferne das letzte Komma, falls vorhanden
          last_element="${last_element%,}"

          # Setze das aktualisierte letzte Element zurück
          accounts[-1]="$last_element"
      fi

      # Erstelle die config.json-Datei  
      echo "{\"attachments\":$attachments,\"url\":\"$url\",\"passphrase\":\"$encrypted_password_hash\",\"accounts\":[${accounts[@]}]}" > "$config_file"
      echo "config.json file created: $config_file"
  }


    # Überprüfe, ob ein Konfigurationsdateiname angegeben wurde
    if [ -z "$config_file" ]; then
        echo "Error: No configuration file specified."
        show_help
        exit 1
    fi

    # Überprüfe, ob die Konfigurationsdatei bereits existiert
    if [ -e "$config_file" ]; then
        read -p "Configuration file already exists. Do you want to overwrite it? (y/n): " overwrite
        if [ "$overwrite" != "y" ]; then
            echo "Aborted. No changes made."
            exit 0
        fi
    fi

    # Rufe die Funktion zum Erstellen der Konfigurationsdatei auf
    create_config_file
}

trap on_exit EXIT

# Verarbeite die Kommandozeilenargumente
while [[ $# -gt 0 ]]; do
  case "$1" in
    backup)
      subcommand="backup"
      shift
      ;;
    generate)
      subcommand="generate"
      shift
      ;;
    -a|--attachments)
      attachments=true
      shift
      ;;
    -c|--config)
      if [[ -n "$2" ]]; then
        config_file="$2"
        shift 2
      else
        echo "Error: Missing argument for $1"
        exit 1
      fi
      ;;
    -o|--output)
      if [[ -n "$2" ]]; then
        output_file="$2"
        shift 2
      else
        echo "Error: Missing argument for $1"
        exit 1
      fi
      ;;
    -q|--quiet)
      quiet=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Error: Unknown option or argument: $1"
      exit 1
      ;;
  esac
done

# Überprüfe, ob ein Subcommand spezifiziert wurde
if [[ -z "$subcommand" ]]; then
  echo "Error: No subcommand specified."
  echo
  show_help
  exit 1
fi

# Programmlogik ausführen je nach Subcommand
case "$subcommand" in
  backup)
    backup_command
    ;;
  generate)
    generate_command
    ;;
  *)
    echo "Error: Unknown subcommand: $subcommand"
    exit 1
esac

#echo "Programm wurde erfolgreich ausgeführt"
exit 0

# Ausgabe der verarbeiteten Optionen
#echo "Subcommand: $subcommand"
#echo "Attachments: $attachments"
#echo "Config file: $config_file"
