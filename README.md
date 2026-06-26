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

3. Create Manager User
   
- Open Keycloak http://eegfaktura-keycloak:8080 and login as admin. Passwort: SuperSecretPassword
- Create a new user in the EEGFaktura Realm
- Assign role **Manager** to the User

![image](https://github.com/user-attachments/assets/81b1168e-e867-4192-a1f3-326820d8e7a5)

4. Re-create client 'admin-cli' Secret-Key

![image](https://github.com/user-attachments/assets/dc7f870d-6790-4787-9d2e-833aca2ba6d4)

Copy the new generated key to the file **keycloak/keycloak.json**
Section 'admin-cli' -> secret

![image](https://github.com/user-attachments/assets/556edffd-a5ea-4f07-ac35-30873b96e4aa)


5. Restart docker compose
```bash
docker compose down
docker compose up
```

6. Create a EEG
   
open the Admin Portal on http://localhost:8002

Register a new EEG

![image](https://github.com/user-attachments/assets/12275efa-10c8-46ba-b8e5-3df0cd500477)

```
RC-Nummer: TE100200
Gemeinschafts-ID: AT00999900000TC100200000000000002
Netzbetreiber-ID: AT009999
```

7. Open EEGFaktura
   
- Open the Platform on http://localhost:8001
- Log in using the credentials provided during the creation process. (Step 6)
- Upload Masterdata and Energiedata

![image](https://github.com/user-attachments/assets/f39a41c7-155f-4910-b088-5390369a737a)

```
Stammdaten: TE100200-Muster-Stammdatenimport.xlsx
Energiedaten: TEST_EEG_Report_AT00999900000TE100100.xlsx
```

