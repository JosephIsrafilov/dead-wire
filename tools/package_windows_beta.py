"""Package an existing standalone Windows export without invoking Godot.

The packager validates a real Godot PCK v4 directory (magic, bounds, payload
MD5s), enforces an explicit source manifest, refuses known-private or
provenance-blocked paths inside the pack, and stamps the result with a build
identifier derived from the final runtime manifest only.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import struct
import subprocess
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

EXCLUDED_PARTS = {
    ".hermes", ".codex", ".agents", ".git", ".godot", "builds", "docs", "research",
    "tools", "tests", "logs", "credentials", "variable_source",
}
EXCLUDED_NAMES = {".env", ".env.example", ".env.local"}
EXCLUDED_SUFFIXES = {".log", ".secret", ".credentials", ".blend", ".gdignore", ".py", ".zip", ".bak", ".dmp"}
EXCLUDED_SOURCE_SUFFIXES = {".json", ".svg"}

# Known-unknown-provenance asset kept in the repository for rollback only.
# It must never reach a beta package; the beta replacement stays required.
LEGACY_RUNTIME_PATHS = {"audio/sfx/foley/footstep_wood.wav"}
LEGACY_IMPORTED_PREFIXES = ("res://.godot/imported/footstep_wood.wav-",)
REQUIRED_IMPORTED_PREFIXES = ("res://.godot/imported/footstep_wood_beta.wav-",)

SPOILER_DOCUMENTS = {"sound_handoff_spoilers.md"}
SOURCE_EXECUTABLE = "dead-wire-windows-beta-x86_64.exe"
SOURCE_PACK = "dead-wire-windows-beta-x86_64.pck"

PCK_MAGIC = b"GDPC"
PCK_FORMAT_VERSION = 4
PCK_ENTRY_FLAG_ENCRYPTED = 1
PCK_ENTRY_FLAG_RELATIVE_OFFSET = 2
_PCK_HEADER = struct.Struct("<4s6I")  # magic, version, engine maj/min/patch, flags, file_base lo/hi is packed separately


@dataclass(frozen=True)
class PckEntry:
    path: str
    offset: int
    size: int
    md5: bytes
    flags: int


def entry_md5(data: bytes) -> bytes:
    return hashlib.md5(data).digest()


def read_pck_directory(pck: Path) -> list[PckEntry]:
    """Parse a real Godot PCK v4 directory with bounds checks.

    Only the exact format this project ships is supported; anything else must
    fail loudly instead of degrading into substring guessing.
    """
    blob = pck.read_bytes()
    if len(blob) < 40 or blob[:4] != PCK_MAGIC:
        raise ValueError(f"{pck}: not an unencrypted Godot PCK (bad magic)")
    version, engine_major, engine_minor, engine_patch, flags = struct.unpack_from("<5I", blob, 4)
    if version != PCK_FORMAT_VERSION:
        raise ValueError(f"{pck}: unsupported PCK format version {version}; only {PCK_FORMAT_VERSION} is supported")
    if flags & PCK_ENTRY_FLAG_ENCRYPTED:
        raise ValueError(f"{pck}: encrypted packs are not supported")
    (file_base,) = struct.unpack_from("<Q", blob, 24)
    (dir_offset,) = struct.unpack_from("<Q", blob, 32)
    if dir_offset + 4 > len(blob):
        raise ValueError(f"{pck}: directory offset {dir_offset} is out of bounds")
    (count,) = struct.unpack_from("<I", blob, dir_offset)
    if count > 1_000_000:
        raise ValueError(f"{pck}: implausible entry count {count}")
    cursor = dir_offset + 4
    entries: list[PckEntry] = []
    for _ in range(count):
        if cursor + 4 > len(blob):
            raise ValueError(f"{pck}: truncated directory at {cursor}")
        (length,) = struct.unpack_from("<I", blob, cursor)
        if not 1 <= length < 4096:
            raise ValueError(f"{pck}: implausible path length {length} at {cursor}")
        raw = blob[cursor + 4 : cursor + 4 + length]
        if len(raw) != length:
            raise ValueError(f"{pck}: truncated path at {cursor}")
        cursor += 4 + length + (-length % 4)
        if cursor + 36 > len(blob):
            raise ValueError(f"{pck}: truncated entry record at {cursor}")
        offset, size = struct.unpack_from("<QQ", blob, cursor)
        md5 = blob[cursor + 16 : cursor + 32]
        (entry_flags,) = struct.unpack_from("<I", blob, cursor + 32)
        cursor += 36
        entries.append(PckEntry(raw.rstrip(b"\0").decode("utf-8", "replace"), offset, size, md5, entry_flags))
    return entries


def verify_pck_payloads(pck: Path, entries: list[PckEntry] | None = None) -> None:
    """Every directory entry must reference in-bounds, hash-matching bytes."""
    blob = pck.read_bytes()
    (file_base,) = struct.unpack_from("<Q", blob, 24)
    for entry in entries or read_pck_directory(pck):
        if entry.flags & PCK_ENTRY_FLAG_ENCRYPTED:
            raise ValueError(f"{pck}: encrypted entry {entry.path}")
        # Godot loads entry offsets relative to the embedded-file base whenever
        # the pack is appended to the executable; the flag only marks packs where
        # it was stored already-adjusted. The shipped p10 pack needs the base.
        offset = entry.offset + file_base
        if entry.flags & PCK_ENTRY_FLAG_RELATIVE_OFFSET:
            offset = entry.offset
        if offset < 0 or entry.size < 0 or offset + entry.size > len(blob):
            raise ValueError(f"{pck}: payload for {entry.path} is out of bounds")
        if hashlib.md5(blob[offset : offset + entry.size]).digest() != entry.md5:
            raise ValueError(f"{pck}: payload MD5 mismatch for {entry.path}")


def class_script_paths(cache: Path) -> set[str]:
    """Script paths of every class_name in Godot's global class cache."""
    text = cache.read_text(encoding="utf-8")
    return set(re.findall(r'"path": "(res://[^"]+\.gd)"', text))


