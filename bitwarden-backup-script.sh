#!/bin/bash

# Global color variables
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
GREY='\033[0;90m'
NC='\033[0m'  # ANSI Escape Code to reset color

# Store the absolute path of the script
script_path=$(realpath "$0")
temp_dir=".bw_backup"

# Default values for options
attachments=false
config_file="config.json"
output_file="bitwarden_backup_$(date +"%d_%m_%Y_%H_%M")"
non_interactive=false
#gpg
#passphrase
#gpg_passphrase
#quiet (default: false)
#archive

# Function to display help
show_help() {
  cat << EOT
  Version: 0.1
  Author: Jensberger90

  Usage: $0 <subcommand> <opts>
  Bitwarden CLI backup helper

  Commands:
    backup                           do a backup of the bitwarden instance
    generate                         generates a config file
    extract                          extract and optionally decrypt the backup archive

  Options:
    -a --attachments                 Adds attachments to the backup
    -c --config <file>               Set the config file (default: config.json)
    -o --output <file|folder>        Set the output file or folder (default: bitwarden_backup_<timestamp>)
    -q --quiet                       Suppress output
    -p --passphrase <passphrase>     Set the passphrase for encryption/decryption of the config file (only recommended in secure environments)
    -g --gpg                         Encrypt the backup using GPG (symmetric encryption)
    -s --gpg-passphrase <passphrase> Set the passphrase for GPG encryption/decryption
    -n --non-interactive             Run in non-interactive mode (useful for cron jobs)
    -f --archive <file>              Set the archive file to extract

  Global Options:
    -h --help                        Show this help message
EOT
}

# Function to log text with different colors
log() {
    local type="${1}"   # Type of text (normal, warning, error, success), default is normal
    shift
    
    # Check if quiet mode is activated
    if [ "$quiet" = true ]; then
        return 0  # Quiet mode activated, no output
    else
        case "$type" in
            normal)
                echo "$@"
                ;;
            warning)
                echo -e "${YELLOW}Warning: $@${NC}"
                ;;
            error)
                echo -e "${RED}Error: $@${NC}"
                ;;
            success)
                echo -e "${GREEN}$@${NC}"
                ;;
            *)
                echo "$type $@"
                ;;
        esac
    fi
}

# Bitwarden Logout on exit if logged in
on_exit() {
    local exit_code=$?

    # Check if the user is logged in to Bitwarden
    if bw login --check > /dev/null 2>&1; then
      # User is logged in, perform logout
      bw logout "${quiet:+--quiet}"
      log "Logged out from Bitwarden."
    fi

    # Check if the temporary folder exists before deleting
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir" && log "Temporary files cleaned up successfully."
    fi

    exit $exit_code
}

# Function to check dependencies
check_dependencies() {
  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    log error "jq is not installed. Please install jq to proceed."
    exit 1
  fi

  # Check if gpg is installed (optional)
  if command -v gpg &> /dev/null; then
    log success "GPG is installed. Encryption feature is available."
  else
    log warning "GPG is not installed. Encryption feature will be disabled."
  fi

  # Check if bw (Bitwarden CLI) is installed
  if ! command -v bw &> /dev/null; then
    log error "Bitwarden CLI (bw) is not installed. Please install bw to proceed."
    exit 1
  fi

  # Check if openssl is installed
  if ! command -v openssl &> /dev/null; then
    log error "openssl is not installed. Please install openssl to proceed."
    exit 1
  fi
}

# Function to check password input
check_password_match() {
  local pass1="$1"
  local pass2="$2"

  if [ "$pass1" != "$pass2" ]; then
    log error "Passwords do not match. Please try again."
    exit 1
  fi
}

debug_global_options() {
  echo "Debug global options:"
  echo "Attachments option: $attachments"
  echo "Config file option: $config_file"
  echo "Ouput file option: $output_file"
  echo "Passphrase option: $passphrase"
  echo "GPG passphrase option: $gpg_passphrase"
  echo "GPG option: $gpg"
  echo "Non interactive option: $non_interactive"
  echo "Archive option: $archive"
  echo "Quiet option: $quiet"
  echo "-------------------------------"
  echo
}

# Function to encrypt a password and create the hash
encrypt_password() {
    local password="$1"
    local passphrase="$2"

    local encrypted_password=$(echo "$password" | openssl enc -aes-256-cbc -md sha512  -pbkdf2 -iter 100000 -salt -pass pass:"$passphrase" | base64 -w 0 2> /dev/null) 

    echo -n "$encrypted_password"
}

