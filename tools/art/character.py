"""The player character (assets/character/<slot>_<variant>.png).

One sheet per layer and variant, all with the same layout: 16x32 frames, one row per
facing (down, up, left, right), columns idle, walk 1..4. Drawn for "right" and "left" is
its mirror image. The layers are drawn in the same coordinates, so any combination lines
up; game/state/appearance.gd says which are worn and in what order.

The figure is 28 rows tall (outline included, y 4..31, feet on the bottom row): head 8
rows (y 5..12), torso 10 (13..22), legs 8 (23..30). Only the outer silhouette has the ink
outline; inside it, parts are separated by darker shades of their own colour.
"""

from canvas import NEIGHBOURS, blank, rect

CHARACTER_WIDTH = 16
CHARACTER_HEIGHT = 32
PLAYER_FACINGS = ("down", "up", "left", "right")
PLAYER_FRAMES = ("idle", "walk1", "walk2", "walk3", "walk4")

# The hair variants: a base colour with a light and a shade, and the style (see `draw_hair`).
HAIR_STYLES = {
    "0": {"base": "soil", "light": "soil_light", "shade": "soil_dark", "style": "short"},
    "1": {"base": "straw", "light": "gold", "shade": "reed", "style": "long"},
    "2": {"base": "soil_mid", "light": "soil_light", "shade": "soil", "style": "tied"},
}
# The ribbon that ties back the "tied" hair.
HAIR_RIBBON = "ink"

# The undershirt and shorts that the bare body wears.
UNDERSHIRT = "sand_light"
UNDERSHIRT_SHADE = "sand"
SHORTS = "mud"

# A walk is two contact frames (walk 1 and 3: the hips sink, the legs spread) and two
# passing frames (walk 2 and 4: one leg swings through). `lift` is how far each of the two
# legs is raised (the far or left leg first), `stride` how far the near leg is ahead in a
# side view and `swing` how far the near arm swings against it.
POSES = {
    "idle": {"sink": 0, "lift": (0, 0), "stride": 0, "swing": 0},
    "walk1": {"sink": 1, "lift": (0, 0), "stride": 2, "swing": -2},
    "walk2": {"sink": 0, "lift": (1, 0), "stride": 0, "swing": 0},
    "walk3": {"sink": 1, "lift": (0, 0), "stride": -2, "swing": 2},
    "walk4": {"sink": 0, "lift": (0, 1), "stride": 0, "swing": 0},
}
# Passing out (see `collapse_sheet`): kneeling, the figure sinks onto its folded legs (see
# `draw_kneeling_legs`); asleep, its eye is shut.
KNEEL = {"sink": 6, "lift": (0, 0), "stride": 0, "swing": 0, "kneel": True}
ASLEEP = POSES["idle"] | {"asleep": True}


def leg_boxes(facing, pose):
    """The columns, top row and bottom row of each leg, back leg first. None for a kneeling
    figure, whose legs are folded (see `draw_kneeling_legs`)."""
    if pose.get("kneel"):
        return []
    stride = pose["stride"]
    if facing in ("down", "up"):
        columns = ((5, 7), (9, 11))
    else:
        columns = ((6 - stride, 8 - stride), (7 + stride, 9 + stride))
    return [(x0, x1, 23 + pose["sink"], 30 - lift) for (x0, x1), lift in zip(columns, pose["lift"])]


