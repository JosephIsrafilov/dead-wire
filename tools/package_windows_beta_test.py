"""Unit tests for Windows beta packaging helpers; no Godot invocation.

PCK fixtures are real format-v4 packs built by `build_pck` in this file, so
directory, payload and hash checks run against actual pack structure.
"""
import importlib.util
import struct
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

MODULE_PATH = Path(__file__).with_name("package_windows_beta.py")
SPEC = importlib.util.spec_from_file_location("package_windows_beta", MODULE_PATH)
package_windows_beta = importlib.util.module_from_spec(SPEC)
sys.modules["package_windows_beta"] = package_windows_beta
SPEC.loader.exec_module(package_windows_beta)

PCK_MAGIC = b"GDPC"
FORMAT_VERSION = 4
FILE_BASE = 112


def build_pck(path: Path, entries: dict[str, bytes], engine=(4, 7, 1)) -> None:
    """Write a minimal but structurally real Godot 4 PCK v4.

    Layout mirrors the shipped game pack: 40-byte header, pad to file_base
    (112), directory block, then payloads at absolute offsets.
    """
    names = list(entries)
    directory = bytearray(struct.pack("<I", len(names)))
    for name in names:
        encoded = name.encode()
        directory += struct.pack("<I", len(encoded))
        directory += encoded + b"\x00" * (-len(encoded) % 4)
        directory += struct.pack("<QQ", 0, len(entries[name]))
        directory += package_windows_beta.entry_md5(entries[name])
        directory += struct.pack("<I", 0)
    payload_start = FILE_BASE + len(directory)
    offsets = {}
    position = payload_start
    for name in names:
        offsets[name] = position
        position += len(entries[name])
    # Patch offsets and directory position now that sizes are known.
    directory = bytearray(struct.pack("<I", len(names)))
    for name in names:
        encoded = name.encode()
        directory += struct.pack("<I", len(encoded))
        directory += encoded + b"\x00" * (-len(encoded) % 4)
        directory += struct.pack("<QQ", offsets[name] - FILE_BASE, len(entries[name]))
        directory += package_windows_beta.entry_md5(entries[name])
        directory += struct.pack("<I", 0)
    header = bytearray()
    header += PCK_MAGIC
    header += struct.pack("<5I", FORMAT_VERSION, engine[0], engine[1], engine[2], 2)
    header += struct.pack("<Q", FILE_BASE)
    header += struct.pack("<Q", FILE_BASE)  # directory offset (absolute)
    header += b"\x00" * (FILE_BASE - len(header))
    assert len(header) == FILE_BASE
    path.write_bytes(bytes(header) + bytes(directory) + b"".join(entries[n] for n in names))


def make_source(root: Path, pck_entries: dict[str, bytes], extra: dict[str, bytes] | None = None) -> Path:
    source = root / "export"
    source.mkdir()
    build_pck(source / package_windows_beta.SOURCE_PACK, pck_entries)
    (source / package_windows_beta.SOURCE_EXECUTABLE).write_bytes(b"fake engine exe")
    docs = root / "docs" / "beta"
    docs.mkdir(parents=True, exist_ok=True)
    (docs / "README_WINDOWS_BETA.md").write_text("readme", encoding="utf-8")
    (docs / "THIRD_PARTY_NOTICES.md").write_text("notices", encoding="utf-8")
    godot = root / ".godot"
    godot.mkdir(exist_ok=True)
    (godot / "global_script_class_cache.cfg").write_text("", encoding="utf-8")
    for name, data in (extra or {}).items():
        (source / name).write_bytes(data)
    return source


