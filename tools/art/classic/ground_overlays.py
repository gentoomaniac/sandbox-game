"""The pictures of the classic 16 px ground that are not in the terrain atlas: the moister looks
of tilled soil and their fades (soil_beds.py), and the hint of a clay spot (`clay_hint` of
meadow.py at commit acf236e, unchanged)."""

import soil_beds
import terrain
from canvas import TILE, blank


def soil_wet():
    """The overlays of the moister steps of tilled soil (see soil_beds.py)."""
    return soil_beds.overlay_rows(TILE, terrain.SOIL_SHAPES, terrain.soil_pixel_of)


# How many pixels deep a wetter tile's brown fades out into a drier one.
_SOIL_FADE_DEPTH = 4


def soil_fade():
    """The fades of wetter tilled soil into drier (see soil_beds.py)."""
    return soil_beds.fade_rows(TILE, _SOIL_FADE_DEPTH, terrain.SOIL_SHAPES, terrain.soil_pixel_of)


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
