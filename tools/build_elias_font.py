#!/usr/bin/env python3
"""Build Elias's deterministic authored working hand.
The source of truth is the small vector stroke table below. This deliberately
avoids a host font: each glyph is an editable SVG and is rasterized into the
atlas by the same deterministic stroke renderer that writes the BMFont metrics.
The authored forms use a moderate fixed rightward pen angle, not runtime jitter.
"""
from __future__ import annotations
import math, re, struct, zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "fonts" / "elias_working"
GLYPHS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?;:'-/()"
CELL_W, CELL_H = 64, 80
ATLAS_PADDING = 4
LINE_HEIGHT = 80
COLS = 16
ROWS = math.ceil(len(GLYPHS) / COLS)
ATLAS_W, ATLAS_H = CELL_W * COLS, CELL_H * ROWS
INK = (255, 255, 255, 255)
HAND_LEAN = 0.11

# Coordinates are intentionally quick, open pen strokes.  A fixed per-glyph
# skew and a few asymmetric joins make this a hand, not a perfect geometric UI
# face; there is no runtime jitter or context-dependent substitution.
S = {
    "A": [[(7,54),(22,9),(39,54)],[(13,37),(32,37)]],
    "B": [[(9,9),(9,54),(28,54),(37,48),(37,39),(28,33),(10,33)],[(28,33),(37,25),(36,15),(28,9),(9,9)]],
    "C": [[(38,13),(31,9),(17,10),(9,19),(8,43),(17,53),(31,54),(38,49)]],
    "D": [[(9,9),(9,54),(27,54),(38,44),(38,19),(27,9),(9,9)]],
    "E": [[(37,9),(9,9),(9,54),(38,54)],[(9,32),(30,32)]],
    "F": [[(37,9),(9,9),(9,54)],[(9,32),(30,32)]],
    "G": [[(38,15),(32,9),(17,10),(9,20),(9,44),(18,54),(34,52),(39,44),(39,35),(25,35)]],
    "H": [[(9,9),(9,54)],[(38,9),(38,54)],[(10,33),(37,32)]],
    "I": [[(10,9),(38,9)],[(24,9),(22,54)],[(10,54),(37,54)]],
    "J": [[(37,9),(37,45),(31,54),(18,54),(9,47),(9,40)]],
    "K": [[(10,9),(9,54)],[(38,9),(10,32),(39,54)]],
    "L": [[(10,9),(9,54),(38,54)]],
    "M": [[(8,54),(10,9),(24,35),(38,9),(39,54)]],
    "N": [[(9,54),(10,9),(38,54),(38,9)]],
    "O": [[(18,9),(31,10),(38,20),(38,43),(30,54),(17,53),(9,43),(9,20),(18,9)]],
    "P": [[(9,54),(9,9),(28,9),(37,16),(37,26),(28,33),(9,33)]],
    "Q": [[(18,9),(31,10),(38,20),(38,43),(30,54),(17,53),(9,43),(9,20),(18,9)],[(27,43),(40,57)]],
    "R": [[(9,54),(9,9),(28,9),(37,16),(37,26),(28,33),(9,33)],[(27,33),(40,54)]],
    "S": [[(37,13),(29,9),(17,10),(9,18),(11,29),(29,35),(37,42),(34,51),(24,54),(12,50)]],
    "T": [[(8,9),(39,9)],[(24,9),(22,54)]],
    "U": [[(9,9),(9,43),(17,53),(30,54),(38,44),(38,9)]],
    "V": [[(8,9),(22,54),(39,9)]],
    "W": [[(7,9),(14,54),(24,28),(32,54),(40,9)]],
    "X": [[(9,9),(39,54)],[(38,9),(8,54)]],
    "Y": [[(8,9),(23,31),(39,9)],[(23,31),(22,54)]],
    "Z": [[(9,9),(39,9),(9,54),(39,54)]],
    "0": [[(18,9),(31,10),(38,20),(38,43),(30,54),(17,53),(9,43),(9,20),(18,9)],[(11,20),(35,44)]],
    "1": [[(13,19),(23,9),(23,54)],[(12,54),(35,54)]],
    "2": [[(11,18),(18,10),(30,10),(38,18),(36,28),(10,54),(39,54)]],
    "3": [[(10,14),(19,9),(31,10),(38,18),(32,30),(23,31)],[(32,30),(39,38),(35,50),(24,54),(11,50)]],
    "4": [[(31,9),(10,39),(39,39)],[(31,9),(31,54)]],
    "5": [[(37,10),(12,10),(10,31),(26,29),(36,35),(38,45),(30,53),(17,54),(9,47)]],
    "6": [[(36,12),(25,9),(14,16),(9,31),(11,46),(21,54),(33,50),(38,41),(34,32),(23,29),(10,34)]],
    "7": [[(9,10),(39,10),(21,54)]],
    "8": [[(20,9),(32,11),(36,20),(30,30),(17,33),(10,26),(11,16),(20,9)],[(17,33),(31,34),(38,42),(33,52),(21,54),(10,48),(10,39),(17,33)]],
    "9": [[(36,31),(28,34),(16,30),(10,21),(15,11),(27,9),(37,17),(38,33),(32,48),(22,54)]],
    ".": [[(18,53),(19,54)]],
    ",": [[(19,52),(18,61),(13,63)]],
    "!": [[(20,9),(19,42)],[(19,53),(20,54)]],
    "?": [[(10,17),(17,10),(30,10),(38,18),(37,27),(24,35),(23,43)],[(23,53),(24,54)]],
    ";": [[(20,33),(21,34)],[(20,53),(19,61),(14,63)]],
    ":": [[(20,27),(21,28)],[(20,53),(21,54)]],
    "'": [[(19,9),(18,20)]],
    "-": [[(11,32),(36,32)]],
    "/": [[(38,8),(10,55)]],
    "(": [[(30,9),(21,18),(17,32),(21,47),(30,55)]],
    ")": [[(18,9),(27,18),(31,32),(27,47),(18,55)]],
}