def cache_with(*paths: str) -> str:
    return "".join(
        '{\n"base": &"RefCounted",\n"class": &"C%d",\n"path": "%s"\n}' % (i, p)
        for i, p in enumerate(paths)
    )


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
            "audio/sfx/foley/footstep_wood.wav",
            "audio/sfx/foley/footstep_wood.wav.import",
        )
        for path in paths:
            with self.subTest(path=path):
                self.assertTrue(package_windows_beta.is_excluded(Path(path)))

    def test_unexpected_source_files_are_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = make_source(root, {"res://icon.svg": b"png"})
            (source / "private-notes.txt").write_text("draft")
            output = root / "builds" / "pkg.zip"
            with patch.object(package_windows_beta, "git_revision", return_value="abc123"):
                with self.assertRaises(ValueError) as caught:
                    package_windows_beta.package(root, source, output)
            self.assertIn("private-notes.txt", str(caught.exception))

    def test_explicit_extra_runtime_dll_is_allowed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = make_source(root, {
                "res://icon.svg": b"png",
                "res://.godot/imported/footstep_wood_beta.wav-9bb5baa446e205f786a293ff220a641a.sample": b"beta",
            }, {"approved.dll": b"dll"})
            output = root / "builds" / "pkg.zip"
            with patch.object(package_windows_beta, "git_revision", return_value="abc123"):
                identifier, names = package_windows_beta.package(
                    root, source, output, allowed_extras=("approved.dll",),
                )
            self.assertTrue(output.is_file())
            self.assertIn("dead-wire-windows-beta/approved.dll", names)

    def test_unapproved_dll_without_allow_flag_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = make_source(root, {"res://icon.svg": b"png"}, {"untrusted.dll": b"dll"})
            with patch.object(package_windows_beta, "git_revision", return_value="abc123"):
                with self.assertRaises(ValueError):
                    package_windows_beta.package(root, source, root / "builds" / "pkg.zip")

    def test_build_id_contains_revision_and_content_digest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = make_source(root, {"res://icon.svg": b"png"})
            with patch.object(package_windows_beta, "git_revision", return_value="abc123"):
                identifier = package_windows_beta.build_id(root, source)
            self.assertTrue(identifier.startswith("dead-wire-windows-beta-abc123-"))
            self.assertEqual(len(identifier.rsplit("-", 1)[-1]), 12)

    def test_build_id_ignores_non_manifest_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = make_source(root, {"res://icon.svg": b"png"})
            with patch.object(package_windows_beta, "git_revision", return_value="abc123"):
                first = package_windows_beta.build_id(root, source)
                (source / "scratch.txt").write_text("late edit")
                second = package_windows_beta.build_id(root, source)
            self.assertEqual(first, second)

    def test_versioned_output_path_always_contains_build_id(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = make_source(root, {"res://icon.svg": b"png"})
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


class PckDirectoryTests(unittest.TestCase):
    def test_reader_parses_real_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            pck = Path(directory) / "game.pck"
            entries = {"res://icon.svg": b"pngdata", "res://scripts/ui/game_settings.gd": b"code"}
            build_pck(pck, entries)
            read = package_windows_beta.read_pck_directory(pck)
            self.assertEqual({e.path for e in read}, set(entries))
            by_path = {e.path: e for e in read}
            self.assertEqual(by_path["res://icon.svg"].size, len(b"pngdata"))
            self.assertEqual(by_path["res://icon.svg"].md5, package_windows_beta.entry_md5(b"pngdata"))

    def test_reader_rejects_non_pck_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            pck = Path(directory) / "game.pck"
            pck.write_bytes(b"res://scripts/ui/game_settings.gd")
            with self.assertRaises(ValueError):
                package_windows_beta.read_pck_directory(pck)

    def test_reader_rejects_unsupported_format_version(self):
        with tempfile.TemporaryDirectory() as directory:
            pck = Path(directory) / "game.pck"
            build_pck(pck, {"res://icon.svg": b"x"})
            blob = bytearray(pck.read_bytes())
            blob[4:8] = struct.pack("<I", 3)
            pck.write_bytes(blob)
            with self.assertRaises(ValueError):
                package_windows_beta.read_pck_directory(pck)

    def test_payload_md5_mismatch_is_detected(self):
        with tempfile.TemporaryDirectory() as directory:
            pck = Path(directory) / "game.pck"
            build_pck(pck, {"res://scripts/ui/game_settings.gd": b"runtime bytecode here"})
            blob = bytearray(pck.read_bytes())
            blob[-1] ^= 0xFF  # corrupt the last payload byte
            pck.write_bytes(blob)
            with self.assertRaises(ValueError):
                package_windows_beta.verify_pck_payloads(pck)
            build_pck(pck, {"res://scripts/ui/game_settings.gd": b"runtime bytecode here"})
            package_windows_beta.verify_pck_payloads(pck)

    def test_class_script_requires_directory_entry_not_substring(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cache = root / "cache.cfg"
            cache.write_text(cache_with("res://scripts/ui/game_settings.gd"), encoding="utf-8")
            pck = root / "game.pck"
            # The class path appears only inside another entry's payload.
            build_pck(pck, {"res://scripts/ui/main_menu.gd": b'ref: "res://scripts/ui/game_settings.gd"'})
            with self.assertRaises(RuntimeError):
                package_windows_beta.check_pck_has_class_scripts(pck, cache)
            # As a real directory entry it passes.
            build_pck(pck, {
                "res://scripts/ui/main_menu.gd": b"code",
                "res://scripts/ui/game_settings.gd": b"code",
            })
            package_windows_beta.check_pck_has_class_scripts(pck, cache)

    def test_class_script_via_remap_requires_existing_gdc_target(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cache = root / "cache.cfg"
            cache.write_text(cache_with("res://scripts/ui/game_settings.gd"), encoding="utf-8")
            pck = root / "game.pck"
            remap = b'[remap]\n\npath="res://.godot/exported/133200997/export-abc-game_settings.gdc"\n'
            build_pck(pck, {
                "res://scripts/ui/game_settings.gd.remap": remap,
                "res://.godot/exported/133200997/export-abc-game_settings.gdc": b"bytecode",
            })
            package_windows_beta.check_pck_has_class_scripts(pck, cache)
            # Same remap but the .gdc target is missing.
            build_pck(pck, {"res://scripts/ui/game_settings.gd.remap": remap})
            with self.assertRaises(RuntimeError):
                package_windows_beta.check_pck_has_class_scripts(pck, cache)

    def test_legacy_footstep_is_refused_and_beta_required(self):
        beta = "res://.godot/imported/footstep_wood_beta.wav-9bb5baa446e205f786a293ff220a641a.sample"
        with tempfile.TemporaryDirectory() as directory:
            pck = Path(directory) / "game.pck"
            build_pck(pck, {
                "res://audio/sfx/foley/footstep_wood.wav": b"unknown legacy bytes",
                "res://audio/sfx/foley/footstep_wood.wav.import": b"[remap]",
                "res://.godot/imported/footstep_wood.wav-27053a10b84cc01ebb63a166e35ffe06.sample": b"sample",
                beta: b"beta",
            })
            with self.assertRaises(RuntimeError):
                package_windows_beta.check_pck_exclusions(pck)
            # Legacy removed but the beta replacement missing: still refused.
            build_pck(pck, {"res://audio/sfx/telegraph/sounder_down.wav": b"ok"})
            with self.assertRaises(RuntimeError):
                package_windows_beta.check_pck_exclusions(pck)
            # Clean manifest with the beta replacement: accepted.
            build_pck(pck, {
                "res://audio/sfx/telegraph/sounder_down.wav": b"ok",
                beta: b"beta",
            })
            package_windows_beta.check_pck_exclusions(pck)

    def test_private_paths_are_refused_in_pck(self):
        with tempfile.TemporaryDirectory() as directory:
            pck = Path(directory) / "game.pck"
            build_pck(pck, {
                "res://docs/beta/README_WINDOWS_BETA.md": b"doc",
                "res://tools/generate_sounder.py": b"script",
                "res://tests/ui/framing_test.gd": b"test",
                "res://sites/dead-wire/img/icon.svg": b"web",
            })
            with self.assertRaises(RuntimeError):
                package_windows_beta.check_pck_exclusions(pck)

    def test_build_id_changes_when_executable_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = make_source(root, {"res://icon.svg": b"png"})
            with patch.object(package_windows_beta, "git_revision", return_value="abc123"):
                first = package_windows_beta.build_id(root, source)
                (source / package_windows_beta.SOURCE_EXECUTABLE).write_bytes(b"exe2")
                second = package_windows_beta.build_id(root, source)
            self.assertNotEqual(first, second)


if __name__ == "__main__":
    unittest.main()
