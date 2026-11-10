"""Tests of the art of worn ground (`make test` runs them): the full tiles of trodden grass and
the path are an even colour with a few single specks, so a worn yard shows no shape of its own
per tile. Both art sets."""

import unittest
from collections import Counter

import terrain
from classic import terrain as classic_terrain

# The biggest patch of one colour but the tile's main one, in pixels: a speck, or two touching.
BIGGEST_PATCH = 4
# The most pixels of a full tile that are not its main colour.
MOST_SPECKS = 0.08


def pixels_of(tile):
    return [colour for row in tile for colour in row]


def biggest_patch(tile):
    """The pixels of the biggest 4-connected patch of any colour but the tile's main one."""
    size = len(tile)
    main = Counter(pixels_of(tile)).most_common(1)[0][0]
    seen = set()
    biggest = 0
    for start_y in range(size):
        for start_x in range(size):
            if (start_x, start_y) in seen or tile[start_y][start_x] in (None, main):
                continue
            colour = tile[start_y][start_x]
            seen.add((start_x, start_y))
            pending = [(start_x, start_y)]
            patch = 0
            while pending:
                x, y = pending.pop()
                patch += 1
                for next_x, next_y in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if (
                        0 <= next_x < size
                        and 0 <= next_y < size
                        and (next_x, next_y) not in seen
                        and tile[next_y][next_x] == colour
                    ):
                        seen.add((next_x, next_y))
                        pending.append((next_x, next_y))
            biggest = max(biggest, patch)
    return biggest


class WornGroundTest(unittest.TestCase):
    def test_full_tiles_are_even_with_a_few_single_specks(self):
        for art in (terrain, classic_terrain):
            for layer in (art.trodden, art.path):
                tiles, _ = layer()
                for tile in tiles[terrain.EDGE_VARIANTS * terrain.FULL :]:
                    name = f"{art.__name__}.{layer.__name__}"
                    self.assertLessEqual(biggest_patch(tile), BIGGEST_PATCH, name)
                    specks = 1 - Counter(pixels_of(tile)).most_common(1)[0][1] / len(pixels_of(tile))
                    self.assertLessEqual(specks, MOST_SPECKS, name)


if __name__ == "__main__":
    unittest.main()
