"""The graves of church.py as they were drawn at 16 px (commit e303759), its part of the module
unchanged: the classic object atlas has their row too, and the classic church.py has only the
buildings.
"""

import math

from canvas import blank, outline_edge, rect


def oak_cross():
    """An oak cross, 11x16 px, lit on the left, its arms a little below the top."""
    picture = blank(11, 16)
    rect(picture, 4, 0, 6, 15, "soil_mid")
    rect(picture, 0, 4, 10, 6, "soil_mid")
    rect(picture, 4, 0, 4, 15, "soil_light")
    rect(picture, 0, 4, 10, 4, "soil_light")
    rect(picture, 6, 7, 6, 15, "soil")
    rect(picture, 0, 6, 10, 6, "soil")
    return outline_edge(picture, "soil_dark", keep_bottom=True)


def headstone():
    """A headstone of sandstone, 11x14 px, its top round, a cross cut into it over three lines
    of letters; lichen on its foot."""
    picture = blank(11, 14)
    for y in range(14):
        for x in range(11):
            if y >= 5 or math.hypot(x - 5, y - 5) <= 5.5:
                picture[y][x] = "sand_light" if x < 3 or y < 2 else "sand" if x < 9 else "mud"
    rect(picture, 5, 2, 5, 6, "mud")
    rect(picture, 3, 3, 7, 3, "mud")
    for y, (left, right) in zip((8, 10), ((2, 8), (3, 7))):
        for x in range(left, right + 1, 2):
            picture[y][x] = "mud"
    rect(picture, 1, 12, 3, 12, "olive")
    picture[11][2] = "dry"
    return outline_edge(picture, "mud_dark", keep_bottom=True)


def fieldstone_slab():
    """A low slab of grey granite, 13x9 px, rough on top, a cross cut into it."""
    picture = blank(13, 9)
    tops = (3, 2, 1, 1, 0, 0, 0, 1, 1, 1, 2, 2, 3)
    for x, top in enumerate(tops):
        for y in range(top, 9):
            picture[y][x] = "stone_light" if y <= top + 1 or x < 2 else "stone" if x < 11 else "stone_dark"
    rect(picture, 6, 2, 6, 6, "stone_dark")
    rect(picture, 4, 3, 8, 3, "stone_dark")
    return outline_edge(picture, "stone_dark", keep_bottom=True)


def graves():
    """The looks of a grave, standing: the variants of the world object `grave`, the oak cross only
    (the user, 2026-11-10). headstone() and fieldstone_slab() wait for tombstone items to come."""
    return [oak_cross()]
