"""Art for the dead and the half-dead trees of every kind (issue #102), in the classic 16 px art.

As the new art's snags.py, at half its size: a dead tree keeps the build and the bark of its kind,
its limbs bare, broken and grey where the bark has gone, three of each kind from lately dead to an
old ruin; a half-dead tree is the living tree with a dead side or a dead top, two of each kind.

Each picture is an object cell (48x80, see canvas.py) with its foot at the bottom centre, in
palette colour names. generate.py takes `rows()` and the winter redraws of `redraws()`.
"""

import math
import random

import alder
import beech
import birch
import trees
import willow
from canvas import OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, blank, outline
from trees import BARK, ground_shadow, tree_trunk, twigs

WIDTH, HEIGHT = OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT
CENTRE, BOTTOM = OBJECT_CENTRE, OBJECT_BOTTOM

KINDS = ("oak", "beech", "birch", "alder", "willow", "pine", "spruce")
DEAD_VARIANTS = 3
HALF_DEAD_VARIANTS = 2

# Weathered wood where the bark has gone, lit to dark; a dead beech's brown-grey wood; the
# splintered ends and the rotten heart of a broken trunk.
SILVER = ("stone_light", "stone", "stone", "stone_dark")
BEECH_DEAD = ("bare_light", "bare", "bare", "mud_dark")
FRESH_WOOD = ("sand_light", "sand", "bare", "mud_dark")
SPLINTER = ("sand_light", "bare_light")
ROT = ("soil_dark", "ink")
# The tinder fungus (grey hoof, pale rim) and the birch polypore (light brown, white rim).
TINDER = ("stone_light", "stone", "bare", "mud_dark")
TINDER_RIM = "sand_light"
POLYPORE = ("sand_light", "sand", "mud", "mud_dark")
POLYPORE_RIM = "lime"


def cell():
    return blank(WIDTH, HEIGHT)


def _point(start, angle, length):
    return (start[0] + math.sin(angle) * length, start[1] - math.cos(angle) * length)


def _is_clear(colour):
    return colour in (None, "shadow")


def _layer_onto(canvas, layer, where=None):
    """Draws the drawn pixels of `layer` over the canvas, where `where` (of the colour under) allows."""
    for y, row in enumerate(layer):
        for x, colour in enumerate(row):
            if colour is not None and (where is None or where(canvas[y][x])):
                canvas[y][x] = colour


