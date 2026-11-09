"""The vegetation and rocks of assets/objects.png: oak, stone, spruce, pine, dead tree, berry
bush, shrub, sapling, fern, boulder, and the stumps trees leave behind, drawn at 32 px per tile.

Every object is a 96x160 cell (canvas.GAME_OBJECT_CELL_WIDTH x _HEIGHT) with its feet at the
bottom centre; `vegetation()` returns the rows in the atlas order. Pictures are lists of rows of
palette colour names. The light comes from the top left. Nothing here is outlined in ink: each
plant and rock is rimmed in the darkest shade of its own colours, and stands on a ground shadow.
"""

import math
import random

import forms
import numpy as np
from canvas import GAME_OBJECT_BOTTOM, GAME_OBJECT_CELL_HEIGHT, GAME_OBJECT_CELL_WIDTH, GAME_OBJECT_CENTRE, blank, outline, rect

# The cell the plants are drawn in, and where an object stands in it.
WIDTH, HEIGHT = GAME_OBJECT_CELL_WIDTH, GAME_OBJECT_CELL_HEIGHT
CENTRE, BOTTOM = GAME_OBJECT_CENTRE, GAME_OBJECT_BOTTOM

BARK = ("soil_mid", "soil", "soil", "soil_dark")
LEAVES = ("green_bright", "green_light", "green", "green_dark", "green_deep", "olive")
# What shade_under_crown takes for foliage: the ground shadow too.
FOLIAGE = LEAVES + ("shadow",)
# How lit a pixel of a crown must be for each shade of its ramp, lightest first (see `foliage`);
# below DEEP_SHADE it is the crown's edge colour, a gap deep between the sprays.
FOLIAGE_THRESHOLDS = (0.62, 0.3, -0.05)
DEEP_SHADE = -0.75


def cell():
    """A clear cell of the object atlas."""
    return blank(WIDTH, HEIGHT)


def ground_shadow(canvas, half_width, centre=CENTRE, rows=5):
    """A soft dark oval on the ground under an object, `rows` high, with a dithered rim; it is
    drawn first so the object covers its middle."""
    middle = BOTTOM - (rows - 1) / 2
    for y in range(BOTTOM - rows + 1, BOTTOM + 1):
        across = (y - middle) / (rows / 2)
        reach = half_width * math.sqrt(max(0.0, 1 - across * across))
        for x in range(math.floor(centre - reach), math.ceil(centre + reach)):
            if abs(x + 0.5 - centre) < reach - 1.5 or (x + y) % 2 == 0:
                canvas[y][x] = "shadow"


def dense_foot(canvas, rows, rim="green_deep", centre=CENTRE):
    """The dense foot of a plant with loose blades, drawn with a rim round it: `rows` are
    (y, half width, colour) from the top down, each centred on `centre`. The rim is the darkest
    shade of the plant's own ramp, never ink, and the blades above it get none."""
    foot = cell()
    for y, half_width, colour in rows:
        rect(foot, centre - half_width, y, centre + half_width - 1, y, colour)
    paste(canvas, outline(foot, rim))


def blade(canvas, x0, y0, height, lean, shades, droop=0.0, shaded=0.35):
    """A leaf or grass blade from its foot (x0, y0), `height` px tall, curving over by `lean` px
    and drooping by `droop` at its tip: two pixels wide in its lower half, one at the tip. Its
    lower part (`shaded`, a share of its height) is in `shades[0]`, the darkest; above, its left
    edge is lit (`shades[2]`) and its right in `shades[1]`."""
    steps = round(height * 1.5) + 1
    for step in range(steps):
        t = step / steps
        x = round(x0 + lean * t * t)
        y = round(y0 - height * t + droop * t**4)
        if not (0 <= x < WIDTH - 1 and 0 <= y <= BOTTOM):
            return
        if t < shaded:
            canvas[y][x] = canvas[y][x + 1] = shades[0]
        elif t < 0.6:
            canvas[y][x], canvas[y][x + 1] = shades[2], shades[1]
        else:
            canvas[y][x] = shades[1] if t < 0.85 else shades[2]


def paste(canvas, picture):
    """Draws the drawn pixels of `picture` (as big as the canvas) over the canvas."""
    for y, row in enumerate(picture):
        for x, colour in enumerate(row):
            if colour is not None:
                canvas[y][x] = colour


