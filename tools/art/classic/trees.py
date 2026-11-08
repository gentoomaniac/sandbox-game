"""The vegetation and rocks of assets/objects.png: oak, stone, spruce, pine, dead tree, berry
bush, shrub, sapling, fern, boulder, and the stumps trees leave behind.

Every object is a 48x80 cell (see canvas.py) with its feet at the bottom centre; `vegetation()`
returns the rows in the atlas order. Pictures are lists of rows of palette colour names.
"""

import math
import random

from canvas import NEIGHBOURS, OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, blank, outline, rect

def shaded_blob(canvas, rng, blobs, shades, edge_colour):
    """Fills the union of circles (cx, cy, radius) with `shades`, lightest first: light
    comes from the top left, so a pixel is darker the further down and right of its
    circle's centre it is. Pixels on the blob's border get `edge_colour`."""
    covered = set()
    for y in range(len(canvas)):
        for x in range(OBJECT_CELL_WIDTH):
            best = None
            for cx, cy, radius in blobs:
                distance = math.hypot(x - cx, y - cy)
                if distance <= radius:
                    # 0 at the lit top left of the circle, 1 at its dark bottom right.
                    light = ((x - cx) * 0.5 + (y - cy) * 0.9) / radius * 0.5 + 0.5
                    if best is None or light < best:
                        best = light
            if best is not None:
                covered.add((x, y))
                noise = rng.random() * 0.25 - 0.12
                index = min(len(shades) - 1, max(0, int((best + noise) * len(shades))))
                canvas[y][x] = shades[index]
    for x, y in covered:
        if any((x + dx, y + dy) not in covered for dx, dy in NEIGHBOURS):
            canvas[y][x] = edge_colour


BARK = ("soil_mid", "soil", "soil", "soil_dark")
LEAVES = ("green_bright", "green_light", "green", "green_dark", "green_deep", "olive")
# What shade_under_crown takes for foliage: the ground shadow (once drawn in green_deep)
# too, which keeps the summer art as it was.
FOLIAGE = LEAVES + ("shadow",)


def ground_shadow(canvas, half_width, centre=OBJECT_CENTRE):
    """A soft dark ellipse on the ground under an object, 3 rows high, with a dithered
    rim; it is drawn first so the object covers its middle."""
    bottom = OBJECT_BOTTOM
    for y, reach in ((bottom - 2, half_width - 3), (bottom - 1, half_width), (bottom, half_width - 2)):
        for x in range(centre - reach, centre + reach):
            if abs(x - centre) < reach - 1 or (x + y) % 2 == 0:
                canvas[y][x] = "shadow"


def dense_foot(canvas, rows, rim="green_deep", centre=OBJECT_CENTRE):
    """The dense foot of a plant with loose blades, drawn with a rim round it: `rows` are
    (y, half width, colour) from the top down, each centred on `centre`. The rim is the darkest
    shade of the plant's own ramp, never ink, and the blades above it get none."""
    foot = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    for y, half_width, colour in rows:
        rect(foot, centre - half_width, y, centre + half_width - 1, y, colour)
    for y, row in enumerate(outline(foot, rim)):
        for x, colour in enumerate(row):
            if colour is not None:
                canvas[y][x] = colour


