"""Build the FORM 19 multi-resolution Windows .ico, PNG assets, and variant contact sheet."""

from __future__ import annotations

import struct
from collections import deque
from io import BytesIO
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ARTIFACT_DIR = Path(
    r"C:\Users\YUSIF\.gemini\antigravity-cli\brain\92ca4bb6-f899-45ca-9721-4d5093bad9d9"
)

VARIANTS = [
    ("v1_seal", "1. Wax Seal & Brass 19 (Active)", "raw_v1_seal_1795397778540.jpg"),
    ("v2_key", "2. Telegraph Key & Tape", "raw_v2_key_1795397777664.jpg"),
    ("v3_nib", "3. Dip Nib & Crimson Ink 19", "raw_v3_nib_v2_1795397796952.jpg"),
]

ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]


def remove_white_background(img: Image.Image) -> Image.Image:
    """Flood-fill connected near-white background from borders and defringe edges."""
    rgba = np.array(img.convert("RGBA"), dtype=np.float32)
    h, w, _ = rgba.shape
    rgb = rgba[:, :, :3]
    lum = (rgb[:, :, 0] + rgb[:, :, 1] + rgb[:, :, 2]) / 3.0
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    bg_candidate = (lum > 234.0) & (sat < 22.0)

    visited = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bg_candidate[y, x] and not visited[y, x]:
                visited[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if bg_candidate[y, x] and not visited[y, x]:
                visited[y, x] = True
                q.append((y, x))

    while q:
        cy, cx = q.popleft()
        for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and bg_candidate[ny, nx]:
                visited[ny, nx] = True
                q.append((ny, nx))

    alpha = np.where(visited, 0.0, 255.0).astype(np.float32)

    # Soft 1px feather + white halo decontamination along the silhouette boundary.
    bg_mask_img = Image.fromarray(visited.astype(np.uint8) * 255, mode="L")
    dilated = np.array(bg_mask_img.filter(ImageFilter.MaxFilter(3))) > 0
    eroded = np.array(bg_mask_img.filter(ImageFilter.MinFilter(3))) > 0
    edge_band = dilated & (~visited)

    for y, x in np.argwhere(edge_band):
        patch_lum = lum[y, x]
        patch_sat = sat[y, x]
        if patch_lum > 210.0 and patch_sat < 36.0:
            t = np.clip((242.0 - patch_lum) / 48.0, 0.0, 1.0)
            alpha[y, x] = t * 255.0
            # Decontaminate white background bleed from RGB.
            if t > 0.05:
                rgb[y, x] = np.clip((rgb[y, x] - 255.0 * (1.0 - t)) / t, 0.0, 255.0)

    # Also knock out tiny stray isolated pure-white speckles touching border-dilated band.
    alpha[eroded] = 0.0
    out = np.dstack([np.clip(rgb, 0, 255), np.clip(alpha, 0, 255)]).astype(np.uint8)
    return Image.fromarray(out, mode="RGBA")


def center_and_pad(rgba: Image.Image, target_size: int = 1024, margin_frac: float = 0.055) -> Image.Image:
    """Crop tightly to non-transparent bounds and center inside square canvas."""
    arr = np.array(rgba)
    ys, xs = np.where(arr[:, :, 3] > 12)
    if len(xs) == 0 or len(ys) == 0:
        return rgba.resize((target_size, target_size), Image.Resampling.LANCZOS)
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    cropped = rgba.crop((x0, y0, x1, y1))

    avail = int(round(target_size * (1.0 - 2.0 * margin_frac)))
    cw, ch = cropped.size
    scale = min(avail / cw, avail / ch)
    nw = max(1, int(round(cw * scale)))
    nh = max(1, int(round(ch * scale)))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    canvas.paste(resized, ((target_size - nw) // 2, (target_size - nh) // 2), resized)
    return canvas


def resize_for_icon(master: Image.Image, size: int) -> Image.Image:
    """Downsample master cleanly with gentle sharpening on small taskbar sizes."""
    img = master.resize((size, size), Image.Resampling.LANCZOS)
    if size <= 48:
        img = img.filter(ImageFilter.UnsharpMask(radius=0.8, percent=95, threshold=2))
    return img


def write_ico(master: Image.Image, ico_path: Path) -> int:
    """Write a Windows Vista+ PNG-encoded multi-resolution RGBA .ico file."""
    frames: list[tuple[int, bytes]] = []
    for sz in ICO_SIZES:
        buf = BytesIO()
        resize_for_icon(master, sz).save(buf, format="PNG")
        frames.append((sz, buf.getvalue()))

    header = struct.pack("<HHH", 0, 1, len(frames))
    offset = 6 + 16 * len(frames)
    entries = bytearray()
    payload = bytearray()
    for sz, png_bytes in frames:
        dim = 0 if sz >= 256 else sz
        entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(png_bytes), offset)
        payload += png_bytes
        offset += len(png_bytes)

    ico_path.write_bytes(header + entries + payload)
    return len(header) + len(entries) + len(payload)


def build_contact_sheet(processed: list[tuple[str, str, Image.Image]], out_path: Path) -> None:
    """Render side-by-side comparison of all 3 variants at 256/64/32/16 on dark & light."""
    w, h = 1140, 740
    sheet = Image.new("RGBA", (w, h), (22, 20, 18, 255))
    draw = ImageDraw.Draw(sheet)

    col_w = w // 3
    for idx, (_key, title, master) in enumerate(processed):
        cx = idx * col_w + col_w // 2
        draw.text((idx * col_w + 26, 18), title, fill=(235, 220, 185, 255))

        # 256px preview on dark taskbar slate
        dark_card = (idx * col_w + 26, 48, idx * col_w + col_w - 26, 360)
        draw.rounded_rectangle(dark_card, radius=10, fill=(24, 24, 26, 255), outline=(72, 60, 44, 255))
        p256 = resize_for_icon(master, 256)
        sheet.paste(p256, (cx - 128, 76), p256)

        # Small taskbar sizes row on dark (#181818)
        y_dark = 384
        draw.rounded_rectangle((idx * col_w + 26, y_dark, idx * col_w + col_w - 26, y_dark + 110), radius=8, fill=(24, 24, 24, 255))
        x_cur = idx * col_w + 54
        for sz in (64, 32, 16):
            im = resize_for_icon(master, sz)
            sheet.paste(im, (x_cur, y_dark + (110 - sz) // 2), im)
            draw.text((x_cur, y_dark + 88), f"{sz}", fill=(175, 165, 145, 255))
            x_cur += sz + 44

        # Small desktop sizes row on warm light paper (#E6E2D8)
        y_light = 516
        draw.rounded_rectangle((idx * col_w + 26, y_light, idx * col_w + col_w - 26, y_light + 110), radius=8, fill=(230, 226, 216, 255))
        x_cur = idx * col_w + 54
        for sz in (64, 32, 16):
            im = resize_for_icon(master, sz)
            sheet.paste(im, (x_cur, y_light + (110 - sz) // 2), im)
            draw.text((x_cur, y_light + 88), f"{sz}", fill=(60, 52, 42, 255))
            x_cur += sz + 44

        draw.text((idx * col_w + 30, 650), "Dark taskbar (#181818) & Light (#E6E2D8)", fill=(160, 148, 126, 255))

    sheet.save(out_path)


def main() -> None:
    variant_dir = ROOT / ".dream-loop" / "icon_variants"
    variant_dir.mkdir(parents=True, exist_ok=True)
    branding_dir = ROOT / "assets" / "branding"
    branding_dir.mkdir(parents=True, exist_ok=True)
    icon_preview_dir = ROOT / ".dream-loop" / "icon"
    icon_preview_dir.mkdir(parents=True, exist_ok=True)

    processed: list[tuple[str, str, Image.Image]] = []
    for key, title, filename in VARIANTS:
        src = ARTIFACT_DIR / filename
        raw = Image.open(src)
        clean = center_and_pad(remove_white_background(raw), 1024)
        clean.save(variant_dir / f"{key}.png")
        processed.append((key, title, clean))

    build_contact_sheet(processed, variant_dir / "contact_sheet.png")

    # Install Variant 1 (Wax Seal & Brass 19) as active master + project icon.
    primary_master = processed[0][2]
    primary_master.save(branding_dir / "form19_icon_master.png")
    resize_for_icon(primary_master, 256).save(ROOT / "icon.png")
    resize_for_icon(primary_master, 256).save(icon_preview_dir / "icon_256.png")
    resize_for_icon(primary_master, 32).save(icon_preview_dir / "icon_32.png")
    ico_size = write_ico(primary_master, ROOT / "icon.ico")
    print(f"FORM 19 icon built: {len(ICO_SIZES)} ICO frames ({ico_size} bytes)")


if __name__ == "__main__":
    main()
