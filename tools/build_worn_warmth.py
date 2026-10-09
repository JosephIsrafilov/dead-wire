"""Build the M1 material candidates from existing licensed sources and authored cloth.

.venv-tools/Scripts/python.exe tools/build_worn_warmth.py
Original files are never overwritten. Derived albedos only: no baked lighting or normal maps.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from psx_texture import prepare

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/textures/worn_warmth"
EVIDENCE = ROOT / "docs/art/state_2026-10-08/worn_warmth"
SOURCE = ROOT / "materials/style_tests/textures"


def mean_rgb(image):
    return np.asarray(image.convert("RGB"), dtype=np.float64).mean(axis=(0, 1))


def restrained(image, strength):
    pixels = np.asarray(image.convert("RGB"), dtype=np.float64)
    mean = pixels.mean(axis=(0, 1))
    return Image.fromarray(np.uint8(np.clip(mean + (pixels - mean) * strength, 0, 255)))


def cloth_source():
    # A tiny authored weave, not downloaded or AI-generated. Periodic yarn/noise.
    y, x = np.mgrid[:128, :128]
    yarn = np.sin(2 * np.pi * x / 4) * np.cos(2 * np.pi * y / 4)
    nap = (np.sin(2 * np.pi * (x + y) / 32) + np.cos(2 * np.pi * y / 64)) * 0.45
    rng = np.random.default_rng(1894)
    grain = rng.normal(0, 0.7, (128, 128))
    pixels = np.full((128, 128, 3), (185., 185., 185.))
    pixels += (1.8 * yarn + nap + grain)[..., None]
    return Image.fromarray(np.uint8(np.clip(pixels, 0, 255)))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    wallpaper_path = SOURCE / "psx/psx_wallpaper_stripe_128.png"
    wood_path = SOURCE / "weathered_brown_planks_diff.png"
    paper_path = SOURCE / "paper_worn_diff.png"
    wallpaper, wood, paper = [Image.open(p).convert("RGB") for p in (wallpaper_path, wood_path, paper_path)]
    cloth = cloth_source()
    recipes = [
        ("wallpaper", prepare(restrained(wallpaper, .70), tileable=True, reference=wallpaper), wallpaper_path),
        ("wood", prepare(restrained(wood, .65), tileable=True, reference=wood), wood_path),
        ("baize", prepare(cloth, tileable=True), None),
        ("paper", prepare(restrained(paper, .65), reference=paper), paper_path),
    ]
    records = []
    sheet = Image.new("RGB", (1024, 300), (28, 27, 25))
    draw = ImageDraw.Draw(sheet)
    for i, (name, image, source) in enumerate(recipes):
        path = OUT / f"{name}_128_v1.png"
        image.save(path)
        tile = Image.new("RGB", (384, 384))
        for ty in range(3):
            for tx in range(3):
                tile.paste(image, (tx * 128, ty * 128))
        tile.resize((768, 768), Image.Resampling.NEAREST).save(EVIDENCE / f"{name}_repeat.png")
        sheet.paste(image.resize((256, 256), Image.Resampling.NEAREST), (i * 256, 35))
        draw.text((i * 256 + 10, 12), name + " / actual game albedo", fill="white")
        records.append({"name": name, "source": str(source.relative_to(ROOT)) if source else "authored deterministic cloth_source()",
                        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest() if source else None,
                        "output": str(path.relative_to(ROOT)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                        "mean_rgb": mean_rgb(image).tolist(), "tileable": name != "paper"})
    sheet.save(EVIDENCE / "material_sheet.png")
    (EVIDENCE / "derived_manifest.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")
    print("Prepared four runtime albedos and 3x3 review sheets; originals unchanged")


if __name__ == "__main__":
    main()
