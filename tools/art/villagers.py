"""The villagers' layers (assets/character/<slot>_<variant>.png), drawn like the player's.

The villagers (game/state/npc.gd) are put together from the same kind of layer sheets as the
player: the same 32x64 frames, facings and walk on the same figure (see character.py), so any
layer fits any figure and the player could wear them too. This module adds the women's dress of
the period (a laced bodice over the chemise, a long wool skirt, an apron, a shawl, a white coif
or a headscarf), and the other colours of the men's clothes, skins and hair. data/npcs.cfg says which of them a villager is dressed in. Every colour
is one of the palette's.
"""

import forms
from canvas import blank
from character import (
    CHARACTER_HEIGHT,
    CHARACTER_WIDTH,
    FELT,
    SHIRT,
    STRAW_HAT_SHAPES,
    WAIST,
    Figure,
    draw_body,
    draw_hair,
    draw_hat,
    draw_jacket,
    draw_legs,
    draw_shirt,
    draw_sleeves,
    draw_waistcoat,
    mask,
    ramp,
)

# The skins besides the player's ("0"): light, base of the face and its shade.
SKINS = {
    "fair": {"skin": "cream", "shade": "skin"},
    "tanned": {"skin": "skin_shade", "shade": "soil_light"},
    "dark": {"skin": "soil_light", "shade": "soil_mid"},
}
HAIR_COLOURS = {
    "brown": {"base": "soil", "light": "soil_light", "shade": "soil_dark"},
    "blond": {"base": "straw", "light": "gold", "shade": "reed"},
    "red": {"base": "rust", "light": "maple_light", "shade": "rust_dark"},
    "grey": {"base": "stone_light", "light": "lime", "shade": "stone"},
    "black": {"base": "soil_dark", "light": "soil", "shade": "ink"},
}
HAIR_STYLES = ("short", "long", "tied", "bun", "plaits")

# Dyed wool: madder red, indigo, plant green, undyed brown and black, and heather.
WOOL = {
    "red": {"base": "rust", "light": "red_light", "shade": "rust_dark"},
    "blue": {"base": "water", "light": "water_light", "shade": "water_deep"},
    "green": {"base": "olive", "light": "dry_light", "shade": "green_deep"},
    "brown": {"base": "soil_mid", "light": "soil_light", "shade": "soil"},
    "black": {"base": "stone_dark", "light": "stone", "shade": "ink"},
    "heather": {"base": "heather", "light": "petal", "shade": "heather_dark"},
}
# The men's clothes besides the player's red waistcoat ("clothes_0"), brown breeches ("legs_0")
# and blue jacket ("coat_jacket").
WAISTCOATS = ("blue", "green", "brown", "black")
BREECHES = {
    "leather": {"base": "sand", "light": "sand_light", "shade": "mud", "band": "mud_dark"},
    "black": {"base": "stone_dark", "light": "stone", "shade": "ink", "band": "ink"},
    "blue": {"base": "water_deep", "light": "water", "shade": "ink", "band": "ink"},
}
JACKETS = ("brown", "black")
BODICES = ("red", "blue", "green", "black")
SKIRTS = ("red", "blue", "brown", "black", "heather")
SHAWLS = {
    "red": WOOL["red"],
    "cream": {"base": "cream", "light": "lime", "shade": "sand_light"},
    "heather": WOOL["heather"],
}
# The aprons: white or blue linen.
APRONS = {
    "white": {"base": "lime", "light": "snow_light", "shade": "sand_light", "tie": "sand_light"},
    "blue": {"base": "water_light", "light": "foam", "shade": "water", "tie": "water"},
}
# The white linen coif and the headscarves, each with the colour of its turned edge.
CAPS = {
    "coif": {"base": "lime", "light": "snow_light", "shade": "sand_light", "edge": "snow_light"},
    "scarf_red": WOOL["red"] | {"edge": "red_light"},
    "scarf_blue": WOOL["blue"] | {"edge": "water_light"},
}
# The cord that laces a bodice.
LACING = "cream"