def foliage(canvas, rng, clumps, shades, edge, leaf_size=3.2, holes=0):
    """A crown of leaves: the clumps (cx, cy, radius) drawn from the back (the top) to the front,
    each a ragged dome lit from the top left, its surface broken into sprays of leaves about
    `leaf_size` px across, each lit on its own upper left and dark where it meets the next. The
    crown darkens towards its foot. `shades` are four, lightest first; the crown's border and
    the deepest gaps between the sprays are `edge`, and `holes` dark gaps show the branches."""
    xs, ys = forms.grid(WIDTH, HEIGHT)
    crown = np.zeros((HEIGHT, WIDTH), bool)
    level = np.zeros((HEIGHT, WIDTH))
    for cx, cy, radius in sorted(clumps, key=lambda clump: clump[1]):
        # The rim bulges in a few lobes (a tenth of the radius) with finer ripples on them.
        angle = np.arctan2(ys - cy, xs - cx)
        phase, lobes = rng.uniform(0, 6.3), rng.choice((5, 6, 7))
        ragged = radius * (1 + 0.1 * np.sin(angle * lobes + phase) + 0.05 * np.sin(angle * 13 + phase * 2))
        distance = np.hypot(xs - cx, ys - cy)
        mask = distance <= ragged
        rise = np.sqrt(np.clip(1 - (distance / ragged) ** 2, 0, 1))
        lit = ((xs - cx) / ragged * forms.LIGHT[0] + (ys - cy) / ragged * forms.LIGHT[1] + rise * forms.LIGHT[2])
        # The sprays: every pixel belongs to the nearest of points strewn over the clump, about
        # one point per 2.2 squares of `leaf_size`, so a spray is about `leaf_size` across.
        count = max(4, round(math.pi * radius * radius / (leaf_size * leaf_size * 2.2)))
        points = []
        while len(points) < count:
            px, py = cx + rng.uniform(-radius, radius), cy + rng.uniform(-radius, radius)
            if math.hypot(px - cx, py - cy) <= radius:
                points.append((px, py))
        offsets = np.array([[xs - px, ys - py] for px, py in points])
        distances = np.hypot(offsets[:, 0], offsets[:, 1])
        order = np.argsort(distances, axis=0)
        nearest = np.take_along_axis(distances, order[:1], axis=0)[0]
        second = np.take_along_axis(distances, order[1:2], axis=0)[0]
        dx = np.take_along_axis(offsets[:, 0], order[:1], axis=0)[0]
        dy = np.take_along_axis(offsets[:, 1], order[:1], axis=0)[0]
        # How lit a pixel is: mostly the clump's dome, then its spray's own top-left light, less
        # within about a pixel of the seam to the next spray, and a little grain against banding.
        spray = -(dx * 0.6 + dy * 0.8) / leaf_size
        seam = np.clip(1 - (second - nearest) / 1.2, 0, 1)
        grain = np.random.default_rng(rng.randrange(2**32)).uniform(-0.08, 0.08, (HEIGHT, WIDTH))
        clump_level = lit + 0.32 * spray - 0.45 * seam + grain
        level[mask] = clump_level[mask]
        crown |= mask
    rows = np.nonzero(crown)[0]
    top, foot = rows.min(), rows.max()
    # The crown's foot is in its own shade: up to a third of the ramp darker than its top.
    level -= 0.35 * (ys - 0.5 - top) / max(1, foot - top)
    # A hole is darker than any light can make a pixel, so it is always the edge colour.
    for _ in range(holes):
        x, y = rng.choice(list(zip(*np.nonzero(crown)[::-1])))
        level[forms.ellipse(WIDTH, HEIGHT, x, y, rng.uniform(1, 2), rng.uniform(0.8, 1.5)) & crown] = -math.inf
    for y, x in zip(*np.nonzero(crown)):
        steps = sum(level[y, x] <= threshold for threshold in FOLIAGE_THRESHOLDS)
        canvas[y][x] = edge if level[y, x] < DEEP_SHADE else shades[steps]
    border = forms.edge(crown)
    for y, x in zip(*np.nonzero(border)):
        canvas[y][x] = edge


def tree_trunk(canvas, rng, top, width, shades=BARK, flare=4):
    """A trunk from `top` down to the ground, round and lit on the left, spreading into roots at
    its foot, with furrows in the bark. Its outline is the darkest shade (`shades` are lit to
    dark, the last also the outline)."""
    left = CENTRE - width / 2
    for y in range(top, BOTTOM + 1):
        # The roots spread over the lowest rows, more the nearer the ground.
        spread = flare * max(0.0, 1 - (BOTTOM - y) / 7) ** 2
        x0, x1 = math.floor(left - spread), math.ceil(left + width + spread)
        for x in range(x0, x1):
            across = (x + 0.5 - x0) / (x1 - x0)
            canvas[y][x] = shades[0] if across < 0.25 else shades[1] if across < 0.6 else shades[2]
    # Furrows wander down the bark, with a lit ridge beside each on the lit side.
    for start in range(round(left) + 2, round(left + width) - 1, 3):
        x = start + rng.uniform(-0.5, 0.5)
        y = top + rng.randint(0, 6)
        while y < BOTTOM - 2:
            run = rng.randint(3, 9)
            for _ in range(run):
                if y >= BOTTOM - 1:
                    break
                px = round(x)
                if canvas[y][px] in shades[:3]:
                    canvas[y][px] = shades[3]
                    if px - 1 > left and px < CENTRE and canvas[y][px - 1] == shades[1]:
                        canvas[y][px - 1] = shades[0]
                y += 1
                x += rng.choice((-0.3, 0, 0, 0.3))
            y += rng.randint(1, 4)
    outline_in_bark(canvas, shades[3])


def limb(canvas, start, end, radius, shades=BARK):
    """A limb from the trunk at `start` to `end`, `radius` thick at its foot and tapering, lit on
    its upper side; the crown drawn over it hides its far end."""
    mask = forms.capsule(WIDTH, HEIGHT, start, end, radius, radius * 0.6)
    forms.shade(canvas, mask, (shades[3], shades[1], shades[0]), radius=2)


def shade_under_crown(canvas, shades=BARK):
    """Darkens the trunk where the crown above it casts a shadow, and the crown's own underside,
    so the two read as joined rather than stacked."""
    dark = shades[-1]
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if canvas[y][x] in shades and any(0 <= y - up and canvas[y - up][x] in FOLIAGE for up in range(1, 8)):
                canvas[y][x] = dark if any(canvas[y - up][x] in FOLIAGE for up in range(1, 4)) else shades[2]
    for x in range(WIDTH):
        lowest = max((y for y in range(HEIGHT) if canvas[y][x] in FOLIAGE), default=None)
        if lowest is None:
            continue
        for up in (1, 2):
            if canvas[lowest - up][x] in ("green_bright", "green_light", "green"):
                canvas[lowest - up][x] = "green_dark"


