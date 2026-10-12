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


    def test_archives_and_vcs_or_godot_cache_are_excluded(self):
        for path in ("builds/old.zip", "old-package.zip", ".git/HEAD", ".godot/imported/x.ctex", "export.pck.bak"):
            with self.subTest(path=path):
                self.assertTrue(package_windows_beta.is_excluded(Path(path)))

    def test_spoiler_sound_brief_is_not_packaged(self):
        self.assertTrue(package_windows_beta.is_spoiler_document(Path("SOUND_HANDOFF_SPOILERS.md")))
        self.assertFalse(package_windows_beta.is_spoiler_document(Path("README_WINDOWS_BETA.md")))

    def test_source_requires_matching_exe_and_pck(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "export"
            source.mkdir()
            (source / "dead-wire-windows-beta-x86_64.pck").write_bytes(b"pck")
            with self.assertRaises(FileNotFoundError):
                package_windows_beta.check_source(source, "dead-wire-windows-beta-x86_64")

    def test_output_inside_source_or_source_as_root_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "export"
            source.mkdir()
            with self.assertRaises(ValueError):
                package_windows_beta.check_output(source, source / "pkg.zip", root)
            with self.assertRaises(ValueError):
                package_windows_beta.check_output(root, root / "pkg.zip", root)
            package_windows_beta.check_output(source, root / "builds" / "out" / "pkg.zip", root)

    def test_pck_missing_class_name_script_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cache = root / "cache.cfg"
            cache.write_text('{"class": &"GameSettings", "path": "res://scripts/ui/game_settings.gd"}', encoding="utf-8")
            pck = root / "game.pck"
            pck.write_bytes(b"res://scripts/ui/main_menu.gd")
            with self.assertRaises(RuntimeError):
                package_windows_beta.check_pck_has_class_scripts(pck, cache)
            pck.write_bytes(b"res://scripts/ui/game_settings.gd")
            package_windows_beta.check_pck_has_class_scripts(pck, cache)

    def test_build_id_changes_when_executable_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "export"
            source.mkdir()
            (source / "dead-wire-windows-beta-x86_64.exe").write_bytes(b"exe1")
            (source / "dead-wire-windows-beta-x86_64.pck").write_bytes(b"pck")
            with patch.object(package_windows_beta, "git_revision", return_value="abc123"):
                first = package_windows_beta.build_id(Path(directory), source)
                (source / "dead-wire-windows-beta-x86_64.exe").write_bytes(b"exe2")
                second = package_windows_beta.build_id(Path(directory), source)
            self.assertNotEqual(first, second)


if __name__ == "__main__":
    unittest.main()
