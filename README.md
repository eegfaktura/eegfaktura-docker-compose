# EEGFaktura

**EEGFaktura** is a platform designed for efficient invoice and billing management. This repository provides everything you need to set up and run the platform locally using Docker Compose.

## What's in the stack

This repository orchestrates the full **eegfaktura** suite — an open-source billing
and management platform for Austrian renewable energy communities (EEG) — via a
single `docker-compose.yaml`:

| Service | Role | Tech |
|---|---|---|
| `eegfaktura-keycloak` | Authentication / OIDC issuer | Keycloak |
| `eegfaktura-postgresql` | Database (app + Keycloak) | PostgreSQL |
| `eegfaktura-mosquitto` | MQTT message broker | Eclipse Mosquitto |
| `eegfaktura-backend` | Core domain & billing API | Go (REST/GraphQL/gRPC) |
| `eegfaktura-web` | Customer web UI | React / Ionic |
| `eegfaktura-admin-backend` / `-web` | EEG registration & admin | Scala/Pekko · React |
| `eegfaktura-energystore` | Energy time-series store | Go · BadgerDB |
| `eegfaktura-filestore` | Document storage | Python / FastAPI |
| `eegfaktura-eda` | EDA market communication | Scala/Pekko (Ponton/KEP + email) |
| `eegfaktura-billing` | Invoice / credit-note generation | Java / Spring Boot |
| `eegfaktura-postfix` | Outbound mail relay | Postfix |
| `eegfaktura-proxy` | Reverse proxy | Caddy |

The reverse proxy publishes the main app on **http://localhost:8001** and the admin
portal on **http://localhost:8002**; Keycloak is on **http://eegfaktura-keycloak:8080**.
For access from another device in the LAN or from WSL, set `DEV_BIND_IP=0.0.0.0`.

### Image versions