def esc(s: str) -> str:
    return {"&":"&amp;", "<":"&lt;", ">":"&gt;", "\"":"&quot;"}.get(s, s)

def points_for(ch: str):
    irregularity = ((ord(ch) * 7) % 5 - 2) * 0.35
    result = []
    for stroke in S.get(ch, []):
        points = []
        for x, y in stroke:
            shear = HAND_LEAN * (54.0 - y)
            points.append((x + shear + irregularity * (y / 64.0), y))
        result.append(points)
    return result

def svg_for(ch: str) -> str:
    strokes = points_for(ch)
    body=[]
    for pts in strokes:
        d=" ".join(("M" if i==0 else "L") + f" {x:.2f},{y:.2f}" for i,(x,y) in enumerate(pts))
        body.append(f'<path d="{d}"/>')
    title = "space" if ch == " " else ch
    return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + f'<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{CELL_W}\" height=\"{CELL_H}\" viewBox=\"0 0 {CELL_W} {CELL_H}\"><title>{esc(title)}</title><g fill=\"none\" stroke=\"#261d15\" stroke-width=\"2.7\" stroke-linecap=\"round\" stroke-linejoin=\"round\">' + ''.join(body) + '</g></svg>\n'

def read_svg_strokes(path):
    text = path.read_text(encoding="utf-8")
    strokes = []
    for match in re.finditer(r'<path[^>]*\bd="([^"]+)"', text):
        tokens = re.findall(r'[MLml]|-?\d+(?:\.\d+)?', match.group(1))
        points = []
        i = 0
        while i + 2 < len(tokens):
            if tokens[i].upper() in ("M", "L"):
                points.append((float(tokens[i + 1]), float(tokens[i + 2])))
                i += 3
            else:
                i += 1
        if points:
            strokes.append(points)
    return strokes

def stroke_bounds(strokes):
    points = [point for stroke in strokes for point in stroke]
    if not points:
        return 0.0, 0.0, 0.0, 0.0
    return min(p[0] for p in points), min(p[1] for p in points), max(p[0] for p in points), max(p[1] for p in points)
