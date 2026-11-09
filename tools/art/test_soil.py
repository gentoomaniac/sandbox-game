"""Tests of the tilled soil's art (`make test` runs them): flat, straight furrows and no seams."""

import unittest

import terrain
from canvas import GAME_TILE


class TilledSoilTest(unittest.TestCase):
    def setUp(self):
        self.tiles, self.decorations = terrain.soil()
        self.full = self.tiles[-1]

    def test_all_full_tiles_are_one_so_no_variant_marks_where_tiles_end(self):
        full_tiles = self.tiles[terrain.EDGE_VARIANTS * (terrain.FULL):]
        self.assertEqual(len(full_tiles), 1)

    def test_a_bed_has_no_decorations(self):
        self.assertEqual(self.decorations, [])

    def test_the_rows_run_on_across_the_joins_of_tiles(self):
        for x in range(GAME_TILE):
            for y in range(len(terrain._RIDGE)):
                self.assertEqual(terrain._soil_pixel(x, y), terrain._soil_pixel(x, y + GAME_TILE))
        for y in range(GAME_TILE):
            for x in range(GAME_TILE):
                self.assertEqual(terrain._soil_pixel(x, y), terrain._soil_pixel(x + GAME_TILE, y))

    def test_the_furrows_are_straight_and_the_crest_does_not_wander_into_them(self):
        for y, row in enumerate(self.full):
            step = y % len(terrain._RIDGE)
            if step in (3, 4, 5):
                self.assertNotIn("soil_light", row, f"row {y} is a body row")
            if step in (6, 7):
                self.assertGreaterEqual(row.count("soil_dark"), GAME_TILE * 0.8, f"row {y} is a furrow")


if __name__ == "__main__":
    unittest.main()