def _remap_target(payload: bytes) -> str | None:
    match = re.search(rb'path="(res://[^"]+\.gdc)"', payload)
    return match.group(1).decode() if match else None


def check_pck_has_class_scripts(pck: Path, cache: Path) -> None:
    """Every class_name script must exist as a real directory entry.

    A plain .gd entry, or a .gd.remap entry whose .gdc bytecode target also
    exists, is accepted. A path string left inside another payload does not
    count as shipped code.
    """
    entries = {entry.path.removeprefix("res://"): entry for entry in read_pck_directory(pck)}
    missing: list[str] = []
    for path in sorted(class_script_paths(cache)):
        bare = path.removeprefix("res://")
        if bare in entries:
            continue
        remap = entries.get(bare + ".remap")
        if remap is not None:
            blob = pck.read_bytes()
            (file_base,) = struct.unpack_from("<Q", blob, 24)
            offset = remap.offset + file_base
            if remap.flags & PCK_ENTRY_FLAG_RELATIVE_OFFSET:
                offset = remap.offset
            target = _remap_target(blob[offset : offset + remap.size])
            if target and target.removeprefix("res://") in entries:
                continue
        missing.append(path)
    if missing:
        raise RuntimeError("PCK is missing class_name scripts: " + ", ".join(missing))


def check_pck_exclusions(pck: Path, entries: list[PckEntry] | None = None) -> None:
    """Refuse known-private paths and the unshippable legacy footstep.

    Directory paths are stored without the ``res://`` prefix in PCK v4, but a
    few writer builds keep it; comparison normalizes both sides.
    """
    paths = [entry.path.removeprefix("res://") for entry in (entries or read_pck_directory(pck))]
    forbidden_prefixes = (
        "docs/", "tools/", "tests/", "builds/", "research/", "sites/",
        ".hermes/", ".codex/", ".agents/", "logs/", ".dream-loop/",
    )
    bad: list[str] = []
    for path in paths:
        lowered = path.lower()
        if lowered == "icon.svg" or lowered.startswith(".godot/"):
            continue
        if any(lowered.startswith(prefix) for prefix in forbidden_prefixes):
            bad.append(path)
        elif lowered.endswith((".py", ".blend")) or lowered == ".env" or "credential" in lowered or "secret" in lowered:
            bad.append(path)
        elif lowered in LEGACY_RUNTIME_PATHS or lowered.startswith(".godot/imported/footstep_wood.wav-"):
            bad.append(path)
    if bad:
        raise RuntimeError("PCK contains forbidden paths: " + ", ".join(sorted(bad)))
    present = set(paths)
    legacy_leftovers = sorted(
        path for path in present
        if path in LEGACY_RUNTIME_PATHS or path.startswith(".godot/imported/footstep_wood.wav-")
    )
    if legacy_leftovers:
        raise RuntimeError("PCK still contains legacy rollback-only audio: " + ", ".join(legacy_leftovers))
    if not any(path.startswith(".godot/imported/footstep_wood_beta.wav-") for path in present):
        raise RuntimeError("PCK is missing required runtime audio: footstep_wood_beta (imported sample)")