def oak(seed):
    """The oak in leaf: a stout, furrowed trunk with its first thick limbs, under a broad crown of
    rounded clumps, every variant shaped differently. The crown reaches down over the upper trunk,
    so a dense wood reads as one canopy."""
    rng = random.Random(seed)
    canvas = cell()
    ground_shadow(canvas, 28, rows=7)
    tree_trunk(canvas, rng, 100, 14)
    if seed % 3 != 0:
        limb(canvas, (44, 126), (26, 104), 3.5)
    if seed % 3 != 1:
        limb(canvas, (54, 122), (72, 100), 3.5)
    blobs = [(48 + rng.uniform(-2, 2), 76 + rng.uniform(-2, 2), rng.uniform(24, 27))]
    for cx, cy, radius in ((18, 88, 16), (78, 88, 16), (48, 50, 16), (28, 62, 16), (68, 62, 16), (36, 102, 12), (60, 102, 12)):
        blobs.append((cx + rng.uniform(-4, 4), cy + rng.uniform(-3, 3), radius + rng.uniform(-2, 2)))
    foliage(canvas, rng, blobs, LEAVES[:4], "green_deep", holes=4)
    shade_under_crown(canvas)
    return canvas


def bare_oak(seed):
    """The oak in winter: the trunk of the same seed, parting into a few thick, crooked limbs that
    fan out into twigs in the shape of the crown."""
    rng = random.Random(seed)
    canvas = cell()
    ground_shadow(canvas, 28, rows=7)
    tree_trunk(canvas, rng, 100, 14)
    limbs = ((-0.95, 30), (-0.4, 40), (0.15, 44), (0.65, 38), (1.15, 26))
    # Fewer limbs on some variants, so a forest is not a wall of twigs.
    for angle, length in rng.sample(limbs, 5 - seed % 3):
        angle += rng.uniform(-0.12, 0.12)
        crown_limb(canvas, rng, (CENTRE + angle * 5, 104), angle, length, BARK)
    return canvas


def crown_limb(canvas, rng, start, angle, length, shades, forks=3, spread=0.45):
    """A bare limb from the top of a trunk at `start`, leaning `angle` (radians from straight up),
    thick and elbowed, then forking into fine twigs (see `twigs`)."""
    elbow = angle + rng.uniform(-0.25, 0.25)
    middle = (start[0] + math.sin(angle) * length * 0.55, start[1] - math.cos(angle) * length * 0.55)
    end = (middle[0] + math.sin(elbow) * length * 0.45, middle[1] - math.cos(elbow) * length * 0.45)
    mask = forms.capsule(WIDTH, HEIGHT, start, middle, 4, 3) | forms.capsule(WIDTH, HEIGHT, middle, end, 3, 1.6)
    forms.shade(canvas, mask, (shades[3], shades[1], shades[0]), radius=2)
    forms.paint(canvas, forms.edge(mask), shades[3])
    side = rng.choice((-1, 1))
    twigs(canvas, rng, middle[0], middle[1], elbow + side * 0.7, round(length * 0.3), (shades[1], shades[3]), 2, spread)
    twigs(canvas, rng, end[0], end[1], elbow, round(length * 0.32), (shades[1], shades[3]), forks, spread)


def stone(seed):
    """A small fieldstone about a tile across, for the second variant with a pebble beside it."""
    canvas = cell()
    ground_shadow(canvas, 16)
    stones = [(48, 147, 12, 9.5)] if seed % 2 else [(44, 148, 10.5, 8.5), (60, 154, 5, 3.5)]
    rock(canvas, random.Random(seed), stones, ("stone_dark", "stone", "stone", "stone_light"))
    return canvas


def boulder(seed):
    """A boulder on 2x1 tiles (the cell is centred on its footprint), cracked, with moss on its lit
    top."""
    rng = random.Random(seed)
    canvas = cell()
    ground_shadow(canvas, 30, rows=6)
    rock(canvas, rng, [(46, 138, 20, 17), (32, 145, 12, 11), (62, 143, 13, 13), (52, 128, 14, 11)], ("stone_dark", "stone", "stone", "stone_light"))
    # A crack down the stone, lit on its upper edge.
    x = 54.0
    for y in range(124, 146):
        x += rng.choice((0, 0.4, 0.6))
        if canvas[y][round(x)] in ("stone", "stone_light"):
            canvas[y][round(x)] = "stone_dark"
            if canvas[y][round(x) - 1] == "stone":
                canvas[y][round(x) - 1] = "stone_light"
    # Moss on the lit top: small cushions, lit on top.
    for _ in range(9):
        cx, cy = rng.uniform(30, 58), rng.uniform(118, 132)
        for dy, dx, colour in ((0, 0, "green_light"), (0, 1, "green"), (1, -1, "olive"), (1, 0, "green"), (1, 1, "olive"), (1, 2, "green_dark")):
            x, y = round(cx) + dx, round(cy) + dy
            if canvas[y][x] in ("stone", "stone_light"):
                canvas[y][x] = colour
    return canvas


def rock(canvas, rng, ovals, shades):
    """Stones (cx, cy, rx, ry) shaded as one lump by the light from the top left, flecked, with a
    glint and a rim in the darkest shade."""
    mask = np.zeros((HEIGHT, WIDTH), bool)
    for cx, cy, rx, ry in ovals:
        mask |= forms.ellipse(WIDTH, HEIGHT, cx, cy, rx, ry)
    mask[BOTTOM:, :] = False
    forms.shade(canvas, mask, shades, radius=6, top_light=0.25)
    for y, x in zip(*np.nonzero(forms.shrunk(mask))):
        if rng.random() < 0.06:
            canvas[y][x] = "stone_dark" if canvas[y][x] == "stone" else "stone" if canvas[y][x] == "stone_light" else canvas[y][x]
    for y, x in zip(*np.nonzero(forms.edge(mask))):
        canvas[y][x] = shades[0]


