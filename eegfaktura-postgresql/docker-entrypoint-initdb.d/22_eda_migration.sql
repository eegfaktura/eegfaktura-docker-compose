/** eegfakuta-postgresql
* Postgrsql Container for eegfaktura
* Copyright (C) 2023 Verein zur Förderung von Erneuerbaren Energiegemeinschaften (eegfaktura@vfeeg.org)
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero General Public License for more details.
*
* You should have received a copy of the GNU Affero General Public License
* along with this program.  If not, see <https://www.gnu.org/licenses/>.
**/

/* Change Database to $DB_DATABASE */
/* PLEASE DO NOT EDIT */
/* Target Datababase is automatically replaced by 01_set_environment.sh script */
\c eegfaktura;
/* END PLEASE DO NOT EDIT */

CREATE TABLE IF NOT EXISTS eda.tenantconfig
(
    tenant   VARCHAR PRIMARY KEY,
    domain   VARCHAR NOT NULL,
    host     VARCHAR NOT NULL,
    imapPort INTEGER NOT NULL,
    smtpPort INTEGER NOT NULL,
    smtpHost VARCHAR NOT NULL,
    username VARCHAR NOT NULL,
    pass     VARCHAR NOT NULL,
    imap_security VARCHAR NOT NULL,
    smtp_security VARCHAR NOT NULL,
    active BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS eda.inbox
(
    id       SERIAL PRIMARY KEY,
    tenant   VARCHAR NOT NULL,
    subject VARCHAR NOT NULL,
    content  bytea NOT NULL,
    received TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS eda.outbox
(
    id       SERIAL PRIMARY KEY,
    tenant   VARCHAR NOT NULL,
    content  bytea NOT NULL,
    sent     TIMESTAMP NOT NULL
)