"""Portraits for the chat (assets/character/portrait/<slot>_<variant>.png): head and shoulders,
facing the viewer, one 32x32 picture per layer, drawn from the same colours as the layer's sheet.

The game lays a figure's portrait layers over each other in the order of its sheets (see
game/state/appearance.gd), so a villager's portrait wears what the villager wears. Only the
layers that show in a bust have one: the body, clothes, coat, hair and head; the legs, feet,
apron and the held tool do not. Like the sheets, only the outer silhouette has the ink outline.

The bust: the head 12 px wide (x 10..21) from y 6 to the chin at y 19, the neck below it, and the
shoulders from y 22 down to the bottom edge, where the picture is cut off.
"""

from canvas import blank, rect
from character import (
    HATS,
    JACKET,
    SHIRT,
    WAISTCOAT,
    draw_body,
    draw_hair,
    draw_hat,
    draw_jacket,
    draw_rows,
    draw_shirt,
    draw_waistcoat,
    outlined,
    pixels_of,
)
from villagers import draw_bodice, draw_cap, draw_shawl

PORTRAIT_SIZE = 32
# The colour of the lips and cheeks; on the darkest skin, the cheeks are its own shade.
MOUTH = "rust_dark"
CHEEKS = "petal"
EYES = "soil_dark"
EYE_WHITE = "lime"


def portrait_body(skin="skin", shade="skin_shade", **_):
    """The head with its face, the neck and the shoulders in the linen undershirt."""
    canvas = blank(PORTRAIT_SIZE)
    # The head: rounded at the crown and narrowing to the chin.
    rect(canvas, 12, 6, 19, 6, skin)
    rect(canvas, 11, 7, 20, 7, skin)
    rect(canvas, 10, 8, 21, 17, skin)
    rect(canvas, 11, 18, 20, 18, skin)
    rect(canvas, 12, 19, 19, 19, shade)
    rect(canvas, 21, 9, 21, 17, shade)
    # Ears.
    rect(canvas, 9, 12, 9, 14, skin)
    rect(canvas, 22, 12, 22, 14, shade)
    # The face: brows, eyes with their whites, the nose's shadow, cheeks and mouth.
    rect(canvas, 12, 10, 14, 10, shade)
    rect(canvas, 17, 10, 19, 10, shade)
    for white, pupil in ((12, 13), (19, 18)):
        canvas[12][white] = EYE_WHITE
        rect(canvas, pupil, 12, pupil, 13, EYES)
    rect(canvas, 16, 13, 16, 15, shade)
    canvas[15][15] = shade
    canvas[15][12] = canvas[15][19] = CHEEKS if skin != "soil_light" else shade
    rect(canvas, 14, 17, 17, 17, MOUTH)
    # The neck, shaded under the chin.
    rect(canvas, 14, 20, 17, 22, skin)
    rect(canvas, 14, 20, 17, 20, shade)
    # The shoulders in the undershirt, rounded at the top corners.
    rect(canvas, 8, 22, 23, 22, "sand_light")
    rect(canvas, 5, 23, 26, 23, "sand_light")
    rect(canvas, 4, 24, 27, 31, "sand_light")
    rect(canvas, 14, 22, 17, 23, skin)
    rect(canvas, 8, 25, 8, 31, "sand")
    rect(canvas, 23, 25, 23, 31, "sand")
    return canvas


def _torso(canvas, colour):
    """Fills the shoulders and chest with `colour`."""
    rect(canvas, 8, 22, 23, 22, colour)
    rect(canvas, 5, 23, 26, 23, colour)
    rect(canvas, 4, 24, 27, 31, colour)


def _arm_seams(canvas, colour):
    """The lines where the arms hang beside the chest."""
    rect(canvas, 8, 25, 8, 31, colour)
    rect(canvas, 23, 25, 23, 31, colour)


def portrait_shirt(**_):
    """The linen shirt, open at the neck."""
    canvas = blank(PORTRAIT_SIZE)
    _torso(canvas, SHIRT["base"])
    _arm_seams(canvas, SHIRT["shade"])
    rect(canvas, 4, 24, 4, 31, SHIRT["shade"])
    # The open neck, a V of skin shade, and the collar either side of it.
    rect(canvas, 14, 22, 17, 22, None)
    rect(canvas, 15, 23, 16, 24, "skin_shade")
    rect(canvas, 13, 22, 13, 23, SHIRT["shade"])
    rect(canvas, 18, 22, 18, 23, SHIRT["shade"])
    return canvas


