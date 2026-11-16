"""Tests of the dyke's looks by its height (boundaries.py; `make test` runs them): the low one is a
lower and narrower bank than the usual one, the high one a taller one with a broader crest, and the
torn crest is a gap of clay that leaves the bank whole where it meets its neighbours."""

import unittest

import boundaries

EAST_WEST = 0b1010


def _top_row(picture):
    """The first row of the cell with a pixel of the bank (not of its shadow)."""
    return next(y for y, row in enumerate(picture) if any(name not in (None, "shadow") for name in row))


class DykeLooksTest(unittest.TestCase):
    def test_the_looks_rise_from_low_to_high_and_the_low_one_is_narrower(self):
        looks = boundaries.DYKE_LOOKS
        self.assertLess(looks["low"].foot, looks["normal"].foot)
        self.assertGreater(looks["high"].crest, looks["normal"].crest)
        # Drawn, the taller bank reaches higher up its cell.
        tops = [_top_row(boundaries.dyke(EAST_WEST, look=looks[name])) for name in ("low", "normal", "high")]
        self.assertGreater(tops[0], tops[1])
        self.assertGreater(tops[1], tops[2])

    def test_a_torn_crest_is_raw_clay_in_the_middle_and_whole_at_the_seams(self):
        torn = boundaries.torn_dyke(EAST_WEST)
        whole = boundaries.dyke(EAST_WEST)
        self.assertTrue(any(name in boundaries.DYKE_CLAY for row in torn for name in row))
        # The tile is the middle third of the cell: its first and last columns meet the neighbours.
        left = len(whole[0]) // 3
        for x in (left, left + boundaries.TILE - 1):
            with self.subTest(column=x):
                self.assertEqual([row[x] for row in torn], [row[x] for row in whole])


if __name__ == "__main__":
    unittest.main()
