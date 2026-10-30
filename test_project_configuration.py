"""Offline standard-library checks; run before Flutter/Android builds."""
import importlib.util
import plistlib
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

PROJECT = Path(__file__).resolve().parents[1]
CONFIG = PROJECT / "tools" / "configure_project.py"


class ProjectTests(unittest.TestCase):
    def test_android_manifest_is_valid_xml(self):
        manifest = ET.parse(PROJECT / "templates" / "android" / "AndroidManifest.xml")
        android = "{http://schemas.android.com/apk/res/android}"
        activities = manifest.findall(".//activity")
        self.assertTrue(activities)
        self.assertEqual(activities[0].get(android + "launchMode"), "singleTask")
        self.assertTrue(any(node.get(android + "mimeType") == "audio/*"
                            for node in manifest.iter("data")))

    def test_ios_extension_plist(self):
        with (PROJECT / "templates" / "ios-share-extension" / "Info.plist").open("rb") as handle:
            plist = plistlib.load(handle)
        self.assertIn("NSExtension", plist)
        self.assertEqual(plist["NSExtension"]["NSExtensionPointIdentifier"],
                         "com.apple.share-services")

    def test_pinned_plugin_versions(self):
        pubspec = (PROJECT / "pubspec.yaml").read_text()
        self.assertIn("receive_sharing_intent: 1.8.1", pubspec)
        self.assertIn("share_plus: 11.1.0", pubspec)

    def test_android_setup_is_idempotent(self):
        spec = importlib.util.spec_from_file_location("configure_project", CONFIG)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temp:
            original_root = module.ROOT
            try:
                module.ROOT = Path(temp)
                src = module.ROOT / "templates/android"
                src.mkdir(parents=True)
                (src / "AndroidManifest.xml").write_bytes(
                    (PROJECT / "templates/android/AndroidManifest.xml").read_bytes())
                dest = module.ROOT / "android/app/src/main"
                dest.mkdir(parents=True)
                gradle = module.ROOT / "android/app/build.gradle.kts"
                gradle.write_text("defaultConfig { minSdk = flutter.minSdkVersion }")
                module.configure_android()
                module.configure_android()
                self.assertIn("minSdk = 24", gradle.read_text())
                self.assertEqual((dest / "AndroidManifest.xml").read_bytes(),
                                 (src / "AndroidManifest.xml").read_bytes())
            finally:
                module.ROOT = original_root


if __name__ == "__main__":
    unittest.main()
