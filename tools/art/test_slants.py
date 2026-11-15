"""Tests of the slanting pieces of the dyke (slants.py, boundaries.py; `make test` runs them): a
stair of corners is one bank on the diagonal, so a slanted piece must meet the piece across its
slanted side at the seam, and its bank must come down to the ground in the notches of the stair,
where no dyke tile is. Both art sets."""

import math
import unittest

import slants

# (tile, foot) of the 32 px dyke and of the classic one.
ART_SETS = ((32, 16.0), (16, 8.0))
SIDES = dict(slants.SIDES)


def opposite(bits):
    return ((bits << 2) | (bits >> 2)) & 0b1111


class SlantsTest(unittest.TestCase):
    def test_the_pictures_are_in_the_order_the_game_reads(self):
        # WorldObjectTypes.connection_look: each corner, slanted on its lower side, its higher, both.
        self.assertEqual(slants.SLANTED[:3], ((0b0011, 0b0001), (0b0011, 0b0010), (0b0011, 0b0011)))
        self.assertEqual(slants.SLANTED[-1], (0b1100, 0b1100))
        self.assertEqual(len(set(slants.SLANTED)), 12)

    def test_a_slanted_side_meets_the_step_across_it(self):
        for tile, foot in ART_SETS:
            for mask, slanted in slants.SLANTED:
                piece = slants.Skeleton(mask, slanted, tile, foot)
                for bit, (dx, dy) in slants.SIDES:
                    if not slanted & bit:
                        continue
                    # The step across is joined on the opposite sides and slanted back across this one.
                    step_mask = opposite(mask)
                    for step_slanted in (opposite(bit), step_mask):
                        step = slants.Skeleton(step_mask, step_slanted, tile, foot)
                        for along in range(tile):
                            # The ground pixel just across the seam, in the step's own coordinates.
                            x = along + 0.5 if dx == 0 else (tile + 0.5 if dx > 0 else -0.5)
                            y = along + 0.5 if dy == 0 else (tile + 0.5 if dy > 0 else -0.5)
                            here = piece.at(x, y)
                            there = step.at(x - dx * tile, y - dy * tile)
                            if min(here[0], there[0]) >= min(here[1], there[1]):
                                continue  # Off the bank, on the ground.
                            # The step bends or not further in, which this piece does not know.
                            with self.subTest(tile=tile, mask=mask, slanted=slanted, step=step_slanted, along=along):
                                self.assertAlmostEqual(here[0], there[0], delta=tile / 32)
                                self.assertAlmostEqual(here[1], there[1], delta=tile / 32)

    def test_the_bank_comes_down_in_the_notches_of_the_stair(self):
        for tile, foot in ART_SETS:
            for mask, slanted in slants.SLANTED:
                piece = slants.Skeleton(mask, slanted, tile, foot)
                # The inner corner of the turn, and the far ends of the slanted sides: the corners
                # of the stair where no dyke tile is.
                sides = [direction for bit, direction in slants.SIDES if mask & bit]
                centre = tile / 2
                notches = [(centre + centre * (sides[0][0] + sides[1][0]), centre + centre * (sides[0][1] + sides[1][1]))]
                for bit, (dx, dy) in slants.SIDES:
                    if slanted & bit:
                        other = [d for d in sides if d != (dx, dy)][0]
                        notches.append((centre + centre * (dx - other[0]), centre + centre * (dy - other[1])))
                for notch in notches:
                    distance, reach = piece.at(*notch)
                    with self.subTest(tile=tile, mask=mask, slanted=slanted, notch=notch):
                        self.assertGreaterEqual(distance + 0.01, reach)

    def test_a_stair_of_double_slants_is_a_straight_diagonal(self):
        for tile, foot in ART_SETS:
            piece = slants.Skeleton(0b1100, 0b1100, tile, foot)
            # From the middle of the west side to the middle of the south side.
            for step in range(tile // 2 + 1):
                distance, reach = piece.at(step, tile / 2 + step)
                self.assertAlmostEqual(distance, 0.0, delta=0.01)
                self.assertAlmostEqual(reach, foot / math.sqrt(2), delta=0.01)


if __name__ == "__main__":
    unittest.main()