def draw_body(facing, pose, skin="skin", shade="skin_shade", **_):
    """The figure in a linen undershirt and shorts: head, arms with hands, and legs. Worn
    clothes cover most of it, so this layer is also the silhouette that the outline follows."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    sink, swing = pose["sink"], pose["swing"]
    # The head, with its top corners cut.
    rect(canvas, 4, 6 + sink, 12, 12 + sink, skin)
    rect(canvas, 5, 5 + sink, 11, 5 + sink, skin)
    rect(canvas, 5, 12 + sink, 11, 12 + sink, shade)
    boxes = leg_boxes(facing, pose)
    for x0, x1, top, bottom in boxes:
        rect(canvas, x0, top, x1, bottom, skin)
        rect(canvas, x0, bottom - 1, x1, bottom, shade)
    if facing in ("down", "up"):
        rect(canvas, 6, 13 + sink, 10, 22 + sink, shade)
        rect(canvas, 8, boxes[0][2], 8, boxes[0][3] - 3, shade)
        # The right arm swings; the left one holds the tool.
        rect(canvas, 4, 14 + sink, 5, 20 + sink, skin)
        rect(canvas, 11, 14 + sink + swing // 2, 12, 20 + sink + swing // 2, skin)
        if facing == "down":
            for x in (6, 10):
                rect(canvas, x, 9 + sink, x, 10 + sink, "soil_dark")
            canvas[11 + sink][5] = canvas[11 + sink][11] = "petal"
        # The undershirt, with short sleeves, and the shorts down to the thighs.
        rect(canvas, 6, 13 + sink, 10, 20 + sink, UNDERSHIRT)
        rect(canvas, 10, 15 + sink, 10, 20 + sink, UNDERSHIRT_SHADE)
        for x0, dy in ((4, 0), (11, swing // 2)):
            rect(canvas, x0, 14 + sink + dy, x0 + 1, 15 + sink + dy, UNDERSHIRT)
        rect(canvas, 6, 21 + sink, 10, 22 + sink, SHORTS)
    else:
        rect(canvas, 5, 13 + sink, 10, 22 + sink, shade)
        canvas[10 + sink][13] = skin
        # A shut eye is only its lid line, low on the eye.
        if pose.get("asleep"):
            canvas[10 + sink][11] = "soil_dark"
        else:
            rect(canvas, 11, 9 + sink, 11, 10 + sink, "soil_dark")
        rect(canvas, 7 + swing // 2, 14 + sink, 8 + swing // 2, 17 + sink, skin)
        rect(canvas, 7 + swing, 18 + sink, 8 + swing, 20 + sink, skin)
        rect(canvas, 5, 13 + sink, 10, 20 + sink, UNDERSHIRT)
        rect(canvas, 5, 15 + sink, 5, 20 + sink, UNDERSHIRT_SHADE)
        rect(canvas, 7 + swing // 2, 14 + sink, 8 + swing // 2, 15 + sink, UNDERSHIRT)
        rect(canvas, 5, 21 + sink, 10, 22 + sink, SHORTS)
    for x0, x1, top, _bottom in boxes:
        rect(canvas, x0, top, x1, top + 2, SHORTS)
    if pose.get("kneel"):
        draw_kneeling_legs(canvas, (SHORTS, skin), (skin, shade), (shade, shade, shade))
    return canvas


def draw_kneeling_legs(canvas, thigh, shin, foot):
    """Legs folded under a kneeling figure seen from the side (facing right): the thigh
    forward to the knee, the shin back along the ground to the foot sticking out behind.
    `thigh` and `shin` are (colour, front colour), `foot` (top, middle, sole)."""
    rect(canvas, 5, 27, 9, 28, thigh[0])
    rect(canvas, 10, 27, 11, 28, thigh[1])
    rect(canvas, 4, 29, 11, 29, shin[0])
    rect(canvas, 4, 30, 11, 30, shin[1])
    rect(canvas, 1, 28, 3, 28, foot[0])
    rect(canvas, 1, 29, 3, 29, foot[1])
    rect(canvas, 1, 30, 3, 30, foot[2])


# Knee breeches of brown wool, buttoned at the knee, and white knitted stockings: the pale
# lower legs below dark breeches are what reads as the period at 16x32.
BREECHES = {"base": "soil_mid", "light": "soil_light", "shade": "soil", "band": "soil_dark"}
STOCKINGS = {"base": "lime", "shade": "sand_light"}
# Rows of the breeches from the top of the leg; the last is the band at the knee.
BREECHES_ROWS = 3


def draw_legs(facing, pose, **colours):
    """Knee breeches and stockings; the feet are in stockings too, clogs go over them.
    `colours` replace those of BREECHES (the villagers wear other cloth)."""
    breeches = BREECHES | colours
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    boxes = leg_boxes(facing, pose)
    for index, (x0, x1, top, bottom) in enumerate(boxes):
        knee = top + BREECHES_ROWS - 1
        rect(canvas, x0, top, x1, knee, breeches["base"])
        rect(canvas, x0, knee, x1, knee, breeches["band"])
        rect(canvas, x0, knee + 1, x1, bottom, STOCKINGS["base"])
        rect(canvas, x0, bottom, x1, bottom, STOCKINGS["shade"])
        # The inside of each leg is shaded, which also marks it against the other one.
        seam = x1 if index == 0 and facing in ("down", "up") else x0
        rect(canvas, seam, top, seam, knee - 1, breeches["shade"])
        rect(canvas, seam, knee + 1, seam, bottom, STOCKINGS["shade"])
        if facing in ("left", "right"):
            rect(canvas, x1, top, x1, knee - 1, breeches["light"])
            canvas[bottom][x1 + 1] = STOCKINGS["shade"]
    if facing in ("down", "up"):
        top = boxes[0][2]
        rect(canvas, 8, top, 8, top + BREECHES_ROWS - 2, breeches["shade"])
        rect(canvas, 8, top + BREECHES_ROWS - 1, 8, boxes[0][3] - 3, STOCKINGS["shade"])
    if pose.get("kneel"):
        draw_kneeling_legs(
            canvas,
            (breeches["base"], breeches["band"]),
            (STOCKINGS["base"], STOCKINGS["shade"]),
            (STOCKINGS["base"], STOCKINGS["base"], STOCKINGS["shade"]),
        )
    return canvas


# Wooden clogs, pale and wide: the feet the art guide names as the period cue.
CLOGS = {"light": "sand_light", "base": "sand", "sole": "mud"}


def draw_clogs(facing, pose, **_):
    """Wooden clogs over the stockinged feet, a pixel wider than the leg; from the side their
    long toe points forward."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    for index, (x0, x1, _top, bottom) in enumerate(leg_boxes(facing, pose)):
        if facing in ("down", "up"):
            # Wider to the outside of each foot.
            x0, x1 = (x0 - 1, x1) if index == 0 else (x0, x1 + 1)
            rect(canvas, x0, bottom - 1, x1, bottom - 1, CLOGS["light"])
            rect(canvas, x0, bottom, x1, bottom, CLOGS["base"])
        else:
            rect(canvas, x0, bottom - 1, x1 + 1, bottom - 1, CLOGS["light"])
            rect(canvas, x0, bottom, x1 + 2, bottom, CLOGS["base"])
            canvas[bottom][x0] = CLOGS["sole"]
    if pose.get("kneel"):
        rect(canvas, 1, 28, 3, 28, CLOGS["light"])
        rect(canvas, 1, 29, 3, 29, CLOGS["base"])
        rect(canvas, 1, 30, 3, 30, CLOGS["sole"])
    return canvas


