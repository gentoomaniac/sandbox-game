"""Tests of the art of the ways (ways.py; `make test` runs them): the plank walk and the stone path
are laid tile by tile with a picture per connection mask, so every picture must meet the others
at the seams where a way lies beside it, and have a ragged edge where none does. Both art sets."""

import unittest

import ways
from ways import ALL_SIDES, EAST, NORTH, SOUTH, WEST

TILES = (32, 16)
SIDES = (NORTH, EAST, SOUTH, WEST)


def edge(picture, band):
    """The pixels of a picture within `band` px of its sides, by place."""
    size = len(picture)
    return {(x, y): picture[y][x] for y in range(size) for x in range(size) if min(x, y, size - 1 - x, size - 1 - y) < band}


def side_pixels(picture, side):
    """The outermost row or column of a side of a picture."""
    size = len(picture)
    return {
        NORTH: [picture[0][x] for x in range(size)],
        SOUTH: [picture[size - 1][x] for x in range(size)],
        WEST: [picture[y][0] for y in range(size)],
        EAST: [picture[y][size - 1] for y in range(size)],
    }[side]


def depths_of_edge(picture, side):
    """How far in from a side the first pixel that is drawn lies, along that side."""
    size = len(picture)
    depths = []
    for along in range(size):
        line = {
            NORTH: [picture[d][along] for d in range(size)],
            SOUTH: [picture[size - 1 - d][along] for d in range(size)],
            WEST: [picture[along][d] for d in range(size)],
            EAST: [picture[along][size - 1 - d] for d in range(size)],
        }[side]
        depths.append(next(depth for depth, colour in enumerate(line) if colour not in (None, "shadow")))
    return depths


class OrientationTest(unittest.TestCase):
    # Every mask, bit 0 north, 1 east, 2 south, 3 west. The same table is in tests/test_way_connections.gd.
    LIE_EAST_WEST = [True, True, False, True, True, True, True, True, False, True, False, False, True, True, False, True]

    def test_the_boards_lie_across_the_way_by_its_neighbours(self):
        for mask, expected in enumerate(self.LIE_EAST_WEST):
            self.assertEqual(ways.boards_lie_east_west(mask), expected, f"mask {mask}")

    def test_a_run_has_boards_across_it_a_corner_and_a_crossing_east_to_west(self):
        self.assertTrue(ways.boards_lie_east_west(NORTH | SOUTH))
        self.assertFalse(ways.boards_lie_east_west(EAST | WEST))
        self.assertTrue(ways.boards_lie_east_west(NORTH | EAST))
        self.assertTrue(ways.boards_lie_east_west(ALL_SIDES))
        self.assertTrue(ways.boards_lie_east_west(0))