def tree_trunk(canvas, rng, top, width, shades=BARK):
    """A trunk from `top` down to the ground, lit on the left, with a root flare at its
    foot and a few bark marks. Its outline is the darkest shade."""
    left = OBJECT_CENTRE - width // 2
    for y in range(top, OBJECT_BOTTOM + 1):
        flare = 2 if y == OBJECT_BOTTOM else 1 if y > OBJECT_BOTTOM - 4 else 0
        for x in range(left - flare, left + width + flare):
            index = x - left
            if index <= -1 or index >= width - 1:
                colour = shades[-1]
            elif index == 0:
                colour = shades[1] if flare else shades[0]
            elif index == width - 2:
                colour = shades[2]
            else:
                colour = shades[1]
            canvas[y][x] = colour
    for _ in range((OBJECT_BOTTOM - top) // 5):
        x, y = left + rng.randint(1, width - 3), rng.randint(top, OBJECT_BOTTOM - 4)
        canvas[y][x] = canvas[y + 1][x] = shades[-1]
        canvas[y][x + 1] = shades[2]


def limb(canvas, x, y, direction, length, colour="soil"):
    """A 2px thick limb rising diagonally from the trunk at (x, y); the crown drawn over it
    hides its far end."""
    for step in range(length):
        canvas[y - step][x + step * direction] = colour
        canvas[y - step + 1][x + step * direction] = colour


def shade_under_crown(canvas, shades=BARK):
    """Darkens the trunk where the crown above it casts a shadow, and the crown's own
    underside, so the two read as joined rather than stacked."""
    dark = shades[-1]
    for y in range(len(canvas)):
        for x in range(OBJECT_CELL_WIDTH):
            if canvas[y][x] in shades and any(
                y - up >= 0 and canvas[y - up][x] in FOLIAGE for up in (1, 2, 3, 4)
            ):
                canvas[y][x] = dark
    for x in range(OBJECT_CELL_WIDTH):
        lowest = max((y for y in range(len(canvas)) if canvas[y][x] in FOLIAGE), default=None)
        if lowest is not None and canvas[lowest - 1][x] in ("green_bright", "green_light", "green"):
            canvas[lowest - 1][x] = "green_dark"


def oak(seed):
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 13)
    tree_trunk(canvas, rng, 52, 7)
    # Limbs into the crown, on some variants.
    if seed % 3 != 0:
        limb(canvas, 20, 62, -1, 8)
    if seed % 3 != 1:
        limb(canvas, 27, 60, 1, 8)
    # Canopy of three lobes on top of a broad base, different for every variant. It reaches
    # down over the upper trunk, so that a dense forest reads as one canopy.
    blobs = [(24 + rng.uniform(-1, 1), 38 + rng.uniform(-1, 1), rng.uniform(12, 14))]
    for cx, cy, radius in ((9, 44, 8), (39, 44, 8), (24, 26, 8), (14, 31, 8), (34, 31, 8), (18, 51, 6), (30, 51, 6)):
        blobs.append((cx + rng.uniform(-2, 2), cy + rng.uniform(-1.5, 1.5), radius + rng.uniform(-1, 1)))
    shaded_blob(canvas, rng, blobs, LEAVES[:5], "green_deep")
    shade_under_crown(canvas)
    return canvas


