"""The tables and seats of the interiors (assets/interior/<name>.png): the table laid with plates,
the stool, the bench and the bench along the wall, made of planked tops on turned legs.

The room, and the drawing all furniture shares (the grain of wood, the dithered shadow, the
plates), are in interior.py.
"""

import forms
from canvas import blank, outline_edge, rect
from interior import OAK, T, dither, floor_shadow, grain, plate


def turned_leg(canvas, x, top, bottom):
    """A turned oak leg 4 px wide from `top` to `bottom`, lit on its left, with two rings."""
    rect(canvas, x, top, x + 3, bottom, "soil_mid")
    rect(canvas, x, top, x, bottom, "soil_light")
    rect(canvas, x + 3, top, x + 3, bottom, "soil")
    for y in (top + 2, bottom - 3):
        if top < y < bottom:
            rect(canvas, x, y, x + 3, y, "soil_dark")


def planked_top(canvas, x0, y0, x1, y1, plank, seed):
    """A top of oak planks `plank` rows wide running across, lit, with their joints and grain."""
    rect(canvas, x0, y0, x1, y1, "soil_light")
    for y in range(y0 + plank, y1 + 1, plank):
        rect(canvas, x0, y, x1, y, "soil_mid")
    grain(canvas, x0, y0, x1, y1, "soil_mid", seed, count=(x1 - x0) * (y1 - y0) // 50)
    grain(canvas, x0, y0, x1, y1, "sand", seed + 1, count=(x1 - x0) * (y1 - y0) // 120)


def table():
    """A table 2x1 tiles: a plank top seen from above, its apron and two turned legs; on it a
    candle in a brass stick, a pewter plate with a spoon and a brown clay jug."""
    canvas = blank(2 * T, 48)
    planked_top(canvas, 0, 0, 63, 29, 6, 161)
    rect(canvas, 0, 0, 63, 0, "sand_light")
    rect(canvas, 0, 30, 63, 33, "soil_mid")
    rect(canvas, 0, 30, 63, 30, "soil_light")
    rect(canvas, 0, 34, 63, 35, "soil")
    for x in (3, 56):
        turned_leg(canvas, x, 36, 47)
    # The candle and its brass stick.
    rect(canvas, 47, 9, 52, 13, "ochre_dark")
    rect(canvas, 47, 9, 51, 11, "ochre")
    rect(canvas, 48, 3, 50, 9, "cream")
    rect(canvas, 50, 3, 50, 9, "sand_light")
    canvas[2][49] = "soil_dark"
    rect(canvas, 49, 0, 49, 1, "gold")
    # A pewter plate with a spoon.
    plate = forms.ellipse(2 * T, 48, 17, 14, 8, 6)
    forms.shade(canvas, plate, ("stone", "stone_light"), radius=1)
    forms.paint(canvas, forms.edge(plate), "stone_dark")
    rect(canvas, 14, 12, 19, 15, "stone")
    rect(canvas, 21, 18, 27, 18, "stone_light")
    rect(canvas, 26, 17, 27, 18, "stone_light")
    # A clay jug, its shadow on the table.
    dither(canvas, 36, 18, 41, 20, "soil_mid")
    jug = forms.ellipse(2 * T, 48, 35.5, 14.5, 4, 5)
    forms.shade(canvas, jug, ("rust_dark", "rust", "ochre"), radius=2)
    rect(canvas, 34, 7, 37, 9, "rust_dark")
    rect(canvas, 34, 8, 37, 8, "russet_deep")
    rect(canvas, 39, 11, 40, 15, "rust_dark")
    canvas = outline_edge(canvas, "soil_dark", keep_bottom=True)
    floor_shadow(canvas, 8, 38, 63, 47)
    return canvas


def stool():
    """A stool, 20x20: a round seat of one board on three legs with a stretcher."""
    canvas = blank(20, 20)
    seat = forms.ellipse(20, 20, 10, 4.5, 9.5, 4.5)
    forms.shade(canvas, seat, OAK, radius=2)
    grain(canvas, 4, 3, 15, 7, "soil_mid", 162, count=3)
    rect(canvas, 1, 8, 18, 9, "soil")
    for x0, x1 in ((2, 3), (15, 16), (9, 10)):
        rect(canvas, x0, 10, x1, 19, "soil_mid")
        rect(canvas, x0, 10, x0, 19, "soil_light" if x0 < 10 else "soil_mid")
        rect(canvas, x1, 10, x1, 19, "soil")
    rect(canvas, 4, 14, 14, 14, "soil")
    canvas = outline_edge(canvas, "soil_dark", keep_bottom=True)
    floor_shadow(canvas, 5, 13, 19, 19)
    return canvas


def bench():
    """A bench 2x1 tiles: a plank seat on two pairs of legs with a stretcher."""
    canvas = blank(2 * T, T)
    planked_top(canvas, 0, 5, 63, 14, 5, 163)
    rect(canvas, 0, 5, 63, 5, "sand_light")
    rect(canvas, 0, 15, 63, 17, "soil_mid")
    rect(canvas, 0, 15, 63, 15, "soil_light")
    rect(canvas, 0, 18, 63, 18, "soil")
    for x in (3, 56):
        turned_leg(canvas, x, 19, 31)
    rect(canvas, 7, 24, 55, 25, "soil")
    rect(canvas, 7, 24, 55, 24, "soil_mid")
    canvas = outline_edge(canvas, "soil_dark", keep_bottom=True)
    floor_shadow(canvas, 6, 21, 63, 31)
    return canvas


def wall_bench():
    """A bench 2x1 tiles along the back wall: a back of turned spindles under a rail, standing
    on the wall above the footprint, and a plank seat on four legs."""
    canvas = blank(2 * T, T + 16)
    # The back: a rail and spindles, the wall showing between them in their shadow.
    rect(canvas, 0, 0, 63, 3, "soil_mid")
    rect(canvas, 0, 0, 63, 0, "soil_light")
    rect(canvas, 0, 3, 63, 3, "soil")
    for x in range(2, 62, 6):
        rect(canvas, x, 4, x + 2, 17, "soil_mid")
        rect(canvas, x, 4, x, 17, "soil_light")
        rect(canvas, x + 2, 4, x + 2, 17, "soil")
        rect(canvas, x, 10, x + 2, 10, "soil_dark")
    # The seat, seen from above, and its front edge.
    planked_top(canvas, 0, 18, 63, 29, 6, 164)
    rect(canvas, 0, 18, 63, 18, "soil_mid")
    rect(canvas, 0, 30, 63, 32, "soil_mid")
    rect(canvas, 0, 30, 63, 30, "soil_light")
    rect(canvas, 0, 33, 63, 33, "soil")
    for x in (3, 56):
        turned_leg(canvas, x, 34, 47)
    rect(canvas, 7, 40, 55, 41, "soil")
    rect(canvas, 7, 40, 55, 40, "soil_mid")
    canvas = outline_edge(canvas, "soil_dark", keep_bottom=True)
    floor_shadow(canvas, 6, 37, 63, 47)
    return canvas


def pieces():
    """The tables and seats by name: their picture and their footprint in tiles."""
    return {
        "table": (table(), (2, 1)),
        "stool": (stool(), (1, 1)),
        "bench": (bench(), (2, 1)),
        "wall_bench": (wall_bench(), (2, 1)),
    }