def portrait_waistcoat(**colours):
    """The shirt under the waistcoat, buttoned up to a V at the chest."""
    waistcoat = WAISTCOAT | colours
    canvas = portrait_shirt()
    rect(canvas, 9, 25, 22, 31, waistcoat["base"])
    rect(canvas, 9, 24, 13, 24, waistcoat["base"])
    rect(canvas, 18, 24, 22, 24, waistcoat["base"])
    rect(canvas, 9, 24, 9, 31, waistcoat["light"])
    rect(canvas, 22, 24, 22, 31, waistcoat["shade"])
    for x, y in ((14, 25), (17, 25), (15, 26), (16, 26)):
        canvas[y][x] = SHIRT["base"]
    for y in (28, 30):
        canvas[y][15] = waistcoat["button"]
    return canvas


def portrait_bodice(base, light, shade, **_):
    """The chemise with its round neck, and the bodice laced over it."""
    canvas = portrait_shirt()
    rect(canvas, 15, 23, 16, 24, SHIRT["base"])
    rect(canvas, 14, 22, 17, 22, None)
    rect(canvas, 10, 26, 21, 31, base)
    rect(canvas, 10, 26, 10, 31, light)
    rect(canvas, 21, 26, 21, 31, shade)
    for y in (27, 29, 31):
        canvas[y][14] = canvas[y][17] = "cream"
        if y < 31:
            canvas[y + 1][15] = canvas[y + 1][16] = "cream"
    return canvas


def portrait_jacket(**colours):
    """The short jacket, open over what is under it, with its collar turned down."""
    jacket = JACKET | colours
    canvas = blank(PORTRAIT_SIZE)
    _torso(canvas, jacket["base"])
    rect(canvas, 11, 24, 20, 31, None)
    rect(canvas, 12, 22, 19, 23, None)
    rect(canvas, 10, 22, 11, 26, jacket["light"])
    rect(canvas, 20, 22, 21, 26, jacket["shade"])
    rect(canvas, 5, 23, 9, 23, jacket["light"])
    rect(canvas, 22, 23, 26, 23, jacket["light"])
    _arm_seams(canvas, jacket["shade"])
    return canvas


def portrait_shawl(base, light, shade, **_):
    """The shawl round the shoulders, its ends crossed over the chest."""
    canvas = blank(PORTRAIT_SIZE)
    rect(canvas, 8, 22, 13, 22, base)
    rect(canvas, 18, 22, 23, 22, base)
    rect(canvas, 5, 23, 26, 25, base)
    rect(canvas, 5, 23, 26, 23, light)
    rect(canvas, 14, 23, 17, 23, None)
    for dy in range(6):
        rect(canvas, 10 + dy, 26 + dy, 12 + dy, 26 + dy, base)
        rect(canvas, 19 - dy, 26 + dy, 21 - dy, 26 + dy, shade)
    rect(canvas, 4, 24, 4, 31, base)
    rect(canvas, 27, 24, 27, 31, shade)
    return canvas


def portrait_hair(base, light, shade, style, **_):
    """The hair of each style (see `character.draw_hair`) seen from the front."""
    canvas = blank(PORTRAIT_SIZE)
    # Over the crown and down the sides to the ears.
    rect(canvas, 12, 4, 19, 4, base)
    rect(canvas, 10, 5, 21, 5, base)
    rect(canvas, 9, 6, 22, 8, base)
    rect(canvas, 9, 9, 10, 11, base)
    rect(canvas, 21, 9, 22, 11, base)
    rect(canvas, 12, 5, 15, 5, light)
    rect(canvas, 11, 6, 12, 6, light)
    rect(canvas, 11, 9, 20, 9, shade)
    rect(canvas, 11, 8, 11, 9, base)
    if style in ("short", "tied"):
        # A fringe over the forehead.
        rect(canvas, 12, 9, 15, 9, base)
        canvas[9][19] = base
    if style in ("bun", "plaits"):
        rect(canvas, 15, 4, 16, 8, shade)
        rect(canvas, 11, 9, 20, 9, shade)
    if style == "long":
        for x0 in (8, 21):
            rect(canvas, x0, 9, x0 + 2, 24, base)
            rect(canvas, x0, 22, x0 + 2, 24, shade)
        rect(canvas, 9, 12, 9, 20, light)
        rect(canvas, 21, 12, 21, 21, shade)
    if style == "tied":
        rect(canvas, 23, 13, 24, 18, base)
        rect(canvas, 23, 13, 24, 13, "ink")
    if style == "bun":
        rect(canvas, 13, 1, 18, 3, base)
        rect(canvas, 14, 1, 15, 1, light)
        rect(canvas, 13, 3, 18, 3, shade)
    if style == "plaits":
        for x in (9, 22):
            for y in range(12, 27):
                rect(canvas, x - 1 + (y % 2), y, x + (y % 2), y, base if y % 2 else shade)
            rect(canvas, x - 1, 27, x, 28, "rust")
    return canvas