def draw_bodice(facing, pose, base, light, shade, **_):
    """A laced bodice with straps over the linen chemise, whose sleeves and neck show: laced up
    the front with a cream cord, closed at the back."""
    canvas = draw_shirt(facing, pose)
    figure = Figure(facing, pose)
    top = figure.top
    shades = (shade, base, light)
    if figure.is_side:
        forms.shade(canvas, mask(forms.polygon, [(11, 30 + top), (20, 30 + top), (21, 44 + top), (11, 44 + top)]), shades, 2)
        forms.paint(canvas, mask(forms.box, 14, 26 + top, 15, 30 + top), base)
        for y in range(32, 43, 2):
            forms.dots(canvas, [(20, y + top)], LACING)
    else:
        forms.shade(canvas, mask(forms.rounded_box, 10, 30 + top, 21, 44 + top), shades, 2)
        for x in (11, 12, 19, 20):
            forms.dots(canvas, [(x, y + top) for y in range(26, 30)], light if x < 16 else base)
        if facing == "down":
            for y in range(31, 43, 2):
                forms.dots(canvas, [(15, y + top), (16, y + 1 + top)], LACING)
                forms.dots(canvas, [(16, y + top), (15, y + 1 + top)], shade)
    draw_sleeves(canvas, figure, ramp(SHIRT))
    return canvas


def draw_skirt(facing, pose, base, light, shade, **_):
    """A long wool skirt from the waist to the ankles, falling in folds; its hem swings with the
    stride. Kneeling, it pools on the ground."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    figure = Figure(facing, pose)
    top = figure.top
    shades = (shade, base, light)
    if pose.get("kneel"):
        forms.shade(canvas, mask(forms.polygon, [(10, 50), (22, 50), (27, 62), (4, 62)]), shades, 3)
        forms.dots(canvas, [(x, 62) for x in range(5, 27)], shade)
        return canvas
    stride = pose["stride"]
    sway = (stride > 0) - (stride < 0)
    if figure.is_side:
        outline = [(11, WAIST + top), (21, WAIST + top), (23, 50), (24 + sway, 58), (8 + sway, 58), (9, 50)]
        folds = ((12, 46), (16, 44), (20, 47))
    else:
        outline = [(9, WAIST + top), (22, WAIST + top), (24, 50), (25 + sway, 58), (6 + sway, 58), (7, 50)]
        folds = ((10, 47), (13, 45), (18, 45), (21, 47))
    forms.shade(canvas, mask(forms.polygon, outline), shades, 4)
    for x, fold_top in folds:
        for y in range(fold_top, 58):
            forms.dots(canvas, [(x + (sway if y > 52 else 0), y)], shade)
    forms.dots(canvas, [(x, 58) for x in range(6, 26) if canvas[58][x] is not None], shade)
    return canvas


def draw_apron(facing, pose, base, light, shade, tie, **_):
    """A linen apron tied at the waist over the skirt: from behind only its ties and bow show."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    figure = Figure(facing, pose)
    top = figure.top
    shades = (shade, base, light)
    if pose.get("kneel"):
        cloth = mask(forms.polygon, [(17, 51), (24, 51), (26, 60), (19, 60)])
    elif facing == "up":
        forms.paint(canvas, mask(forms.box, 9, WAIST + top, 22, WAIST + 1 + top), tie)
        forms.paint(canvas, mask(forms.ellipse, 14, 43 + top, 2, 1.5) | mask(forms.ellipse, 18, 43 + top, 2, 1.5), tie)
        forms.paint(canvas, mask(forms.capsule, (15.5, 43 + top), (14, 50 + top), 1, 0.8) | mask(forms.capsule, (16.5, 43 + top), (18, 50 + top), 1, 0.8), tie)
        return canvas
    elif figure.is_side:
        sway = (pose["stride"] > 0) - (pose["stride"] < 0)
        forms.paint(canvas, mask(forms.box, 11, WAIST + top, 21, WAIST + 1 + top), tie)
        cloth = mask(forms.polygon, [(18, WAIST + 2 + top), (21, WAIST + 2 + top), (23, 50), (24 + sway, 56), (20 + sway, 56), (18, 49)])
    else:
        forms.paint(canvas, mask(forms.box, 9, WAIST + top, 22, WAIST + 1 + top), tie)
        cloth = mask(forms.rounded_box, 11, WAIST + 2 + top, 20, 56)
    forms.shade(canvas, cloth, shades, 2)
    return canvas