def bare_oak(seed):
    """The oak in winter: the trunk of the same seed, bare branches instead of the crown."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 13)
    tree_trunk(canvas, rng, 46, 7)
    branches = (
        (22, 46, -1, 20),
        (26, 46, 1, 20),
        (24, 46, rng.choice((-1, 1)), 22),
        (23, 54, -1, 14),
        (27, 52, 1, 14),
    )
    # Fewer branches on some variants, so a forest is not a wall of twigs.
    for x, y, direction, length in branches[: 5 - seed % 3]:
        draw_branch(canvas, rng, x, y, direction, length + rng.randint(-2, 2), "soil_mid")
    outline_in_bark(canvas)
    return canvas


def stone(seed):
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 8)
    # A small stone of 13x12 px, and for the second variant a pebble beside it.
    blobs = [(24, 73, 6)] if seed % 2 else [(22, 73, 5.5), (29, 76, 2.5)]
    shaded_blob(canvas, rng, blobs, ("stone_light", "stone", "stone_dark"), "stone_dark")
    return canvas


def boulder(seed):
    """A boulder on 2x1 tiles: the cell is centred on the footprint, which is 32 px wide."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 14)
    blobs = [(23, 68, 10), (16, 71, 6), (31, 70, 6.5), (26, 64, 7)]
    shaded_blob(canvas, rng, blobs, ("stone_light", "stone", "stone", "stone_dark"), "stone_dark")
    # A crack, and moss on the lit top.
    for step in range(7):
        canvas[62 + step][27 + step // 3] = "stone_dark"
    for _ in range(14):
        x, y = rng.randint(14, 30), rng.randint(58, 66)
        if canvas[y][x] in ("stone_light", "stone"):
            canvas[y][x] = rng.choice(("green_light", "olive", "green"))
    return canvas


def conifer_tier(canvas, rng, top, bottom, half_width):
    """One ragged triangle of needles centred on the cell, lit from the left, with a dark
    underside so the tiers read as layers."""
    centre = OBJECT_CENTRE
    for y in range(top, bottom + 1):
        progress = (y - top) / (bottom - top)
        reach = half_width * (0.2 + 0.8 * progress) + rng.uniform(-0.7, 0.7)
        for x in range(math.floor(centre - reach), math.ceil(centre + reach) + 1):
            side = (x - centre) / max(reach, 1)
            if abs(x - centre) > reach - 0.5 or y == bottom:
                canvas[y][x] = "green_deep"
            else:
                canvas[y][x] = ("green_light", "green", "green", "green_dark")[
                    min(3, int((side * 0.6 + progress * 0.5 + 0.5 + rng.uniform(-0.2, 0.2)) * 2.2))
                ]


def spruce(seed):
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 10)
    tree_trunk(canvas, rng, 66, 5)
    # Tall and narrow: six tiers, the widest at the bottom, each overlapping the next.
    tiers = [(55, 70, 14), (46, 61, 12.5), (37, 53, 11), (28, 45, 9), (20, 37, 7), (13 + rng.randint(0, 2), 29, 5)]
    for top, bottom, half_width in tiers:
        conifer_tier(canvas, rng, top, bottom, half_width + rng.uniform(-0.5, 0.5))
    shade_under_crown(canvas)
    return canvas


# A Scots pine: the trunk's bark, grey-brown and furrowed below, thinner and a warm brown in the
# crown (each lit to dark, then its outline), and the dark blue-green needles (lit top to dark
# underside, then the outline).
PINE_BARK = ("mud", "mud_dark", "soil_dark", "soil_dark")
PINE_CROWN_BARK = ("soil_light", "soil_mid", "rust_dark", "soil_dark")
PINE_NEEDLES = ("meadow_light", "meadow", "green_deep", "bog_dark")
# How far below the top of the trunk the bark turns from warm brown to grey-brown, in rows.
PINE_CROWN_BARK_DEPTH = 34