# The linen shirt, and the waistcoat of madder-red wool with its row of tin buttons.
SHIRT = {"base": "lime", "shade": "sand_light"}
WAISTCOAT = {"base": "rust", "light": "red_light", "shade": "rust_dark", "button": "stone_light"}


def draw_shirt(facing, pose, **_):
    """A linen shirt with long sleeves to the wrist, tucked into the breeches."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    sink, swing = pose["sink"], pose["swing"]
    base, shade = SHIRT["base"], SHIRT["shade"]
    if facing in ("down", "up"):
        rect(canvas, 6, 13 + sink, 10, 22 + sink, base)
        rect(canvas, 10, 15 + sink, 10, 22 + sink, shade)
        rect(canvas, 6, 22 + sink, 10, 22 + sink, shade)
        # Sleeves; the right one swings with the arm.
        for x0, dy in ((4, 0), (11, swing // 2)):
            rect(canvas, x0, 14 + sink + dy, x0 + 1, 18 + sink + dy, base)
            rect(canvas, x0 + 1, 15 + sink + dy, x0 + 1, 17 + sink + dy, shade)
            rect(canvas, x0, 18 + sink + dy, x0 + 1, 18 + sink + dy, shade)
        if facing == "down":
            # The open neck.
            canvas[13 + sink][8] = "skin_shade"
        else:
            rect(canvas, 6, 13 + sink, 10, 13 + sink, shade)
    else:
        rect(canvas, 5, 13 + sink, 10, 22 + sink, base)
        rect(canvas, 5, 15 + sink, 5, 22 + sink, shade)
        rect(canvas, 5, 22 + sink, 10, 22 + sink, shade)
        draw_near_sleeve(canvas, pose, base, shade)
    return canvas


def draw_near_sleeve(canvas, pose, base, shade):
    """The sleeve of the near arm, seen from the side over the torso: a shaded edge at the back,
    and the cuff."""
    sink, swing = pose["sink"], pose["swing"]
    for y in range(14 + sink, 19 + sink):
        x = 7 + (swing // 2 if y < 17 + sink else swing)
        canvas[y][x], canvas[y][x + 1] = shade, base
    rect(canvas, 7 + swing, 18 + sink, 8 + swing, 18 + sink, shade)


def draw_waistcoat(facing, pose, **colours):
    """The shirt under a long red waistcoat, buttoned down the front, its skirts over the hips.
    `colours` replace those of WAISTCOAT."""
    waistcoat = WAISTCOAT | colours
    canvas = draw_shirt(facing, pose)
    sink = pose["sink"]
    base, light, shade = waistcoat["base"], waistcoat["light"], waistcoat["shade"]
    if facing in ("down", "up"):
        rect(canvas, 6, 14 + sink, 10, 22 + sink, base)
        rect(canvas, 5, 21 + sink, 11, 22 + sink, base)
        rect(canvas, 6, 14 + sink, 6, 20 + sink, light)
        rect(canvas, 10, 14 + sink, 10, 20 + sink, shade)
        rect(canvas, 5, 22 + sink, 11, 22 + sink, shade)
        if facing == "down":
            # The neck opening shows the shirt; the buttons run down the middle.
            canvas[14 + sink][8] = SHIRT["base"]
            for y in (16, 18, 20):
                canvas[y + sink][8] = waistcoat["button"]
        else:
            rect(canvas, 8, 15 + sink, 8, 22 + sink, shade)
    else:
        rect(canvas, 5, 14 + sink, 10, 22 + sink, base)
        rect(canvas, 5, 21 + sink, 11, 22 + sink, base)
        rect(canvas, 5, 14 + sink, 5, 21 + sink, shade)
        rect(canvas, 5, 22 + sink, 11, 22 + sink, shade)
        rect(canvas, 10, 14 + sink, 10, 20 + sink, light)
        for y in (16, 18, 20):
            canvas[y + sink][10] = waistcoat["button"]
        draw_near_sleeve(canvas, pose, SHIRT["base"], SHIRT["shade"])
    return canvas


# The short jacket of indigo wool, worn open over the waistcoat.
JACKET = {"base": "water", "light": "water_light", "shade": "water_deep"}


def draw_jacket(facing, pose, **colours):
    """A short jacket with long sleeves, worn open: from the front the waistcoat shows between
    its edges, from the side at the chest. `colours` replace those of JACKET."""
    jacket = JACKET | colours
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    sink, swing = pose["sink"], pose["swing"]
    base, light, shade = jacket["base"], jacket["light"], jacket["shade"]
    if facing in ("down", "up"):
        if facing == "down":
            # The open front: the two edges, and the turned-down collar at the shoulders.
            rect(canvas, 6, 13 + sink, 7, 14 + sink, base)
            rect(canvas, 9, 13 + sink, 10, 14 + sink, base)
            rect(canvas, 6, 15 + sink, 6, 22 + sink, base)
            rect(canvas, 10, 15 + sink, 10, 22 + sink, shade)
            canvas[13 + sink][6] = canvas[13 + sink][9] = light
            rect(canvas, 5, 21 + sink, 6, 22 + sink, base)
            rect(canvas, 10, 21 + sink, 11, 22 + sink, shade)
        else:
            rect(canvas, 6, 13 + sink, 10, 22 + sink, base)
            rect(canvas, 5, 21 + sink, 11, 22 + sink, base)
            rect(canvas, 6, 13 + sink, 10, 13 + sink, light)
            rect(canvas, 10, 14 + sink, 10, 22 + sink, shade)
            rect(canvas, 8, 19 + sink, 8, 22 + sink, shade)
        rect(canvas, 5, 22 + sink, 11, 22 + sink, shade)
        # Sleeves; the right one swings with the arm.
        for x0, dy in ((4, 0), (11, swing // 2)):
            rect(canvas, x0, 14 + sink + dy, x0 + 1, 18 + sink + dy, base)
            rect(canvas, x0, 14 + sink + dy, x0 + 1, 14 + sink + dy, light)
            rect(canvas, x0 + 1, 15 + sink + dy, x0 + 1, 17 + sink + dy, shade)
            rect(canvas, x0, 18 + sink + dy, x0 + 1, 18 + sink + dy, light)
    else:
        rect(canvas, 5, 13 + sink, 9, 22 + sink, base)
        rect(canvas, 5, 21 + sink, 10, 22 + sink, base)
        rect(canvas, 5, 13 + sink, 9, 13 + sink, light)
        rect(canvas, 5, 15 + sink, 5, 22 + sink, shade)
        rect(canvas, 5, 22 + sink, 10, 22 + sink, shade)
        draw_near_sleeve(canvas, pose, base, shade)
        rect(canvas, 7 + swing // 2, 14 + sink, 8 + swing // 2, 14 + sink, light)
        rect(canvas, 7 + swing, 18 + sink, 8 + swing, 18 + sink, light)
    return canvas


def draw_hair(facing, pose, base, light, shade, style, **_):
    """Hair over the head (the same 9x8 block in every view), and from behind over the whole
    back of it: "short", "long" to the shoulders, "tied" back with a ribbon into a tail down
    the neck, parted and pinned up in a "bun" at the back, or parted into two "plaits" tied with
    red ribbons. The darkest shade is the line to the face."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    sink = pose["sink"]
    rect(canvas, 5, 5 + sink, 11, 5 + sink, base)
    rect(canvas, 4, 6 + sink, 12, 7 + sink, base)
    rect(canvas, 5, 6 + sink, 7, 6 + sink, light)
    if facing == "down":
        rect(canvas, 6, 7 + sink, 10, 7 + sink, shade)
        for x in (4, 12):
            rect(canvas, x, 8 + sink, x, 9 + sink, base)
            canvas[9 + sink][x] = shade
        if style == "long":
            for x in (4, 12):
                rect(canvas, x, 10 + sink, x, 14 + sink, base)
                rect(canvas, x, 13 + sink, x, 14 + sink, shade)
        if style in ("bun", "plaits"):
            canvas[6 + sink][8] = shade
        if style == "bun":
            # The knot shows over the top of the head.
            rect(canvas, 7, 4 + sink, 9, 4 + sink, base)
            canvas[4 + sink][7] = light
        if style == "plaits":
            for x in (4, 12):
                draw_plait(canvas, x, 10 + sink, 15 + sink, base, shade)
    elif facing == "up":
        rect(canvas, 4, 8 + sink, 12, 11 + sink, base)
        rect(canvas, 5, 12 + sink, 11, 12 + sink, shade)
        rect(canvas, 8, 7 + sink, 8, 11 + sink, shade)
        rect(canvas, 6, 8 + sink, 6, 9 + sink, light)
        if style == "long":
            rect(canvas, 4, 12 + sink, 12, 16 + sink, base)
            rect(canvas, 5, 17 + sink, 11, 17 + sink, base)
            rect(canvas, 8, 12 + sink, 8, 16 + sink, shade)
            rect(canvas, 6, 13 + sink, 6, 15 + sink, light)
            rect(canvas, 5, 16 + sink, 11, 17 + sink, shade)
        if style == "tied":
            rect(canvas, 7, 12 + sink, 8, 17 + sink, base)
            rect(canvas, 8, 13 + sink, 8, 17 + sink, shade)
            rect(canvas, 6, 13 + sink, 9, 13 + sink, HAIR_RIBBON)
        if style == "bun":
            rect(canvas, 6, 9 + sink, 10, 11 + sink, base)
            rect(canvas, 7, 8 + sink, 9, 12 + sink, base)
            rect(canvas, 7, 12 + sink, 9, 12 + sink, shade)
            canvas[9 + sink][7] = light
        if style == "plaits":
            for x in (6, 10):
                draw_plait(canvas, x, 12 + sink, 17 + sink, base, shade)
    else:
        rect(canvas, 10, 7 + sink, 12, 7 + sink, shade)
        rect(canvas, 4, 8 + sink, 8, 11 + sink, base)
        rect(canvas, 8, 8 + sink, 8, 11 + sink, shade)
        rect(canvas, 5, 12 + sink, 7, 12 + sink, shade)
        rect(canvas, 5, 8 + sink, 5, 9 + sink, light)
        if style == "long":
            rect(canvas, 3, 8 + sink, 6, 16 + sink, base)
            rect(canvas, 3, 15 + sink, 6, 16 + sink, shade)
            rect(canvas, 4, 11 + sink, 4, 14 + sink, light)
        if style == "tied":
            rect(canvas, 3, 11 + sink, 4, 16 + sink, base)
            rect(canvas, 3, 15 + sink, 4, 16 + sink, shade)
            rect(canvas, 3, 12 + sink, 4, 12 + sink, HAIR_RIBBON)
        if style == "bun":
            rect(canvas, 2, 8 + sink, 4, 10 + sink, base)
            rect(canvas, 2, 10 + sink, 4, 10 + sink, shade)
            canvas[8 + sink][3] = light
        if style == "plaits":
            draw_plait(canvas, 4, 11 + sink, 16 + sink, base, shade)
    return canvas


