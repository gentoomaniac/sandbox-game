"""Tests of the art of the footprints (footprints.py; `make test` runs them): four prints, a left
and a right foot in snow and in mud, mirrors of each other, clear around and in both art sets."""

import unittest

import footprints

TILES = (32, 16)


def pressed_columns(cell):
    return [x for row in cell for x, colour in enumerate(row) if colour is not None]


class FootprintsTest(unittest.TestCase):
    def test_sheet_has_a_cell_for_each_kind_and_foot(self):
        for tile in TILES:
            cells = footprints.sheet(tile)[0]
            self.assertEqual(len(cells), 2 * len(footprints.KINDS), f"{tile} px")
            for cell in cells:
                self.assertEqual((len(cell), len(cell[0])), (tile, tile), f"{tile} px")

    def test_prints_stay_clear_of_the_cell_edge(self):
        for tile in TILES:
            for cell in footprints.sheet(tile)[0]:
                columns = pressed_columns(cell)
                self.assertGreater(min(columns), 0, f"{tile} px")
                self.assertLess(max(columns), tile - 1, f"{tile} px")

    def test_right_foot_mirrors_the_left(self):
        for tile in TILES:
            left, right = footprints.sheet(tile)[0][:2]
            mirrored = [[colour is not None for colour in row[::-1]] for row in left]
            self.assertEqual([[colour is not None for colour in row] for row in right], mirrored, f"{tile} px")


if __name__ == "__main__":
    unittest.main()