# Function to decrypt an encrypted password
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
  
  # Login to Bitwarden vault
  key=$(bw login "$email" "$password" --raw)
  export BW_SESSION="$key"

  # Check if login is successful
  if bw login --check > /dev/null 2>&1; then
    if [ -n "$organization_id" ]; then
      log "Logged on $server with $email as Organization."
    else
      log "Logged in on $server with $email."
    fi
  else
    log error "Login failed. Exiting."
    exit 1
  fi

  # Determine the filename for export
  if [ -n "$organization_id" ]; then
    export_dir="./$temp_dir/${email}_orga_${organization_name}"
  else
    export_dir="./$temp_dir/$email"
  fi

  # Export the vault
  bw export $password "${quiet:+--quiet}" --output "$export_dir/bitwarden.json" --format json "${organization_id:+--organizationid $organization_id}" 
  bw export $password "${quiet:+--quiet}" --output "$export_dir/bitwarden.csv" --format csv "${organization_id:+--organizationid $organization_id}" 

  # Create directory for attachments export
  if [ "$attachments" = "true" ]; then
    # Create directory for attachments
    mkdir -p "$export_dir/attachments"

    # Download attachments
    bash <(bw list items --organizationid "${organization_id:-null}" | jq -r '.[] | select(.attachments != null) | . as $parent | .attachments[] | "bw get attachment \(.id) '${quiet:+--quiet}' --itemid \($parent.id) --output \"'$export_dir'/attachments/\($parent.id)/\(.fileName)\""')

  fi

  bw logout "${quiet:+--quiet}"
}