The application images are **pinned to released versions** (`vX.Y.Z`) rather than
`latest`, so that a checkout of this repository always describes one reproducible,
tested combination of services. (Two infrastructure images — `eegfaktura-mosquitto`
and `eegfaktura-postfix` — still track `latest`; they change rarely and carry no
wire format of their own.) They come from the public release tier
`ghcr.io/eegfaktura/*`, which is fed by an explicit promotion step —
see [ADR-0005](https://github.com/vfeeg-development/eegfaktura-platform/blob/main/docs/adr/0005-two-tier-image-registry.md).

This matters more than it looks: the services talk to each other over wire formats
that change (MQTT payload encoding, EDA message versions). A stack mixing an old
image with a new one can start up cleanly and still not work — for example, energy
data simply never arrives, with no error anywhere. Pinning keeps the combination
one we have actually run together.

If you want to run a service you built yourself, override just that one in
`docker-compose.override.yml` instead of editing the pinned versions.

### Services that do not run as root

`eegfaktura-backend`, `eegfaktura-energystore` and `eegfaktura-filestore` run as
UID/GID 1000, not as root (energystore and filestore since v1.5.0 / v1.0.4). Their data
volumes, however, belong to root when an older image created them or when the image does
not create the directory itself — and then the service cannot write.

The one-shot service `eegfaktura-volume-permissions` takes care of this: it runs before
those three services, changes the owner of their named volumes to `1000:1000` once and
exits. On later starts it changes nothing. Nothing to do for you when upgrading — just
`docker compose pull && docker compose up -d` (production: with the files of "Production deployment").

If you replaced the named volumes with host directories (bind mounts) in an override
file, change the owner yourself once: `sudo chown -R 1000:1000 <directory>`.

This needs Docker Compose v2 or docker-compose **1.29 or newer**
(`depends_on: condition: service_completed_successfully`).

### Upgrading to the combination of 2026-11-11

The pins match the production release of 2026-11-11: backend v1.18.0, web v1.24.0,
billing v1.12.0, energystore v1.10.0, eda (kep) v1.5.0, filestore v1.2.0, keycloak v1.0.4,
admin backend and admin web v1.3.0. Coming from the previous pins (backend v1.6.0, billing
v1.1.0, ...):

1. **Back up the database first** (`pg_dump` of `eegfaktura`) and **wait until the dump has
   finished**: the backend's migrations wait at most 60 s for a lock, a running dump or a long
   transaction makes them fail. On its first start the backend migrates its schema
   (`event.action=db.migrate.done` in its log) and billing migrates its own (Flyway). The older
   images do not start on the migrated database; to go back, restore the backup (or follow
   "Rollback to an older image" in the
   [backend README](https://github.com/eegfaktura/eegfaktura-backend#readme)).
2. Pull and start — with the same files and options you run the stack with:
   - development: `docker compose pull && docker compose up -d`
   - production: `docker compose --env-file /etc/eegfaktura/production.env -f docker-compose.yaml -f compose.production.yaml pull`,
     then the same with `up -d` (see "Production deployment"). Without `compose.production.yaml`
     the containers start with the development settings (no TLS, default passwords).

   The API is down while the backend migrates (one instance); do not stop the stack meanwhile.
   If the backend log shows `db.migrate.dirty`, follow "Failed migration (dirty)" in the
   backend README.
3. **`git pull` of this repository:** the directory `templates/` is gone. If you edited those
   files, git refuses the pull; keep a copy elsewhere or delete them — they are not used anymore
   (next point).
4. **Member mails:** since backend v1.9.0 hand-made mail templates on the data volume are
   no longer used. Each community edits its texts in the web app (mail text editor);
   without a saved text the built-in default is sent.
5. **Mails sent by eda** (consent request, metering point active/inactive, the energy data
   report) now go through `eegfaktura-postfix` like billing's, with `SMTP_EMAIL` as sender. Before,
   eda had no mail server configured in this stack and could not send them.
6. **mosquitto** gets `mosquitto/mosquitto.conf` with higher queue limits (as in production):
   energystore acknowledges messages itself since v1.8.0, and with mosquitto's defaults a large
   energy data request could lose messages without any log line. The image is pinned by digest.
7. **Own `eegfaktura-eda.application.conf`:** eda v1.5.0 needs `profile = "slick.jdbc.PostgresProfile$"`
   under `slick.pgsql.local` (instead of `driver`/`dataSourceClass`) and uses one database pool for
   the whole process (24/6/24 is its built-in default; a smaller value in your copy limits it).
8. **Existing Keycloak realm:** the realm import does not change an existing realm. If your
   realm has no role `superuser`, create it (Realm roles → Create role) and assign it to
   whoever registers communities in the Admin Portal; without it the portal gets 403.
   `superuser` is the operator role: it may access every community.
9. **Logs are JSON lines** in all application services. `LOG_FORMAT=text` gives readable
   lines; an unknown `LOG_LEVEL` (e.g. `fatal`) stops the service at start.

Changed in this repository with the upgrade, nothing to do unless you keep your own copy:
energystore now gets the backend's HTTP address (needed since energystore v1.9.0 for the
energy data of member logins) and the eda address for the Excel report by mail, and its
backend gRPC address is now actually read (the variable names must be upper case). The admin
portal reaches energystore under `/energystore` (tool "Energiedaten löschen"). In production
(`Caddyfile.production`) the proxy refuses the services' probe paths (`/healthz`, `/readyz`)
from outside, as the production cluster does.

## ⚙️ Quick Start

Easily run EEGFaktura on your personal computer with a few simple steps.

### Prerequisites

Make sure you have the following installed:

- [Docker](https://www.docker.com/products/docker-desktop)
- [Docker Compose](https://docs.docker.com/compose/)

**Hosts entry (required).** Keycloak is reachable under a single hostname that must
resolve identically for your browser and for the containers, so that the token
issuer (`iss`) matches the URL the backends use to fetch the signing keys (JWKS).
Add this line to your hosts file:

```
127.0.0.1 eegfaktura-keycloak
```

- Linux/macOS: `/etc/hosts`  ·  Windows: `C:\Windows\System32\drivers\etc\hosts`
- In production use a real DNS name for Keycloak instead of this hosts entry.

### Installation

1. Clone the repository:

```bash
git clone https://github.com/eegfaktura/eegfaktura-docker-compose.git
cd eegfaktura-docker-compose
```

2. Start docker compose
```bash
docker compose up
```

3. Export the realm signing certificate for billing and filestore

Keycloak generates a fresh RSA key pair on its **first** start, so the
`jwt-public-key.pem` shipped in this repository never matches your installation.
The billing service and the filestore verify tokens against that file — without this
step every call to `/cash/*` and `/filestore/*` fails authentication.

Write the current certificate into the file (in place, so the container's mount
stays valid; billing re-reads the file per request, the filestore reads it at start):

```bash
curl -s http://eegfaktura-keycloak:8080/realms/EEGFaktura/protocol/openid-connect/certs \
  | python3 -c "import sys,json,textwrap; k=next(k for k in json.load(sys.stdin)['keys'] if k.get('alg')=='RS256' and k.get('use')=='sig'); print('-----BEGIN CERTIFICATE-----'); print('\n'.join(textwrap.wrap(k['x5c'][0],64))); print('-----END CERTIFICATE-----')" \
  > jwt-public-key.pem
docker compose restart eegfaktura-filestore
```

Alternatively, copy it from the Keycloak admin console under
*Realm Settings → Keys → RS256 → Certificate* and wrap it in
`-----BEGIN CERTIFICATE-----` / `-----END CERTIFICATE-----` lines.

4. Create a Manager User

This user administers the **Admin Portal** (step 5). Pick username and password
yourself — nothing else in the stack refers to them.

- Open Keycloak http://eegfaktura-keycloak:8080 and log in as `admin`, password `SuperSecretPassword`
- Create a new user in the **EEGFaktura** realm and set a (non-temporary) password
- Assign the realm roles **Manager** and **superuser** to that user. The admin backend
  answers every call of the Admin Portal with `403 superuser role required` without
  `superuser` (since admin backend v1.0.3). `superuser` is the operator role and may access
  every community — give it only to operators, not to community admins.

![image](https://github.com/user-attachments/assets/81b1168e-e867-4192-a1f3-326820d8e7a5)

5. Create an EEG

Open the Admin Portal on http://localhost:8002 and log in with the Manager user
from step 4. Register a new EEG. Fill in the description ("EEG Beschreibung"): with an
empty description backend v1.18.0 cannot read the community back, and the web app shows
an error instead of the EEG (fixed in eegfaktura/eegfaktura-backend#161, with the next backend release).

![image](https://github.com/user-attachments/assets/12275efa-10c8-46ba-b8e5-3df0cd500477)

```
RC-Nummer: TE100200
Gemeinschafts-ID: AT00999900000TC100200000000000002
Netzbetreiber-ID: AT009999
```

The registration form also asks for the EEG administrator's account. Those are the
credentials you use in step 6.

6. Open EEGFaktura

- Open the platform on http://localhost:8001
- Log in with the account you entered in step 5. **The password from step 5 is
  temporary** — Keycloak asks you to set a new one on first login.
- Upload master data and energy data. Both sample files ship in `data/`:

![image](https://github.com/user-attachments/assets/f39a41c7-155f-4910-b088-5390369a737a)

```
Stammdaten: data/TE100200-Muster-Stammdatenimport.xlsx   (sheet "EEG Stammdaten")
Energiedaten: data/TEST_EEG_Report_AT00999900000TE100100.xlsx   (sheet "Energiedaten")
```


## Production deployment

Requires Python 3 on Linux/macOS (setup.py uses os.fchmod) and Docker Compose >= 2.24.4. The default docker-compose.yaml
remains usable for development. Published development ports bind to localhost
unless DEV_BIND_IP is set.

Copy .env.production.example into a private settings file. Set URLs, SMTP
settings and absolute certificate/public-key paths. Create the SMTP password
file named by `SMTP_PASSWORD_FILE` (mode 600) or replace that setting with
`SMTP_PASSWORD`. Then run:

    install -m 600 /dev/null /etc/eegfaktura/smtp-password
    editor /etc/eegfaktura/smtp-password

    python3 setup.py --env-file /etc/eegfaktura/settings.env --output /etc/eegfaktura/production.env
    docker compose --env-file /etc/eegfaktura/production.env -f docker-compose.yaml -f compose.production.yaml config --quiet
    docker compose --env-file /etc/eegfaktura/production.env -f docker-compose.yaml -f compose.production.yaml up -d

Setup generates matching Keycloak configuration and initial realm import with
restricted redirect origins, secret files, and a private Compose env file.
The generated production realm enables temporary brute-force lockouts with a
failure factor of 10, a minimum password length of 12 characters, and saved
user events with a 30-day retention period. The development template is unchanged.
Existing secrets are preserved on reruns; input settings take precedence.
An explicit password file also overrides a password retained from a previous run.
If both a password and its file are specified in the input, the password wins.
For migration supply existing database passwords and admin-cli secret.
Setup does not change database passwords or update existing Keycloak realms.
Apply existing realm changes separately through Keycloak.

JWT_PUBLIC_KEY_FILE must belong to the deployed realm signing key. Setup
validates its path but does not create or replace a signing key.
The public-key file must be readable by UID 1000 (for example mode 0644);
backend, Energystore and filestore run as non-root users. Do not apply these
permissions to private keys or passwords.
Production disables database/Keycloak host ports and exposes the TLS proxy.
Internal services use the public OIDC issuer; Docker DNS must resolve it to
a reachable TLS endpoint, either the host proxy or a local Keycloak network
alias. Network topology remains deployment-specific.
The server and containers must be able to resolve and reach their own public
Keycloak hostname; configure split DNS or hairpin routing where necessary.

Keep the existing Compose project name when migrating, preserving named volumes.
Generated secret files are readable inside containers and protected by a private
host parent directory. The generated env file includes passwords for services
which accept only environment variables; protect it as a secret.

Healthchecks and depends_on handle Compose startup ordering. Keycloak counts as healthy
only once the realm answers its OIDC discovery (`/realms/EEGFaktura/.well-known/openid-configuration`,
HTTP 200), i.e. after the realm import; backend, Energystore, eda, the admin backend and
admin web (in production also the proxy) start only then. In production backend and
Energystore reach Keycloak through the proxy (`https://AUTH_HOST`), which starts at the same
moment: on a first start one of them may exit once and be restarted. The check runs inside the Keycloak container with its own bash, so the
service images need no tool for waiting (no `curl`, `wget` or shell script). This works
with the current images and with the slim runtime images of backend, Energystore and
filestore. The services start with their image's own entrypoint and command.
Docker daemon restarts do not follow depends_on: if backend or Energystore start before
Keycloak is reachable, they exit and `restart: unless-stopped` (production file) starts
them again until Keycloak answers. Docker's restart delay doubles up to about a minute, so
they can stay down that long after Keycloak is ready, and each failed start logs a panic:
expected while Keycloak starts, not a fault.
