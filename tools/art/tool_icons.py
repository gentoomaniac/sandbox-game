"""The 16x16 icons of the tools: hoe, axe, pickaxe, watering can, scythe, shovel and hammer.

Each lies on the diagonal from the bottom left to the top right, the classic item-icon pose: a
wooden handle 2 px wide (lit on its upper left side) with the working end at the top right, in
an ink outline so its silhouette reads on its own. The metal uses only the METAL ramp, so a
better tool later is the same icon with that ramp swapped (copper, iron). The watering can is
all copper, as cans were before tin-plate. Pictures are lists of rows of palette colour names,
as in items.py.
"""

import math

import items

# Metal, lit to dark: the bright cutting edge, the lit face, the body, the shade.
METAL = ("snow_light", "stone_light", "stone", "stone_dark")
# Wood of the handles, lit to dark.
WOOD = ("sand_light", "soil_light", "soil_mid")

KEYS = {
    "e": METAL[0], "m": METAL[1], "s": METAL[2], "k": METAL[3],
    "l": WOOD[0], "w": WOOD[1], "d": WOOD[2],
}


def stamp(picture, x, y, *rows):
    """Draws rows of key letters (see KEYS) with their top left at (x, y); "." stays as it is."""
    for dy, row in enumerate(rows):
        for dx, letter in enumerate(row):
            if letter != ".":
                picture[y + dy][x + dx] = KEYS[letter]


def handle(picture, top, bottom, diagonal=15):
    """A handle along the diagonal x + y = `diagonal` from row `top` down to row `bottom`: per row
    a lit pixel and a dark one right of it."""
    for y in range(top, bottom + 1):
        x = diagonal - y
        picture[y][x] = WOOD[1]
        picture[y][x + 1] = WOOD[2]
    picture[top][diagonal - top] = WOOD[0]


def curved_band(picture, start, control, end, widths, shades):
    """A band along a quadratic curve from `start` over `control` to `end`, `widths[0]` px thick
    at the start down to `widths[1]` at the end. `shades(t, side)` gives the colour of a pixel
    `t` along the curve (0 to 1) and `side` across it (-1 to 1, positive on the left of the
    direction of travel)."""
    (x0, y0), (cx, cy), (x1, y1) = start, control, end
    for step in range(200):
        t = step / 199
        x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t * t * x1
        y = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * cy + t * t * y1
        dx = 2 * (1 - t) * (cx - x0) + 2 * t * (x1 - cx)
        dy = 2 * (1 - t) * (cy - y0) + 2 * t * (y1 - cy)
        length = math.hypot(dx, dy) or 1
        normal = (dy / length, -dx / length)
        half = (widths[0] + (widths[1] - widths[0]) * t) / 2
        for offset in range(-8, 9):
            side = offset / 8
            px = x + normal[0] * side * half
            py = y + normal[1] * side * half
            picture[int(py)][int(px)] = shades(t, side)


def hoe():
    """A long handle with a flat blade at right angles to its top end, its edge bright."""
    picture = items.canvas()
    handle(picture, 3, 14)
    stamp(
        picture, 2, 1,
        "kmmmmmmmmsk.",
        "kmssssssssk.",
        "mmsk........",
        "mssk........",
        "eeek........",
    )
    return items.outlined(picture, "ink")


def axe():
    """A wedge blade on the left of the handle's top, its curved cutting edge bright."""
    picture = items.canvas()
    handle(picture, 2, 14)
    stamp(
        picture, 2, 1,
        "...eek.....",
        "..emmsk....",
        ".emmmssk...",
        "emmmmsskkkk",
        "emmmmssssk.",
        ".emmmsskk..",
        "..emmsk....",
        "...eek.....",
    )
    return items.outlined(picture, "ink")


