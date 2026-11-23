"""Deterministic 1890 Colorado PSX texture generator for Black Creek M2-A."""

from pathlib import Path
import struct
import zlib
import numpy as np


OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "textures" / "town_v1"
RNG = np.random.default_rng(1890)


def _png_chunk(tag: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)


def save_rgb(name: str, arr: np.ndarray) -> None:
    arr_u8 = np.clip(arr, 0, 255).astype(np.uint8)
    h, w, _ = arr_u8.shape
    raw = b"".join(b"\x00" + arr_u8[y].tobytes() for y in range(h))
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + _png_chunk(b"IHDR", ihdr) + _png_chunk(b"IDAT", zlib.compress(raw, 9)) + _png_chunk(b"IEND", b"")
    (OUT_DIR / name).write_bytes(png)


def make_noise(h: int, w: int, scale: float = 1.0) -> np.ndarray:
    return (RNG.random((h, w)) - 0.5) * 2.0 * scale


def make_batten(size: int, base: tuple[int, int, int], batten_w: int = 2, step: int = 16) -> np.ndarray:
    img = np.full((size, size, 3), base, dtype=np.float32)
    # Vertical wood grain
    col_var = make_noise(1, size, 9.0)
    grain = make_noise(size, size, 6.0)
    img += col_var[:, :, None] + grain[:, :, None]
    for x in range(0, size, step):
        img[:, x : min(x + 1, size)] -= 24.0
        img[:, min(x + 1, size - 1) : min(x + 1 + batten_w, size)] += 10.0
        img[:, min(x + 1 + batten_w, size - 1) : min(x + 2 + batten_w, size)] -= 16.0
    return img


def make_clapboard(size: int, base: tuple[int, int, int], step: int = 12) -> np.ndarray:
    img = np.full((size, size, 3), base, dtype=np.float32)
    row_var = make_noise(size, 1, 5.0)
    grain = make_noise(size, size, 5.5)
    img += row_var[:, :, None] + grain[:, :, None]
    for y in range(0, size, step):
        for dy in range(step):
            yy = (y + dy) % size
            shade = (dy / float(step) - 0.5) * 14.0
            img[yy, :] += shade
        img[y, :] -= 26.0
        if y + 1 < size:
            img[y + 1, :] += 11.0
    return img


def make_planks(size: int, base: tuple[int, int, int], plank_h: int = 16) -> np.ndarray:
    img = np.full((size, size, 3), base, dtype=np.float32)
    grain = make_noise(size, size, 7.0)
    img += grain[:, :, None]
    for idx, y in enumerate(range(0, size, plank_h)):
        tone = float((RNG.random() - 0.5) * 20.0)
        img[y : y + plank_h, :] += tone
        img[y, :] -= 30.0
        if y + 1 < size:
            img[y + 1, :] += 8.0
        seam_x = (idx * 47 + 19) % size
        img[y : y + plank_h, seam_x] -= 26.0
        # Nail dots
        for nx in [(seam_x + 4) % size, (seam_x - 4) % size]:
            for ny in [y + 4, y + plank_h - 4]:
                if ny < size:
                    img[ny, nx] -= 28.0
    return img


