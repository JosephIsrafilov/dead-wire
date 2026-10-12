import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from with_preserved_settings import preserve_settings


class PreservationTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory(dir=os.environ.get("TMP", tempfile.gettempdir()))
        self.path = Path(self.work.name) / "settings.cfg"

    def tearDown(self):
        self.work.cleanup()

    def test_existing_bytes_are_restored(self):
        original = b"\xff\xfeoriginal\x00\r\n"
        self.path.write_bytes(original)
        with preserve_settings(self.path):
            self.path.write_bytes(b"new defaults")
        self.assertEqual(self.path.read_bytes(), original)

    def test_original_absence_is_restored(self):
        with preserve_settings(self.path):
            self.path.write_bytes(b"test preferences")
        self.assertFalse(self.path.exists())

    def test_result_json_keeps_raw_returncode_and_preservation(self):
        self.path.write_bytes(b"owner preferences")
        result_path = Path(self.work.name) / "result.json"
        command = [sys.executable, "-c", "import sys; sys.exit(-1)"]
        result = subprocess.run(
            [sys.executable, "tools/with_preserved_settings.py", "--settings", str(self.path),
             "--result-json", str(result_path), "--", *command],
            check=False,
        )
        expected = 0xFFFFFFFF if os.name == "nt" else 255
        self.assertEqual(result.returncode, expected)
        payload = json.loads(result_path.read_text(encoding="utf-8"))
        self.assertEqual(payload["returncode_hex"], f"0x{expected:08X}")
        self.assertEqual(payload["returncode_unsigned"], expected)
        self.assertTrue(payload["settings_preserved"])

    def test_cleanup_survives_child_failure(self):
        self.path.write_bytes(b"owner preferences")
        with self.assertRaises(RuntimeError):
            with preserve_settings(self.path):
                self.path.write_bytes(b"changed")
                raise RuntimeError("child failed")
        self.assertEqual(self.path.read_bytes(), b"owner preferences")


if __name__ == "__main__":
    unittest.main()