# The ribbons that tie the ends of plaits.
PLAIT_RIBBON = "rust"


def draw_plait(canvas, x, top, bottom, base, shade):
    """A plait one pixel wide from `top` to `bottom`, its strands crossing every other row, and a
    ribbon under its end."""
    for y in range(top, bottom + 1):
        canvas[y][x] = base if (y - top) % 2 == 0 else shade
    canvas[bottom + 1][x] = PLAIT_RIBBON


def draw_rows(canvas, rows, keys, top):
    """Draws rows of characters, each mapped to a colour by `keys` ("." is clear), with the
    first row at `top`."""
    for dy, row in enumerate(rows):
        for x, char in enumerate(row):
            if char != ".":
                canvas[top + dy][x] = keys[char]


# Hats, from the front (also used from behind) and from the side, facing right. Row 0 is y 2
# of a standing figure; the hats sit on the head, which starts at y 5.
STRAW_HAT_KEYS = {"l": "sand_light", "b": "straw", "s": "reed", "d": "soil"}
STRAW_HAT_ROWS = {
    "front": (
        "................",
        "......llbbb.....",
        ".....lbbbbbs....",
        ".....ddddddd....",
        "..lllllbbbbbbs..",
        ".lbbbbbbbbbbbbs.",
        ".ss..........ss.",
    ),
    "side": (
        "................",
        "......lbbb......",
        ".....lbbbbbs....",
        ".....dddddds....",
        "..lllllbbbbbbbs.",
        ".sbbbbbbbbbbbbbs",
        ".s............ss",
    ),
}
KNITTED_CAP_KEYS = {"l": "red_light", "r": "rust", "d": "rust_dark", "c": "ember", "k": "russet_deep"}
KNITTED_CAP_ROWS = {
    "front": (
        "................",
        "......lrrr......",
        ".....lrrrrrd....",
        "....lrrrrrrrdrr.",
        "....ccccccccc.dd",
        "....dkdkdkdkd...",
    ),
    "side": (
        "................",
        ".....lrrrr......",
        "..rrlrrrrrrd....",
        ".ddrrrrrrrrrd...",
        ".d..cccccccccc..",
        "....kdkdkdkdkd..",
    ),
}


