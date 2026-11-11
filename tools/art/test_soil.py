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


class PatchEdgeTest(unittest.TestCase):
    """The edges of wet patches (task 175): the user saw wet tiles as square blocks."""

    @classmethod
    def setUpClass(cls):
        cls.rows = terrain.soil_edge()

    def piece(self, piece, column, phase=0):
        return self.rows[soil_beds.PIECES.index(piece) * soil_beds.PHASES + phase][column]

    @staticmethod
    def north_side(first_end, second_end):
        return first_end * soil_beds.END_KINDS + second_end

    @staticmethod
    def corner(index):
        return 4 * 9 + index

    @staticmethod
    def depths(tile):
        """How many pixels each column of a piece along the north side draws."""
        return [sum(tile[y][x] is not None for y in range(GAME_TILE)) for x in range(GAME_TILE)]

    def test_the_atlas_has_a_row_for_each_phase_of_each_piece_and_a_tile_for_each_side_and_corner(self):
        self.assertEqual(len(self.rows), len(soil_beds.PIECES) * soil_beds.PHASES)
        self.assertEqual({len(row) for row in self.rows}, {4 * 9 + 4})

    def test_the_line_wanders_beyond_the_tile_edge_and_short_of_it(self):
        running_on = self.north_side(soil_beds.END_RUNS_ON, soil_beds.END_RUNS_ON)
        beyond = short = 0
        for phase in range(soil_beds.PHASES):
            beyond += sum(self.depths(self.piece((True, 2), running_on, phase)))
            short += sum(self.depths(self.piece((False, 1), running_on, phase)))
        self.assertGreater(beyond, 0, "a bulge of the wetter brown over the drier tile")
        self.assertGreater(short, 0, "a bite of the drier brown out of the wetter tile")

    def test_the_line_is_no_straight_band_and_runs_on_from_tile_to_tile(self):
        running_on = self.north_side(soil_beds.END_RUNS_ON, soil_beds.END_RUNS_ON)
        line = []
        for phase in range(soil_beds.PHASES):
            beyond = self.depths(self.piece((True, 1), running_on, phase))
            short = self.depths(self.piece((False, 0), running_on, phase))
            line += [out - back for out, back in zip(beyond, short)]
        self.assertGreaterEqual(max(line) - min(line), 12)
        for x in range(len(line)):
            self.assertLessEqual(abs(line[x] - line[x - 1]), 3, f"column {x}")

    def test_where_a_side_turns_its_line_comes_to_the_tiles_corner(self):
        turning = self.north_side(soil_beds.END_TURNS, soil_beds.END_TURNS)
        for phase in range(soil_beds.PHASES):
            beyond = self.depths(self.piece((True, 1), turning, phase))
            short = self.depths(self.piece((False, 0), turning, phase))
            for x in (*range(10), *range(GAME_TILE - 10, GAME_TILE)):
                self.assertEqual((beyond[x], short[x]), (0, 0), f"phase {phase}, column {x}")

    def test_at_the_beds_rim_a_side_stops_short_of_it(self):
        rim_to_the_west = self.north_side(soil_beds.END_RIM, soil_beds.END_RUNS_ON)
        running_on = self.north_side(soil_beds.END_RUNS_ON, soil_beds.END_RUNS_ON)
        for column, is_cut in (rim_to_the_west, True), (running_on, False):
            west_columns = [
                row[0] for phase in range(soil_beds.PHASES) for row in self.piece((False, 2), column, phase)
            ]
            self.assertEqual(all(pixel is None for pixel in west_columns), is_cut)

    def test_a_piece_is_drawn_in_the_browns_of_its_step(self):
        for piece in soil_beds.PIECES:
            for column in range(4 * 9 + 4):
                colours = {colour for row in self.piece(piece, column) for colour in row if colour}
                self.assertTrue(colours <= set(soil_beds.RAMPS[piece[1]]), (piece, column))

    def test_a_patchs_corner_is_rounded_off_and_a_hollow_filled_in(self):
        north_east = self.corner(0)
        corner_pixel = (0, GAME_TILE - 1)
        rounded = self.piece((False, 0), north_east)
        filled = self.piece((True, 1), north_east)
        for tile in rounded, filled:
            y, x = corner_pixel
            self.assertIsNotNone(tile[y][x])
            for y in range(GAME_TILE):
                for x in range(GAME_TILE):
                    is_far = y >= terrain._PATCH_EDGE.convex or GAME_TILE - 1 - x >= terrain._PATCH_EDGE.convex
                    self.assertTrue(tile[y][x] is None or not is_far, (x, y))