def is_spoiler_document(relative_path: Path) -> bool:
    return relative_path.name.lower() in SPOILER_DOCUMENTS


def is_excluded(relative_path: Path) -> bool:
    parts = {part.lower() for part in relative_path.parts}
    name = relative_path.name.lower()
    suffix = relative_path.suffix.lower()
    posix = relative_path.as_posix().lower()
    is_runtime_icon = posix == "icon.svg"
    return (
        posix in LEGACY_RUNTIME_PATHS
        or posix in {f"{p}.import" for p in LEGACY_RUNTIME_PATHS}
        or bool(parts & EXCLUDED_PARTS)
        or name in EXCLUDED_NAMES
        or suffix in EXCLUDED_SUFFIXES
        or (suffix in EXCLUDED_SOURCE_SUFFIXES and not is_runtime_icon)
        or "credential" in name
        or "secret" in name
    )


def check_source(source: Path, _stem: str) -> None:
    missing = [name for name in (SOURCE_EXECUTABLE, SOURCE_PACK) if not (source / name).is_file()]
    if missing:
        raise FileNotFoundError("Export is missing: " + ", ".join(missing))


def check_manifest(source: Path, allowed_extras: tuple[str, ...] = ()) -> list[Path]:
    """The export directory must contain exactly the approved runtime files."""
    manifest = {SOURCE_EXECUTABLE, SOURCE_PACK, *allowed_extras}
    unexpected = sorted(
        item.relative_to(source).as_posix()
        for item in source.rglob("*")
        if item.is_file() and item.relative_to(source).as_posix() not in manifest
    )
    if unexpected:
        raise ValueError(
            "Export contains files outside the approved manifest (pass --allow-extra to approve): "
            + ", ".join(unexpected)
        )
    return [source / name for name in sorted(manifest)]


def check_output(source: Path, output: Path, root: Path) -> None:
    resolved = output.resolve()
    source = source.resolve()
    if source == root.resolve():
        raise ValueError("Refusing: source is the repository root")
    if resolved.is_relative_to(source):
        raise ValueError(f"Refusing output {resolved}: inside the export directory")