class StonePathTest(unittest.TestCase):
    def test_variants_share_their_edge_where_a_way_lies_beside_them(self):
        for tile in TILES:
            first = edge(ways.stone_path(tile, 0), ways.SEAM_BAND)
            for variant in range(1, ways.STONE_VARIANTS):
                self.assertEqual(edge(ways.stone_path(tile, variant), ways.SEAM_BAND), first, f"{tile} px, variant {variant}")

    def test_a_side_with_a_way_beside_it_is_the_same_whether_the_other_sides_have_one_or_not(self):
        for tile in TILES:
            for variant in range(ways.STONE_VARIANTS):
                joined = ways.stone_path(tile, variant, ALL_SIDES)
                for mask in range(ways.CONNECTION_LOOKS):
                    picture = ways.stone_path(tile, variant, mask)
                    for side in SIDES:
                        if mask & side:
                            # Where a kerb of another side runs to this one's corners they differ.
                            middle = slice(tile // 3, tile - tile // 3)
                            self.assertEqual(side_pixels(picture, side)[middle], side_pixels(joined, side)[middle], f"{tile} px, variant {variant}, mask {mask}")

    def test_variants_differ_inside(self):
        for tile in TILES:
            pictures = [ways.stone_path(tile, variant) for variant in range(ways.STONE_VARIANTS)]
            self.assertEqual(len({str(picture) for picture in pictures}), ways.STONE_VARIANTS, f"{tile} px")

    def test_tile_with_ways_on_all_sides_is_covered(self):
        for tile in TILES:
            for variant in range(ways.STONE_VARIANTS):
                self.assertNotIn(None, [colour for row in ways.stone_path(tile, variant) for colour in row])

    def test_a_side_with_no_way_beside_it_is_not_straight(self):
        for tile in TILES:
            for side in SIDES:
                for variant in range(ways.STONE_VARIANTS):
                    depths = depths_of_edge(ways.stone_path(tile, variant, ALL_SIDES & ~side), side)
                    self.assertGreater(len(set(depths)), 1, f"{tile} px, side {side}, variant {variant}")

    def test_a_side_with_no_way_beside_it_has_a_kerb_of_edging_stones(self):
        """A kerb is a row of stones along the side, parted by joints: the earth's colour in the row
        where a stone begins, and the stones lit on their outer face in between."""
        for tile in TILES:
            picture = ways.stone_path(tile, 0, ALL_SIDES & ~WEST)
            first_colours = [next(colour for colour in row if colour not in (None, "shadow")) for row in picture]
            self.assertGreaterEqual(first_colours.count(ways.JOINT), len(ways.KERB_LENGTHS[tile][0]), f"{tile} px")
            lit = {ramp[0] for ramp, _ in ways.STONE_RAMPS}
            self.assertGreater(len(lit & set(first_colours)), 0, f"{tile} px")

    def test_the_kerb_stones_of_a_side_add_up_to_the_tile(self):
        for tile in TILES:
            for lengths in ways.KERB_LENGTHS[tile]:
                self.assertEqual(sum(lengths), tile)

    def test_a_tile_alone_is_covered_in_the_middle(self):
        for tile in TILES:
            picture = ways.stone_path(tile, 0, 0)
            middle = [picture[y][x] for y in range(tile // 3, tile - tile // 3) for x in range(tile // 3, tile - tile // 3)]
            self.assertNotIn(None, middle, f"{tile} px")


class PlankWalkTest(unittest.TestCase):
    def test_boards_start_at_the_tiles_top_and_the_next_tile_goes_on_from_their_gap(self):
        for tile in TILES:
            for variant in range(ways.PLANK_VARIANTS):
                tops = ways._board_tops(tile, variant)
                self.assertEqual(tops[0][0], 0)
                self.assertEqual(sum(len(rows) for _, rows in tops), tile, f"{tile} px, variant {variant}")

    def test_boards_vary_in_width(self):
        for tile in TILES:
            for variant in range(ways.PLANK_VARIANTS):
                self.assertGreater(len(set(ways.BOARD_WIDTHS[tile][variant])), 1, f"{tile} px, variant {variant}")

    def test_where_ways_lie_beside_a_tile_its_boards_run_on_to_their_side(self):
        """Not at the corners, where the end of a board that stops may leave a pixel open."""
        for tile in TILES:
            for variant in range(ways.PLANK_VARIANTS):
                for mask in (NORTH | SOUTH | EAST | WEST, NORTH | SOUTH | EAST, NORTH | SOUTH | WEST):
                    picture = ways.plank_walk(tile, variant, mask)
                    for side in SIDES:
                        if mask & side:
                            self.assertNotIn(None, side_pixels(picture, side)[tile // 3 : tile - tile // 3], f"{tile} px, variant {variant}, mask {mask}, side {side}")

    def test_boards_lie_across_the_way(self):
        """The gaps between the boards run across a north to south way and along an east to west one:
        the rows of a way running north to south all have a gap."""
        for tile in TILES:
            across = ways.plank_walk(tile, 0, NORTH | SOUTH)
            along = ways.plank_walk(tile, 0, EAST | WEST)
            gap_rows = [y for y in range(tile) if across[y][tile // 2] == ways.BOARD_GAP and across[y][tile // 2 + 1] == ways.BOARD_GAP]
            gap_columns = [x for x in range(tile) if along[tile // 2][x] == ways.BOARD_GAP and along[tile // 2 + 1][x] == ways.BOARD_GAP]
            expected = [top + len(rows) - 1 for top, rows in ways._board_tops(tile, 0)]
            self.assertEqual(gap_rows[: len(expected) - 1], expected[:-1], f"{tile} px")
            self.assertEqual(gap_columns[: len(expected) - 1], expected[:-1], f"{tile} px")

    def test_the_ends_of_the_boards_are_ragged_where_no_way_lies_beside_them(self):
        for tile in TILES:
            for variant in range(ways.PLANK_VARIANTS):
                picture = ways.plank_walk(tile, variant, NORTH | SOUTH)
                for side in (EAST, WEST):
                    self.assertGreater(len(set(depths_of_edge(picture, side))), 1, f"{tile} px, variant {variant}, side {side}")

    def test_some_variants_have_a_knot_and_some_do_not(self):
        knots = [ways.KNOTS[variant] for variant in range(ways.PLANK_VARIANTS)]
        self.assertIn(0, knots)
        self.assertGreater(max(knots), 0)

    def test_boards_are_not_all_alike(self):
        for tile in TILES:
            pictures = [ways.plank_walk(tile, variant, NORTH | SOUTH) for variant in range(ways.PLANK_VARIANTS)]
            self.assertEqual(len({str(picture) for picture in pictures}), ways.PLANK_VARIANTS, f"{tile} px")

    def test_a_tile_laid_with_the_boards_the_other_way_is_the_first_turned_over_its_diagonal(self):
        for tile in TILES:
            along = ways.plank_walk(tile, 1, EAST | WEST)
            across = ways.plank_walk(tile, 1, NORTH | SOUTH)
            self.assertEqual(along, [list(column) for column in zip(*across)])


class WayEdgeTest(unittest.TestCase):
    @staticmethod
    def drawn(picture):
        return {(x, y) for y, row in enumerate(picture) for x, colour in enumerate(row) if colour is not None}

    def test_a_tile_with_no_way_beside_it_has_no_edge(self):
        for tile in TILES:
            self.assertEqual(self.drawn(ways.way_edge(tile, 0)), set(), f"{tile} px")

    def test_the_edge_lies_along_the_side_with_the_way(self):
        for tile in TILES:
            reach = len(ways.EDGE_DENSITY[tile])
            for side in SIDES:
                for x, y in self.drawn(ways.way_edge(tile, side)):
                    depth = {NORTH: y, SOUTH: tile - 1 - y, WEST: x, EAST: tile - 1 - x}[side]
                    self.assertLess(depth, reach, f"{tile} px, side {side}")

    def test_the_edges_of_the_sides_add_up(self):
        for tile in TILES:
            for mask in range(ways.CONNECTION_LOOKS):
                expected = set().union(*(self.drawn(ways.way_edge(tile, side)) for side in SIDES if mask & side))
                self.assertEqual(self.drawn(ways.way_edge(tile, mask)), expected, f"{tile} px, mask {mask}")

    def test_the_edge_thins_out_away_from_the_way(self):
        for tile in TILES:
            picture = ways.way_edge(tile, WEST)
            by_depth = [sum(picture[y][depth] is not None for y in range(tile)) for depth in range(len(ways.EDGE_DENSITY[tile]))]
            self.assertGreater(max(by_depth), 2 * by_depth[-1], f"{tile} px")
            self.assertGreater(by_depth[0], tile // 2, f"{tile} px")

    def test_the_edge_is_the_same_wherever_it_is_laid(self):
        for tile in TILES:
            self.assertEqual(ways.way_edge(tile, WEST | NORTH)[tile // 2], ways.way_edge(tile, WEST)[tile // 2], f"{tile} px")


if __name__ == "__main__":
    unittest.main()
