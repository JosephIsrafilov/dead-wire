"""Calibrate the deliberately strict transverse-crossing diagnostic."""
import unittest
from hand_skin_crossings import crossings


class SkinCrossingsTest(unittest.TestCase):
    def data(self, second):
        return {"vertices": [[-1., -1., 0.], [1., -1., 0.], [0., 1., 0.]] + second,
                "faces": [[0, 1, 2], [3, 4, 5]]}

    def test_detects_transverse_crossing(self):
        data = self.data([[.1, -.5, -1.], [.1, -.5, 1.], [.1, .5, 1.]])
        self.assertEqual(crossings(data), [(0, 1)])
        data["faces"].reverse()
        self.assertEqual(crossings(data), [(0, 1)])

    def test_rejects_separated_triangles(self):
        self.assertEqual(crossings(self.data([[3., 0., -1.], [3., 0., 1.], [3., 1., 1.]])), [])

    def test_coplanar_overlap_is_outside_scope(self):
        self.assertEqual(crossings(self.data([[-.5, -.5, 0.], [.5, -.5, 0.], [0., .5, 0.]])), [])

    def test_shared_vertex_pairs_are_excluded(self):
        data = self.data([[.1, -.5, -1.], [.1, -.5, 1.], [.1, .5, 1.]])
        data["faces"][1][0] = 0
        self.assertEqual(crossings(data), [])


if __name__ == "__main__":
    unittest.main()
