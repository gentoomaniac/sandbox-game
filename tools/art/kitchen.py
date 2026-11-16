"""The kitchen of the interiors: the hearth (assets/interior/hearth.png, and the flame strip
assets/fire/hearth.png that fire.py draws over it) and the plate rack (assets/interior/plate_rack.png).

The room, and the drawing all furniture shares (the grain of wood, the dithered shadow, the
plates), are in interior.py.
"""

import random

import fire
import forms
from canvas import blank, outline_edge, rect
from interior import T, dither, grain, plate

# The hearth stands against the back wall: its footprint is the lower half of its picture, and
# the upper half, the smoke hood, is drawn over the back wall.
HEARTH_WIDTH, HEARTH_HEIGHT = 2 * T, 4 * T
# The box of the hearth's picture that its flame burns in (x, y, width, height; the flame stands
# on its bottom row, over the logs), and the flame's half width and height.
HEARTH_FLAME = ((16, 52, 32, 44), 10.0, 28)


def hearth_without_flame():
    """An open hearth 2x2 tiles under a smoke hood: a raised hearth of buff brick with two logs
    on it and an iron pot beside them, and over it, on the back wall, a lime-washed hood on an
    oak mantel beam that takes the smoke up into the chimney. The wall under the hood is laid
    with Delft tiles, black with soot behind the fire."""
    canvas = blank(HEARTH_WIDTH, HEARTH_HEIGHT)
    # The hood: a shaft up into the ceiling beam, flaring out to the mantel, lit from the top
    # left, its right flank in shade.
    for y in range(0, 32):
        half = 12 if y < 10 else 12 + round((y - 9) * 20 / 22)
        rect(canvas, 32 - half, y, 31 + half, y, "lime")
        rect(canvas, 32 - half, y, 32 - half + 1, y, "snow_light")
        shade = max(4, half // 3)
        rect(canvas, 31 + half - shade, y, 31 + half, y, "sand_light")
        rect(canvas, 31 + half - shade - 1, y, 31 + half - shade - 1, y, "snow_shadow" if y % 3 else "sand_light")
    rect(canvas, 20, 0, 20, 9, "snow_shadow")
    # Soot creeps up from the mantel.
    rng = random.Random(171)
    for y in range(24, 32):
        for x in range(4, 60):
            if rng.random() < (y - 22) / 12:
                canvas[y][x] = "bare_light" if canvas[y][x] in ("lime", "snow_light") else "bare"
    # The mantel beam, with a lit top edge and grain.
    rect(canvas, 0, 32, 63, 39, "soil")
    rect(canvas, 0, 32, 63, 32, "soil_light")
    rect(canvas, 0, 33, 63, 34, "soil_mid")
    grain(canvas, 0, 35, 63, 38, "soil_mid", 172, count=6)
    rect(canvas, 0, 39, 63, 39, "soil_dark")
    # The wall under the hood, tiled, in the mantel's shadow and black with soot where the fire
    # licks it.
    delft_tiles(canvas, 2, 40, 61, 79)
    dither(canvas, 2, 40, 61, 43, "soil_dark")
    rect(canvas, 2, 40, 61, 41, "soil_dark")
    soot(canvas)
    # The brackets that carry the mantel.
    for x in (2, 56):
        rect(canvas, x, 40, x + 5, 45, "soil")
        rect(canvas, x + 2, 46, x + 5, 50, "soil")
        rect(canvas, x, 40, x + 5, 40, "soil_mid")
        rect(canvas, x + 5, 40, x + 5, 50, "soil_dark")
    # The raised hearth: its top, bricks seen from above, and its front of buff brick.
    rect(canvas, 0, 80, 63, 103, "sand")
    for y in range(80, 104, 4):
        rect(canvas, 0, y + 3, 63, y + 3, "mud")
        for x in range(2 + (y // 4) % 2 * 6, 64, 12):
            rect(canvas, x, y, x, y + 2, "mud")
            rect(canvas, x + 1, y, x + 4, y, "sand_light")
    rect(canvas, 0, 80, 63, 80, "sand_light")
    rect(canvas, 0, 103, 63, 103, "sand_light")
    rect(canvas, 0, 104, 63, 126, "sand")
    for y in range(104, 127, 4):
        rect(canvas, 0, y + 3, 63, y + 3, "mud")
        for x in range(1 + (y // 4) % 2 * 4, 64, 8):
            rect(canvas, x, y, x, y + 2, "mud")
        for x in range(2 + (y // 4) % 2 * 4, 64, 8):
            rect(canvas, x, y, x + 2, y, "sand_light")
    rect(canvas, 0, 104, 63, 104, "mud_dark")
    rect(canvas, 0, 127, 63, 127, "mud_dark")
    # The ash bed and the logs, the flame stands on them (its box ends at row 95).
    ash = forms.ellipse(HEARTH_WIDTH, HEARTH_HEIGHT, 32, 94, 15, 5)
    forms.paint(canvas, ash, "stone")
    forms.paint(canvas, forms.shrunk(ash), "stone_dark")
    for (x0, y0), (x1, y1) in (((20, 95), (42, 91)), ((22, 90), (44, 95))):
        log = forms.capsule(HEARTH_WIDTH, HEARTH_HEIGHT, (x0, y0), (x1, y1), 2.5)
        forms.shade(canvas, log, ("soil_dark", "soil", "soil_mid"), radius=2)
    for x, y in ((19, 95), (44, 96)):
        rect(canvas, x, y - 1, x + 1, y, "ember")
        canvas[y - 1][x] = "flame"
    # A three-legged iron pot, a brass glint on its lid.
    pot = forms.ellipse(HEARTH_WIDTH, HEARTH_HEIGHT, 54, 89, 6, 6)
    forms.shade(canvas, pot, ("ink", "stone_dark", "stone"), radius=2)
    rect(canvas, 49, 82, 59, 83, "ink")
    rect(canvas, 50, 82, 58, 82, "stone_dark")
    canvas[81][53] = canvas[81][54] = "ochre"
    for x in (49, 58):
        rect(canvas, x, 95, x, 98, "ink")
    return outline_edge(canvas, "soil_dark", keep_bottom=True)


def delft_tiles(canvas, x0, y0, x1, y1):
    """Blue-and-white Delft tiles over x0..x1, y0..y1, 8 px square: white with a blue flower in
    the middle and blue corner ornaments where four tiles meet, in grey-blue joints."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            across, down = (x - x0) % 8, (y - y0) % 8
            middle = abs(across - 3.5) + abs(down - 3.5)
            if across == 7 or down == 7:
                colour = "snow_shadow"
            elif middle <= 1:
                colour = "water_deep"
            elif across in (0, 6) and down in (0, 6):
                colour = "water"
            elif middle <= 2 and (across == 3 or across == 4 or down == 3 or down == 4):
                colour = "water"
            else:
                colour = "lime"
            canvas[y][x] = colour


def soot(canvas):
    """The soot on the wall behind the fire: a black core that fades out upwards in ragged
    edges."""
    rng = random.Random(173)
    for y in range(44, 80):
        half = 4 + (y - 44) * 8 // 35
        for x in range(32 - half - 3, 32 + half + 3):
            inside = abs(x + 0.5 - 32) < half
            if inside and y >= 58:
                canvas[y][x] = "ink"
            elif inside or rng.random() < 0.5:
                canvas[y][x] = "stone_dark"


def hearth_layers():
    """The hearth without its flame: what is behind the flame and what is in front of it
    (nothing: the fire stands free on the hearth)."""
    return hearth_without_flame(), blank(HEARTH_WIDTH, HEARTH_HEIGHT)


def hearth():
    """The open hearth with a fire on it: the first frame of its flame (fire.strip)."""
    return fire.burning(*hearth_layers(), *HEARTH_FLAME)


def plate_rack():
    """A plate rack 1x2 tiles, hung on the back wall: an oak back with a carved crest and two
    shelves, each with a rail in front, holding a Delft plate and a pewter one."""
    canvas = blank(T, 2 * T)
    rect(canvas, 2, 8, 29, 52, "soil")
    for x in range(4, 28, 4):
        rect(canvas, x, 12, x, 50, "soil_dark")
    # The crest.
    for y in range(4, 9):
        half = 7 + (y - 4) * 2
        rect(canvas, 16 - half, y, 15 + half, y, "soil_mid")
    rect(canvas, 9, 4, 22, 4, "soil_light")
    canvas[6][15] = canvas[6][16] = "soil_dark"
    for top, plates in ((12, ("delft", "pewter")), (32, ("pewter", "delft"))):
        for cx, kind in zip((10, 21), plates):
            plate(canvas, cx, top + 6, kind)
        # The shelf the plates stand on and the rail that holds them.
        rect(canvas, 2, top + 12, 29, top + 14, "soil_mid")
        rect(canvas, 2, top + 12, 29, top + 12, "soil_light")
        rect(canvas, 2, top + 14, 29, top + 14, "soil")
        rect(canvas, 3, top + 8, 28, top + 9, "soil_mid")
        rect(canvas, 3, top + 8, 28, top + 8, "soil_light")
    for x0, x1 in ((2, 3), (28, 29)):
        rect(canvas, x0, 8, x1, 52, "soil_mid")
    rect(canvas, 2, 8, 2, 52, "soil_light")
    canvas = outline_edge(canvas, "soil_dark")
    dither(canvas, 4, 53, 30, 55, "sand")
    return canvas


def pieces():
    """The kitchen's furniture by name: its picture and its footprint in tiles."""
    return {
        "hearth": (hearth(), (2, 2)),
        "plate_rack": (plate_rack(), (1, 2)),
    }
