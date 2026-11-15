"""Tests of the art of the ways (ways.py; `make test` runs them): the plank walk and the stone path
are laid tile by tile with variants picked at random, so every variant must meet every other at
the seams. Both art sets."""

import unittest

import ways

TILES = (32, 16)


def edge(picture, band):
    """The pixels of a picture within `band` px of its sides, by place."""
    size = len(picture)
    return {(x, y): picture[y][x] for y in range(size) for x in range(size) if min(x, y, size - 1 - x, size - 1 - y) < band}


class StonePathTest(unittest.TestCase):
    def test_variants_share_their_edge(self):
        for tile in TILES:
            first = edge(ways.stone_path(tile, 0), ways.SEAM_BAND)
            for variant in range(1, ways.STONE_VARIANTS):
                self.assertEqual(edge(ways.stone_path(tile, variant), ways.SEAM_BAND), first, f"{tile} px, variant {variant}")

    def test_variants_differ_inside(self):
        for tile in TILES:
            pictures = [ways.stone_path(tile, variant) for variant in range(ways.STONE_VARIANTS)]
            self.assertEqual(len({str(picture) for picture in pictures}), ways.STONE_VARIANTS, f"{tile} px")

    def test_tile_is_covered(self):
        for tile in TILES:
            for variant in range(ways.STONE_VARIANTS):
                self.assertNotIn(None, [colour for row in ways.stone_path(tile, variant) for colour in row])


class PlankWalkTest(unittest.TestCase):
    def test_boards_run_on_across_the_seams(self):
        """The rows of boards and gaps are the same at both sides of every variant, so they
        line up with the neighbours'; only a board's end may stop a pixel short."""
        for tile in TILES:
            for variant in range(ways.PLANK_VARIANTS):
                picture = ways.plank_walk(tile, variant)
                gaps = [y for y in range(tile) if picture[y][tile // 2] == ways.BOARD_GAP and picture[y][tile // 2 + 1] == ways.BOARD_GAP]
                self.assertEqual(gaps, [top + len(rows) - 1 for top, rows in ways._board_tops(tile)], f"{tile} px, variant {variant}")
                for y in range(tile):
                    self.assertTrue(picture[y][1] is not None and picture[y][tile - 2] is not None, f"{tile} px, variant {variant}, row {y}")


if __name__ == "__main__":
    unittest.main()
