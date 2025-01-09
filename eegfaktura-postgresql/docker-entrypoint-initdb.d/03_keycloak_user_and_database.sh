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

load_password_from_file "KEYCLOAK_DB_PASSWORD" "KEYCLOAK_DB_PASSWORD_FILE"

# Check and log missing environment variables
missing_vars=()

[[ -z "$POSTGRES_USER" ]] && missing_vars+=("POSTGRES_USER")
[[ -z "$POSTGRES_DB" ]] && missing_vars+=("POSTGRES_DB")
[[ -z "$KEYCLOAK_DB_DATABASE" ]] && missing_vars+=("KEYCLOAK_DB_DATABASE")
[[ -z "$KEYCLOAK_DB_PASSWORD" ]] && missing_vars+=("KEYCLOAK_DB_PASSWORD")
[[ -z "$KEYCLOAK_DB_USERNAME" ]] && missing_vars+=("KEYCLOAK_DB_USERNAME")

if [[ ${#missing_vars[@]} -ne 0 ]]; then
    echo "Error: The following required environment variables are not set:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    exit 1
fi
# Path to psql
PSQL=$(command -v psql)

# Create Keycloak user and database
$PSQL -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER $KEYCLOAK_DB_USERNAME WITH PASSWORD '$KEYCLOAK_DB_PASSWORD';
    CREATE DATABASE $KEYCLOAK_DB_DATABASE OWNER $KEYCLOAK_DB_USERNAME;
EOSQL

# Grant privileges on the new database
$PSQL -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$KEYCLOAK_DB_DATABASE" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE $KEYCLOAK_DB_DATABASE TO $KEYCLOAK_DB_USERNAME;
    GRANT ALL PRIVILEGES ON SCHEMA public TO $KEYCLOAK_DB_USERNAME;
EOSQL