# The hats from the front, 32 px wide; row 0 is y 0 of the portrait.
STRAW_HAT_ROWS = (
    "................................",
    "................................",
    "...........llbbbbbbs............",
    "..........lbbbbbbbbbbs..........",
    ".........lbbbbbbbbbbbbs.........",
    ".........dddddddddddddd.........",
    "....llllllllbbbbbbbbbbbbbbbs....",
    "..lbbbbbbbbbbbbbbbbbbbbbbbbbbs..",
    "..ss........................ss..",
)
KNITTED_CAP_ROWS = (
    "................................",
    "................................",
    "............lrrrrrr.............",
    "..........lrrrrrrrrrd...........",
    ".........lrrrrrrrrrrrdrrr.......",
    ".........rrrrrrrrrrrrrdrrrr.....",
    ".........rrrrrrrrrrrrrr..dd.....",
    ".........cccccccccccccc.........",
    ".........dkdkdkdkdkdkdk.........",
)
PORTRAIT_HATS = {"straw_hat": STRAW_HAT_ROWS, "knitted_cap": KNITTED_CAP_ROWS, "felt_hat": STRAW_HAT_ROWS}


def portrait_hat(hat, **_):
    """A hat of `character.HATS` from the front, in the same colours."""
    _rows, keys = HATS[hat]
    canvas = blank(PORTRAIT_SIZE)
    draw_rows(canvas, PORTRAIT_HATS[hat], keys, 0)
    return canvas


def portrait_cap(base, light, shade, edge, **_):
    """The coif or headscarf: over the crown and down beside the face to the jaw, with its
    turned edge framing the face."""
    canvas = blank(PORTRAIT_SIZE)
    rect(canvas, 12, 3, 19, 3, base)
    rect(canvas, 10, 4, 21, 4, base)
    rect(canvas, 8, 5, 23, 8, base)
    rect(canvas, 7, 9, 10, 17, base)
    rect(canvas, 21, 9, 24, 17, base)
    rect(canvas, 8, 18, 10, 18, shade)
    rect(canvas, 21, 18, 23, 18, shade)
    rect(canvas, 12, 4, 15, 5, light)
    rect(canvas, 23, 6, 24, 17, shade)
    rect(canvas, 10, 8, 21, 8, edge)
    rect(canvas, 10, 9, 10, 17, edge)
    rect(canvas, 21, 9, 21, 17, edge)
    return canvas


# Each layer sheet's drawing, and the portrait drawn for it with the same colours.
PORTRAIT_OF = {
    draw_body: portrait_body,
    draw_shirt: portrait_shirt,
    draw_waistcoat: portrait_waistcoat,
    draw_bodice: portrait_bodice,
    draw_jacket: portrait_jacket,
    draw_shawl: portrait_shawl,
    draw_hair: portrait_hair,
    draw_hat: portrait_hat,
    draw_cap: portrait_cap,
}


def portraits(layer_sheets):
    """The portraits of the layers in `layer_sheets` (name to the sheet's drawing and colours, as
    `character.layers`) that show in a bust, by name, outlined like the sheets."""
    body_pixels = pixels_of(portrait_body())
    result = {}
    for name, (draw, colours) in layer_sheets.items():
        if draw in PORTRAIT_OF:
            picture = PORTRAIT_OF[draw](**colours)
            result[name] = outlined(picture, set() if draw is draw_body else body_pixels)
    return result
