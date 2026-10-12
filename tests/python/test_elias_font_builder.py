import importlib.util
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools" / "build_elias_font.py"
OUT = ROOT / "assets" / "fonts" / "elias_working"
GLYPHS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?;:'-/()"
spec = importlib.util.spec_from_file_location("build_elias_font", SOURCE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class EliasFontBuilderTests(unittest.TestCase):
    def test_sources_are_complete_and_preserved_as_inputs(self):
        self.assertEqual(len(GLYPHS), 48)
        source = SOURCE.read_text(encoding="utf-8")
        self.assertIn("if not source.exists()", source)
        self.assertNotIn("unlink()", source)
        for char in GLYPHS:
            name = "space" if char == " " else f"u{ord(char):04X}"
            path = OUT / f"glyph_{name}.svg"
            self.assertTrue(path.exists(), f"missing SVG source for {char!r}")
            if char != " ":
                self.assertTrue(module.read_svg_strokes(path), f"empty vector for {char!r}")

    def test_slant_is_fixed_rightward_and_per_glyph_strokes_are_authored(self):
        for char in "ABCDG":
            path = OUT / f"glyph_u{ord(char):04X}.svg"
            strokes = module.read_svg_strokes(path)
            self.assertTrue(strokes)
        points = module.points_for("A")
        self.assertTrue(any(x > 22 for x, y in points[0] if y < 20))
        self.assertEqual(module.points_for("A"), module.points_for("A"))

    def test_metrics_measure_actual_vectors_and_keep_overhangs(self):
        text = (OUT / "elias_working.fnt").read_text(encoding="utf-8")
        self.assertIn("lineHeight=80", text)
        rows = {int(re.search(r"char id=(\d+)", line).group(1)): dict(re.findall(r"(\w+)=([^ ]+)", line))
                for line in text.splitlines() if line.startswith("char id=")}
        self.assertEqual(set(rows), {ord(char) for char in GLYPHS})
        for char in GLYPHS:
            metrics = rows[ord(char)]
            source = OUT / ("glyph_space.svg" if char == " " else f"glyph_u{ord(char):04X}.svg")
            bounds = module.stroke_bounds(module.read_svg_strokes(source))
            if char != " ":
                self.assertGreaterEqual(int(metrics["width"]), int(bounds[2] - bounds[0]) + 3, char)
                self.assertGreaterEqual(int(metrics["height"]), int(bounds[3] - bounds[1]) + 3, char)
            self.assertLessEqual(int(metrics["x"]) + int(metrics["width"]), module.ATLAS_W)
            self.assertLessEqual(int(metrics["y"]) + int(metrics["height"]), module.ATLAS_H)
            self.assertLessEqual(int(metrics["width"]), module.CELL_W - 2 * module.ATLAS_PADDING)
            self.assertLessEqual(int(metrics["height"]), module.CELL_H - 2 * module.ATLAS_PADDING)
            self.assertGreaterEqual(int(metrics["xadvance"]), int(metrics["width"]))

    def test_raised_punctuation_is_within_its_own_measured_height(self):
        text = (OUT / "elias_working.fnt").read_text(encoding="utf-8")
        comma = next(line for line in text.splitlines() if line.startswith(f"char id={ord(',')} "))
        metrics = dict(re.findall(r"(\w+)=([^ ]+)", comma))
        self.assertGreaterEqual(int(metrics["height"]), 12)
        self.assertGreater(int(metrics["yoffset"]), 0)

    def test_atlas_is_white_alpha_mask_and_problem_glyph_ink_is_present(self):
        data = (OUT / "elias_working_atlas.png").read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(module.INK, (255, 255, 255, 255))
        self.assertEqual((module.ATLAS_W, module.ATLAS_H), (1024, 240))
        self.assertIn(b"IDAT", data)
        rgba = __import__("zlib").decompress(data[data.index(b"IDAT") + 4:-12])
        self.assertIn(bytes((255, 255, 255, 255)), rgba)
        self.assertIn(bytes((0, 0, 0, 0)), rgba)

if __name__ == "__main__":
    unittest.main()