def pine(seed):
    """A Scots pine: a tall, slightly crooked trunk, bare for most of its height, warm brown up in
    the crown and grey-brown below with a few dead branch stubs; the crown is a loose, flat-topped
    umbrella of dark blue-green needle clumps on branches spreading from the top third, with gaps
    where the sky shows through."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 10)
    top = 9 + rng.randint(0, 3)
    red_from = top + PINE_CROWN_BARK_DEPTH
    # The trunk wanders a little from side to side as it rises, and leans as a whole.
    lean = rng.choice((-1.5, 1.5, 2.5, -2.5))
    bend = rng.uniform(0, 6.3)
    centres = {}
    for y in range(top, OBJECT_BOTTOM + 1):
        rise = (OBJECT_BOTTOM - y) / (OBJECT_BOTTOM - top)
        centres[y] = OBJECT_CENTRE + lean * rise * rise + math.sin(rise * 5 + bend) * 0.8
    for y, centre in centres.items():
        width = 5 if y > OBJECT_BOTTOM - 30 else 4 if y > red_from - 10 else 3
        flare = 2 if y == OBJECT_BOTTOM else 1 if y > OBJECT_BOTTOM - 3 else 0
        left = round(centre - width / 2) - flare
        # The upper bark peels off into the grey-brown below over a few rows.
        shades = PINE_CROWN_BARK if y < red_from + rng.randint(-3, 3) else PINE_BARK
        for x in range(left, left + width + 2 * flare):
            index = x - left
            canvas[y][x] = shades[0] if index == 1 else shades[2] if index == width + 2 * flare - 2 else shades[1]
        canvas[y][left - 1] = canvas[y][left + width + 2 * flare] = shades[3]
    # Furrows in the grey-brown bark below, and the stubs of dead lower branches.
    for _ in range(8):
        y = rng.randint(red_from + 2, OBJECT_BOTTOM - 4)
        x = round(centres[y]) + rng.choice((-1, 0, 1))
        canvas[y][x] = canvas[y + 1][x] = "soil_dark"
    side = rng.choice((-1, 1))
    for _ in range(2 + seed % 2):
        y = rng.randint(red_from - 6, OBJECT_BOTTOM - 24)
        x = round(centres[y]) + side * 3
        for step in range(rng.randint(2, 3)):
            canvas[y - step // 2][x + side * step] = "soil_dark"
        side = -side
    # The crown: clumps on branches that spread up and out from the top third of the trunk, the
    # lower ones reaching furthest, so the crown is wide and flat on top. Its outline stays ragged.
    clumps = [(centres[top], top + 2, 7 + rng.uniform(0, 2))]
    side = rng.choice((-1, 1))
    for index in range(5 + seed % 2):
        foot_y = top + 4 + index * 4 + rng.randint(0, 2)
        reach = side * (5 + index * 1.6 + rng.uniform(0, 3))
        rise = 3 + index + rng.randint(0, 2)
        cx = centres[foot_y] + reach
        cy = foot_y - rise
        clumps.append((cx, cy, 4.5 + rng.uniform(0, 2.5) + index * 0.3))
        # The branch: from the trunk, up and out to under its clump.
        steps = max(abs(round(reach)), 1)
        for step in range(steps + 1):
            x = round(centres[foot_y] + reach * step / steps)
            y = round(foot_y - rise * step / steps + 2)
            canvas[y][x] = "russet_deep"
            if step < 3:
                canvas[y + 1][x] = "soil_dark"
        side = -side
    # Two more clumps fill out the top, so it reads as one crown and not as pads on a stick.
    for side in (-1, 1):
        clumps.append((centres[top] + side * rng.uniform(4, 6), top + 5 + rng.randint(0, 2), 5 + rng.uniform(0, 1.5)))
    # The lowest clump is drawn first, so the ones above overlap it like layers.
    for cx, cy, width in sorted(clumps, key=lambda clump: -clump[1]):
        needle_clump(canvas, rng, cx, cy, width)
    return canvas


def needle_clump(canvas, rng, cx, cy, half_width):
    """A flat cloud of needles, lit on top and dark underneath, ragged at its rim."""
    ovals = [(cx, cy, half_width, 3.5)]
    for _ in range(5):
        ovals.append((cx + rng.uniform(-0.75, 0.75) * half_width, cy + rng.uniform(-2.5, 1.0), rng.uniform(3, 5.5), rng.uniform(2.5, 3.5)))
    covered = set()
    for y in range(max(0, math.floor(cy - 6)), math.ceil(cy + 6)):
        for x in range(math.floor(cx - half_width - 5), math.ceil(cx + half_width + 5)):
            if not 0 <= x < OBJECT_CELL_WIDTH:
                continue
            inside = min(((x + 0.5 - ox) / rx) ** 2 + ((y + 0.5 - oy) / ry) ** 2 for ox, oy, rx, ry in ovals)
            if inside < 1 + rng.uniform(-0.25, 0.25):
                covered.add((x, y))
    for x, y in sorted(covered):
        if (x, y - 1) not in covered or (x, y + 1) not in covered or (x - 1, y) not in covered or (x + 1, y) not in covered:
            canvas[y][x] = PINE_NEEDLES[3]
            continue
        # Lit where there is open sky a row or two above, dark where the clump ends below.
        lit = (x, y - 2) not in covered
        dark = (x, y + 2) not in covered or rng.random() < 0.15
        canvas[y][x] = PINE_NEEDLES[2] if dark else PINE_NEEDLES[0] if lit else PINE_NEEDLES[1]
    # Tufts of needles stick out of the rim, so it is not a smooth oval.
    rim = sorted(covered)
    for x, y in rng.sample(rim, min(len(rim), 10)):
        dx, dy = rng.choice(((0, -1), (1, -1), (-1, -1), (1, 0), (-1, 0)))
        if (x + dx, y + dy) not in covered and 0 <= x + dx < OBJECT_CELL_WIDTH and canvas[y + dy][x + dx] is None:
            canvas[y + dy][x + dx] = PINE_NEEDLES[3]


def draw_branch(canvas, rng, x, y, direction, length, colour):
    """A twisting branch going up from (x, y), drifting sideways, 2 px thick near the
    trunk; may fork once."""
    for step in range(length):
        y -= 1
        if y < 0 or not 0 <= x < OBJECT_CELL_WIDTH - 1:
            return
        canvas[y][x] = colour
        if step < length // 2:
            canvas[y][x + 1] = "mud_dark"
        if rng.random() < 0.7:
            x += direction
            canvas[y][x] = colour
        if step == length // 2 and length > 6:
            draw_branch(canvas, rng, x, y, -direction, length // 2, colour)


def twigs(canvas, rng, x, y, angle, length, colours, forks, spread):
    """A bare branch growing from (x, y) at `angle` (radians from straight up, positive to the
    right), wavering a little, that forks `forks` times into two thinner, shorter ones `spread`
    either side of it: a limb ending in a fan of fine twigs. `colours` are its lit and its
    shaded side; a limb that still forks twice or more is 2 px thick, and the last twigs are all
    shade."""
    for _ in range(length):
        x += math.sin(angle)
        y -= math.cos(angle)
        angle += rng.uniform(-0.12, 0.12)
        px, py = round(x), round(y)
        if not (0 <= px < OBJECT_CELL_WIDTH - 1 and 0 <= py < OBJECT_CELL_HEIGHT):
            return
        canvas[py][px] = colours[0] if forks else colours[1]
        if forks >= 2:
            canvas[py][px + 1] = colours[1]
    if forks:
        for side in (-1, 1):
            twigs(canvas, rng, x, y, angle + side * spread * rng.uniform(0.6, 1.2), max(2, round(length * 0.68)), colours, forks - 1, spread)


def dead_tree(seed):
    """A long-dead tree: a solid, weathered grey trunk, snapped off at the top, with a few
    thick, gnarled limbs broken off short. Lit from the left, outlined in ink."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 12)
    # The trunk leans a little and bends once; it is thick at the foot, flaring into roots.
    top = 27 + rng.randint(0, 4)
    lean = rng.choice((-2, -1, 1, 2))
    trunk = []
    for y in range(OBJECT_BOTTOM, top - 1, -1):
        rise = (OBJECT_BOTTOM - y) / (OBJECT_BOTTOM - top)
        x = OBJECT_CENTRE + lean * rise + math.sin(rise * math.pi * 1.5) * 1.2
        radius = 5 - 1.8 * rise + max(0, 3 - (OBJECT_BOTTOM - y)) * 0.9
        trunk.append((x, y, radius))
    for x, y, radius in trunk:
        deadwood_disc(canvas, x, y, radius)
    # Limbs from the upper half, each curving upwards and broken off.
    first_side = rng.choice((-1, 1))
    for index, height in enumerate((0.4, 0.62, 0.8)[: 2 + seed % 2]):
        side = first_side * (-1) ** index
        x, y, radius = trunk[round(len(trunk) * (height + rng.uniform(-0.05, 0.05)))]
        angle = math.radians(side * rng.uniform(62, 78))
        thickness = 2.5 - index * 0.4
        for step in range(rng.randint(11, 15)):
            x += math.sin(angle)
            y -= math.cos(angle)
            angle -= side * math.radians(3)
            deadwood_disc(canvas, x, y, thickness - step * 0.06)
        broken_end(canvas, round(x), round(y))
    # The trunk snapped off at a slant, its high point on the left.
    tip_x = round(trunk[-1][0])
    for y in range(top - 4, top + 5):
        for x in range(tip_x - 4, tip_x + 5):
            if y - top < (x - tip_x) * 1.2 + 1:
                canvas[y][x] = None
    broken_end(canvas, tip_x - 2, top + 1)
    # Cracks in the bark, and a knothole.
    for _ in range(9):
        x, y = rng.randint(OBJECT_CENTRE - 3, OBJECT_CENTRE + 3), rng.randint(top + 4, OBJECT_BOTTOM - 4)
        if canvas[y][x] in ("stone", "stone_light") and canvas[y + 3][x] in ("stone", "stone_light"):
            for step in range(rng.randint(2, 4)):
                canvas[y + step][x] = "stone_dark"
    hole_x, hole_y = round(trunk[len(trunk) // 2][0]), OBJECT_BOTTOM - len(trunk) // 2
    canvas[hole_y][hole_x] = canvas[hole_y + 1][hole_x] = "ink"
    canvas[hole_y - 1][hole_x] = "stone_dark"
    canvas[hole_y][hole_x + 1] = "bare_light"
    outline_in_bark(canvas, "ink")
    return canvas


def deadwood_disc(canvas, cx, cy, radius):
    """A disc of weathered grey wood, lit on its upper left: one stamp of a trunk or limb."""
    for y in range(math.floor(cy - radius), min(OBJECT_BOTTOM, math.ceil(cy + radius)) + 1):
        for x in range(math.floor(cx - radius), math.ceil(cx + radius) + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if dx * dx + dy * dy > radius * radius:
                continue
            light = (dx * 0.85 + dy * 0.5) / radius
            canvas[y][x] = "stone_light" if light < -0.45 else "stone" if light < 0.2 else "bare" if light < 0.6 else "stone_dark"


def broken_end(canvas, x, y):
    """The splintered end of a limb or of the trunk: pale bare wood with a jagged tip."""
    for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1)):
        if canvas[y + dy][x + dx] is not None:
            canvas[y + dy][x + dx] = "bare_light"
    canvas[y - 2][x - 1] = canvas[y - 1][x - 1] = "bare_light"


def berry_bush(seed, is_picked=False):
    """With berries, or picked: the same bush without them."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 14)
    blobs = [(24, 68, 8.5), (17, 70, 5.5), (31, 70, 5.5), (20, 64, 5.5), (28, 64, 5.5)]
    shaded_blob(canvas, rng, blobs, ("green_light", "green", "green", "green_dark"), "green_deep")
    # Berries on the leaves: red, purple or both, with a pale glint.
    berries = {0: ("ember",), 1: ("heather",)}.get(seed % 3, ("ember", "heather", "petal"))
    for _ in range(0 if is_picked else 11):
        x, y = rng.randint(14, 33), rng.randint(63, 74)
        if canvas[y][x] not in ("green_light", "green", "green_dark"):
            continue
        canvas[y][x] = rng.choice(berries)
        canvas[y][x + 1] = canvas[y][x]
        if canvas[y - 1][x] is not None:
            canvas[y - 1][x] = "cream" if rng.random() < 0.3 else canvas[y - 1][x]
    return canvas


def shrub(seed):
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    shades = (("green_bright", "green_light", "green", "green_dark"),
              ("green_light", "olive", "olive", "green_dark"),
              ("dry_light", "dry", "olive", "green_dark"))[seed % 3]
    ground_shadow(canvas, 12)
    blobs = [(24, 71, 6.5), (17, 73, 4.5), (31, 73, 4.5), (22, 67, 4)]
    shaded_blob(canvas, rng, blobs, shades, "green_deep")
    return canvas


def sapling(seed):
    """A young tree 13 px wide and about 22 tall: a thin trunk tied to a stake."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 7)
    lean = rng.choice((-1, 0, 1))
    for y in range(62, OBJECT_BOTTOM - 1):
        x = OBJECT_CENTRE + lean * (OBJECT_BOTTOM - 2 - y) // 10
        canvas[y][x] = "soil_mid"
        canvas[y][x + 1] = "soil_dark"
    for y in range(64, OBJECT_BOTTOM - 1):
        canvas[y][OBJECT_CENTRE + 3] = "straw"
    canvas[70][OBJECT_CENTRE + 2] = canvas[70][OBJECT_CENTRE + 3] = "sand_light"
    top = OBJECT_CENTRE + lean * 2
    blobs = [(top, 61, 4), (top - 3, 65, 2.5), (top + 3, 64, 2.5)]
    shaded_blob(canvas, rng, blobs, ("green_bright", "green_light", "green"), "green_dark")
    return canvas


def fern_bush(seed):
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 11)
    # The body of the fern, where the fronds join: the dense part, in the dark greens.
    dense_foot(canvas, ((75, 2, "green_dark"), (76, 4, "green_dark"), (77, 5, "green_dark"), (78, 4, "green_deep")))
    # Fronds fan out from the base and droop at their tips, with leaflets along them. Their
    # lower third is in shade.
    for angle in (-78, -58, -36, -14, 8, 30, 54, 76):
        angle = math.radians(angle + rng.uniform(-6, 6))
        length = rng.uniform(9, 12)
        for step in range(int(length * 2)):
            s = step / 2
            x = round(OBJECT_CENTRE + math.sin(angle) * s)
            y = round(77 - math.cos(angle) * s * 0.95 + s * s * 0.02 * abs(math.sin(angle)))
            canvas[y][x] = "green_bright" if step > length * 0.8 else "green_light" if s > length * 0.35 else "green_dark"
            if step % 3 == 1 and step > 3:
                canvas[y + 1][x] = "green_dark"
                canvas[y - 1][x + (1 if step % 2 else -1)] = "green"
    return canvas