def conifer_tier(canvas, rng, top, bottom, half_width):
    """One tier of a spruce: branches hanging from the stem in a ragged triangle, in sprays that
    droop outwards, their tips hanging below the tier's foot; lit on the left and on top, dark
    underneath and at the rim."""
    phase = rng.uniform(0, 6.3)
    tier = set()
    for y in range(top, bottom + 3):
        progress = min(1.0, (y - top) / (bottom - top))
        reach = half_width * (0.15 + 0.85 * progress) + rng.uniform(-1, 1)
        for x in range(math.floor(CENTRE - reach), math.ceil(CENTRE + reach) + 1):
            across = abs(x + 0.5 - CENTRE)
            # The foot hangs in tips, lowest at the end of each spray.
            foot = bottom - 3 + 5 * ((across + phase) % 7) / 7
            if across <= reach and y <= foot:
                tier.add((x, y))
    for x, y in tier:
        side = (x + 0.5 - CENTRE) / half_width
        spray = math.sin(((y - top) - abs(x + 0.5 - CENTRE) * 0.55) / 5 * math.tau + phase)
        light = -side * 0.5 + spray * 0.35 - (y - top) / (bottom - top) * 0.45 + rng.uniform(-0.15, 0.15)
        if (x, y - 1) not in tier or (x - 1, y) not in tier or (x + 1, y) not in tier or (x, y + 1) not in tier:
            canvas[y][x] = "green_deep"
        elif (x, y + 2) not in tier:
            canvas[y][x] = "green_dark"
        else:
            canvas[y][x] = "green_light" if light > 0.25 else "green" if light > -0.25 else "green_dark"


def spruce(seed):
    """A spruce: tall and narrow, seven tiers of hanging branches, the widest at the bottom, each
    overlapping the next, the straight stem showing at the foot."""
    rng = random.Random(seed)
    canvas = cell()
    ground_shadow(canvas, 22, rows=6)
    tree_trunk(canvas, rng, 130, 9, flare=3)
    tiers = [(112, 142, 28), (96, 126, 25), (80, 110, 22), (64, 94, 19), (48, 78, 15.5), (34, 62, 12), (24 + rng.randint(0, 4), 46, 8)]
    for top, bottom, half_width in tiers:
        conifer_tier(canvas, rng, top, bottom, half_width + rng.uniform(-1, 1))
    # The leader at the very top.
    for y in range(tiers[-1][0] - 4, tiers[-1][0] + 2):
        canvas[y][CENTRE] = "green_dark"
        canvas[y][CENTRE - 1] = "green_deep" if y < tiers[-1][0] else canvas[y][CENTRE - 1]
    shade_under_crown(canvas)
    return canvas


# A Scots pine: the trunk's bark, grey-brown and furrowed below, thinner and a warm brown in the
# crown (each lit to dark, then its outline), and the dark blue-green needles (lit top to dark
# underside, then the outline).
PINE_BARK = ("mud", "mud_dark", "soil_dark", "soil_dark")
PINE_CROWN_BARK = ("soil_light", "soil_mid", "rust_dark", "soil_dark")
PINE_NEEDLES = ("meadow_light", "meadow", "green_deep", "bog_dark")
# How far below the top of the trunk the bark turns from warm brown to grey-brown, in rows.
PINE_CROWN_BARK_DEPTH = 68


