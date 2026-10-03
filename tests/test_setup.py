import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("deployment_setup", Path(__file__).parents[1] / "setup.py")
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ("cert", "key", "jwt"):
            (self.root / name).write_text("fixture")
        self.settings = self.root / "settings.env"
        self.output = self.root / "production.env"
        self.settings.write_text(
            "WEB_URL=https://web.example.org\nADMIN_URL=https://admin.example.org\n"
            "KEYCLOAK_URL=https://auth.example.org\nSMTP_HOST=smtp.example.org\n"
            "SMTP_USER=account\nSMTP_EMAIL=eeg@example.org\nSMTP_DOMAIN=example.org\n"
            "SMTP_PASSWORD=contains$dollar\n"
            + "".join(f"{k}={self.root / name}\n" for k, name in [
                ("TLS_CERT_FILE", "cert"), ("TLS_KEY_FILE", "key"), ("JWT_PUBLIC_KEY_FILE", "jwt")])
        )

    def test_consistent_secrets_and_idempotency(self):
        setup.generate(self.settings, self.output)
        first = setup.read_env(self.output)
        setup.generate(self.settings, self.output)
        self.assertEqual(first, setup.read_env(self.output))
        self.assertEqual(self.output.stat().st_mode & 0o777, 0o600)
        config = json.loads(Path(first["KEYCLOAK_CONFIG_FILE"]).read_text())
        realm = json.loads((Path(first["KEYCLOAK_IMPORT_DIR"]) / "realm-export.json").read_text())
        clients = {c["clientId"]: c for c in realm["clients"]}
        self.assertEqual(config["admin-cli"]["secret"], clients["admin-cli"]["secret"])
        self.assertEqual(first["KEYCLOAK_ADMIN_CLI_SECRET"], clients["admin-cli"]["secret"])
        self.assertEqual(["https://admin.example.org"], clients["at.ourproject.vfeeg.admin"]["webOrigins"])
        self.assertEqual("contains$dollar", Path(first["SMTP_PASSWORD_FILE"]).read_text().strip())

    def test_existing_passwords_are_kept(self):
        self.settings.write_text(self.settings.read_text() + "DATABASE_PASSWORD=existing-secret\n")
        setup.generate(self.settings, self.output)
        values = setup.read_env(self.output)
        self.assertEqual("existing-secret", values["DATABASE_PASSWORD"])
        self.assertEqual("existing-secret", Path(values["DATABASE_PASSWORD_FILE"]).read_text().strip())

    def test_production_realm_security(self):
        template = setup.ROOT / "keycloak/import/realm-export.json"
        original = template.read_bytes()
        setup.generate(self.settings, self.output)
        values = setup.read_env(self.output)
        realm = json.loads((Path(values["KEYCLOAK_IMPORT_DIR"]) / "realm-export.json").read_text())
        self.assertTrue(realm["bruteForceProtected"])
        self.assertEqual(10, realm["failureFactor"])
        self.assertFalse(realm["permanentLockout"])
        self.assertEqual("length(12)", realm["passwordPolicy"])
        self.assertTrue(realm["eventsEnabled"])
        self.assertIn("LOGIN", realm["enabledEventTypes"])
        self.assertIn("LOGIN_ERROR", realm["enabledEventTypes"])
        self.assertEqual(2592000, realm["eventsExpiration"])
        self.assertEqual(original, template.read_bytes())

    def test_input_password_file_overrides_previous_password(self):
        setup.generate(self.settings, self.output)
        password_file = self.root / "replacement-password"
        password_file.write_text("replacement-secret\n")
        self.settings.write_text(self.settings.read_text() +
                                 f"DATABASE_PASSWORD_FILE={password_file}\n")
        setup.generate(self.settings, self.output)
        values = setup.read_env(self.output)
        self.assertEqual("replacement-secret", values["DATABASE_PASSWORD"])
        self.assertEqual("replacement-secret", Path(values["DATABASE_PASSWORD_FILE"]).read_text().strip())

    def test_explicit_password_wins_over_explicit_file(self):
        password_file = self.root / "alternative-password"
        password_file.write_text("file-secret\n")
        self.settings.write_text(self.settings.read_text() +
                                 f"DATABASE_PASSWORD_FILE={password_file}\nDATABASE_PASSWORD=direct-secret\n")
        setup.generate(self.settings, self.output)
        self.assertEqual("direct-secret", setup.read_env(self.output)["DATABASE_PASSWORD"])

    def test_http_and_missing_files_rejected(self):
        self.settings.write_text(self.settings.read_text().replace("https://web.", "http://web."))
        with self.assertRaises(ValueError):
            setup.generate(self.settings, self.output)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