# A black felt hat with a broad brim: the straw hat's shape in felt, with a band of ribbon.
FELT_HAT_KEYS = {"l": "stone", "b": "stone_dark", "s": "ink", "d": "soil_dark"}
# The hats by name: their rows and the colours of the rows' characters.
HATS = {
    "straw_hat": (STRAW_HAT_ROWS, STRAW_HAT_KEYS),
    "knitted_cap": (KNITTED_CAP_ROWS, KNITTED_CAP_KEYS),
    "felt_hat": (STRAW_HAT_ROWS, FELT_HAT_KEYS),
}


def draw_hat(facing, pose, hat, **_):
    """A hat of HATS, from its front and side rows."""
    rows, keys = HATS[hat]
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    draw_rows(canvas, rows["side" if facing in ("left", "right") else "front"], keys, 2 + pose["sink"])
    return canvas


def draw_held_hoe(facing, pose, **_):
    """A hoe in the right hand, in dark soil colours with a light edge on the blade."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    sink = pose["sink"]
    if facing in ("down", "up"):
        shaft = 3 if facing == "down" else 13
        top = 13 + sink
        rect(canvas, shaft, top, shaft, 30, "soil_dark")
        blade = (shaft - 2, shaft) if facing == "down" else (shaft, shaft + 2)
        rect(canvas, blade[0], top - 1, blade[1], top, "soil_dark")
        rect(canvas, blade[0], top - 1, blade[1], top - 1, "soil_light")
        if facing == "down":
            rect(canvas, shaft, 19, shaft, 20, "skin")
    else:
        top = 13 + sink
        rect(canvas, 12, top, 12, 30, "soil_dark")
        rect(canvas, 12, top + 1, 14, top + 2, "soil_dark")
        rect(canvas, 12, top + 1, 14, top + 1, "soil_light")
        rect(canvas, 11, 19, 12, 20, "skin")
    return canvas


def mirrored(canvas):
    return [row[::-1] for row in canvas]


def outlined(canvas, skip):
    """Adds a 1 px ink outline around the drawing, except on pixels covered by `skip`: the
    body already outlines itself, and a layer drawn over it must not cut lines into it."""
    width, height = len(canvas[0]), len(canvas)
    covered = pixels_of(canvas)
    for x, y in covered:
        for dx, dy in NEIGHBOURS:
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in covered and (nx, ny) not in skip:
                canvas[ny][nx] = "ink"
    return canvas


def pixels_of(canvas):
    return {(x, y) for y, row in enumerate(canvas) for x, colour in enumerate(row) if colour is not None}


def character_sheet(draw, variant_colours):
    """One layer's sheet: the layer drawn in every facing and frame, with its outline."""
    rows = []
    for facing in PLAYER_FACINGS:
        drawn_facing = "right" if facing == "left" else facing
        row = []
        for frame in PLAYER_FRAMES:
            pose = POSES[frame]
            body_pixels = pixels_of(draw_body(drawn_facing, pose))
            canvas = draw(drawn_facing, pose, **variant_colours)
            canvas = outlined(canvas, set() if draw is draw_body else body_pixels)
            row.append(mirrored(canvas) if facing == "left" else canvas)
        rows.append(row)
    return rows


