#!/bin/bash
set -e

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

# Check and log missing environment variables
missing_vars=()

[[ -z "$POSTGRES_USER" ]] && missing_vars+=("POSTGRES_USER")
[[ -z "$POSTGRES_DB" ]] && missing_vars+=("POSTGRES_DB")
[[ -z "$DB_USERNAME" ]] && missing_vars+=("DB_USERNAME")
[[ -z "$DB_PASSWORD" ]] && missing_vars+=("DB_PASSWORD")
[[ -z "$DB_DATABASE" ]] && missing_vars+=("DB_DATABASE")

if [[ ${#missing_vars[@]} -ne 0 ]]; then
    echo "Error: The following required environment variables are not set:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    exit 1
fi

# Path to psql
PSQL=$(command -v psql)

# Create User and Database
$PSQL -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER $DB_USERNAME WITH PASSWORD '$DB_PASSWORD';
    CREATE DATABASE $DB_DATABASE OWNER $DB_USERNAME;
EOSQL

# Connect to the new database and create the UUID extension
$PSQL -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB_DATABASE" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOSQL
