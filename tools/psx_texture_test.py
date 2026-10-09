"""Run with the project tooling Python: python tools/psx_texture_test.py."""
import unittest
import numpy as np
from PIL import Image
from psx_texture import LEVELS, prepare


class TexturePreparationTest(unittest.TestCase):
    def test_size_palette_and_repeatability(self):
        # A fixture, never shipped as replacement art.
        rng = np.random.default_rng(1894)
        source = Image.fromarray(rng.integers(0, 256, (1024, 1024, 3), dtype=np.uint8))
        result = prepare(source)
        self.assertEqual(result.size, (128, 128))
        self.assertTrue(np.isin(np.asarray(result), LEVELS).all())
        self.assertEqual(result.tobytes(), prepare(source).tobytes())

    def test_tile_boundaries(self):
        pixels = np.zeros((1024, 1024, 3), dtype=np.uint8)
        pixels[:512] = (90, 120, 140)
        pixels[:, :512] += 50
        result = np.asarray(prepare(Image.fromarray(pixels), tileable=True))
        np.testing.assert_array_equal(result[0], result[-1])
        np.testing.assert_array_equal(result[:, 0], result[:, -1])

    def test_mean_matching_within_quantization(self):
        result = prepare(Image.new("RGB", (1024, 1024), (220, 200, 140)),
                         reference=Image.new("RGB", (16, 16), (90, 80, 58)))
        np.testing.assert_allclose(np.asarray(result).mean(axis=(0, 1)), (90, 80, 58), atol=4.2)


if __name__ == "__main__":
    unittest.main()
