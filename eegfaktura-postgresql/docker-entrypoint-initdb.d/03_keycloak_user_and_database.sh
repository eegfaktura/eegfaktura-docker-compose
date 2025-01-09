#!/bin/bash
set -e

# Ensure required environment variables are set
if [[ -z "$POSTGRES_USER" || -z "$POSTGRES_DB" || -z "$KEYCLOAK_DB_USERNAME" || -z "$KEYCLOAK_DB_PASSWORD" || -z "$KEYCLOAK_DATABASE" ]]; then
    echo "Error: One or more required environment variables are not set."
    echo "Required: POSTGRES_USER, POSTGRES_DB, KEYCLOAK_DB_USERNAME, KEYCLOAK_DB_PASSWORD, KEYCLOAK_DATABASE"
    exit 1
fi

# Path to psql
PSQL=$(command -v psql)

# Create Keycloak user and database
$PSQL -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER $KEYCLOAK_DB_USERNAME WITH PASSWORD '$KEYCLOAK_DB_PASSWORD';
    CREATE DATABASE $KEYCLOAK_DATABASE OWNER $KEYCLOAK_DB_USERNAME;
EOSQL

# Grant privileges on the new database
$PSQL -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$KEYCLOAK_DATABASE" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE $KEYCLOAK_DATABASE TO $KEYCLOAK_DB_USERNAME;
    GRANT ALL PRIVILEGES ON SCHEMA public TO $KEYCLOAK_DB_USERNAME;
EOSQL
