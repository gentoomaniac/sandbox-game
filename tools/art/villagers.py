"""The villagers' layers (assets/character/<slot>_<variant>.png), drawn like the player's.

The villagers (game/state/npc.gd) are put together from the same kind of layer sheets as the
player: the same 16x32 frames, facings and walk (see character.py), so any layer fits any
figure and the player could wear them too. This module adds the women's dress of the period
(a laced bodice over the chemise, a long wool skirt, an apron, a shawl, a white cap or a
headscarf) and the other colours of the men's clothes, skins and hair. data/npcs.cfg says which
of them a villager is dressed in. Every colour is one of the palette's.
"""

from canvas import blank, rect
from character import (
    CHARACTER_HEIGHT,
    CHARACTER_WIDTH,
    SHIRT,
    draw_body,
    draw_hair,
    draw_hat,
    draw_jacket,
    draw_legs,
    draw_near_sleeve,
    draw_shirt,
    draw_waistcoat,
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
APRONS = {
    "white": {"base": "lime", "shade": "sand_light", "tie": "sand_light"},
    "blue": {"base": "water_light", "shade": "water", "tie": "water"},
}
# The white linen cap and the headscarves, each with the colour of its edge.
CAPS = {
    "coif": {"base": "lime", "light": "snow_light", "shade": "sand_light", "edge": "cream"},
    "scarf_red": WOOL["red"] | {"edge": "red_light"},
    "scarf_blue": WOOL["blue"] | {"edge": "water_light"},
}


def draw_bodice(facing, pose, base, light, shade, **_):
    """A laced bodice over the linen chemise, whose sleeves and neck show: laced up the front
    with a cream cord, closed at the back."""
    canvas = draw_shirt(facing, pose)
    sink = pose["sink"]
    if facing in ("down", "up"):
        rect(canvas, 6, 15 + sink, 10, 22 + sink, base)
        rect(canvas, 6, 15 + sink, 6, 21 + sink, light)
        rect(canvas, 10, 15 + sink, 10, 22 + sink, shade)
        rect(canvas, 6, 22 + sink, 10, 22 + sink, shade)
        if facing == "down":
            for y in (16, 18, 20):
                canvas[y + sink][7] = canvas[y + sink][9] = "cream"
                canvas[y + 1 + sink][8] = "cream"
    else:
        rect(canvas, 5, 15 + sink, 10, 22 + sink, base)
        rect(canvas, 5, 15 + sink, 5, 22 + sink, shade)
        rect(canvas, 10, 15 + sink, 10, 21 + sink, light)
        rect(canvas, 5, 22 + sink, 10, 22 + sink, shade)
        draw_near_sleeve(canvas, pose, SHIRT["base"], SHIRT["shade"])
    return canvas


def draw_skirt(facing, pose, base, light, shade, **_):
    """A long wool skirt from the waist to the ankles, flaring a little; its hem swings with
    the stride. Kneeling, it pools on the ground."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    if pose.get("kneel"):
        rect(canvas, 3, 25, 12, 30, base)
        rect(canvas, 3, 30, 12, 30, shade)
        rect(canvas, 11, 25, 12, 29, light)
        return canvas
    sink, stride = pose["sink"], pose["stride"]
    sway = (stride > 0) - (stride < 0)
    is_side = facing in ("left", "right")
    left, right = (5, 10) if is_side else (5, 11)
    for y in range(21 + sink, 29):
        widen = 1 if y >= 24 + sink else 0
        shift = sway if y >= 26 else 0
        rect(canvas, left - widen + shift, y, right + widen + shift, y, base)
        # Folds: lit to the front (or left), shaded to the back (or right), one down the middle.
        canvas[y][left - widen + shift] = shade if is_side else light
        canvas[y][right + widen + shift] = light if is_side else shade
        if y >= 24 + sink and not is_side:
            canvas[y][8 + shift] = shade
    rect(canvas, left - 1 + sway, 28, right + 1 + sway, 28, shade)
    return canvas


def draw_apron(facing, pose, base, shade, tie, **_):
    """A linen apron tied at the waist over the skirt: from behind only its ties and bow show."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    sink, stride = pose["sink"], pose["stride"]
    if pose.get("kneel"):
        rect(canvas, 9, 21 + sink, 11, 27, base)
        return canvas
    if facing == "up":
        rect(canvas, 6, 21 + sink, 10, 21 + sink, tie)
        rect(canvas, 7, 22 + sink, 9, 23 + sink, tie)
    elif facing == "down":
        rect(canvas, 6, 21 + sink, 10, 21 + sink, tie)
        rect(canvas, 6, 22 + sink, 10, 27, base)
        rect(canvas, 10, 22 + sink, 10, 27, shade)
        rect(canvas, 6, 27, 10, 27, shade)
    else:
        sway = (stride > 0) - (stride < 0)
        rect(canvas, 5, 21 + sink, 10, 21 + sink, tie)
        rect(canvas, 10, 22 + sink, 11, 27, base)
        rect(canvas, 11 + sway, 25, 11 + sway, 27, base)
        rect(canvas, 10, 27, 11 + sway, 27, shade)
    return canvas


def draw_shawl(facing, pose, base, light, shade, **_):
    """A wool shawl over the shoulders, crossed over the chest and tucked into the bodice; from
    behind its point hangs down the back."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    sink = pose["sink"]
    if facing == "down":
        rect(canvas, 5, 13 + sink, 11, 14 + sink, base)
        rect(canvas, 5, 13 + sink, 11, 13 + sink, light)
        for dy in range(4):
            canvas[15 + dy + sink][6 + dy // 2] = base
            canvas[15 + dy + sink][10 - dy // 2] = shade
        canvas[13 + sink][8] = "skin_shade"
    elif facing == "up":
        rect(canvas, 5, 13 + sink, 11, 15 + sink, base)
        rect(canvas, 6, 16 + sink, 10, 17 + sink, base)
        rect(canvas, 7, 18 + sink, 9, 19 + sink, base)
        canvas[20 + sink][8] = shade
        rect(canvas, 5, 13 + sink, 11, 13 + sink, light)
        rect(canvas, 10, 14 + sink, 10, 17 + sink, shade)
    else:
        rect(canvas, 5, 13 + sink, 10, 15 + sink, base)
        rect(canvas, 5, 13 + sink, 10, 13 + sink, light)
        rect(canvas, 5, 16 + sink, 6, 18 + sink, base)
        canvas[19 + sink][5] = shade
        rect(canvas, 9, 16 + sink, 10, 17 + sink, base)
        canvas[18 + sink][10] = shade
    return canvas


def draw_cap(facing, pose, base, light, shade, edge, **_):
    """A cap of cloth over the whole head but the face, the white linen coif or a headscarf: a
    turned edge frames the face, and behind it covers the hair down to the nape."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    sink = pose["sink"]
    rect(canvas, 5, 4 + sink, 11, 4 + sink, base)
    rect(canvas, 4, 5 + sink, 12, 6 + sink, base)
    rect(canvas, 5, 4 + sink, 7, 5 + sink, light)
    if facing == "down":
        rect(canvas, 5, 7 + sink, 11, 7 + sink, edge)
        for x in (3, 4, 12, 13):
            rect(canvas, x, 6 + sink, x, 10 + sink, base)
        rect(canvas, 3, 11 + sink, 4, 11 + sink, shade)
        rect(canvas, 12, 11 + sink, 13, 11 + sink, shade)
        rect(canvas, 4, 7 + sink, 4, 10 + sink, edge)
        rect(canvas, 12, 7 + sink, 12, 10 + sink, edge)
    elif facing == "up":
        rect(canvas, 3, 6 + sink, 13, 11 + sink, base)
        rect(canvas, 4, 12 + sink, 12, 12 + sink, shade)
        rect(canvas, 8, 7 + sink, 8, 11 + sink, shade)
        rect(canvas, 5, 7 + sink, 5, 9 + sink, light)
    else:
        rect(canvas, 3, 6 + sink, 9, 11 + sink, base)
        rect(canvas, 4, 12 + sink, 8, 12 + sink, shade)
        rect(canvas, 9, 5 + sink, 10, 10 + sink, edge)
        rect(canvas, 4, 7 + sink, 4, 10 + sink, light)
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
    result["head_felt_hat"] = (draw_hat, {"hat": "felt_hat"})
    for name, colours in CAPS.items():
        result[f"head_{name}"] = (draw_cap, colours)
    return result