def git_revision(root: Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", "--short=12", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def _pck_engine_version(pck: Path) -> str:
    header = pck.read_bytes()[:24]
    if header[:4] != PCK_MAGIC:
        return "unknown"
    _, major, minor, patch = struct.unpack_from("<4I", header, 0)
    return f"{major}.{minor}.{patch}"


def build_id(root: Path, source: Path, manifest: list[Path] | None = None) -> str:
    """Content digest over the final runtime manifest (EXE, PCK, approved extras)."""
    digest = hashlib.sha256()
    files = manifest if manifest is not None else [source / name for name in (SOURCE_EXECUTABLE, SOURCE_PACK)]
    for item in files:
        digest.update(item.relative_to(source).as_posix().encode())
        digest.update(item.read_bytes())
    return f"dead-wire-windows-beta-{git_revision(root)}-{digest.hexdigest()[:12]}"


def versioned_output_path(root: Path, source: Path, requested: Path | None = None) -> Path:
    identifier = build_id(root, source)
    if requested is None:
        return root / "builds" / "windows-beta" / f"{identifier}.zip"
    requested = requested.resolve()
    directory = requested if requested.suffix.lower() != ".zip" else requested.parent
    stem = requested.stem if requested.suffix.lower() == ".zip" else requested.name
    if identifier not in stem:
        stem = f"{stem}-{identifier}"
    return directory / f"{stem}.zip"


def package(root: Path, source: Path, output: Path, allowed_extras: tuple[str, ...] = ()) -> tuple[str, list[str]]:
    docs = root / "docs" / "beta"
    required = [docs / "README_WINDOWS_BETA.md", docs / "THIRD_PARTY_NOTICES.md"]
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise FileNotFoundError("Missing package documents: " + ", ".join(missing))
    check_source(source, output.stem)
    manifest = check_manifest(source, allowed_extras)
    check_output(source, output, root)
    pck_path = source / SOURCE_PACK
    entries = read_pck_directory(pck_path)
    verify_pck_payloads(pck_path, entries)
    check_pck_exclusions(pck_path, entries)
    check_pck_has_class_scripts(pck_path, root / ".godot" / "global_script_class_cache.cfg")
    identifier = build_id(root, source, manifest)
    output.parent.mkdir(parents=True, exist_ok=True)
    names: list[str] = []
    exe_hash = hashlib.sha256((source / SOURCE_EXECUTABLE).read_bytes()).hexdigest()
    pck_hash = hashlib.sha256(pck_path.read_bytes()).hexdigest()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for item in manifest:
            name = f"dead-wire-windows-beta/{item.relative_to(source).as_posix()}"
            archive.write(item, name)
            names.append(name)
        for document in sorted(docs.glob("*.md")):
            if is_spoiler_document(Path(document.name)):
                continue
            name = f"dead-wire-windows-beta/hand-off/{document.name}"
            archive.write(document, name)
            names.append(name)
        notices = docs / "THIRD_PARTY_NOTICES.md"
        archive.write(notices, "dead-wire-windows-beta/THIRD_PARTY_NOTICES.md")
        names.append("dead-wire-windows-beta/THIRD_PARTY_NOTICES.md")
        for license_file in sorted((root / "assets" / "fonts").glob("*/OFL.txt")):
            name = f"dead-wire-windows-beta/licenses/fonts/{license_file.parent.name}/OFL.txt"
            archive.write(license_file, name)
            names.append(name)
        attribution = root / "audio" / "music" / "temp" / "ATTRIBUTION.txt"
        if attribution.is_file():
            archive.write(attribution, "dead-wire-windows-beta/licenses/audio/ATTRIBUTION.txt")
            names.append("dead-wire-windows-beta/licenses/audio/ATTRIBUTION.txt")
        provenance = (
            f"Build identifier: {identifier}\n"
            f"Package timestamp (UTC): {datetime.now(timezone.utc).isoformat()}\n"
            f"Godot PCK format: {PCK_FORMAT_VERSION}; engine build target {_pck_engine_version(pck_path)}\n"
            f"PCK directory entries: {len(entries)} (payload MD5s verified)\n"
            f"Source manifest: {', '.join(item.name for item in manifest)}\n"
            f"SHA256 {SOURCE_EXECUTABLE}: {exe_hash}\n"
            f"SHA256 {SOURCE_PACK}: {pck_hash}\n"
            "Export invocation: not performed by this packaging tool.\n"
            "Export/runtime verification: engine version above; route evidence lives in the research logs.\n"
        )
        archive.writestr("dead-wire-windows-beta/hand-off/BUILD_PROVENANCE.txt", provenance)
        names.append("dead-wire-windows-beta/hand-off/BUILD_PROVENANCE.txt")
    return identifier, names


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Existing standalone Windows export directory")
    parser.add_argument("--output", type=Path, help="Output directory or ZIP stem; build ID is always appended")
    parser.add_argument("--allow-extra", action="append", default=[], metavar="NAME",
                        help="Approve one additional runtime file by exact name (e.g. an engine DLL)")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.root.resolve()
    source = args.source.resolve()
    output = versioned_output_path(root, source, args.output)
    identifier, names = package(root, source, output, tuple(args.allow_extra))
    print(f"Prepared {output} ({len(names)} files); build id {identifier}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
