"""Publication checks use fabricated values, never real signing material."""
import sys
import os
import subprocess
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'Scripts'))
from publication_audit import issues_for

class PublicationAuditTests(unittest.TestCase):
    def test_rejects_personal_builds_even_when_force_staged(self):
        for path in ['build/private.png', '.local/development.env', 'Config/device.mobileprovision',
                     'App.app/Contents/Info.plist', 'Setup.plist', '.env.local', 'capture.mov']:
            self.assertTrue(issues_for(path, b'example'), path)

    def test_detects_fabricated_sensitive_content_without_disclosing_value(self):
        examples = [('/Us'+'ers/'+'example/Code', 'personal home path'),
                    ('0'*8+'-'+'1'*16, 'device identifier'),
                    ('ghp_'+'A'*36, 'GitHub credential'),
                    ('-----BEGIN '+'PRIVATE KEY-----', 'private key material')]
        for value, reason in examples:
            result = issues_for('Docs/test.md', value.encode())
            self.assertIn(reason, result)
            self.assertNotIn(value, str(result))

    def test_permits_public_assets_examples_and_pinned_commits(self):
        self.assertEqual(issues_for('Assets/AppIcon.icns', b'\x00icon'), [])
        self.assertEqual(issues_for('Config/Local.env.example', b"export IPHONE_UDID='YOUR_IPHONE_UDID'"), [])
        self.assertEqual(issues_for('Scripts/bootstrap-wda.sh', b'revision='+b'a'*40), [])
        self.assertEqual(issues_for('ThirdPartyLicenses/Apache-2.0.txt', b'Apache License'), [])

    def test_rejects_unreviewed_images_and_external_links(self):
        self.assertTrue(issues_for('Docs/phone-screen.png', b'image'))
        self.assertTrue(issues_for('Sources/link.swift', b'../../private', mode='120000'))
        self.assertTrue(issues_for('upstream', b'', mode='160000'))

class PersonalSetupValidationTests(unittest.TestCase):
    script = Path(__file__).resolve().parents[2]/'Scripts/setup-personal-app.sh'

    def test_help_needs_no_account_or_device(self):
        result = subprocess.run(['bash', str(self.script), '--help'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn('WDA_TEAM_ID', result.stdout)

    def test_placeholder_configuration_is_rejected_before_external_tools(self):
        environment = dict(os.environ, IPHONE_UDID='YOUR_IPHONE_UDID',
                           WDA_TEAM_ID='YOUR_TEAM_ID', WDA_BUNDLE_ID='com.example.wda')
        result = subprocess.run(['bash', str(self.script)], env=environment, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('not a supported device identifier', result.stderr)

if __name__ == '__main__': unittest.main()
