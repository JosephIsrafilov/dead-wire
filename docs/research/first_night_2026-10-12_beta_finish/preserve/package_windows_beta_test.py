"""Unit tests for Windows beta packaging helpers; no Godot invocation."""
import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

MODULE_PATH = Path(__file__).with_name("package_windows_beta.py")
SPEC = importlib.util.spec_from_file_location("package_windows_beta", MODULE_PATH)
package_windows_beta = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(package_windows_beta)


class PackageFilterTests(unittest.TestCase):
    def test_runtime_files_are_kept(self):
        self.assertFalse(package_windows_beta.is_excluded(Path("dead-wire.pck")))
        self.assertFalse(package_windows_beta.is_excluded(Path("audio/sfx/telegraph/sounder_down.wav")))
        self.assertFalse(package_windows_beta.is_excluded(Path("icon.svg")))
        self.assertFalse(package_windows_beta.is_excluded(Path("assets/fonts/noto/NotoSans-Regular.ttf")))

    def test_development_and_sensitive_files_are_excluded(self):
        paths = (
            "tools/x.py", "tests/x.gd", ".hermes/state", "research/note.md",
            "docs/notes.md", ".codex/state", ".agents/state", "builds/old.zip",
            "logs/session.log", "credentials/key.txt", ".env", "debug.secret",
            "assets/source.blend", "assets/source.json", "assets/unused.svg",
            "assets/fonts/noto/variable_source/NotoSans.ttf",
            "assets/fonts/noto/x.gdignore",
        )
        for path in paths:
            with self.subTest(path=path):
                self.assertTrue(package_windows_beta.is_excluded(Path(path)))

    def test_build_id_contains_revision_and_content_digest(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "export"
            source.mkdir()
            (source / "game.pck").write_bytes(b"fixture")
            with patch.object(package_windows_beta, "git_revision", return_value="abc123"):
                identifier = package_windows_beta.build_id(Path(directory), source)
            self.assertTrue(identifier.startswith("dead-wire-windows-beta-abc123-"))
            self.assertEqual(len(identifier.rsplit("-", 1)[-1]), 12)

    def test_versioned_output_path_always_contains_build_id(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "export"
            source.mkdir()
            (source / "game.pck").write_bytes(b"fixture")
            with patch.object(package_windows_beta, "git_revision", return_value="abc123"):
                output = package_windows_beta.versioned_output_path(Path(directory), source, Path("beta.zip"))
            self.assertTrue(output.name.startswith("beta-dead-wire-windows-beta-abc123-"))
            self.assertEqual(output.suffix, ".zip")


if __name__ == "__main__":
    unittest.main()
