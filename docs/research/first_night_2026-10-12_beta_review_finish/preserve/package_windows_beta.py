"""Package an existing standalone Windows export without invoking Godot."""
from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import zipfile
from datetime import datetime, timezone
from pathlib import Path

EXCLUDED_PARTS = {
    ".hermes", ".codex", ".agents", ".git", ".godot", "builds", "docs", "research",
    "tools", "tests", "logs", "credentials", "variable_source",
}
EXCLUDED_NAMES = {".env", ".env.example", ".env.local"}
EXCLUDED_SUFFIXES = {".log", ".secret", ".credentials", ".blend", ".gdignore", ".py", ".zip", ".bak", ".dmp"}
EXCLUDED_SOURCE_SUFFIXES = {".json", ".svg"}


SPOILER_DOCUMENTS = {"sound_handoff_spoilers.md"}
SOURCE_EXECUTABLE = "dead-wire-windows-beta-x86_64.exe"
SOURCE_PACK = "dead-wire-windows-beta-x86_64.pck"


def is_spoiler_document(relative_path: Path) -> bool:
    return relative_path.name.lower() in SPOILER_DOCUMENTS


def check_source(source: Path, _stem: str) -> None:
    missing = [name for name in (SOURCE_EXECUTABLE, SOURCE_PACK) if not (source / name).is_file()]
    if missing:
        raise FileNotFoundError("Export is missing: " + ", ".join(missing))


def class_script_paths(cache: Path) -> set[str]:
    """Script paths of every class_name in Godot's global class cache."""
    text = cache.read_text(encoding="utf-8")
    return set(re.findall(r'"path": "(res://[^"]+\.gd)"', text))


def check_pck_has_class_scripts(pck: Path, cache: Path) -> None:
    """Refuse a PCK that lacks any class_name script: Godot's scene export does not follow class_name references."""
    data = pck.read_bytes()
    missing = sorted(path for path in class_script_paths(cache) if path.encode() not in data)
    if missing:
        raise RuntimeError("PCK is missing class_name scripts: " + ", ".join(missing))


def check_output(source: Path, output: Path, root: Path) -> None:
    resolved = output.resolve()
    source = source.resolve()
    if source == root.resolve():
        raise ValueError("Refusing: source is the repository root")
    if resolved.is_relative_to(source):
        raise ValueError(f"Refusing output {resolved}: inside the export directory")


def is_excluded(relative_path: Path) -> bool:
    parts = {part.lower() for part in relative_path.parts}
    name = relative_path.name.lower()
    suffix = relative_path.suffix.lower()
    is_runtime_icon = relative_path.as_posix() == "icon.svg"
    return (
        bool(parts & EXCLUDED_PARTS)
        or name in EXCLUDED_NAMES
        or suffix in EXCLUDED_SUFFIXES
        or (suffix in EXCLUDED_SOURCE_SUFFIXES and not is_runtime_icon)
        or "credential" in name
        or "secret" in name
    )


def git_revision(root: Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", "--short=12", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def build_id(root: Path, source: Path) -> str:
    digest = hashlib.sha256()
    for item in sorted(source.rglob("*")):
        if item.is_file() and not is_excluded(item.relative_to(source)) and not is_spoiler_document(item.relative_to(source)):
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


def add_tree(archive: zipfile.ZipFile, source: Path, prefix: str) -> list[str]:
    added: list[str] = []
    for item in sorted(source.rglob("*")):
        if not item.is_file():
            continue
        relative = item.relative_to(source)
        if is_excluded(relative) or is_spoiler_document(relative):
            continue
        name = f"{prefix}/{relative.as_posix()}"
        archive.write(item, name)
        added.append(name)
    return added


def package(root: Path, source: Path, output: Path) -> tuple[str, list[str]]:
    docs = root / "docs" / "beta"
    required = [docs / "README_WINDOWS_BETA.md", docs / "THIRD_PARTY_NOTICES.md"]
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise FileNotFoundError("Missing package documents: " + ", ".join(missing))
    check_source(source, output.stem)
    check_output(source, output, root)
    check_pck_has_class_scripts(source / SOURCE_PACK, root / ".godot" / "global_script_class_cache.cfg")
    identifier = build_id(root, source)
    output.parent.mkdir(parents=True, exist_ok=True)
    names: list[str] = []
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        names.extend(add_tree(archive, source, "dead-wire-windows-beta"))
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
            "Export invocation: not performed by this packaging tool.\n"
            "Export/runtime verification: not performed by this packaging tool.\n"
        )
        archive.writestr("dead-wire-windows-beta/hand-off/BUILD_PROVENANCE.txt", provenance)
        names.append("dead-wire-windows-beta/hand-off/BUILD_PROVENANCE.txt")
    return identifier, names


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Existing standalone Windows export directory")
    parser.add_argument("--output", type=Path, help="Output directory or ZIP stem; build ID is always appended")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.root.resolve()
    source = args.source.resolve()
    output = versioned_output_path(root, source, args.output)
    identifier, names = package(root, source, output)
    print(f"Prepared {output} ({len(names)} files); build id {identifier}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