# Passing out (assets/character/collapse/<name>.png, one per layer sheet but the held tool,
# which is let go): one row of 32x32 frames, facing right (the game mirrors them for left),
# with the feet or the body on the bottom row: kneeling, tipping over forward, lying and
# asleep. Lying is the side view of the standing figure laid down head first, face up.
COLLAPSE_SIZE = 32
# How far each row of the kneeling figure leans forward, per row above the ground: slumped
# while kneeling, then tipping over.
SLUMP_LEAN = 0.12
TIP_LEAN = 0.45


def leaning(lean):
    """Places the 16x32 figure in the middle of the frame, each row moved forward by its
    height above the ground times `lean`. Whole pixel steps keep the art crisp."""

    def place(canvas):
        frame = blank(COLLAPSE_SIZE)
        left = (COLLAPSE_SIZE - CHARACTER_WIDTH) // 2
        ground = CHARACTER_HEIGHT - 1
        for y, row in enumerate(canvas):
            shift = left + round((ground - y) * lean)
            for x, colour in enumerate(row):
                if colour is not None:
                    frame[y][x + shift] = colour
        return frame

    return place


def lying(canvas):
    """The standing figure laid down on the bottom half of the frame: its head to the right
    (forward), its front (face and toes) up."""
    frame = blank(COLLAPSE_SIZE)
    for y, row in enumerate(canvas):
        for x, colour in enumerate(row):
            if colour is not None:
                frame[COLLAPSE_SIZE - 1 - x][CHARACTER_HEIGHT - 1 - y] = colour
    return frame