def pickaxe():
    """A curved head with two points, crossing the top of the handle."""
    picture = items.canvas()
    handle(picture, 5, 14)
    curved_band(
        picture, (2.5, 2.5), (13, 0.5), (13.5, 12.5), (1, 1),
        lambda t, side: METAL[1] if side > 0.2 else METAL[2],
    )
    curved_band(
        picture, (4, 2.6), (12, 1.6), (12.6, 10), (2.4, 2.4),
        lambda t, side: METAL[1] if side > 0.3 else METAL[2] if side > -0.5 else METAL[3],
    )
    stamp(picture, 10, 3, "ksk", "skk")
    return items.outlined(picture, "ink")


def scythe():
    """A long snath with a grip peg, and a long curved blade off its top, the biggest icon."""
    picture = items.canvas()
    handle(picture, 2, 14)
    stamp(picture, 3, 7, "lw", ".lw")
    curved_band(
        picture, (13, 2.2), (6, -0.5), (1.2, 6.5), (2.6, 1),
        lambda t, side: METAL[0] if side < -0.4 else METAL[1] if side < 0.3 else METAL[2],
    )
    stamp(picture, 12, 1, "kk", "k.")
    return items.outlined(picture, "ink")


def shovel():
    """A pointed spade blade at the bottom left, a D-grip at the top right."""
    picture = items.canvas()
    handle(picture, 3, 7)
    stamp(
        picture, 11, 0,
        ".lww",
        "lw.w",
        "wwww",
    )
    # The blade, measured along the handle (`along`, from its socket towards the tip) and across
    # it (`across`, positive on the lit upper left side).
    for y in range(16):
        for x in range(16):
            along = ((8.5 - x) + (y - 7.5)) / math.sqrt(2)
            across = ((8.5 - x) - (y - 7.5)) / math.sqrt(2)
            reach = 2.9 if along < 5 else 2.9 * (8 - along) / 3
            if 0 <= along < 8 and abs(across) <= reach:
                if along > 6.2 or (across > 1.9 and along > 3):
                    colour = METAL[0]
                elif along < 0.8:
                    colour = METAL[3]
                else:
                    colour = METAL[1] if across > 0.6 else METAL[2] if across > -1.6 else METAL[3]
                picture[y][x] = colour
    return items.outlined(picture, "ink")


def hammer():
    """A heavy, blocky head square on the top of the handle, its striking faces bright."""
    picture = items.canvas()
    handle(picture, 7, 14)
    stamp(
        picture, 5, 1,
        "emmmmmmk",
        "emmsssmk",
        "emsssssk",
        "emsssssk",
        "emsssssk",
        "ekkkkkkk",
    )
    return items.outlined(picture, "ink")


# Copper, lit to dark, for the watering can: a glint, the lit face, the body, the shade.
COPPER = {"g": "gold", "o": "ochre", "a": "ochre_dark", "u": "umber"}


def watering_can():
    """A copper can of the old kind: a tall round body, a handle arching over the top, and a
    spout rising to a big round rose, its face pricked with holes."""
    picture = items.canvas()
    rows = (
        "..........aaaa.",
        ".........aoggoa",
        "...aaa...aguoua",
        "..o...a..aouoga",
        ".o.....a..aaau.",
        ".aoooooa..ou...",
        "agoooaaau.ou...",
        "agooaaaauou....",
        "agooaaaaauu....",
        "agoaaaaaau.....",
        "agoaaaaaau.....",
        ".aaaaaaau......",
        "..uuuuuu.......",
    )
    for dy, row in enumerate(rows):
        for dx, letter in enumerate(row):
            if letter != ".":
                picture[2 + dy][dx] = COPPER[letter]
    return items.outlined(picture, "ink")


def icons():
    """The 16x16 icons by item id."""
    return {
        "hoe": hoe(),
        "axe": axe(),
        "pickaxe": pickaxe(),
        "watering_can": watering_can(),
        "scythe": scythe(),
        "shovel": shovel(),
        "hammer": hammer(),
    }
