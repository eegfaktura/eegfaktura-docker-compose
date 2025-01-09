#!/bin/bash
# eegfakuta-postgresql
# Postgrsql Container for eegfaktura
# Copyright (C) 2023 Verein zur Förderung von Erneuerbaren Energiegemeinschaften
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

SED=`which sed`

#Replace Database in SQL file if DB_DATABASE differs from "eegfaktura"
if [ "$DB_DATABASE" != "eegfaktura" ]; then
  cd /docker-entrypoint-initdb.d/
  echo "Change Database from eegfatura to $DB_DATABASE"
  $SED -i "s/\\c eegfaktura/c\\ $DB_DATABASE/g" *.sql
fi

if [ "$DB_PASSWORD" == "" ] && [ "$DB_PASSWORD_FILE" != "" ] && [ -f "$DB_PASSWORD_FILE" ]; then
  export DB_PASSWORD=`head -n 1 "$DB_PASSWORD_FILE"`
fi

if [ "$KEYCLOAK_DB_PASSWORD" == "" ] && [ "$KEYCLOAK_DB_PASSWORD_FILE" != "" ] && [ -f "$KEYCLOAK_DB_PASSWORD_FILE" ]; then
  export KEYCLOAK_DB_PASSWORD=`head -n 1 "$KEYCLOAK_DB_PASSWORD_FILE"`
fi