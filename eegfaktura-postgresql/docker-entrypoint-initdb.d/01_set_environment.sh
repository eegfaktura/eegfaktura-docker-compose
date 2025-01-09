#!/bin/bash
set -e

# Validate `sed` existence
SED=$(command -v sed)
if [[ ! -x "$SED" ]]; then
  echo "Error: sed not found or not executable."
  exit 1
fi

# Log environment variable checks
echo "Checking required environment variables..."

# Check if DB_DATABASE is set
if [[ -z "$DB_DATABASE" ]]; then
  echo "Error: DB_DATABASE is not set."
  exit 1
else
  echo "DB_DATABASE is set to '$DB_DATABASE'."
fi

# Function to load passwords from files
load_password_from_file() {
  local password_var_name=$1
  local password_file_var_name=$2
  local password_file=${!password_file_var_name}

  if [[ -z "${!password_var_name}" && -n "$password_file" && -f "$password_file" ]]; then
    echo "Loading ${password_var_name} from file '$password_file'."
    local password_value=$(head -n 1 "$password_file")
    if [[ -z "$password_value" ]]; then
      echo "Error: $password_file_var_name file is empty."
      exit 1
    fi
    export $password_var_name=$password_value
    echo "${password_var_name} loaded successfully."
  elif [[ -n "${!password_var_name}" ]]; then
    echo "${password_var_name} is already set."
  else
    echo "$password_file_var_name not set, does not exist, or $password_var_name already set."
  fi
}

# Load DB_PASSWORD and KEYCLOAK_DB_PASSWORD from files if needed
load_password_from_file "DB_PASSWORD" "DB_PASSWORD_FILE"
load_password_from_file "KEYCLOAK_DB_PASSWORD" "KEYCLOAK_DB_PASSWORD_FILE"

# Replace Database in SQL file if `DB_DATABASE` differs from "eegfaktura"
if [[ "$DB_DATABASE" != "eegfaktura" ]]; then
  echo "DB_DATABASE differs from 'eegfaktura'. Updating SQL files..."
  cd /docker-entrypoint-initdb.d/ || {
    echo "Failed to cd into /docker-entrypoint-initdb.d"
    exit 1
  }
  for sql_file in *.sql; do
    if [[ -f "$sql_file" ]]; then
      echo "Processing $sql_file to replace 'eegfaktura' with '$DB_DATABASE'."
      $SED -i "s/\\c eegfaktura/c\\ $DB_DATABASE/g" "$sql_file"
    else
      echo "No SQL files found in /docker-entrypoint-initdb.d."
    fi
  done
else
  echo "DB_DATABASE is already set to 'eegfaktura'. No changes needed."
fi

echo "Script execution completed successfully."