def draw_shawl(facing, pose, base, light, shade, **_):
    """A wool shawl over the shoulders, crossed over the chest and tucked into the bodice; from
    behind its point hangs down the back."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    figure = Figure(facing, pose)
    top = figure.top
    shades = (shade, base, light)
    if facing == "down":
        shawl = mask(forms.polygon, [(8, 26 + top), (23, 26 + top), (23, 30 + top), (17, 38 + top), (15, 38 + top), (8, 30 + top)])
        shawl &= ~mask(forms.polygon, [(13, 26 + top), (18, 26 + top), (16, 30 + top), (15, 30 + top)])
        forms.shade(canvas, shawl, shades, 2)
        # Where the ends cross.
        forms.dots(canvas, [(16 + d, 31 + d + top) for d in range(6)], shade)
    elif facing == "up":
        forms.shade(canvas, mask(forms.polygon, [(8, 26 + top), (23, 26 + top), (23, 30 + top), (16, 41 + top), (15, 41 + top), (8, 30 + top)]), shades, 3)
        forms.dots(canvas, [(16, y + top) for y in range(30, 40)], shade)
    else:
        forms.shade(canvas, mask(forms.polygon, [(10, 26 + top), (19, 26 + top), (21, 31 + top), (19, 37 + top), (16, 32 + top), (11, 35 + top), (9, 30 + top)]), shades, 2)
    return canvas


def draw_cap(facing, pose, base, light, shade, edge, **_):
    """A cap of cloth over the whole head but the face, the white linen coif or a headscarf: a
    turned edge frames the face, and behind it covers the hair down to the nape."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    figure = Figure(facing, pose)
    top = figure.top
    cx, cy = figure.head
    shades = (shade, base, light)
    if facing == "down":
        face = mask(forms.ellipse, cx, cy + 2.5, 6.6, 7.2)
        cap = mask(forms.ellipse, cx, cy - 1.5, 9.2, 8.6) & mask(forms.box, 0, 0, 31, 23 + top) & ~face
        forms.shade(canvas, cap, shades, 3)
        forms.paint(canvas, cap & mask(forms.ellipse, cx, cy + 2.5, 7.6, 8.2), edge)
    elif facing == "up":
        cap = mask(forms.ellipse, cx, cy - 1, 9, 8.8) & mask(forms.box, 0, 0, 31, 24 + top)
        cap |= mask(forms.rounded_box, 10, 20 + top, 21, 25 + top)
        forms.shade(canvas, cap, shades, 3)
        forms.dots(canvas, [(x, 22 + top) for x in range(11, 21)], shade)
    else:
        face = mask(forms.ellipse, cx + 5, cy + 1, 6.2, 7.2)
        cap = mask(forms.ellipse, cx - 1, cy - 3.5, 8.2, 7.8) | mask(forms.ellipse, cx - 6.5, cy - 0.5, 3.6, 4.2)
        cap |= mask(forms.box, 9, 15 + top, 15, 25 + top)
        cap &= ~face
        forms.shade(canvas, cap, shades, 3)
        forms.paint(canvas, cap & mask(forms.ellipse, cx + 5, cy + 1, 7.2, 8.2), edge)
        # The seam where the crown piece meets the band.
        forms.dots(canvas, [(15, y + top) for y in range(11, 21)], shade)
    return canvas


def layers():
    """The villagers' layer sheets by file name, each as the function that draws it and the
    colours of its variant (like `character.layers`)."""
    result = {}
    for name, colours in SKINS.items():
        result[f"body_{name}"] = (draw_body, colours)
    for style in HAIR_STYLES:
        for colour, colours in HAIR_COLOURS.items():
            result[f"hair_{style}_{colour}"] = (draw_hair, colours | {"style": style})
    for colour in WAISTCOATS:
        result[f"clothes_waistcoat_{colour}"] = (draw_waistcoat, WOOL[colour])
    for colour in BODICES:
        result[f"clothes_bodice_{colour}"] = (draw_bodice, WOOL[colour])
    for name, colours in BREECHES.items():
        result[f"legs_breeches_{name}"] = (draw_legs, colours)
    for colour in SKIRTS:
        result[f"legs_skirt_{colour}"] = (draw_skirt, WOOL[colour])
    for name, colours in APRONS.items():
        result[f"apron_{name}"] = (draw_apron, colours)
    for colour in JACKETS:
        result[f"coat_jacket_{colour}"] = (draw_jacket, WOOL[colour])
    for name, colours in SHAWLS.items():
        result[f"coat_shawl_{name}"] = (draw_shawl, colours)
    result["head_felt_hat"] = (draw_hat, {"shapes": STRAW_HAT_SHAPES, "colours": FELT})
    for name, colours in CAPS.items():
        result[f"head_{name}"] = (draw_cap, colours)
    return result