def _disc(canvas, cx, cy, radius, ramp):
    """A disc of wood lit on its upper left (as trees.deadwood_disc): one stamp of a limb."""
    for y in range(math.floor(cy - radius), min(BOTTOM, math.ceil(cy + radius)) + 1):
        for x in range(math.floor(cx - radius), math.ceil(cx + radius) + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if dx * dx + dy * dy > radius * radius or not (0 <= x < WIDTH and 0 <= y < HEIGHT):
                continue
            light = (dx * 0.85 + dy * 0.5) / max(radius, 0.5)
            canvas[y][x] = ramp[0] if light < -0.3 else ramp[1] if light < 0.4 else ramp[2]


def dead_twigs(canvas, rng, x, y, angle, length, colours, forks, spread, broken=0.3):
    """Stiff, crooked dead twigs, as trees.twigs draws living ones, each fork broken off short by
    the chance `broken`."""
    for _ in range(length):
        x += math.sin(angle)
        y -= math.cos(angle)
        angle += rng.uniform(-0.12, 0.12)
        px, py = round(x), round(y)
        if not (0 <= px < WIDTH - 1 and 0 <= py < HEIGHT):
            return
        canvas[py][px] = colours[0] if forks >= 2 else colours[1]
    if not forks:
        return
    for side in (-1, 1):
        child = angle + side * spread * rng.uniform(0.6, 1.2)
        if rng.random() < broken:
            dead_twigs(canvas, rng, x, y, child, 1, colours, 0, spread, 0)
        else:
            dead_twigs(canvas, rng, x, y, child, max(2, round(length * 0.68)), colours, forks - 1, spread, broken)


def dead_limb(canvas, rng, start, angle, length, bark, wood, radius=1.6, broken=False, forks=1, behind=False, bark_share=0.55):
    """A dead limb from `start` leaning `angle` (radians from straight up), elbowed, in `bark` near
    the trunk and weathered `wood` beyond, ending in a few stiff twigs or broken off short and
    splintered; rimmed in the darkest of `bark`. With `behind` it is drawn only where nothing is."""
    layer = cell()
    elbow = angle + rng.uniform(-0.3, 0.3)
    middle = _point(start, angle, length * 0.55)
    end = _point(middle, elbow, length * 0.45 * (rng.uniform(0.2, 0.55) if broken else 1))
    steps = max(2, round(length * 2))
    for index in range(steps + 1):
        t = index / steps
        point = _point(start, angle, length * 0.55 * t * 2) if t < 0.5 else _point(middle, elbow, math.dist(middle, end) * (t - 0.5) * 2)
        _disc(layer, point[0], point[1], radius * (1 - 0.55 * t), bark if t < bark_share else wood)
    layer = outline(layer, bark[3])
    if broken:
        layer[round(end[1])][round(end[0])] = SPLINTER[1]
    else:
        dead_twigs(layer, rng, end[0], end[1], elbow, round(length * 0.35), (wood[1], wood[3]), forks, 0.5)
    _layer_onto(canvas, layer, _is_clear if behind else None)
    return end


def peel(canvas, rng, bark, wood, box, count, size=(1.5, 3.5)):
    """Patches where the bark has fallen off a trunk inside `box` (x0, y0, x1, y1), the wood under
    it as lit as the bark was, a dark lip at their top."""
    x0, y0, x1, y1 = box
    for _ in range(count):
        cx, cy = rng.uniform(x0, x1), rng.uniform(y0, y1)
        rx, ry = rng.uniform(size[0] * 0.6, size[0]), rng.uniform(size[1] * 0.6, size[1])
        patch = []
        for y in range(math.floor(cy - ry), math.ceil(cy + ry) + 1):
            for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1):
                inside = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1
                is_inner = all(canvas[y + dy][x + dx] in bark for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if inside and canvas[y][x] in bark and is_inner:
                    patch.append((x, y))
        for x, y in patch:
            canvas[y][x] = wood[0] if canvas[y][x] == bark[0] else wood[1]
        for x, y in patch:
            if (x, y - 1) not in patch:
                canvas[y][x] = bark[3]


def snap(canvas, rng, centre, top, half_width, slope=None, hollow=True, clear_above=False):
    """Breaks a trunk off at `top` along a jagged line, pale splinters at the break and, on a hollow
    trunk, its dark rotten heart. With `clear_above` everything above the break goes."""
    slope = rng.choice((-0.5, 0.5)) if slope is None else slope
    cut = {}
    for x in range(math.floor(centre - half_width - 1), math.ceil(centre + half_width + 1) + 1):
        cut[x] = round(top + slope * (x - centre) + rng.choice((0, 0, 1)) - (rng.randint(2, 3) if rng.random() < 0.18 else 0))
    for x, y_cut in cut.items():
        for y in range(y_cut):
            canvas[y][x] = None
    if clear_above:
        for y in range(min(cut.values())):
            canvas[y] = [None] * WIDTH
    for x, y in cut.items():
        if canvas[y][x] is not None:
            canvas[y][x] = SPLINTER[0] if x < centre else SPLINTER[1]
            if hollow and abs(x + 0.5 - centre) < half_width - 1:
                canvas[y][x] = ROT[1]


# Bracket fungi growing to the right of their foot column: l lit, m middle, r the pale rim, o the
# outline and underside.
_BRACKETS = {"small": (".oo.", "olmo", "orro"), "large": ("..oo..", ".olmmo", "olmmmo", "orrrro")}


def bracket(canvas, x, y, size="small", ramp=TINDER, rim=TINDER_RIM, side=1):
    """A bracket fungus whose foot is at (x, y) on the edge of a trunk, sticking out to `side`."""
    colours = {"l": ramp[0], "m": ramp[1], "o": ramp[3], "r": rim}
    rows = _BRACKETS[size]
    for dy, row in enumerate(rows):
        for dx, letter in enumerate(row):
            if letter != ".":
                canvas[y - len(rows) + 2 + dy][x + dx - 1 if side > 0 else x - dx + 1] = colours[letter]


def hole(canvas, x, y, bark):
    """A woodpecker's hole: two dark pixels, the lower lip lit."""
    canvas[y][x] = canvas[y + 1][x] = ROT[1]
    canvas[y + 2][x] = bark[0]


def _trunk_middle(canvas, y):
    """The middle of the trunk on row `y`: the run of drawn pixels nearest the cell's centre."""
    xs = [x for x in range(WIDTH) if canvas[y][x] not in (None, "shadow")]
    nearest = min(xs, key=lambda x: abs(x - CENTRE))
    left = right = nearest
    while left - 1 in xs:
        left -= 1
    while right + 1 in xs:
        right += 1
    return (left + right + 1) / 2


# --- The oak --------------------------------------------------------------------------------

OAK_LIMBS = ((-1.15, 16), (-0.5, 20), (0.1, 22), (0.75, 19), (1.3, 14))


def dead_oak(variant):
    """A dead oak: its stout trunk and crooked limbs, grey where the bark has gone; older, the limbs
    broken at the elbow and the bark peeling; the oldest a hollow ruin."""
    rng = random.Random(f"dead_oak-{variant}")
    canvas = cell()
    ground_shadow(canvas, 13)
    tree_trunk(canvas, rng, 50, 7)
    left = CENTRE - 3
    if variant == 0:
        for index, (angle, length) in enumerate(OAK_LIMBS):
            angle += rng.uniform(-0.1, 0.1)
            dead_limb(canvas, rng, (CENTRE + angle * 2.5 + 0.5, 52 + abs(angle) * 2), angle, length, BARK, SILVER, broken=index == 3, forks=2, bark_share=0.65)
        peel(canvas, rng, BARK, SILVER, (left + 1, 56, left + 5, 70), 1)
    elif variant == 1:
        for angle, length, broken in ((-1.0, 17, False), (-0.35, 22, True), (0.25, 23, False), (0.85, 18, True)):
            dead_limb(canvas, rng, (CENTRE + angle * 2.5 + 0.5, 52 + abs(angle) * 2), angle + rng.uniform(-0.1, 0.1), length, BARK, SILVER, radius=1.8, broken=broken, bark_share=0.4)
        peel(canvas, rng, BARK, SILVER, (left + 1, 54, left + 5, 72), 3)
    else:
        for angle, length in ((-1.05, 13), (0.6, 11)):
            dead_limb(canvas, rng, (CENTRE + angle * 3 + 0.5, 54), angle, length, BARK, SILVER, radius=2, broken=True, bark_share=0.3)
        snap(canvas, rng, CENTRE + 0.5, 48, 3.5, slope=0.5)
        peel(canvas, rng, BARK, SILVER, (left + 1, 54, left + 5, 72), 3)
        for y in range(BOTTOM - 7, BOTTOM - 1):
            canvas[y][CENTRE] = ROT[1]
            if y > BOTTOM - 6:
                canvas[y][CENTRE + 1] = ROT[1]
        bracket(canvas, CENTRE + 4, 62, "large")
    return canvas


def _oak_crown(variant):
    """The clumps of a half-dead oak still in leaf: the right side gone, or the top (stag-headed)."""
    def keep(clumps):
        (cx, cy, radius), *rest = clumps
        if variant == 0:
            return [(cx - 4, cy + 1, radius - 2)] + [clump for clump in rest if clump[0] < 30]
        return [(cx, cy + 5, radius - 1.5)] + [(x, y + 2, r) for x, y, r in rest if y > 35]
    return keep


_OAK_LIVING = (((22, 46, -1, 20), (23, 54, -1, 14), (24, 46, 1, 12)), ((22, 46, -1, 12), (26, 46, 1, 12), (23, 54, -1, 10), (27, 52, 1, 10)))
_OAK_DEAD = (((0.6, 26, False), (0.25, 22, True)), ((-0.3, 30, False), (0.15, 31, True), (0.5, 26, False)))


def _oak_dead_part(canvas, rng, variant, behind):
    for angle, length, broken in _OAK_DEAD[variant]:
        dead_limb(canvas, rng, (CENTRE + angle * 2.5 + 0.5, 52), angle, length, BARK, SILVER, radius=1.5, broken=broken, behind=behind)


def half_dead_oak(variant):
    """A half-dead oak in leaf: its right side dead, or its top (stag-headed)."""
    canvas = trees.oak(trees.OAK_SEEDS[variant], _oak_crown(variant))
    _oak_dead_part(canvas, random.Random(f"half_dead_oak-{variant}"), variant, behind=True)
    return canvas


def bare_half_dead_oak(variant):
    """The half-dead oak in winter: the living branches of the bare oak and the dead limbs."""
    rng = random.Random(trees.OAK_SEEDS[variant])
    canvas = cell()
    ground_shadow(canvas, 13)
    tree_trunk(canvas, rng, 46, 7)
    for x, y, direction, length in _OAK_LIVING[variant]:
        trees.draw_branch(canvas, rng, x, y, direction, length + rng.randint(-2, 2), "soil_mid")
    trees.outline_in_bark(canvas)
    _oak_dead_part(canvas, random.Random(f"half_dead_oak-{variant}"), variant, behind=False)
    return canvas


# --- The beech ------------------------------------------------------------------------------


def dead_beech(variant):
    """A dead beech: its smooth grey bole with tinder fungi, the bark coming off in sheets; lately
    dead with its steep limbs, older with most broken, the oldest snapped off high up."""
    rng = random.Random(f"dead_beech-{variant}")
    canvas = cell()
    bark = beech.BARK
    left = CENTRE - beech.TRUNK_WIDTH // 2
    if variant < 2:
        beech._bole(canvas, rng)
        limbs = ((-0.85, 22, False), (-0.35, 25, True), (0.15, 26, False), (0.65, 21, False)) if variant == 0 else ((-0.75, 15, True), (-0.2, 27, False), (0.5, 13, True))
        for angle, length, broken in limbs:
            dead_limb(canvas, rng, (CENTRE + angle * 2.5, beech.FORK_Y + 1), angle + rng.uniform(-0.08, 0.08), length, bark, BEECH_DEAD, radius=1.6, broken=broken, bark_share=0.75 if variant == 0 else 0.45)
        peel(canvas, rng, bark, BEECH_DEAD, (left + 1, 54, left + 5, 70), 1 + variant)
        for y, side, size in ((59, 1, "large"), (67, -1, "small"), (63, -1, "small"))[: 2 + variant]:
            bracket(canvas, CENTRE + side * 3, y, size, side=side)
    else:
        ground_shadow(canvas, 12)
        tree_trunk(canvas, rng, 28, beech.TRUNK_WIDTH, bark)
        snap(canvas, rng, CENTRE, 31, 3, slope=-0.5)
        peel(canvas, rng, bark, BEECH_DEAD, (left + 1, 36, left + 5, 70), 3)
        hole(canvas, CENTRE - 1, 42, bark)
        for y, side, size in ((46, 1, "small"), (51, -1, "large"), (56, 1, "large"), (62, -1, "small"), (67, 1, "small")):
            bracket(canvas, CENTRE + side * 3, y, size, side=side)
    return canvas


def _beech_crown(variant):
    def keep(clumps):
        (cx, cy, radius), *rest = clumps
        if variant == 0:
            return [(cx + 4, cy + 1.5, radius - 3)] + [clump for clump in rest if clump[0] > 20]
        return [(cx, cy + 6, radius - 2)] + [(x, y + 3, r) for x, y, r in rest if y > 31]
    return keep


_BEECH_LIVING = ((0.15, 10), (0.6, 9)), ((-0.6, 7), (-0.1, 8), (0.4, 8), (0.8, 7))
_BEECH_DEAD = (((-0.75, 26, False), (-0.35, 23, True)), ((-0.2, 30, False), (0.2, 29, True)))


def _beech_dead_part(canvas, rng, variant, behind):
    for angle, length, broken in _BEECH_DEAD[variant]:
        dead_limb(canvas, rng, (CENTRE + angle * 2.5, beech.FORK_Y + 1), angle, length, beech.BARK, BEECH_DEAD, radius=1.4, broken=broken, behind=behind)


def half_dead_beech(variant):
    """A half-dead beech in leaf: one side of its dome dead, or its top."""
    canvas = beech.beech(beech.BEECH_SEEDS[variant], _beech_crown(variant))
    _beech_dead_part(canvas, random.Random(f"half_dead_beech-{variant}"), variant, behind=True)
    return canvas


def bare_half_dead_beech(variant):
    """The half-dead beech in winter: its living limbs fanning into fine twigs, and the dead ones."""
    rng = random.Random(beech.BEECH_SEEDS[variant])
    canvas = cell()
    beech._bole(canvas, rng)
    trees.outline_in_bark(canvas, "stone_dark")
    for angle, length in _BEECH_LIVING[variant]:
        twigs(canvas, rng, CENTRE + round(angle * 3), beech.FORK_Y + 1, angle + rng.uniform(-0.1, 0.1), length, ("stone", "stone_dark"), 4, 0.36)
    _beech_dead_part(canvas, random.Random(f"half_dead_beech-{variant}"), variant, behind=False)
    return canvas


# --- The birch ------------------------------------------------------------------------------

BIRCH_DEAD_TWIGS = ("stone_light", "stone_dark")


def _bark_curls(canvas, rng, centres, rows, count):
    """Strips of white bark curling off the edges of a birch trunk."""
    for _ in range(count):
        y = rng.randint(*rows)
        side = rng.choice((-1, 1))
        x = round(centres[y]) + side * 2
        canvas[y][x] = "lime"
        if canvas[y + 1][x] is None:
            canvas[y + 1][x] = "stone_dark"


def _polypores(canvas, centres, spots):
    for y, side, size in spots:
        bracket(canvas, round(centres[y]) + side * 2, y, size, POLYPORE, POLYPORE_RIM, side)


def dead_birch(variant):
    """A dead birch: the white bark holds on while the wood rots, so the top breaks off, polypores
    grow on it and strips of bark curl off; older snapped half-way, the oldest a short stump."""
    rng = random.Random(f"dead_birch-{variant}")
    canvas = cell()
    centres = birch._trunk(canvas, rng, variant)
    trees.outline_in_bark(canvas, birch.BARK[3])
    if variant == 0:
        side = rng.choice((-1, 1))
        for index, y in enumerate(range(birch.TOP + 9, 50, 6)):
            dead_twigs(canvas, rng, centres[y], y, side * rng.uniform(0.6, 0.95), 7 + index, BIRCH_DEAD_TWIGS, 2, 0.55, broken=0.4)
            side = -side
        snap(canvas, rng, centres[25], 25, 1.5, slope=0.8, hollow=False)
        _polypores(canvas, centres, ((48, 1, "small"), (56, -1, "small")))
        _bark_curls(canvas, rng, centres, (30, 64), 3)
    elif variant == 1:
        for y, angle in ((46, -0.9), (52, 0.8)):
            dead_twigs(canvas, rng, centres[y], y, angle, 4, BIRCH_DEAD_TWIGS, 1, 0.5, broken=0.8)
        snap(canvas, rng, centres[39], 39, 2, slope=-0.7)
        _polypores(canvas, centres, ((48, 1, "large"), (55, -1, "small"), (61, 1, "small")))
        _bark_curls(canvas, rng, centres, (42, 68), 3)
    else:
        snap(canvas, rng, centres[56], 56, 2, slope=0.7)
        _polypores(canvas, centres, ((62, 1, "large"), (67, -1, "small")))
        _bark_curls(canvas, rng, centres, (58, 70), 2)
    return canvas


def _birch_crown(variant, centres):
    def keep(clumps):
        if variant == 0:
            return [clump for clump in clumps if clump[1] > 33]
        return [clump for clump in clumps if clump[0] > centres[max(birch.TOP, round(clump[1]))] - 1.5]
    return keep


def _birch_dead_part(canvas, rng, centres, variant, behind):
    layer = cell()
    if variant == 0:
        for y, angle, length in ((22, -0.6, 6), (26, 0.7, 7), (30, -0.8, 6)):
            dead_twigs(layer, rng, centres[y], y, angle, length, BIRCH_DEAD_TWIGS, 2, 0.5, broken=0.4)
    else:
        for y, length in ((27, 9), (36, 11), (45, 9)):
            dead_twigs(layer, rng, centres[y], y, -rng.uniform(0.7, 1.0), length, BIRCH_DEAD_TWIGS, 2, 0.5, broken=0.4)
    _layer_onto(canvas, layer, _is_clear if behind else None)


def half_dead_birch(variant):
    """A half-dead birch in leaf: its top dead, or its left side."""
    seed = birch.BIRCH_SEEDS[variant]
    centres = birch._trunk(cell(), random.Random(seed), seed)
    canvas = birch.birch(seed, _birch_crown(variant, centres))
    _birch_dead_part(canvas, random.Random(f"half_dead_birch-{variant}"), centres, variant, behind=True)
    return canvas


def bare_half_dead_birch(variant):
    """The half-dead birch in winter: fine brown twigs on its living part only."""
    seed = birch.BIRCH_SEEDS[variant]
    rng = random.Random(seed)
    canvas = cell()
    centres = birch._trunk(canvas, rng, seed)
    trees.outline_in_bark(canvas, birch.BARK[3])
    side = rng.choice((-1, 1))
    for index, y in enumerate(range(birch.TOP + 6, 50, 6)):
        angle = side * rng.uniform(0.55, 0.9)
        if (variant == 0 and y > 32) or (variant == 1 and side > 0):
            twigs(canvas, rng, centres[y], y, angle, 8 + index, birch.TWIGS, 2, 0.55)
        side = -side
    if variant == 1:
        twigs(canvas, rng, centres[birch.TOP], birch.TOP, 0.2, 5, birch.TWIGS, 2, 0.4)
    birch._hanging_tips(canvas, rng, {birch.TWIGS[1]}, birch.TWIGS[1], 10)
    _birch_dead_part(canvas, random.Random(f"half_dead_birch-{variant}"), centres, variant, behind=False)
    return canvas


# --- The alder ------------------------------------------------------------------------------

ALDER_DEAD_TWIGS = ("stone", "stone_dark")


def _cones(canvas, rng, end_colour, count):
    """Old black cones hanging from the tips of an alder's twigs."""
    tips = [(x, y) for y in range(HEIGHT - 30) for x in range(WIDTH - 1) if canvas[y][x] == end_colour and canvas[y + 1][x] is None]
    for x, y in rng.sample(tips, min(len(tips), count)):
        canvas[y + 1][x] = alder.CONE
        if canvas[y + 1][x + 1] is None:
            canvas[y + 1][x + 1] = alder.CONE


def dead_alder(variant):
    """A dead alder: its straight dark stem with tiers of short grey branches; older, its top broken
    and the branches gone to stubs; the oldest snapped off low, hollow."""
    rng = random.Random(f"dead_alder-{variant}")
    canvas = cell()
    alder._stem(canvas, rng)
    trees.outline_in_bark(canvas, alder.BARK[3])
    bark = alder.BARK
    left = CENTRE - alder.TRUNK_WIDTH // 2
    if variant == 0:
        side = rng.choice((-1, 1))
        for y in range(alder.TOP + 3, 50, 4):
            dead_twigs(canvas, rng, CENTRE, y, side * rng.uniform(0.8, 1.1), 4 + (y - alder.TOP) // 5, ALDER_DEAD_TWIGS, 2, 0.5, broken=0.35)
            side = -side
        _cones(canvas, rng, ALDER_DEAD_TWIGS[1], 8)
        peel(canvas, rng, bark, SILVER, (left + 1, 54, left + 4, 70), 1)
    elif variant == 1:
        side = rng.choice((-1, 1))
        for y in range(32, 50, 4):
            dead_twigs(canvas, rng, CENTRE, y, side * rng.uniform(0.9, 1.2), rng.randint(2, 4), ALDER_DEAD_TWIGS, 1, 0.5, broken=0.7)
            side = -side
        snap(canvas, rng, CENTRE, 29, 1.5, slope=0.8, hollow=False)
        peel(canvas, rng, bark, SILVER, (left + 1, 52, left + 4, 72), 2)
    else:
        snap(canvas, rng, CENTRE, 45, 2.5, slope=-0.6)
        dead_limb(canvas, rng, (CENTRE + 2, 50), 0.9, 8, bark, SILVER, radius=1.2, broken=True)
        peel(canvas, rng, bark, SILVER, (left + 1, 52, left + 4, 72), 2)
        bracket(canvas, CENTRE + 3, 58, "small")
    return canvas


def _alder_crown(variant):
    def keep(clumps):
        if variant == 0:
            return [clump for clump in clumps if clump[1] > 34]
        return [clump for clump in clumps if clump[0] < CENTRE + 2]
    return keep


def _alder_dead_part(canvas, rng, variant, behind):
    layer = cell()
    if variant == 0:
        side = -1
        for y in range(alder.TOP + 3, 35, 4):
            dead_twigs(layer, rng, CENTRE, y, side * rng.uniform(0.8, 1.1), 4 + (y - alder.TOP) // 5, ALDER_DEAD_TWIGS, 2, 0.5, broken=0.35)
            side = -side
    else:
        for y in range(alder.TOP + 5, 52, 5):
            dead_twigs(layer, rng, CENTRE + 1, y, rng.uniform(0.8, 1.1), 5 + (y - alder.TOP) // 4, ALDER_DEAD_TWIGS, 2, 0.5, broken=0.35)
    _layer_onto(canvas, layer, _is_clear if behind else None)


def half_dead_alder(variant):
    """A half-dead alder in leaf: its top dead, or its right side."""
    canvas = alder.alder(alder.ALDER_SEEDS[variant], _alder_crown(variant))
    _alder_dead_part(canvas, random.Random(f"half_dead_alder-{variant}"), variant, behind=True)
    return canvas


def bare_half_dead_alder(variant):
    """The half-dead alder in winter: its living branches with cones, and the dead ones."""
    rng = random.Random(alder.ALDER_SEEDS[variant])
    canvas = cell()
    alder._stem(canvas, rng)
    trees.outline_in_bark(canvas, alder.BARK[3])
    side = rng.choice((-1, 1))
    for y in range(alder.TOP + 3, 50, 4):
        length = 4 + (y - alder.TOP) // 5
        if (variant == 0 and y > 35) or (variant == 1 and side < 0):
            twigs(canvas, rng, CENTRE, y, side * rng.uniform(0.8, 1.1), length, alder.TWIGS, 2, 0.5)
        side = -side
    _cones(canvas, rng, alder.TWIGS[1], 12)
    _alder_dead_part(canvas, random.Random(f"half_dead_alder-{variant}"), variant, behind=False)
    return canvas


# --- The pollard willow ---------------------------------------------------------------------

DEAD_RODS = ("mud_dark", "stone", "stone_light")


def _dead_rods(canvas, rng, feet, count, keeps=None, behind=False):
    """Dead rods from the willow's head: stiff and grey, many broken off short."""
    layer = cell()
    for rod in willow._rods(rng, feet, count):
        if not rod or (keeps and not keeps(rod[-1])):
            continue
        if rng.random() < 0.45:
            rod = rod[: max(2, round(len(rod) * rng.uniform(0.2, 0.55)))]
        for step, (x, y) in enumerate(rod):
            if 0 <= x < WIDTH and 0 <= y < HEIGHT and layer[y][x] is None:
                layer[y][x] = DEAD_RODS[0] if step < 3 else DEAD_RODS[1]
    _layer_onto(canvas, layer, (lambda under: under is None or under in willow.LEAVES + willow.RODS) if behind else lambda under: under not in willow.KNOBS)


def dead_willow(variant):
    """A dead pollard willow: a few stiff grey rods on its head; older, a few thick dead poles; the
    oldest split down the middle, the hollow inside showing."""
    rng = random.Random(f"dead_willow-{variant}")
    canvas = cell()
    feet = willow._trunk_and_head(canvas, rng)
    left = CENTRE - willow.TRUNK_WIDTH // 2
    if variant == 0:
        _dead_rods(canvas, rng, feet, 14)
        peel(canvas, rng, willow.BARK, SILVER, (left + 2, willow.HEAD_Y + 4, left + 8, 75), 1)
    elif variant == 1:
        for angle, length, broken in ((-0.55, 23, False), (-0.15, 27, True), (0.25, 25, False), (0.6, 19, True)):
            foot = feet[round((angle + 0.7) / 1.4 * (len(feet) - 1))]
            dead_limb(canvas, rng, (foot[0], foot[1] + 1), angle, length, (willow.KNOBS[0], willow.KNOBS[1], willow.KNOBS[1], willow.KNOBS[2]), SILVER, radius=1.2, broken=broken, bark_share=0.3)
        _dead_rods(canvas, rng, feet, 6)
        peel(canvas, rng, willow.BARK, SILVER, (left + 2, willow.HEAD_Y + 4, left + 8, 75), 2)
    else:
        _split(canvas, rng)
        _dead_rods(canvas, rng, feet[: len(feet) // 2], 4)
    return canvas


def _split(canvas, rng):
    """Splits a willow's trunk and head down the middle, its right half fallen away."""
    x = CENTRE + 0.5
    for y in range(BOTTOM - 8, -1, -1):
        x += rng.choice((-0.5, 0, 0, 0.5)) if y < BOTTOM - 10 else 0
        edge = round(x)
        if y < willow.HEAD_Y + 2:
            for column in range(edge, WIDTH):
                if canvas[y][column] != "shadow":
                    canvas[y][column] = None
            if canvas[y][edge - 1] is not None:
                canvas[y][edge - 1] = SPLINTER[0]
        if y >= willow.HEAD_Y - 2:
            for dx in (2, 3):
                if canvas[y][edge - dx] not in (None, "shadow"):
                    canvas[y][edge - dx] = ROT[1]


def _is_dead_side(variant, x):
    return x > CENTRE + 1 if variant == 0 else x < CENTRE - 3


def _willow_dead_part(canvas, variant, feet, behind):
    rng = random.Random(f"half_dead_willow-{variant}")
    if variant == 1:
        dead_limb(canvas, rng, (feet[1][0], feet[1][1] + 1), -0.35, 27, (willow.KNOBS[0], willow.KNOBS[1], willow.KNOBS[1], willow.KNOBS[2]), SILVER, radius=1.1, bark_share=0.3, behind=behind)
    _dead_rods(canvas, rng, feet, 18, lambda tip: _is_dead_side(variant, tip[0]), behind)


def half_dead_willow(variant):
    """A half-dead pollard willow in leaf: the rods of one side of its head dead and grey."""
    seed = willow.WILLOW_SEEDS[variant]
    canvas = willow.willow(seed)
    for y in range(willow.HEAD_Y - 3):
        for x in range(WIDTH):
            if _is_dead_side(variant, x) and canvas[y][x] in willow.LEAVES + (willow.SILVER,):
                canvas[y][x] = None
    feet = willow._trunk_and_head(cell(), random.Random(seed))
    _willow_dead_part(canvas, variant, feet, behind=True)
    return canvas


def bare_half_dead_willow(variant):
    """The half-dead willow in winter: the living rods bare, the dead ones grey."""
    seed = willow.WILLOW_SEEDS[variant]
    rng = random.Random(seed)
    canvas = cell()
    feet = willow._trunk_and_head(canvas, rng)
    for rod in willow._rods(rng, feet, willow._rod_count(seed)):
        if not rod or _is_dead_side(variant, rod[-1][0]):
            continue
        for step, (x, y) in enumerate(rod):
            if canvas[y][x] is None or canvas[y][x] in willow.RODS:
                canvas[y][x] = willow.RODS[0] if step < 2 else willow.RODS[1]
    _willow_dead_part(canvas, variant, feet, behind=False)
    return canvas


# --- The Scots pine -------------------------------------------------------------------------

DEAD_PINE_SEEDS = (134, 135, 136)
PINE_DEAD_TWIGS = ("stone", "stone_dark")


def _pine_parts(seed, keep=lambda clumps: []):
    """A pine of `seed` with only the needle clumps `keep` picks, and all its clumps (the top's,
    those on the branches, then the two that fill out the top)."""
    clumps = []

    def crown(all_clumps):
        clumps.extend(all_clumps)
        return keep(all_clumps)

    return trees.pine(seed, crown), clumps


def _pine_twigs(canvas, rng, clumps, behind=False):
    """Dead twigs fanning up from the ends of the branches whose clumps are gone."""
    layer = cell()
    for cx, cy, half_width in clumps:
        side = 1 if cx >= _trunk_middle(canvas, round(cy) + 3) else -1
        for angle in (side * 0.35, side * 1.0, -side * 0.15):
            dead_twigs(layer, rng, cx, cy + 2, angle, round(half_width * 0.7), PINE_DEAD_TWIGS, 1, 0.5, broken=0.35)
    _layer_onto(canvas, layer, _is_clear if behind else None)


def dead_pine(variant):
    """A dead Scots pine: the umbrella of branches bare and grey; older, its top broken off; the
    oldest a tall snapped stem with woodpecker holes."""
    rng = random.Random(f"dead_pine-{variant}")
    canvas, clumps = _pine_parts(DEAD_PINE_SEEDS[variant])
    top_y = clumps[0][1] - 2
    if variant == 0:
        _pine_twigs(canvas, rng, clumps[1:-2])
        dead_twigs(canvas, rng, clumps[0][0], top_y, rng.uniform(-0.2, 0.2), 5, PINE_DEAD_TWIGS, 2, 0.5, broken=0.3)
        peel(canvas, rng, trees.PINE_BARK, FRESH_WOOD, (CENTRE - 3, 48, CENTRE + 3, 68), 1)
    elif variant == 1:
        cut = top_y + 11
        _pine_twigs(canvas, rng, [clump for clump in clumps[1:-2] if clump[1] > cut + 2])
        snap(canvas, rng, _trunk_middle(canvas, cut + 1), cut, 1.5, clear_above=True, hollow=False)
        peel(canvas, rng, trees.PINE_BARK, FRESH_WOOD, (CENTRE - 3, 45, CENTRE + 3, 72), 2)
    else:
        cut = 37
        snap(canvas, rng, _trunk_middle(canvas, cut + 1), cut, 2, clear_above=True)
        peel(canvas, rng, trees.PINE_BARK, FRESH_WOOD, (CENTRE - 3, 42, CENTRE + 3, 72), 3)
        hole(canvas, round(_trunk_middle(canvas, 46)) - 1, 46, trees.PINE_BARK)
        hole(canvas, round(_trunk_middle(canvas, 53)), 53, trees.PINE_BARK)
    return canvas


def _pine_keep(variant):
    def keep(clumps):
        top, *branches = clumps
        branches, fill = branches[:-2], branches[-2:]
        if variant == 0:
            return [top] + fill + [clump for index, clump in enumerate(branches) if index < 2 or clump[0] < top[0]]
        return branches[2:]
    return keep


def half_dead_pine(variant):
    """A half-dead pine: the branches of one side bare and grey, or its top dead."""
    canvas, clumps = _pine_parts((131, 132, 133)[variant], _pine_keep(variant))
    kept = _pine_keep(variant)(clumps)
    rng = random.Random(f"half_dead_pine-{variant}")
    _pine_twigs(canvas, rng, [clump for clump in clumps[1:-2] if clump not in kept], behind=True)
    if variant == 1:
        dead_twigs(canvas, rng, clumps[0][0], clumps[0][1] - 2, rng.uniform(-0.2, 0.2), 5, PINE_DEAD_TWIGS, 2, 0.5, broken=0.3)
    return canvas


# --- The spruce -----------------------------------------------------------------------------

SPRUCE_STEM_TOP = 11
SPRUCE_DEAD = ("stone", "bare", "mud_dark")


def _spruce_stem(canvas, top, bottom=66, behind=False):
    """The straight stem of a spruce from `top` down to `bottom`, thickening downwards."""
    for y in range(top, bottom):
        width = 1 + round(3 * (y - top) / (bottom - top))
        left = CENTRE - width // 2
        for x in range(left - 1, left + width + 1):
            if behind and canvas[y][x] is not None:
                continue
            canvas[y][x] = BARK[3] if x in (left - 1, left + width) else BARK[0] if x == left and width > 1 else BARK[1]


def _spruce_whorls(canvas, rng, top, bottom, reach, sides=(-1, 1), behind=False):
    """Dead drooping branches of a spruce in whorls from `top` to `bottom`, `reach(y)` px long,
    with dark twigs hanging from them."""
    layer = cell()
    y = top
    while y < bottom:
        for side in sides:
            length = max(1, round(reach(y) + rng.uniform(-1, 1)))
            for step in range(length):
                x = CENTRE + side * (1 + step)
                by = round(y + step * 0.35)
                if not (0 <= x < WIDTH and by < BOTTOM - 1):
                    break
                layer[by][x] = SPRUCE_DEAD[1] if step < length - 1 else SPRUCE_DEAD[0]
                if step > 1 and step % 2 == rng.randint(0, 1) and layer[by + 1][x] is None:
                    layer[by + 1][x] = SPRUCE_DEAD[2]
        y += rng.randint(2, 3)
    _layer_onto(canvas, layer, _is_clear if behind else None)


def _spruce_reach(y):
    return 2 + (y - SPRUCE_STEM_TOP) * 0.24


def dead_spruce(variant):
    """A dead spruce: a narrow grey cone of dead drooping branches round the stem; older, its top
    broken and its lower branches gone to stubs; the oldest a bare stem of stubs, snapped off."""
    rng = random.Random(f"dead_spruce-{variant}")
    canvas = cell()
    ground_shadow(canvas, 10)
    tree_trunk(canvas, rng, 66, 5)
    if variant == 0:
        _spruce_stem(canvas, SPRUCE_STEM_TOP)
        _spruce_whorls(canvas, rng, SPRUCE_STEM_TOP + 2, 64, _spruce_reach)
    elif variant == 1:
        _spruce_stem(canvas, 18)
        _spruce_whorls(canvas, rng, 22, 52, _spruce_reach)
        _spruce_whorls(canvas, rng, 53, 64, lambda y: 1.5)
        snap(canvas, rng, CENTRE, 21, 1, hollow=False)
        peel(canvas, rng, BARK, SILVER, (CENTRE - 1, 67, CENTRE + 1, 75), 1)
    else:
        _spruce_stem(canvas, 28)
        _spruce_whorls(canvas, rng, 33, 64, lambda y: 1.5)
        snap(canvas, rng, CENTRE, 32, 1.5)
        peel(canvas, rng, BARK, SILVER, (CENTRE - 1, 67, CENTRE + 1, 75), 1)
        hole(canvas, CENTRE, 69, BARK)
    return canvas


def half_dead_spruce(variant):
    """A half-dead spruce: its top dead, a grey spike over the green tiers, or its right side."""
    seed = (121, 122, 123)[variant]
    rng = random.Random(f"half_dead_spruce-{variant}")
    if variant == 0:
        canvas = trees.spruce(seed, lambda tier: tier[0] > 30)
        _spruce_stem(canvas, SPRUCE_STEM_TOP, 36, behind=True)
        _spruce_whorls(canvas, rng, SPRUCE_STEM_TOP + 2, 35, _spruce_reach, behind=True)
        return canvas
    canvas = trees.spruce(seed)
    greens = {"green_light", "green", "green_dark", "green_deep"}
    for y in range(HEIGHT):
        boundary = CENTRE + 1 + (y // 3) % 2
        for x in range(boundary, WIDTH):
            if canvas[y][x] in greens:
                canvas[y][x] = None
        if canvas[y][boundary - 1] in greens:
            canvas[y][boundary - 1] = "green_deep"
    _spruce_stem(canvas, 14, behind=True)
    _spruce_whorls(canvas, rng, 15, 64, _spruce_reach, sides=(1,), behind=True)
    return canvas


# --- The registry ---------------------------------------------------------------------------

DEAD = {
    "oak": dead_oak,
    "beech": dead_beech,
    "birch": dead_birch,
    "alder": dead_alder,
    "willow": dead_willow,
    "pine": dead_pine,
    "spruce": dead_spruce,
}
# Each half-dead kind: its picture in leaf, and the bare one for winter (None for the evergreens).
HALF_DEAD = {
    "oak": (half_dead_oak, bare_half_dead_oak),
    "beech": (half_dead_beech, bare_half_dead_beech),
    "birch": (half_dead_birch, bare_half_dead_birch),
    "alder": (half_dead_alder, bare_half_dead_alder),
    "willow": (half_dead_willow, bare_half_dead_willow),
    "pine": (half_dead_pine, None),
    "spruce": (half_dead_spruce, None),
}


def rows():
    """The sheets of the dead and the half-dead trees, as (kind, variants), as the new art's."""
    dead = [(f"dead_{kind}", [DEAD[kind](variant) for variant in range(DEAD_VARIANTS)]) for kind in KINDS]
    half_dead = [(f"half_dead_{kind}", [HALF_DEAD[kind][0](variant) for variant in range(HALF_DEAD_VARIANTS)]) for kind in KINDS]
    return dead + half_dead


def redraws():
    """The half-dead trees drawn anew for winter, bare: kind to a function of the variant."""
    return {f"half_dead_{kind}": draw[1] for kind, draw in HALF_DEAD.items() if draw[1] is not None}