def pine(seed):
    """A Scots pine: a tall, slightly crooked trunk, bare for most of its height, warm brown up in
    the crown and grey-brown below with a few dead branch stubs; the crown is a loose, flat-topped
    umbrella of dark blue-green needle clumps on branches spreading from the top third, with gaps
    where the sky shows through."""
    rng = random.Random(seed)
    canvas = cell()
    ground_shadow(canvas, 20, rows=6)
    top = 18 + rng.randint(0, 6)
    red_from = top + PINE_CROWN_BARK_DEPTH
    # The trunk wanders a little from side to side as it rises, and leans as a whole.
    lean = rng.choice((-3, 3, 5, -5))
    bend = rng.uniform(0, 6.3)
    centres = {}
    for y in range(top, BOTTOM + 1):
        rise = (BOTTOM - y) / (BOTTOM - top)
        centres[y] = CENTRE + lean * rise * rise + math.sin(rise * 5 + bend) * 1.6
    peel = {}
    for y, centre in centres.items():
        width = 10 if y > BOTTOM - 60 else 8 if y > red_from - 20 else 6
        spread = 4 * max(0.0, 1 - (BOTTOM - y) / 6) ** 2
        left = round(centre - width / 2 - spread)
        right = round(centre + width / 2 + spread)
        # The upper bark peels off into the grey-brown below over a few rows.
        peel.setdefault(y // 3, rng.randint(-6, 6))
        shades = PINE_CROWN_BARK if y < red_from + peel[y // 3] else PINE_BARK
        for x in range(left, right):
            across = (x + 0.5 - left) / (right - left)
            canvas[y][x] = shades[0] if across < 0.3 else shades[2] if across > 0.75 else shades[1]
        canvas[y][left - 1] = canvas[y][right] = shades[3]
    # Plates and furrows in the grey-brown bark below, and the stubs of dead lower branches.
    for _ in range(26):
        y = rng.randint(red_from + 4, BOTTOM - 6)
        x = round(centres[y]) + rng.randint(-3, 2)
        for step in range(rng.randint(2, 5)):
            canvas[y + step][x] = "soil_dark"
        if canvas[y][x - 1] == PINE_BARK[1]:
            canvas[y][x - 1] = PINE_BARK[0]
    side = rng.choice((-1, 1))
    for _ in range(2 + seed % 2):
        y = rng.randint(red_from - 12, BOTTOM - 48)
        x = round(centres[y]) + side * 5
        for step in range(rng.randint(4, 6)):
            canvas[y - step // 2][x + side * step] = "soil_dark"
            canvas[y - step // 2 - 1][x + side * step] = "mud"
        side = -side
    # The crown: clumps on branches that spread up and out from the top third of the trunk, the
    # lower ones reaching furthest, so the crown is wide and flat on top. Its outline stays ragged.
    clumps = [(centres[top], top + 4, 14 + rng.uniform(0, 4))]
    side = rng.choice((-1, 1))
    for index in range(5 + seed % 2):
        foot_y = top + 8 + index * 8 + rng.randint(0, 4)
        reach = side * (10 + index * 3.2 + rng.uniform(0, 6))
        rise = 6 + 2 * index + rng.randint(0, 4)
        cx = centres[foot_y] + reach
        cy = foot_y - rise
        clumps.append((cx, cy, 9 + rng.uniform(0, 5) + index * 0.6))
        # The branch: from the trunk, up and out to under its clump, thicker at the trunk.
        steps = max(abs(round(reach)), 1)
        for step in range(steps + 1):
            x = round(centres[foot_y] + reach * step / steps)
            y = round(foot_y - rise * step / steps + 4)
            canvas[y][x] = "russet_deep"
            canvas[y - 1][x] = "soil_mid" if step < steps * 0.6 else "russet_deep"
            if step < 5:
                canvas[y + 1][x] = "soil_dark"
        side = -side
    # Two more clumps fill out the top, so it reads as one crown and not as pads on a stick.
    for side in (-1, 1):
        clumps.append((centres[top] + side * rng.uniform(8, 12), top + 10 + rng.randint(0, 4), 10 + rng.uniform(0, 3)))
    # The lowest clump is drawn first, so the ones above overlap it like layers.
    for cx, cy, half_width in sorted(clumps, key=lambda clump: -clump[1]):
        needle_clump(canvas, rng, cx, cy, half_width)
    return canvas


def needle_clump(canvas, rng, cx, cy, half_width):
    """A flat cloud of needles, lit on top and dark underneath, in tufts with dark seams between
    them, ragged at its rim."""
    ovals = [(cx, cy, half_width, 7)]
    for _ in range(7):
        ovals.append((cx + rng.uniform(-0.75, 0.75) * half_width, cy + rng.uniform(-5, 2), rng.uniform(6, 11), rng.uniform(5, 7)))
    covered = set()
    for y in range(max(0, math.floor(cy - 12)), math.ceil(cy + 12)):
        for x in range(math.floor(cx - half_width - 10), math.ceil(cx + half_width + 10)):
            if not 0 <= x < WIDTH:
                continue
            inside = min(((x + 0.5 - ox) / rx) ** 2 + ((y + 0.5 - oy) / ry) ** 2 for ox, oy, rx, ry in ovals)
            if inside < 1 + rng.uniform(-0.2, 0.2):
                covered.add((x, y))
    for x, y in sorted(covered):
        if any((x + dx, y + dy) not in covered for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0))):
            canvas[y][x] = PINE_NEEDLES[3]
            continue
        # Lit where there is open sky a few rows above, dark where the clump ends below; the
        # needles stand in short upright tufts, a seam of shade every few pixels.
        lit = (x, y - 3) not in covered
        dark = (x, y + 3) not in covered or (x, y + 2) not in covered
        seam = (x * 7 + y * 3) % 11 == 0 or rng.random() < 0.1
        if dark:
            canvas[y][x] = PINE_NEEDLES[2]
        elif lit:
            canvas[y][x] = PINE_NEEDLES[0] if not seam else PINE_NEEDLES[1]
        else:
            canvas[y][x] = PINE_NEEDLES[2] if seam else PINE_NEEDLES[1]
    # Tufts of needles stick out of the rim, so it is not a smooth oval.
    rim = sorted(covered)
    for x, y in rng.sample(rim, min(len(rim), 24)):
        dx, dy = rng.choice(((0, -1), (1, -1), (-1, -1), (1, 0), (-1, 0)))
        for step in (1, 2):
            px, py = x + dx * step, y + dy * step
            if (px, py) not in covered and 0 <= px < WIDTH and canvas[py][px] is None:
                canvas[py][px] = PINE_NEEDLES[3]


def twigs(canvas, rng, x, y, angle, length, colours, forks, spread, crooked=False):
    """A bare branch growing from (x, y) at `angle` (radians from straight up, positive to the
    right), wavering a little (`crooked`: an oak's elbows), that forks `forks` times into two
    thinner, shorter ones `spread` either side of it: a limb ending in a fan of fine twigs.
    `colours` are its lit and its shaded side; a limb is as many pixels thick as it still forks
    (at most 3), lit on its left, and the last twigs are one pixel of shade."""
    thickness = min(3, forks)
    for step in range(length):
        x += math.sin(angle)
        y -= math.cos(angle)
        angle += rng.uniform(-0.12, 0.12)
        if crooked and rng.random() < 0.08:
            angle += rng.choice((-0.5, 0.5))
        px, py = round(x), round(y)
        if not (0 <= px < WIDTH - thickness and 0 <= py < HEIGHT):
            return
        if thickness == 0:
            canvas[py][px] = colours[1]
        for across in range(thickness):
            canvas[py][px + across] = colours[0] if across == 0 and thickness > 1 else colours[1]
    if forks:
        for side in (-1, 1):
            twigs(canvas, rng, x, y, angle + side * spread * rng.uniform(0.6, 1.2), max(3, round(length * 0.68)), colours, forks - 1, spread, crooked)


def dead_tree(seed):
    """A long-dead tree: a solid, weathered grey trunk, snapped off at the top, with a few thick,
    gnarled limbs broken off short. Lit from the left, rimmed in its darkest grey."""
    rng = random.Random(seed)
    canvas = cell()
    ground_shadow(canvas, 24, rows=6)
    # The trunk leans a little and bends once; it is thick at the foot, flaring into roots.
    top = 54 + rng.randint(0, 8)
    lean = rng.choice((-4, -2, 2, 4))
    trunk = []
    for y in range(BOTTOM, top - 1, -1):
        rise = (BOTTOM - y) / (BOTTOM - top)
        x = CENTRE + lean * rise + math.sin(rise * math.pi * 1.5) * 2.4
        radius = 10 - 3.6 * rise + max(0, 6 - (BOTTOM - y)) * 0.9
        trunk.append((x, y, radius))
    for x, y, radius in trunk:
        deadwood_disc(canvas, x, y, radius)
    # Limbs from the upper half, each curving upwards and broken off.
    first_side = rng.choice((-1, 1))
    for index, height in enumerate((0.4, 0.62, 0.8)[: 2 + seed % 2]):
        side = first_side * (-1) ** index
        x, y, radius = trunk[round(len(trunk) * (height + rng.uniform(-0.05, 0.05)))]
        angle = math.radians(side * rng.uniform(62, 78))
        thickness = 5 - index * 0.8
        for step in range(rng.randint(22, 30)):
            x += math.sin(angle)
            y -= math.cos(angle)
            angle -= side * math.radians(1.5)
            deadwood_disc(canvas, x, y, thickness - step * 0.06)
        broken_end(canvas, round(x), round(y))
    # The trunk snapped off at a slant, its high point on the left.
    tip_x = round(trunk[-1][0])
    for y in range(top - 8, top + 10):
        for x in range(tip_x - 9, tip_x + 10):
            if y - top < (x - tip_x) * 1.2 + 2:
                canvas[y][x] = None
    broken_end(canvas, tip_x - 4, top + 2)
    # Long cracks in the bark, the grain of the wood, and a knothole.
    for _ in range(12):
        x, y = rng.randint(CENTRE - 6, CENTRE + 6), rng.randint(top + 8, BOTTOM - 8)
        for step in range(rng.randint(5, 12)):
            if canvas[y + step][x] in ("stone", "stone_light", "bare"):
                canvas[y + step][x] = "stone_dark"
                if canvas[y + step][x - 1] == "stone":
                    canvas[y + step][x - 1] = "stone_light"
            x += rng.choice((0, 0, 0, 1, -1))
    hole_x, hole_y = round(trunk[len(trunk) // 2][0]) - 1, BOTTOM - len(trunk) // 2
    hole = forms.ellipse(WIDTH, HEIGHT, hole_x + 0.5, hole_y + 1, 2, 3)
    forms.paint(canvas, hole, "soil_dark")
    canvas[hole_y - 2][hole_x] = canvas[hole_y - 2][hole_x + 1] = "stone_dark"
    canvas[hole_y + 4][hole_x] = canvas[hole_y + 4][hole_x + 1] = "bare_light"
    outline_in_bark(canvas, "stone_dark")
    return canvas


def deadwood_disc(canvas, cx, cy, radius):
    """A disc of weathered grey wood, lit on its upper left: one stamp of a trunk or limb."""
    for y in range(math.floor(cy - radius), min(BOTTOM, math.ceil(cy + radius)) + 1):
        for x in range(math.floor(cx - radius), math.ceil(cx + radius) + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if dx * dx + dy * dy > radius * radius:
                continue
            light = (dx * 0.85 + dy * 0.5) / radius
            canvas[y][x] = "stone_light" if light < -0.45 else "stone" if light < 0.2 else "bare" if light < 0.6 else "stone_dark"


def broken_end(canvas, x, y):
    """The splintered end of a limb or of the trunk: pale bare wood with jagged spikes."""
    for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1), (-1, -1), (1, 1), (0, 1)):
        if canvas[y + dy][x + dx] is not None:
            canvas[y + dy][x + dx] = "bare_light"
    for dx, height in ((-2, 4), (0, 2), (1, 3)):
        for step in range(1, height + 1):
            canvas[y - step][x + dx] = "bare_light" if step < height else "stone"


def leafy_bush(canvas, rng, clumps, shades, edge="green_deep"):
    """A bush: its few woody stems at the foot, under a dense mound of leaves."""
    for dx in (-4, 0, 3):
        for y in range(BOTTOM - 8, BOTTOM):
            canvas[y][CENTRE + dx] = "soil_dark"
    foliage(canvas, rng, clumps, shades, edge, leaf_size=2.8)


def berry_bush(seed, is_picked=False):
    """A berry bush, with berries or picked: the same bush without them."""
    rng = random.Random(seed)
    canvas = cell()
    ground_shadow(canvas, 28, rows=6)
    leafy_bush(canvas, rng, [(48, 138, 17), (34, 142, 11), (62, 142, 11), (40, 128, 11), (56, 128, 11)], ("green_light", "green", "green", "green_dark"))
    # Berries in bunches on the leaves: red, purple or both, each round, lit with a glint on its
    # upper left and dark on its lower right.
    berries = {0: ("ember",), 1: ("heather",)}.get(seed % 3, ("ember", "heather"))
    berry_rng = random.Random(seed + 7)
    for _ in range(0 if is_picked else 8):
        x, y = berry_rng.randint(32, 62), berry_rng.randint(124, 148)
        colour = berry_rng.choice(berries)
        dark = "rust_dark" if colour == "ember" else "heather_dark"
        for bx, by in ((x, y), (x + 3, y + 1), (x + 1, y + 3)):
            if any(canvas[by + dy][bx + dx] not in ("green_light", "green", "green_dark", colour, dark) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                continue
            for dx, dy, shade in ((0, -1, colour), (-1, 0, colour), (0, 0, colour), (1, 0, dark), (0, 1, dark)):
                canvas[by + dy][bx + dx] = shade
            canvas[by - 1][bx] = "cream"
    return canvas


def shrub(seed):
    """A low shrub of small leaves, in one of three greens: fresh, olive or dry."""
    rng = random.Random(seed)
    canvas = cell()
    shades = (("green_bright", "green_light", "green", "green_dark"),
              ("green_light", "olive", "olive", "green_dark"),
              ("dry_light", "dry", "olive", "green_dark"))[seed % 3]
    ground_shadow(canvas, 24, rows=6)
    leafy_bush(canvas, rng, [(48, 144, 13), (34, 148, 9), (62, 148, 9), (44, 134, 8)], shades)
    return canvas


def sapling(seed):
    """A young tree a tile wide and about 44 px tall: a thin leaning trunk that stands on its own,
    a small crown of fresh leaves."""
    rng = random.Random(seed)
    canvas = cell()
    ground_shadow(canvas, 14)
    lean = rng.choice((-1, 0, 1))
    for y in range(124, BOTTOM - 1):
        x = CENTRE + lean * (BOTTOM - 2 - y) // 14
        canvas[y][x - 1] = "soil_mid"
        canvas[y][x] = "soil"
        canvas[y][x + 1] = "soil_dark"
    # The foot is a little wider, so the stem looks rooted without a support.
    for y in range(BOTTOM - 5, BOTTOM - 1):
        x = CENTRE + lean * (BOTTOM - 2 - y) // 14
        canvas[y][x - 2] = "soil_mid"
        canvas[y][x + 2] = "soil_dark"
    top = CENTRE + lean * 4
    foliage(canvas, rng, [(top, 120, 8), (top - 6, 128, 5), (top + 6, 127, 5), (top, 112, 5)], ("green_bright", "green_light", "green", "green_dark"), "green_deep", leaf_size=2.2)
    return canvas


def fern_bush(seed):
    """A bracken fern: a dense dark body where the fronds join, and fronds arching out of it and
    drooping at their tips, each a stalk with a comb of leaflets, shorter towards the tip. The back
    fronds are a shade darker, every frond's underside is in shade, and its lower edge is rimmed in
    the darkest green."""
    rng = random.Random(seed)
    canvas = cell()
    ground_shadow(canvas, 26, rows=6)
    dense_foot(canvas, ((149, 5, "green_dark"), (150, 7, "green_dark"), (151, 9, "green_dark"), (152, 10, "green_deep"), (153, 10, "green_deep"), (154, 8, "green_deep")))
    # The back fronds first, then those in front, so the front ones overlap them.
    angles = sorted((-60, -38, -16, 6, 28, 50, 70), key=lambda angle: -abs(angle))
    for index, angle in enumerate(angles):
        angle = math.radians(angle + rng.uniform(-7, 7))
        frond(canvas, rng, angle, rng.uniform(26, 32), is_back=index < 3)
    return canvas


def frond(canvas, rng, angle, length, is_back):
    """One frond of a fern from the middle of its foot: a stalk arching out at `angle` (radians
    from straight up) and drooping, with leaflets slanting off it on both sides."""
    lit, middle, shade = ("green_light", "green", "green_dark") if is_back else ("green_bright", "green_light", "green")
    points = []
    for step in range(round(length * 1.5) + 1):
        s = step / 1.5
        droop = s * s * 0.028 * (0.3 + abs(math.sin(angle)))
        points.append((CENTRE + math.sin(angle) * s, 151 - math.cos(angle) * s * 1.3 + droop))
    upper, lower = np.zeros((HEIGHT, WIDTH), bool), np.zeros((HEIGHT, WIDTH), bool)
    for index in range(4, len(points), 4):
        x, y = points[index]
        share = index / len(points)
        reach = 5 * math.sin(math.pi * min(1.0, share * 1.15)) + 1.5
        # Leaflets slant towards the tip; the side the stalk bends over is the upper one.
        tx, ty = points[min(index + 2, len(points) - 1)][0] - x, points[min(index + 2, len(points) - 1)][1] - y
        norm = math.hypot(tx, ty) or 1
        tx, ty = tx / norm, ty / norm
        for side, mask in ((-1, upper), (1, lower)):
            nx, ny = -ty * side, tx * side
            if math.sin(angle) < 0:
                nx, ny = -nx, -ny
            end = (x + (nx + tx * 0.6) * reach, y + (ny + ty * 0.6) * reach)
            mask |= forms.capsule(WIDTH, HEIGHT, (x, y), end, 0.8, 0.5)
    upper[BOTTOM - 4 :, :] = False
    lower[BOTTOM - 4 :, :] = False
    forms.paint(canvas, upper & ~lower, lit)
    forms.paint(canvas, lower, middle)
    whole = upper | lower
    for y, x in zip(*np.nonzero(whole)):
        if not whole[y + 1, x]:
            canvas[y][x] = shade if y < 140 else "green_deep"
    for x, y in points[: len(points) - 2]:
        if round(y) < BOTTOM - 3:
            canvas[round(y)][round(x)] = "green_dark" if y > 146 else middle if not is_back else shade


def stump(seed):
    """What is left of a felled tree: a short trunk about 30 px wide, its cut top with year rings
    and a crack, bark lit on the left, and roots spreading into the ground."""
    rng = random.Random(seed)
    canvas = cell()
    ground_shadow(canvas, 26, rows=6)
    centre_x, top_y, radius_x, radius_y = CENTRE, 134, 15, 8
    ground = BOTTOM - 2
    left, right = round(centre_x - radius_x), round(centre_x + radius_x) - 1
    bark = ("soil_light", "soil_mid", "soil", "soil_dark")
    # The sides of the trunk down to the ground, lit on the left, with bark furrows.
    for y in range(top_y, ground + 1):
        for x in range(left, right + 1):
            across = (x + 0.5 - centre_x) / radius_x
            canvas[y][x] = bark[0] if across < -0.6 else bark[1] if across < 0.1 else bark[2] if across < 0.7 else bark[3]
    for start in range(left + 3, right - 2, 4):
        x = start + rng.randint(-1, 1)
        for y in range(top_y + rng.randint(5, 9), ground - rng.randint(1, 4)):
            canvas[y][x] = bark[3]
            x += rng.choice((0, 0, 0, 1, -1)) if left + 2 < x < right - 2 else 0
    # Roots: wedges running out from the foot and dipping into the ground, a long one to each
    # side and on some stumps a short one in front.
    roots = [(left - 1, -1, 10, 8), (right + 1, 1, 8, 8)]
    if seed % 2:
        roots.append((centre_x - 6, -1, 4, 4))
    for start, direction, length, height in roots:
        for step in range(length):
            x = start + direction * step
            first = ground - height + 1 + step * height // length
            for y in range(first, ground + 1):
                canvas[y][x] = bark[1] if direction < 0 else bark[2]
            canvas[first][x] = bark[0] if direction < 0 else bark[1]
            canvas[ground][x] = bark[3]
    # The cut top: year rings round the pith, a darker rim of bark, a crack from the middle.
    rings = ("sand_light", "straw", "sand_light", "sand", "sand_light", "straw", "sand")
    for y in range(round(top_y - radius_y), round(top_y + radius_y)):
        for x in range(left, right + 1):
            distance = math.hypot((x + 0.5 - centre_x) / radius_x, (y + 0.5 - top_y) / radius_y)
            if distance > 1:
                continue
            if distance > 0.86:
                canvas[y][x] = bark[1] if x < centre_x else bark[2]
            else:
                canvas[y][x] = rings[min(len(rings) - 1, int(distance / 0.86 * len(rings)))]
    canvas[top_y][centre_x - 1] = canvas[top_y][centre_x] = "soil_mid"
    for step in range(1, 9):
        canvas[top_y + step // 3][centre_x + step] = "soil"
    outline_in_bark(canvas)
    return canvas


def dead_stump(seed):
    """What is left of a felled dead tree: a short stub of weathered grey wood like the dead
    tree's, its top snapped off into a ragged crown of pale splinters round a dark rotten heart,
    split by cracks, with roots; odd seeds wear moss on the left, even ones a bracket fungus on
    the right."""
    rng = random.Random(seed)
    canvas = cell()
    ground_shadow(canvas, 26, rows=6)
    centre_x, top_y, radius_x = CENTRE, 126, 14
    ground = BOTTOM - 2
    left, right = centre_x - radius_x, centre_x + radius_x - 1
    wood = ("stone_light", "stone", "bare", "stone_dark")
    # The splinters: each column is broken off at its own height, a few stand up as spikes.
    tops = {}
    for x in range(left, right + 1):
        if x % 2 == 0 or x - 1 not in tops:
            tops[x] = top_y + rng.randint(0, 4) - (6 if rng.random() < 0.2 else 0)
        else:
            tops[x] = tops[x - 1] + rng.choice((0, 1))
        if abs(x - centre_x) < 6:
            tops[x] += 4
    for x, top in tops.items():
        across = (x + 0.5 - centre_x) / radius_x
        shade = wood[0] if across < -0.55 else wood[1] if across < 0.1 else wood[2] if across < 0.7 else wood[3]
        for y in range(top, ground + 1):
            canvas[y][x] = shade
        canvas[top][x] = canvas[top + 1][x] = "bare_light"
        if abs(x - centre_x) < 6:
            canvas[top][x] = canvas[top + 1][x] = "soil_dark"
            canvas[top + 2][x] = canvas[top + 3][x] = "stone_dark"
    # Cracks running down the grey wood from the broken top.
    for _ in range(5):
        x = rng.randint(left + 3, right - 3)
        for y in range(tops[x] + 5, min(ground - 3, tops[x] + 5 + rng.randint(6, 16))):
            canvas[y][x] = "stone_dark"
    # Roots: wedges running out from the foot, in the same grey.
    roots = [(left - 1, -1, 10, 8), (right + 1, 1, 8, 8)]
    if seed % 2:
        roots.append((centre_x - 6, -1, 4, 4))
    for start, direction, length, height in roots:
        for step in range(length):
            x = start + direction * step
            first_row = ground - height + 1 + step * height // length
            for y in range(first_row, ground + 1):
                canvas[y][x] = wood[1] if direction < 0 else wood[2]
            canvas[first_row][x] = wood[0] if direction < 0 else wood[1]
    if seed % 2:
        for _ in range(40):
            x, y = rng.randint(left, left + 8), rng.randint(ground - 18, ground - 1)
            canvas[y][x] = rng.choice(("green_dark", "green", "green_light", "olive"))
    else:
        fungus = forms.ellipse(WIDTH, HEIGHT, right - 3, ground - 11, 5, 2.5) & ~forms.ellipse(WIDTH, HEIGHT, right - 3, ground - 9, 5, 2.5)
        forms.shade(canvas, fungus | forms.ellipse(WIDTH, HEIGHT, right - 3, ground - 10.5, 5, 1.6), ("soil_mid", "sand", "sand_light"), radius=1)
    outline_in_bark(canvas, "stone_dark")
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