def put_pixel(buf, x, y, rgba=INK):
    if 0 <= x < ATLAS_W and 0 <= y < ATLAS_H:
        i=(y*ATLAS_W+x)*4
        # opaque authored ink over transparent atlas
        buf[i:i+4]=bytes(rgba)

def draw_disc(buf, x, y, r=1.6):
    rr=r*r
    for yy in range(max(0,int(y-r-1)), min(ATLAS_H,int(y+r+2))):
        for xx in range(max(0,int(x-r-1)), min(ATLAS_W,int(x+r+2))):
            if (xx-x)**2+(yy-y)**2 <= rr:
                put_pixel(buf,xx,yy)

def draw_line(buf, x0,y0,x1,y1,width=2.7):
    steps=max(1,int(max(abs(x1-x0),abs(y1-y0))*2))
    for n in range(steps+1):
        t=n/steps
        draw_disc(buf,x0+(x1-x0)*t,y0+(y1-y0)*t,width/2)

def png_bytes(buf):
    raw=b''.join(b'\x00'+bytes(buf[y*ATLAS_W*4:(y+1)*ATLAS_W*4]) for y in range(ATLAS_H))
    def chunk(tag,data):
        return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',ATLAS_W,ATLAS_H,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for ch in GLYPHS:
        name = "space" if ch == " " else f"u{ord(ch):04X}"
        source = OUT / f"glyph_{name}.svg"
        if not source.exists():
            source.write_text(svg_for(ch), encoding="utf-8")
    buf = bytearray(ATLAS_W * ATLAS_H * 4)
    chars = []
    for i, ch in enumerate(GLYPHS):
        source = OUT / ("glyph_space.svg" if ch == " " else f"glyph_u{ord(ch):04X}.svg")
        strokes = read_svg_strokes(source)
        min_x, min_y, max_x, max_y = stroke_bounds(strokes)
        width = max(1, int(math.ceil(max_x - min_x + 4))) if strokes else 1
        height = max(1, int(math.ceil(max_y - min_y + 4))) if strokes else 1
        advance = 14 if ch == " " else max(18, int(math.ceil(max_x - min_x + 8)))
        atlas_x = (i % COLS) * CELL_W + ATLAS_PADDING
        atlas_y = (i // COLS) * CELL_H + ATLAS_PADDING
        for stroke in strokes:
            shifted = [(x - min_x + atlas_x + 2, y - min_y + atlas_y + 2) for x, y in stroke]
            for a, b in zip(shifted, shifted[1:]):
                draw_line(buf, a[0], a[1], b[0], b[1])
        chars.append((ch, atlas_x, atlas_y, width, height, int(math.floor(min_x - 2)) if strokes else 0, int(math.floor(min_y - 2)) if strokes else 0, advance))
    (OUT / "elias_working_atlas.png").write_bytes(png_bytes(buf))
    lines = [f'info face="Elias Working" size=48 bold=0 italic=0 charset="{GLYPHS}" unicode=1 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1', f"common lineHeight={LINE_HEIGHT} base=54 scaleW={ATLAS_W} scaleH={ATLAS_H} pages=1 packed=0", 'page id=0 file="elias_working_atlas.png"', f"chars count={len(chars)}"]
    for ch, x, y, width, height, xoffset, yoffset, advance in chars:
        lines.append(f"char id={ord(ch)} x={x} y={y} width={width} height={height} xoffset={xoffset} yoffset={yoffset} xadvance={advance} page=0 chnl=15")
    (OUT / "elias_working.fnt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (OUT / "README.md").write_text("# Elias Working\n\nSVG files are the editable glyph sources. The builder only creates a missing source, then consumes every SVG to produce the white-alpha atlas and measured BMFont metrics.\n", encoding="utf-8")
    print(f"generated {len(chars)} glyphs, {ATLAS_W}x{ATLAS_H} atlas at {OUT}")
if __name__=='__main__': main()
