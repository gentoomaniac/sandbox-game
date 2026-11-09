"""Tests of the tilled soil's art (`make test` runs them): flat, straight furrows, no seams, and the
moisture steps."""

import unittest

import soil_beds
import terrain
from canvas import GAME_TILE
from palette import PALETTE


class TilledSoilTest(unittest.TestCase):
    def setUp(self):
        self.tiles, self.decorations = terrain.soil()
        self.full = self.tiles[-1]

    def test_all_full_tiles_are_one_so_no_variant_marks_where_tiles_end(self):
        full_tiles = self.tiles[terrain.EDGE_VARIANTS * terrain.FULL :]
        self.assertEqual(len(full_tiles), 1)

    def test_a_bed_has_no_decorations(self):
        self.assertEqual(self.decorations, [])

    def test_the_rows_run_on_across_the_joins_of_tiles(self):
        pixel = terrain.soil_pixel_of(soil_beds.RAMPS[0])
        for y in range(GAME_TILE):
            for x in range(GAME_TILE):
                self.assertEqual(pixel(x, y), pixel(x + GAME_TILE, y + 2 * GAME_TILE))

    def test_the_furrows_are_straight_and_the_crest_stays_on_its_ridge(self):
        furrow, body, _ = soil_beds.RAMPS[-1]
        pixel = terrain.soil_pixel_of(soil_beds.RAMPS[-1])
        for y in range(GAME_TILE):
            row = [pixel(x, y) for x in range(GAME_TILE)]
            if y % 8 == 3:
                self.assertEqual(set(row), {body}, f"row {y} is flat body")
            if y % 8 in (6, 7):
                self.assertEqual(set(row), {furrow}, f"row {y} is a furrow")


class MoistureStepsTest(unittest.TestCase):
    def test_each_step_is_darker_than_the_one_before_it(self):
        def lightness(name):
            return sum(bytes.fromhex(PALETTE[name]))

        bodies = [lightness(ramp[1]) for ramp in soil_beds.RAMPS]
        for drier, wetter in zip(bodies, bodies[1:]):
            self.assertGreater(drier, wetter)

    def test_the_overlay_has_a_row_for_each_step_above_the_driest_and_a_tile_for_each_bed_shape(self):
        rows = terrain.soil_wet()
        self.assertEqual(len(rows), len(soil_beds.RAMPS) - 1)
        self.assertEqual({len(row) for row in rows}, {47})

    def test_inside_a_bed_the_overlay_fills_the_tile_so_wet_tiles_show_no_seam(self):
        inside = soil_beds.BED_MASKS[-1]
        for row in terrain.soil_wet():
            tile = row[soil_beds.BED_MASKS.index(inside)]
            self.assertTrue(all(all(pixel is not None for pixel in line) for line in tile))

    def test_at_the_edge_of_a_bed_the_overlay_stays_inside_the_terrain(self):
        alone = soil_beds.BED_MASKS.index(0)
        for row in terrain.soil_wet():
            tile = row[alone]
            drawn = sum(pixel is not None for line in tile for pixel in line)
            self.assertLess(drawn, GAME_TILE * GAME_TILE * 0.6)
            self.assertGreater(drawn, 0)


if __name__ == "__main__":
    unittest.main()
