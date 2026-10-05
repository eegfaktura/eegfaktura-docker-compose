#!/usr/bin/env python3
"""Generate production settings and initial Keycloak import without editing dev files."""
import argparse
import json
import os
from pathlib import Path
import re
import secrets
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent


def read_env(path):
    result = {}
    for number, line in enumerate(path.read_text().splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, sep, value = line.partition("=")
        if not sep or not re.fullmatch(r"[A-Z][A-Z0-9_]*", key):
            raise ValueError(f"{path}:{number}: expected KEY=value")
        if value.startswith(("'", '"')):
            if len(value) < 2 or value[-1] != value[0]:
                raise ValueError(f"{path}:{number}: unclosed quote")
            value = value[1:-1]
        result[key] = value
    return result


def write_file(path, text, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + ".tmp")
    fd = os.open(temp, os.O_CREAT | os.O_TRUNC | os.O_WRONLY, mode)
    os.fchmod(fd, mode)
    with os.fdopen(fd, "w") as stream:
        stream.write(text)
    temp.replace(path)


def generate(source, output):
    output = output.resolve()
    if output == source.resolve():
        raise ValueError("input and output files must differ")
    values = read_env(output) if output.exists() else {}
    inputs = read_env(source)
    values.update(inputs)
    for key in ("WEB_URL", "ADMIN_URL", "KEYCLOAK_URL"):
        url = urlsplit(values.get(key, ""))
        if (url.scheme != "https" or not url.hostname or url.username or url.password
                or url.path not in ("", "/") or url.query or url.fragment):
            raise ValueError(f"{key} must be an HTTPS origin")
        values[key] = values[key].rstrip("/")
    for key in ("TLS_CERT_FILE", "TLS_KEY_FILE", "JWT_PUBLIC_KEY_FILE"):
        path = Path(values.get(key, ""))
        if not path.is_absolute() or not path.is_file():
            raise ValueError(f"{key} must name an existing absolute file")
    for key in ("SMTP_HOST", "SMTP_USER", "SMTP_EMAIL", "SMTP_DOMAIN"):
        if not values.get(key):
            raise ValueError(f"{key} is required")
    generated = output.parent / "generated"
    generated.mkdir(parents=True, exist_ok=True)
    generated.chmod(0o700)
    for key, filename, filekey in [
        ("POSTGRES_PASSWORD", "postgres-password", "POSTGRES_PASSWORD_FILE"),
        ("DATABASE_PASSWORD", "database-password", "DATABASE_PASSWORD_FILE"),
        ("KEYCLOAK_DB_PASSWORD", "keycloak-db-password", "KEYCLOAK_DB_PASSWORD_FILE"),
        ("SMTP_PASSWORD", "smtp-password", "SMTP_PASSWORD_FILE"),
    ]:
        path = generated / filename
        if filekey in inputs and key not in inputs:
            values.pop(key, None)
        if values.get(key):
            secret = values[key]
        elif values.get(filekey):
            input_path = Path(values[filekey])
            try:
                secret = input_path.read_text().strip()
            except FileNotFoundError as exc:
                raise ValueError(
                    f"{filekey} points to missing file {input_path}; create it or set {key}"
                ) from exc
        elif path.exists():
            secret = path.read_text().strip()
        elif key == "SMTP_PASSWORD":
            raise ValueError("SMTP_PASSWORD or SMTP_PASSWORD_FILE is required")
        else:
            secret = secrets.token_urlsafe(32)
        if not secret:
            raise ValueError(f"{key} is empty")
        write_file(path, secret + "\n", 0o644)
        values[filekey] = str(path)
        if key == "SMTP_PASSWORD":
            values.pop(key, None)
        else:
            values[key] = secret
    for key in ("KEYCLOAK_ADMIN_PASSWORD", "KEYCLOAK_ADMIN_CLI_SECRET"):
        if not values.get(key):
            values[key] = secrets.token_urlsafe(32)
    config = json.loads((ROOT / "keycloak/keycloak.json").read_text())
    for client in config.values():
        client["auth-server-url"] = values["KEYCLOAK_URL"]
        client.pop("issuer_url", None)
    config["admin-cli"]["secret"] = values["KEYCLOAK_ADMIN_CLI_SECRET"]
    realm = json.loads((ROOT / "keycloak/import/realm-export.json").read_text())
    realm.update({
        "bruteForceProtected": True,
        "failureFactor": 10,
        "permanentLockout": False,
        "passwordPolicy": "length(12)",
        "eventsEnabled": True,
        "enabledEventTypes": ["LOGIN", "LOGIN_ERROR", "LOGOUT", "LOGOUT_ERROR",
                              "UPDATE_PASSWORD", "UPDATE_PASSWORD_ERROR",
                              "RESET_PASSWORD", "RESET_PASSWORD_ERROR"],
        "eventsExpiration": 30 * 24 * 60 * 60,
    })
    realm.setdefault("attributes", {})["frontendUrl"] = values["KEYCLOAK_URL"]
    for client in realm["clients"]:
        if client["clientId"] == "admin-cli":
            client["secret"] = values["KEYCLOAK_ADMIN_CLI_SECRET"]
        elif client["clientId"] in ("at.ourproject.vfeeg.app", "at.ourproject.vfeeg.admin"):
            url = values["WEB_URL" if client["clientId"].endswith(".app") else "ADMIN_URL"]
            client["redirectUris"] = [url + "/*"]
            client["webOrigins"] = [url]
            client.setdefault("attributes", {})["post.logout.redirect.uris"] = url + "/*"
    imports = generated / "keycloak-import"
    imports.mkdir(exist_ok=True)
    imports.chmod(0o755)
    write_file(imports / "realm-export.json", json.dumps(realm, indent=2) + "\n", 0o644)
    write_file(generated / "keycloak.json", json.dumps(config, indent=2) + "\n", 0o644)
    values["KEYCLOAK_IMPORT_DIR"] = str(imports)
    values["KEYCLOAK_CONFIG_FILE"] = str(generated / "keycloak.json")
    values["CADDY_CONFIG_FILE"] = str(ROOT / "caddy/Caddyfile.production")
    for key, urlkey in [("WEB_HOST", "WEB_URL"), ("ADMIN_HOST", "ADMIN_URL"), ("AUTH_HOST", "KEYCLOAK_URL")]:
        values[key] = urlsplit(values[urlkey]).netloc
    values.setdefault("COMPOSE_PROJECT_NAME", "eegfaktura-docker-compose")
    for key, value in values.items():
        if any(char in value for char in ("'", "\n", "\r")):
            raise ValueError(f"{key} contains unsupported characters")
    write_file(output, "".join(f"{key}='{value}'\n" for key, value in sorted(values.items())))
    print(f"Generated: {output}")
    print("Startup import does not update an existing Keycloak realm.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        generate(args.env_file, args.output)
    except (ValueError, OSError, KeyError) as error:
        parser.exit(1, f"Setup failed: {error}\n")


if __name__ == "__main__":
    main()
