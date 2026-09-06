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

3. Create a Manager User

This user administers the **Admin Portal** (step 4). Pick username and password
yourself — nothing else in the stack refers to them.

- Open Keycloak http://eegfaktura-keycloak:8080 and log in as `admin`, password `SuperSecretPassword`
- Create a new user in the **EEGFaktura** realm and set a (non-temporary) password
- Assign the realm role **Manager** to that user

![image](https://github.com/user-attachments/assets/81b1168e-e867-4192-a1f3-326820d8e7a5)

4. Create an EEG

Open the Admin Portal on http://localhost:8002 and log in with the Manager user
from step 3. Register a new EEG:

![image](https://github.com/user-attachments/assets/12275efa-10c8-46ba-b8e5-3df0cd500477)

```
RC-Nummer: TE100200
Gemeinschafts-ID: AT00999900000TC100200000000000002
Netzbetreiber-ID: AT009999
```

The registration form also asks for the EEG administrator's account. Those are the
credentials you use in step 5.

5. Open EEGFaktura

- Open the platform on http://localhost:8001
- Log in with the account you entered in step 4. **The password from step 4 is
  temporary** — Keycloak asks you to set a new one on first login.
- Upload master data and energy data. Both sample files ship in `data/`:

![image](https://github.com/user-attachments/assets/f39a41c7-155f-4910-b088-5390369a737a)

```
Stammdaten: data/TE100200-Muster-Stammdatenimport.xlsx   (sheet "EEG Stammdaten")
Energiedaten: data/TEST_EEG_Report_AT00999900000TE100100.xlsx   (sheet "Energiedaten")
```