def make_brick(size: int) -> np.ndarray:
    img = np.full((size, size, 3), (124, 61, 50), dtype=np.float32)
    mortar = np.array([154, 146, 134], dtype=np.float32)
    bh, bw = 8, 16
    for row, y in enumerate(range(0, size, bh)):
        off = (bw // 2) if (row % 2 == 1) else 0
        for x in range(-bw, size + bw, bw):
            bx = x + off
            tone = float((RNG.random() - 0.5) * 24.0)
            x0, x1 = max(0, bx + 1), min(size, bx + bw)
            y0, y1 = max(0, y + 1), min(size, y + bh)
            if x1 > x0 and y1 > y0:
                img[y0:y1, x0:x1] += tone + make_noise(y1 - y0, x1 - x0, 6.0)[:, :, None]
        img[y, :] = mortar
    for row, y in enumerate(range(0, size, bh)):
        off = (bw // 2) if (row % 2 == 1) else 0
        for x in range(0, size, bw):
            vx = (x + off) % size
            img[y : min(size, y + bh), vx] = mortar
    return img


def make_stone(size: int) -> np.ndarray:
    img = np.full((size, size, 3), (104, 102, 96), dtype=np.float32)
    img += make_noise(size, size, 12.0)[:, :, None]
    for y in range(0, size, 16):
        img[y, :] -= 22.0
        off = 12 if (y // 16) % 2 else 0
        for x in range(0, size, 24):
            vx = (x + off) % size
            img[y : min(size, y + 16), vx] -= 20.0
            tone = float((RNG.random() - 0.5) * 18.0)
            x1 = min(size, vx + 23)
            img[y + 1 : min(size, y + 16), vx + 1 : x1] += tone
    return img


def make_mud_road(size: int) -> np.ndarray:
    img = np.full((size, size, 3), (96, 76, 56), dtype=np.float32)
    img += make_noise(size, size, 10.0)[:, :, None]
    # Longitudinal spring wagon ruts
    xs = np.arange(size, dtype=np.float32)
    rut_mask = (
        np.exp(-((xs - size * 0.30) ** 2) / 90.0)
        + np.exp(-((xs - size * 0.42) ** 2) / 90.0)
        + np.exp(-((xs - size * 0.58) ** 2) / 90.0)
        + np.exp(-((xs - size * 0.70) ** 2) / 90.0)
    )
    img -= rut_mask[None, :, None] * np.array([18.0, 15.0, 11.0])
    # Damp sheen & pebbles
    for _ in range(180):
        px, py = int(RNG.integers(0, size)), int(RNG.integers(0, size))
        delta = 18.0 if RNG.random() > 0.5 else -18.0
        img[py, px] += delta
    return img


def make_shingles(size: int) -> np.ndarray:
    img = np.full((size, size, 3), (74, 65, 57), dtype=np.float32)
    for row, y in enumerate(range(0, size, 12)):
        off = 6 if row % 2 else 0
        for x in range(0, size, 12):
            vx = (x + off) % size
            tone = float((RNG.random() - 0.5) * 16.0)
            img[y : min(size, y + 12), vx : min(size, vx + 11)] += tone
            img[y : min(size, y + 12), vx] -= 18.0
        img[y, :] -= 22.0
    return img


def make_grass_thaw(size: int) -> np.ndarray:
    img = np.full((size, size, 3), (94, 96, 62), dtype=np.float32)
    img += make_noise(size, size, 14.0)[:, :, None]
    for _ in range(220):
        px, py = int(RNG.integers(0, size)), int(RNG.integers(0, size))
        if RNG.random() > 0.45:
            img[py, px] = np.array([112, 98, 66]) + make_noise(1, 1, 8.0)[0, 0]
        else:
            img[py, px] = np.array([76, 86, 52])
    return img


def make_wallpaper(size: int) -> np.ndarray:
    img = np.full((size, size, 3), (124, 130, 108), dtype=np.float32)
    for x in range(0, size, 16):
        img[:, x : x + 3] = np.array([142, 144, 118])
        img[:, x + 8] = np.array([104, 110, 90])
        for y in range(4, size, 16):
            img[y : y + 3, x + 7 : x + 10] = np.array([154, 146, 108])
            img[y + 1, x + 8] = np.array([118, 86, 74])
    img += make_noise(size, size, 4.0)[:, :, None]
    return img


def make_patchwork(size: int) -> np.ndarray:
    palette = [
        (114, 54, 48),
        (56, 72, 94),
        (164, 142, 96),
        (82, 96, 72),
        (178, 168, 146),
        (134, 86, 52),
    ]
    img = np.zeros((size, size, 3), dtype=np.float32)
    bs = 16
    for gy in range(0, size, bs):
        for gx in range(0, size, bs):
            col = palette[((gx // bs) * 3 + (gy // bs) * 5) % len(palette)]
            img[gy : gy + bs, gx : gx + bs] = col
            img[gy, gx : gx + bs] = np.array(col) * 0.72
            img[gy : gy + bs, gx] = np.array(col) * 0.72
    img += make_noise(size, size, 5.0)[:, :, None]
    return img


def make_rag_rug(size: int) -> np.ndarray:
    stripes = [
        (126, 62, 54),
        (172, 156, 128),
        (72, 86, 98),
        (148, 118, 66),
        (88, 96, 72),
    ]
    img = np.zeros((size, size, 3), dtype=np.float32)
    for idx, y in enumerate(range(0, size, 4)):
        col = stripes[idx % len(stripes)]
        img[y : y + 4, :] = col
    img += make_noise(size, size, 9.0)[:, :, None]
    return img


def make_creek(size: int) -> np.ndarray:
    img = np.full((size, size, 3), (78, 114, 132), dtype=np.float32)
    for y in range(size):
        wave = np.sin(y * 0.35 + np.arange(size) * 0.22) * 14.0
        img[y, :, 0] += wave
        img[y, :, 1] += wave * 1.1
        img[y, :, 2] += wave * 1.25
    img += make_noise(size, size, 8.0)[:, :, None]
    return img


def make_window(size: int, lit: bool) -> np.ndarray:
    pane_col = np.array([218, 174, 96], dtype=np.float32) if lit else np.array([76, 98, 118], dtype=np.float32)
    mullion = np.array([204, 194, 174], dtype=np.float32)
    img = np.full((size, size, 3), pane_col, dtype=np.float32)
    if lit:
        yy, xx = np.mgrid[0:size, 0:size]
        dist = np.sqrt(((xx - size * 0.5) / size) ** 2 + ((yy - size * 0.5) / size) ** 2)
        img *= (1.12 - dist * 0.45)[:, :, None]
    else:
        img += make_noise(size, size, 4.0)[:, :, None]
        for i in range(size):
            if 6 <= i < size - 6:
                img[i, min(size - 1, i // 2 + 12)] += 16.0
    m = 4
    img[:m, :] = mullion
    img[-m:, :] = mullion
    img[:, :m] = mullion
    img[:, -m:] = mullion
    mid = size // 2
    img[mid - 2 : mid + 2, :] = mullion
    img[:, mid - 1 : mid + 1] = mullion
    return img


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    save_rgb("depot_ochre_batten_128.png", make_batten(128, (150, 112, 62)))
    save_rgb("oxide_red_trim_64.png", make_batten(64, (96, 44, 36), 1, 16))
    save_rgb("mud_road_ruts_256.png", make_mud_road(256))
    save_rgb("boardwalk_planks_128.png", make_planks(128, (138, 118, 92)))
    save_rgb("saloon_oxblood_siding_128.png", make_clapboard(128, (112, 46, 42)))
    save_rgb("mercantile_mustard_siding_128.png", make_clapboard(128, (168, 130, 66)))
    save_rgb("company_brick_128.png", make_brick(128))
    save_rgb("boarding_sage_clapboard_128.png", make_clapboard(128, (110, 124, 114)))
    save_rgb("clinic_slate_clapboard_128.png", make_clapboard(128, (76, 94, 108)))
    save_rgb("weathered_pine_128.png", make_batten(128, (118, 114, 104), 1, 16))
    save_rgb("wood_shingles_128.png", make_shingles(128))
    save_rgb("stone_foundation_128.png", make_stone(128))
    save_rgb("grass_spring_thaw_128.png", make_grass_thaw(128))
    save_rgb("pine_needles_64.png", make_grass_thaw(64) * np.array([0.44, 0.62, 0.48]))
    save_rgb("boarding_wallpaper_128.png", make_wallpaper(128))
    save_rgb("patchwork_quilt_128.png", make_patchwork(128))
    save_rgb("rag_rug_128.png", make_rag_rug(128))
    save_rgb("creek_water_128.png", make_creek(128))
    save_rgb("window_panes_day_64.png", make_window(64, False))
    save_rgb("window_panes_lit_64.png", make_window(64, True))
    print(f"Generated {len(list(OUT_DIR.glob('*.png')))} PSX town textures in {OUT_DIR}")


if __name__ == "__main__":
    main()
