"""Tests of the tilled soil's art (`make test` runs them): flat, straight furrows, no seams, the
moisture steps, and the crops in the middle of their tiles."""

import unittest
from collections import Counter

import crops
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

    def test_its_decorations_are_weeds_green_on_their_shadow_of_soil(self):
        self.assertGreaterEqual(len(self.decorations), 3)
        for decoration in self.decorations:
            colours = {colour for row in decoration for colour in row if colour}
            self.assertTrue(colours <= {*terrain.GRASS_RAMP, "soil"}, colours)
            self.assertIn("soil", colours, "a shadow")

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


class BedShapeTest(unittest.TestCase):
    # In a cell of the dual grid the tile border runs across the middle, and a tile's corner is at
    # the cell's middle.
    BORDER = GAME_TILE // 2

    def test_a_beds_side_runs_a_pixel_or_a_few_inside_the_tiles_edge(self):
        for shapes in terrain._SOIL_SHAPES:
            north_tiles_tilled = shapes[terrain.TL | terrain.TR]
            for x in range(GAME_TILE):
                last_row = max(y for y in range(GAME_TILE) if north_tiles_tilled(x, y))
                self.assertIn(self.BORDER - 1 - last_row, range(5), f"column {x}")

    def test_a_beds_corner_is_rounded_off_but_reaches_near_the_tiles_corner(self):
        corner = self.BORDER - 1
        for shapes in terrain._SOIL_SHAPES:
            only_north_west_tilled = shapes[terrain.TL]
            self.assertFalse(only_north_west_tilled(corner, corner))
            self.assertTrue(only_north_west_tilled(corner - 6, corner - 6))

    def test_the_weeds_of_fallow_soil_stay_on_the_bed_of_a_tile_tilled_alone(self):
        _, weeds = terrain.soil()
        on_bed = soil_beds.inside_bed(GAME_TILE, 0, terrain._SOIL_SHAPES)
        for weed in weeds:
            for y, row in enumerate(weed):
                for x, colour in enumerate(row):
                    self.assertTrue(colour is None or on_bed[y][x], (x, y))


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


class FadeTest(unittest.TestCase):
    def setUp(self):
        self.rows = terrain.soil_fade()

    def drawn(self, steps, column):
        return self.rows[soil_beds.STEP_PAIRS.index(steps)][column]

    def test_the_atlas_has_a_row_for_each_pair_of_steps_and_a_tile_for_each_cut_side_and_corner(self):
        self.assertEqual(len(self.rows), 6)
        self.assertEqual({len(row) for row in self.rows}, {4 * 9 + 4})

    def test_a_fade_thins_out_away_from_its_side_and_stays_within_its_depth(self):
        west_inside_the_bed = 3 * 9 + 8
        tile = self.drawn((3, 0), west_inside_the_bed)
        drawn_in_column = [sum(tile[y][x] is not None for y in range(GAME_TILE)) for x in range(GAME_TILE)]
        depth = terrain._SOIL_FADE_DEPTH
        self.assertEqual(drawn_in_column[0], GAME_TILE)
        self.assertEqual(drawn_in_column, sorted(drawn_in_column, reverse=True))
        self.assertGreater(sum(drawn_in_column[depth // 2 : depth]), 0)
        self.assertEqual(set(drawn_in_column[depth:]), {0})

    def test_a_fade_steps_through_the_browns_between_its_steps_only(self):
        tile = self.drawn((3, 0), 0 * 9 + 8)
        colours = {colour for row in tile for colour in row if colour}
        self.assertTrue(colours <= {*soil_beds.RAMPS[1], *soil_beds.RAMPS[2], *soil_beds.RAMPS[3]}, colours)
        self.assertIn(soil_beds.RAMPS[2][1], colours, "the body of the step between")
        one_step = self.drawn((2, 1), 0 * 9 + 8)
        self.assertTrue({colour for row in one_step for colour in row if colour} <= set(soil_beds.RAMPS[2]))

    def test_a_fade_stops_short_of_the_rim_where_the_bed_ends_beside_it(self):
        inside = self.drawn((3, 0), 0 * 9 + 8)
        north_with_no_bed_west = self.drawn((3, 0), 0 * 9 + 0 * 3 + 2)
        for tile in inside, north_with_no_bed_west:
            self.assertTrue(all(pixel is not None for pixel in tile[0][GAME_TILE // 2 :]))
        self.assertIsNotNone(inside[0][0])
        self.assertIsNone(north_with_no_bed_west[0][0])

    def test_a_corner_fade_meets_the_fades_of_the_sides_beside_it(self):
        # The tile north of a corner fading from the north-west fades from the west: the corner
        # fade's top row goes on from that fade's bottom row, which is like its top row.
        north_west = self.drawn((3, 0), 4 * 9 + 3)
        west = self.drawn((3, 0), 3 * 9 + 8)
        north = self.drawn((3, 0), 0 * 9 + 8)
        self.assertEqual(north_west[0][: GAME_TILE // 2], west[0][: GAME_TILE // 2])
        self.assertEqual([row[0] for row in north_west[: GAME_TILE // 2]], [row[0] for row in north[: GAME_TILE // 2]])


class SownSoilTest(unittest.TestCase):
    def test_a_sown_mound_is_dark_earth_with_seeds_on_it_so_it_reads_on_every_step(self):
        colours = Counter(colour for row in crops.sown() for colour in row if colour)
        body, _ = colours.most_common(1)[0]
        self.assertIn(body, ("soil", "soil_dark"))
        self.assertGreaterEqual(colours["cream"], 3)


class CropsOnTheirTileTest(unittest.TestCase):
    @staticmethod
    def drawn_rows_in_tile(cell):
        """The first and the last drawn row of a crop's cell, counted from the top of its tile."""
        tile_top = len(cell) - GAME_TILE
        drawn = [y - tile_top for y, row in enumerate(cell) if any(row)]
        return drawn[0], drawn[-1]

    def test_every_stage_that_fits_its_tile_sits_in_its_middle(self):
        for crop in crops.ARTISTS:
            for stage, cell in enumerate(crops.sheet_rows(crop)):
                top, bottom = self.drawn_rows_in_tile(cell)
                if top >= 0:
                    self.assertLessEqual(abs(top - (GAME_TILE - 1 - bottom)), 1, (crop, stage))

    def test_a_stage_that_reaches_above_its_tile_stands_on_its_lower_part(self):
        _, bottom = self.drawn_rows_in_tile(crops.sheet_rows("wheat")[3])
        self.assertGreater(bottom, GAME_TILE * 3 // 4)


if __name__ == "__main__":
    unittest.main()
