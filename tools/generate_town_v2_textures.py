"""Prepare original CC0 Poly Haven 1K surfaces for the town's PSX material kit."""
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess

from PIL import Image, ImageChops, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/textures/town_v2'
CACHE = ROOT / '.dream-loop/town_cc0_cache'
SOURCES = {
    'plank': ('weathered_brown_planks', 256, .78, .88, .12),
    'roof': ('roof_slates_02', 512, .64, .88, .18),
    'brick': ('red_brick', 256, .81, .90, .15),
    'stone': ('old_stone_wall_02', 256, .69, .91, .16),
    # 1890 Black Creek is a spring-thawed clay street, not a beach: lift the
    # Poly Haven mud out of its grey and warm it toward Colorado red clay.
    'road': ('brown_mud_02', 512, 1.30, .84, .22),
    'mahogany': ('wood_cabinet_worn_long', 256, .83, .44, .21),
    'plaster': ('worn_plaster_wall', 256, .68, .92, .12),
    'iron': ('rusty_metal_02', 256, .79, .65, .30),
    # Rut silt, trampled to a slick skin, and boiler slag spread as track ballast.
    'clay': ('brown_mud_03', 256, 1.10, .72, .18),
    'slag': ('burned_ground_01', 256, .34, .86, 1.6),
}

# PSX-era tint per surface: the shader grades on top of these, so keep them neutral
# except where the source's own hue is wrong for 1890 Colorado.
TINTS = {
    'road': (1.30, 1.06, .88),
    'clay': (1.06, .94, .82),
    'slag': (1.0, 1.0, 1.0),
}


def cached(url, path):
    if not path.is_file():
        tmp = path.with_suffix('.tmp')
        tmp.write_bytes(subprocess.check_output(['curl.exe' if os.name == 'nt' else 'curl',
                                                '-fsSL', '--retry', '2', '--max-time', '35', url]))
        tmp.replace(path)
    return path


def bake(item):
    stem, (slug, size, saturation, rough, contrast) = item
    meta = json.loads(cached('https://api.polyhaven.com/files/'+slug, CACHE/(slug+'.json')).read_text())
    for source, target in [('Diffuse', 'albedo'), ('nor_gl', 'normal'), ('Rough', 'roughness')]:
        record = meta[source]['1k']
        spec = record.get('jpg') or record.get('png') or next(iter(record.values()))
        file = cached(spec['url'], CACHE/(slug+'_'+source+'.img'))
        im = Image.open(file).convert('L' if target == 'roughness' else 'RGB')
        im = im.filter(ImageFilter.GaussianBlur(.7)).resize((size, size), Image.Resampling.LANCZOS)
        if target == 'albedo':
            im = ImageEnhance.Color(im).enhance(saturation)
            tint = TINTS.get(stem)
            if tint:
                # Channel gains keep the source detail while moving the hue to the
                # street's own palette; quantising stays after the tint so the
                # posterised PSX banding survives.
                gain = Image.new('RGB', im.size, tuple(int(round(255 * g)) for g in tint))
                im = ImageChops.multiply(im, gain)
            im = im.point(lambda v: min(255, round(v / 4) * 4))
        elif target == 'normal':
            im = Image.blend(Image.new('RGB', im.size, (128, 128, 255)), im, .67)
        else:
            im = im.point(lambda v: min(255, round(255*rough + (v-128)*contrast)))
        im.save(OUT/f'{stem}_{target}.png', optimize=True)
    print(stem, slug, size, flush=True)


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=8) as workers:
        list(workers.map(bake, SOURCES.items()))
