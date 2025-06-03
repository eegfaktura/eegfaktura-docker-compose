# EEGFaktura

**EEGFaktura** is a platform designed for efficient invoice and billing management. This repository provides everything you need to set up and run the platform locally using Docker Compose.

## ⚙️ Quick Start

Easily run EEGFaktura on your personal computer with a few simple steps.

### Prerequisites

Make sure you have the following installed:

- [Docker](https://www.docker.com/products/docker-desktop)
- [Docker Compose](https://docs.docker.com/compose/)

### Installation

1. Clone the repository:

```bash
git clone https://github.com/eegfaktura/eegfaktura-docker-compose.git
cd eegfaktura-docker-compose

2. Start docker compose
´´´bash
docker compose up

3. Create Manager User
Open Keycloak and login as admin. Passwort: SuperSecretPassword
Create a new user in the EEGFaktura Realm
Assign role 'Manager' to the User

4. Re-create client 'admin-cli' Secret-Key
Copy the new generated key to the file keycloak/keycloak.json
  Section 'admin-cli' -> secret

5. Restart docker compose
docker compose down
docker compose up

6. Create a EEG
open the Admin Portal on http://localhost:8002
Register a new EEG

![image](https://github.com/user-attachments/assets/12275efa-10c8-46ba-b8e5-3df0cd500477)

Add an user, provide other settings.

7. Open EEGFaktura
Open the Platform on http://localhost:8001
Login with the EEG user
Upload Masterdata and Energie data


