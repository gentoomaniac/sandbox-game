"""Tests of the dyke's looks by its height (boundaries.py; `make test` runs them): the low one is a
lower and narrower bank than the usual one, the high one a taller one with a broader crest."""

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


if __name__ == "__main__":
    unittest.main()
