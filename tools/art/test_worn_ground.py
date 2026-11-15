"""Tests of the art of worn ground (`make test` runs them): the full tiles of trodden grass and
the path are an even colour with a few single specks, so a worn yard shows no shape of its own
per tile. Their muddy looks have puddles and wet patches on that earth too, small and inside the
tile, so the pools are never cut at a seam. Both art sets."""

import unittest
from collections import Counter

import terrain
from classic import terrain as classic_terrain

# The biggest patch of one colour but the tile's main one, in pixels: a speck, or two touching.
BIGGEST_PATCH = 4
# The most pixels of a full tile that are not its main colour.
MOST_SPECKS = 0.08
# On muddy ground: the biggest patch, a puddle or a wet patch, and the most pixels of a full tile
# that are specks, puddles and wet patches.
BIGGEST_POOL = 24
MOST_WET = 0.2


def pixels_of(tile):
    return [colour for row in tile for colour in row]


def patches(tile):
    """The 4-connected patches of one colour, but the tile's main one, as sets of pixels."""
    size = len(tile)
    main = Counter(pixels_of(tile)).most_common(1)[0][0]
    seen = set()
    found = []
    for start_y in range(size):
        for start_x in range(size):
            if (start_x, start_y) in seen or tile[start_y][start_x] in (None, main):
                continue
            colour = tile[start_y][start_x]
            seen.add((start_x, start_y))
            pending = [(start_x, start_y)]
            patch = set()
            while pending:
                x, y = pending.pop()
                patch.add((x, y))
                for next_x, next_y in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if (
                        0 <= next_x < size
                        and 0 <= next_y < size
                        and (next_x, next_y) not in seen
                        and tile[next_y][next_x] == colour
                    ):
                        seen.add((next_x, next_y))
                        pending.append((next_x, next_y))
            found.append(patch)
    return found


def biggest_patch(tile):
    """The pixels of the biggest patch of any colour but the tile's main one."""
    return max((len(patch) for patch in patches(tile)), default=0)


def not_main_share(tile):
    return 1 - Counter(pixels_of(tile)).most_common(1)[0][1] / len(pixels_of(tile))


def full_tiles(layer):
    tiles, _ = layer()
    return tiles[terrain.EDGE_VARIANTS * terrain.FULL :]


class WornGroundTest(unittest.TestCase):
    def test_full_tiles_are_even_with_a_few_single_specks(self):
        for art in (terrain, classic_terrain):
            for layer in (art.trodden, art.path):
                name = f"{art.__name__}.{layer.__name__}"
                for tile in full_tiles(layer):
                    self.assertLessEqual(biggest_patch(tile), BIGGEST_PATCH, name)
                    self.assertLessEqual(not_main_share(tile), MOST_SPECKS, name)

    def test_muddy_full_tiles_have_small_pools_clear_of_the_border(self):
        for art in (terrain, classic_terrain):
            for layer in (art.muddy_trodden, art.muddy_path):
                name = f"{art.__name__}.{layer.__name__}"
                tiles = full_tiles(layer)
                self.assertTrue(any(biggest_patch(tile) > BIGGEST_PATCH for tile in tiles), f"{name} has no pools")
                for tile in tiles:
                    last = len(tile) - 1
                    self.assertLessEqual(biggest_patch(tile), BIGGEST_POOL, name)
                    self.assertLessEqual(not_main_share(tile), MOST_WET, name)
                    for patch in patches(tile):
                        if len(patch) > BIGGEST_PATCH:
                            self.assertFalse(any(x in (0, last) or y in (0, last) for x, y in patch), name)


if __name__ == "__main__":
    unittest.main()