COLLAPSE_FRAMES = (
    (KNEEL, leaning(SLUMP_LEAN)),
    (KNEEL, leaning(TIP_LEAN)),
    (POSES["idle"], lying),
    (ASLEEP, lying),
)


def collapse_sheet(draw, variant_colours):
    """One layer's passing-out frames, outlined after they are placed, like `character_sheet`."""
    row = []
    for pose, place in COLLAPSE_FRAMES:
        body_pixels = pixels_of(place(draw_body("right", pose)))
        canvas = place(draw("right", pose, **variant_colours))
        row.append(outlined(canvas, set() if draw is draw_body else body_pixels))
    return [row]


def layers():
    """The layer sheets by file name (assets/character/<name>.png, and the same names in
    collapse/ for passing out), each as the function that draws it and the colours of its
    variant."""
    result = {"body_0": (draw_body, {})}
    result["clothes_0"] = (draw_waistcoat, {})
    result["clothes_1"] = (draw_shirt, {})
    result["coat_jacket"] = (draw_jacket, {})
    for variant, colours in HAIR_STYLES.items():
        result[f"hair_{variant}"] = (draw_hair, colours)
    result["legs_0"] = (draw_legs, {})
    result["feet_clogs"] = (draw_clogs, {})
    result["head_straw_hat"] = (draw_hat, {"hat": "straw_hat"})
    result["head_knitted_cap"] = (draw_hat, {"hat": "knitted_cap"})
    return result


def sleep_z():
    """The "z" that rises from a sleeping figure (assets/effects/sleep_z.png): a cream glyph
    with the ink outline around its strokes."""
    return outlined(
        [
            [{"c": "cream"}.get(key) for key in line]
            for line in ("......", ".cccc.", "...cc.", "..cc..", ".cc...", ".cccc.", "......")
        ],
        set(),
    )
