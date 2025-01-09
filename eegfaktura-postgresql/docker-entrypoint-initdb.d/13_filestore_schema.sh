#!/bin/bash
set -e

# Validate required environment variables
if [[ -z "$POSTGRES_USER" || -z "$DB_DATABASE" || -z "$DB_USERNAME" ]]; then
    echo "Error: Required environment variables are not set."
    echo "Required: POSTGRES_USER, DB_DATABASE, DB_USERNAME"
    exit 1
fi

# Path to psql
PSQL=$(command -v psql)

# Create schema and grant privileges
$PSQL -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB_DATABASE" <<-EOSQL
    CREATE SCHEMA IF NOT EXISTS filestore;
    GRANT ALL PRIVILEGES ON DATABASE $DB_DATABASE TO $DB_USERNAME;
    GRANT USAGE ON SCHEMA filestore TO $DB_USERNAME;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA filestore TO $DB_USERNAME;
    ALTER DEFAULT PRIVILEGES IN SCHEMA filestore GRANT ALL PRIVILEGES ON TABLES TO $DB_USERNAME;
EOSQL