# Function for the backup subcommand
backup_command() {

  # Check if the user is logged in to Bitwarden
  if bw login --check > /dev/null 2>&1; then
    # User is logged in, perform logout
    bw logout "${quiet:+--quiet}"
    log "Logged out from Bitwarden."
  fi

  # Check if the configuration file exists
  if [ ! -e "$config_file" ]; then
    log error "Configuration file not found: $config_file"
    exit 1
  fi

  # Check if the JSON file is valid
  if ! jq empty < "$config_file" &> /dev/null; then
    log error "The JSON file '$config_file' is not valid."
    exit 1
  fi

  # Check if non_interactive mode is enabled
  if [ "$non_interactive" = true ]; then
      # Log that non-interactive mode is enabled
      log "Non-interactive mode is enabled."

      # Check if passphrase is set
      if [ -z "$passphrase" ]; then
          # Log an error and exit
          log error "Passphrase is required in non-interactive mode."
          exit 1
      fi

      # Check if GPG is enabled
      if [ "$gpg" = true ]; then
          # Check if GPG passphrase is set
          if [ -z "$gpg_passphrase" ]; then
              # Log an error and exit
              log error "GPG passphrase is required in non-interactive mode."
              exit 1
          fi
      else
        # Set gpg to false if not explicitly set to true
        gpg=false
      fi
  fi

  # Read data from the configuration file
  attachments=$(jq -r '.attachments' "$config_file")
  encryption_passphrase=$(jq -r '.passphrase' "$config_file")
  bitwarden_server=$(jq -r '.url' "$config_file")
  accounts=($(jq -c '.accounts[]' "$config_file"))

  # Check if passphrase is already set by flag
  if [ -n "$passphrase" ]; then
    log "Using pre-defined passphrase."
    decryption_passphrase="$passphrase"
  else
    # Check if the encryption passphrase is correct
    read -p "Enter decryption passphrase for backup: " -s decryption_passphrase
    echo
  fi

  if [[ $(decrypt_password "$encryption_passphrase" "$decryption_passphrase") != "$decryption_passphrase" ]]; then
      log error "Incorrect passphrase. Exiting."
      exit 1
  fi

  # Check if the temporary folder exists
  if [ ! -d "$temp_dir" ]; then
      # Create the folder if it doesn't exist
      mkdir -p "$temp_dir" && log "Temporary folder created successfully."
  else
      # Clear the existing content if the folder already exists
      rm -rf "$temp_dir"/* && log "Cleared existing content in the temporary folder."
  fi

  # Configure Bitwarden with the extracted server
  bw config server "$bitwarden_server" "${quiet:+--quiet}"

  # Loop over accounts and call export_data for each
  for account in "${accounts[@]}"; do
    # Extract user data
    email=$(jq -r '.email' <<< "$account")
    password_hash=$(jq -r '.password' <<< "$account")
    password=$(decrypt_password "$password_hash" "$decryption_passphrase")

    # Check for organization
    if [ "$(jq -r '.organisation' <<< "$account")" == "true" ]; then
        # Organisation-Details extrahieren
        organisation_id=$(jq -r '.organisation_id' <<< "$account")
        organisation_name=$(jq -r '.organisation_name' <<< "$account")
    fi

    # Export data
    export_data "$bitwarden_server" "$email" "$password" "$organisation_id" "$organisation_name"
  done

  # Ask user whether to encrypt the ZIP file with GPG if gpg is not set
  if [ -z "$gpg" ]; then
      read -p "Do you want to encrypt the ZIP file with GPG? (Y/n): " encrypt_with_gpg

      # Set default value for encryption to "Y" if no input is provided
      encrypt_with_gpg="${encrypt_with_gpg:-Y}"

      # Check if the input starts with "Y" or "y" (case-insensitive)
      if [ "$encrypt_with_gpg" != "${encrypt_with_gpg#[YyjJ]}" ]; then
          gpg=true
      else
          gpg=false
      fi
  fi

  # Check if GPG is installed when gpg enabled
  if [ "$gpg" = true ] && ! command -v gpg &> /dev/null; then
      log error "GPG is not installed. Please install GPG to proceed."
      exit 1
  fi

  # Check if gpg enabled
  if [ "$gpg" = true ]; then
    log "Encrypting the Archive file with GPG..."

    # Check if GPG passphrase is set
    if [ -z "$gpg_passphrase" ]; then
      # Encrypt the TAR file using GPG without passphrase
      tar cz -C "$temp_dir" . | gpg --symmetric --cipher-algo AES256 -o "$output_file.tar.gz.gpg"
    else
      # Encrypt the TAR file using GPG with passphrase in batch modus
      tar cz -C "$temp_dir" . | gpg --batch --passphrase "$gpg_passphrase" --symmetric --cipher-algo AES256 -o "$output_file.tar.gz.gpg"
    fi

    log "Encryption completed. Encrypted file: $output_file.tar.gz.gpg"
  else
    log warning "The output file is saved unencrypted because gpg is not enabled."
    log "Creating the TAR archive..."

    # Creating the TAR archive without encryption
    tar czpf "$output_file.tar.gz" -C "$temp_dir" .

    log "TAR archive created. File: $output_file.tar.gz"
  fi

}

# Function for the generate subcommand
generate_command() {

    # Function for interactively creating the config.json file
    create_config_file() {
      log "Generating $config_file..."

      read -p "Add attachments to the backup? (true/false): " -r attachments
      attachments="${attachments:-false}"  # Set default value if attachments is empty

      read -p "Enter Bitwarden URL (default: https://vault.bitwarden.com): " -r url
      url="${url:-https://vault.bitwarden.com}"   # Set default value if url is empty

      # Check if passphrase is already set by flag
      if [ -n "$passphrase" ]; then
        log "Using pre-defined passphrase."
        encryption_passphrase="$passphrase"
      else
        read -p "Enter encryption passphrase for password encryption: " -s encryption_passphrase
        echo
        read -p "Confirm encryption passphrase: " -s confirm_passphrase
        echo

        # Check if passphrase is empty
        if [ -z "$encryption_passphrase" ]; then
          log error "Passphrase cannot be empty."
          exit 1
        fi

        # Check if passwords match
        check_password_match "$encryption_passphrase" "$confirm_passphrase"
      fi

      # Encryption and hashing of the password
      encrypted_password_hash=$(encrypt_password "$encryption_passphrase" "$encryption_passphrase")

      # Array for user accounts
      accounts=()

      while true; do
      
        read -p "Enter email address: " -r email
        read -p "Enter password: " -s password
        echo

        # Encryption and hashing of the password
        encrypted_password=$(encrypt_password "$password" "$encryption_passphrase")
        accounts+=("{\"email\":\"$email\",\"password\":\"$encrypted_password\"")

        read -p "Is this account part of an organization? (true/false): " -r organisation
        organisation="${organisation:-false}" # Set default value if organisation is empty

        # If the account is part of an organization, prompt for additional information
        if [ "$organisation" == "true" ]; then
            read -p "Enter organization ID: " -r organisation_id
            read -p "Enter organization name: " -r organisation_name
        fi

        # Add account to the list
        accounts+=(",\"organisation\":$organisation")
        
        # If the account is part of an organization, add additional information
        if [ "$organisation" == "true" ]; then
            accounts+=(",\"organisation_id\":\"$organisation_id\",\"organisation_name\":\"$organisation_name\"")
        fi

        accounts+=("},")

        log "Account added."

        # Ask the user if they want to add another account
        read -p "Do you want to add another account? (y/N): " -r add_another
        add_another="${add_another:-N}" # Set default value if add_another is empty

        if [ "$add_another" == "${add_another#[YyjJ]}" ]; then
            break
        fi
      done

      # Check if the accounts array is not empty
      if [ ${#accounts[@]} -gt 0 ]; then
          # Get the last element
          last_element="${accounts[-1]}"

          # Remove the trailing comma if present
          last_element="${last_element%,}"

          # Set back the updated last element
          accounts[-1]="$last_element"
      fi

      # Create the config.json file  
      echo "{\"attachments\":$attachments,\"url\":\"$url\",\"passphrase\":\"$encrypted_password_hash\",\"accounts\":[${accounts[@]}]}" > "$config_file"
      log "config.json file created: $config_file"
  }

    # Check if a configuration file name is provided
    if [ -z "$config_file" ]; then
        log error "No configuration file specified."
        show_help
        exit 1
    fi

    # Check if non_interactive mode is enabled
    if [ "$non_interactive" = true ]; then
        log error "The generate command cannot be used in non-interactive mode."
        exit 1
    fi

    # Check if the configuration file already exists
    if [ -e "$config_file" ]; then
        read -p "Configuration file already exists. Do you want to overwrite it? (y/N): " overwrite
        if [ "$overwrite" == "${overwrite#[YyjJ]}" ]; then
            log "Aborted. No changes made."
            exit 0
        fi
    fi

    # Call the function to create the configuration file
    create_config_file
}

# Function for the extract subcommand
extract_command() {

    # Check if the 'archive' variable is set
    if [ -z "$archive" ]; then
        log error "The path to the archive is not specified."
        exit 1
    fi

    # Check if the file specified by 'archive' exists
    if [ ! -f "$archive" ]; then
        # Log an error message and exit the script
        log error "The specified archive file does not exist: $archive"
        exit 1
    fi

    # Get the file extension of the archive
    ext="${archive##*.}"

    # Check if the file extension is .gpg or if the gpg option is set
    if [ "$ext" == "gpg" ] || [ "$gpg" = true ]; then
      gpg=true
    fi

    # Check if GPG is installed when gpg enabled
    if [ "$gpg" = true ] && ! command -v gpg &> /dev/null; then
        log error "GPG is not installed. Please install GPG to proceed."
        exit 1
    fi

    # Check if non_interactive mode is enabled
    if [ "$non_interactive" = true ]; then
        # Log that non-interactive mode is enabled
        log "Non-interactive mode is enabled."

        # Check if GPG is enabled
        if [ "$gpg" = true ]; then
            # Check if GPG passphrase is set
            if [ -z "$gpg_passphrase" ]; then
                # Log an error and exit
                log error "GPG passphrase is required in non-interactive mode."
                exit 1
            fi
        fi
    fi


    # Check if gpg enabled
    if [ "$gpg" = true ]; then
      log "Decrypting the GPG encrypted TAR file..."

      # Check if GPG passphrase is set
      if [ -z "$gpg_passphrase" ]; then
        # Decrypt the GPG encrypted TAR file without passphrase
        gpg --decrypt --output "$output_file.tar.gz" "$archive"
      else
        # Decrypt the GPG encrypted TAR file with passphrase in batch mode
        gpg --batch --passphrase $gpg_passphrase --decrypt --output "$output_file.tar.gz" "$archive"
      fi

      log "Decryption completed. Decrypted file: $output_file.tar.gz"
    fi

    # Check if the output directory exists, if not create it
    if [ ! -d "$output_file" ]; then
      mkdir -p "$output_file"
    fi


    log "Extracting the TAR archive..."
    tar xzf "$output_file.tar.gz" -C "$output_file"

    # Remove the temporary TAR.GZ file
    rm "$output_file.tar.gz"

    log "Extraction completed. Files are extracted to: $output_file"

}

trap on_exit EXIT

# Process command line arguments
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
    extract)
      subcommand="extract"
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
        log error "Missing argument for $1"
        exit 1
      fi
      ;;
    -o|--output)
      if [[ -n "$2" ]]; then
        output_file="$2"
        shift 2
      else
        log error "Missing argument for $1"
        exit 1
      fi
      ;;
    -p|--passphrase)
      if [[ -n "$2" ]]; then
        passphrase="$2"
        shift 2
      else
        log error "Missing argument for $1"
        exit 1
      fi
      ;;
    -f|--archive)
      if [[ -n "$2" ]]; then
        archive="$2"
        shift 2
      else
        log error "Missing argument for $1"
        exit 1
      fi
      ;;
    -q|--quiet)
      quiet=true
      shift
      ;;
    -g|--gpg)
      gpg=true
      shift
      ;;
    -s|--gpg-passphrase)
      if [[ -n "$2" ]]; then
        gpg_passphrase="$2"
        shift 2
      else
        log error "Missing argument for $1"
        exit 1
      fi
      ;;
    -n|--non-interactive)
      non_interactive=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      log error "Unknown option or argument: $1"
      exit 1
      ;;
  esac
done

# Check if a subcommand is specified
if [[ -z "$subcommand" ]]; then
  log error "No subcommand specified."
  echo
  show_help
  exit 1
fi

# Check if all necessary dependencies are installed
check_dependencies

# Execute program logic based on the subcommand
case "$subcommand" in
  backup)
    backup_command
    ;;
  generate)
    generate_command
    ;;
  extract)
    extract_command
    ;;
  *)
    log error "Unknown subcommand: $subcommand"
    exit 1
esac

# echo "Program executed successfully"
exit 0