def stump(seed):
    """What is left of a felled tree: a short trunk about 16 px wide, its cut top with year rings
    and a crack, bark lit on the left, and roots spreading into the ground."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 13)
    centre_x, top_y, radius_x, radius_y = OBJECT_CENTRE, 67, 7.5, 4
    ground = OBJECT_BOTTOM - 1
    left, right = round(centre_x - radius_x), round(centre_x + radius_x) - 1
    bark = ("soil_light", "soil_mid", "soil", "soil_dark")
    # The sides of the trunk down to the ground, lit on the left, with bark furrows.
    for y in range(top_y, ground + 1):
        for x in range(left, right + 1):
            across = (x + 0.5 - centre_x) / radius_x
            canvas[y][x] = bark[0] if across < -0.55 else bark[1] if across < 0.1 else bark[2] if across < 0.7 else bark[3]
    for _ in range(5):
        x = rng.randint(left + 2, right - 2)
        y = rng.randint(top_y + 4, ground - 3)
        canvas[y][x] = canvas[y + 1][x] = bark[3]
    # Roots: wedges running out from the foot and dipping into the ground, a long one to each
    # side and on some stumps a short one in front.
    roots = [(left - 1, -1, 5, 4), (right + 1, 1, 4, 4)]
    if seed % 2:
        roots.append((centre_x - 3, -1, 2, 2))
    for start, direction, length, height in roots:
        for step in range(length):
            x = start + direction * step
            for y in range(ground - height + 1 + step * height // length, ground + 1):
                canvas[y][x] = bark[1] if direction < 0 else bark[2]
            canvas[ground - height + 1 + step * height // length][x] = bark[0] if direction < 0 else bark[1]
    # The cut top: year rings round the pith, a darker rim of bark, a crack from the middle.
    rings = ("sand_light", "straw", "sand_light", "sand")
    for y in range(round(top_y - radius_y), round(top_y + radius_y)):
        for x in range(left, right + 1):
            distance = math.hypot((x + 0.5 - centre_x) / radius_x, (y + 0.5 - top_y) / radius_y)
            if distance > 1:
                continue
            if distance > 0.82:
                canvas[y][x] = bark[1] if x < centre_x else bark[2]
            else:
                canvas[y][x] = rings[min(len(rings) - 1, int(distance / 0.82 * len(rings)))]
    canvas[top_y][centre_x - 1] = "soil_mid"
    for step in range(1, 4):
        canvas[top_y + (step > 2)][centre_x - 1 + step] = "soil"
    outline_in_bark(canvas)
    return canvas


def dead_stump(seed):
    """What is left of a felled dead tree: a short stub of weathered grey wood like the dead
    tree's, its top snapped off into a ragged crown of pale splinters round a dark rotten
    heart, split by cracks, with roots; odd seeds wear moss on the left, even ones a bracket
    fungus on the right."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 13)
    centre_x, top_y, radius_x = OBJECT_CENTRE, 63, 7
    ground = OBJECT_BOTTOM - 1
    left, right = centre_x - radius_x, centre_x + radius_x - 1
    wood = ("stone_light", "stone", "bare", "stone_dark")
    # The splinters: each column is broken off at its own height, a few stand up as spikes.
    tops = {}
    for x in range(left, right + 1):
        tops[x] = top_y + rng.randint(0, 2) - (3 if rng.random() < 0.2 else 0)
        if abs(x - centre_x) < 3:
            tops[x] += 2
    for x, top in tops.items():
        across = (x + 0.5 - centre_x) / radius_x
        shade = wood[0] if across < -0.55 else wood[1] if across < 0.1 else wood[2] if across < 0.7 else wood[3]
        for y in range(top, ground + 1):
            canvas[y][x] = shade
        canvas[top][x] = canvas[top + 1][x] = "bare_light"
        if abs(x - centre_x) < 3:
            canvas[top][x] = "ink"
            canvas[top + 1][x] = canvas[top + 2][x] = "stone_dark"
    # Cracks running down the grey wood from the broken top.
    for _ in range(3):
        x = rng.randint(left + 2, right - 2)
        for y in range(tops[x] + 3, min(ground - 2, tops[x] + 3 + rng.randint(3, 8))):
            canvas[y][x] = "stone_dark"
    # Roots: wedges running out from the foot, in the same grey.
    roots = [(left - 1, -1, 5, 4), (right + 1, 1, 4, 4)]
    if seed % 2:
        roots.append((centre_x - 3, -1, 2, 2))
    for start, direction, length, height in roots:
        for step in range(length):
            x = start + direction * step
            first_row = ground - height + 1 + step * height // length
            for y in range(first_row, ground + 1):
                canvas[y][x] = wood[1] if direction < 0 else wood[2]
            canvas[first_row][x] = wood[0] if direction < 0 else wood[1]
    if seed % 2:
        for _ in range(14):
            x, y = rng.randint(left, left + 4), rng.randint(ground - 9, ground - 1)
            canvas[y][x] = rng.choice(("green_dark", "green", "green_light"))
    else:
        for x, y in ((right - 3, ground - 6), (right - 2, ground - 6), (right - 1, ground - 6), (right - 2, ground - 5)):
            canvas[y][x] = "sand_light" if y < ground - 5 else "soil_mid"
    outline_in_bark(canvas, "ink")
    return canvas


def outline_in_bark(canvas, colour="soil_dark"):
    """A one pixel outline round everything drawn except the ground shadow, by default in the
    darkest bark colour."""
    canvas[:] = outline(canvas, colour, ignoring=("shadow",))


def vegetation():
    """The vegetation rows of assets/objects.png, in the order of their atlas_row in
    game/state/world_object_types.gd, starting at row 4, after the camp rows."""
    return [
        [spruce(seed) for seed in (121, 122, 123)],
        [pine(seed) for seed in (131, 132, 133)],
        [dead_tree(seed) for seed in (141, 142, 143)],
        # Columns 0 to 2 bear berries, 3 to 5 are the same bushes picked.
        [berry_bush(seed) for seed in (151, 152, 153)]
        + [berry_bush(seed, is_picked=True) for seed in (151, 152, 153)],
        [shrub(seed) for seed in (161, 162, 163)],
        [sapling(seed) for seed in (171, 172, 173)],
        [fern_bush(seed) for seed in (181, 182, 183)],
    ]


OAK_SEEDS = (101, 102, 103)
