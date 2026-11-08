"""The two pictures of the classic 16 px ground that are not in the terrain atlas, as they were at
commit acf236e: the damp and wet looks of tilled soil (`soil_wet` of crop_icons.py, drawn here
without crops.Surface, so that it stays as it was when the crops are redrawn) and the hint of a
clay spot (`clay_hint` of meadow.py, unchanged)."""

import random

from canvas import TILE, blank


def soil_wet():
    """The overlay of damp and of wet soil as two tiles: dashes of darker soil, in the middle of
    the tile only, so the rounded edges of a field stay clear. Wet has more of them and a few of
    the darkest, and they include all of the damp ones. The light bands of the soil texture
    turn dark where they lie."""
    rng = random.Random("soil-wet")
    spots = [(x, y) for y in range(2, TILE - 2) for x in range(2, TILE - 3)]
    rng.shuffle(spots)
    tiles = []
    for count, darkest in ((14, 0), (36, 8)):
        tile = blank()
        for index, (x, y) in enumerate(spots[:count]):
            colour = "soil" if index >= darkest else "soil_dark"
            tile[y][x] = tile[y][x + 1] = colour
        tiles.append(tile)
    return tiles


def clay_hint():
    """A 16x16 tile with a few reddish-grey pixels: all that shows of a clay spot."""
    tile = blank()
    for x, y, colour in (
        (6, 8, "soil_light"),
        (7, 8, "bare_light"),
        (8, 9, "soil_light"),
        (6, 10, "bare_light"),
        (7, 10, "soil_light"),
        (10, 7, "bare_light"),
        (9, 11, "soil_light"),
    ):
        tile[y][x] = colour
    return tile
