#!/bin/bash
set -e

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
