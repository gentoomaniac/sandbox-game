"""Art for the dead and the half-dead trees of every kind (issue #102), drawn at 32 px per tile.

A dead tree (a snag) keeps the build and the bark of its kind, so a dead oak reads as an oak and a
dead pine as a pine: no leaves or needles, no fine twigs, its limbs broken, its bark peeling off in
patches to the weathered wood under it. Each kind has three, from a tree that died lately (its
crown of limbs whole) to an old ruin (snapped off, hollow, fungi on it). A half-dead tree is the
living tree of its kind with a dead part, a bare side or a dead top, which stays bare while the rest
of it is in leaf; each kind has two.

Each picture is an object cell (96x160 at 32 px per tile, see trees.py) with its foot at the
bottom centre, in palette colour names. `rows()` gives the sheets as (kind, variants) in the order
of DEAD_KINDS and HALF_DEAD_KINDS, `redraws()` the half-dead deciduous trees bare for winter (the
leaf-out looks grow from those, see seasons.py).
"""

import math
import random

import alder
import beech
import birch
import forms
import numpy as np
import trees
import willow
from trees import BARK, BOTTOM, CENTRE, HEIGHT, WIDTH, cell, ground_shadow, tree_trunk, twigs

KINDS = ("oak", "beech", "birch", "alder", "willow", "pine", "spruce")
DEAD_KINDS = tuple(f"dead_{kind}" for kind in KINDS)
HALF_DEAD_KINDS = tuple(f"half_dead_{kind}" for kind in KINDS)
DEAD_VARIANTS = 3
HALF_DEAD_VARIANTS = 2

# Wood weathered silver-grey where the bark has gone, lit to dark; the darkest also outlines it.
SILVER = ("stone_light", "stone", "stone", "stone_dark")
# Wood where the bark came off lately: pale and warm.
FRESH_WOOD = ("sand_light", "sand", "bare", "mud_dark")
# A dead beech's limbs: the grey bark gone brown-grey.
BEECH_DEAD = ("bare_light", "bare", "bare", "mud_dark")
# The splintered end of a broken limb or trunk.
SPLINTER = ("sand_light", "bare_light")
# The rotten heart of a hollow trunk, where the top broke off.
ROT = ("soil_dark", "ink")
# The tinder fungus of beech and birch, the hoof-shaped bracket: lit grey top, a pale rim where it
# grows, dark below; and the birch polypore, a rounded cream shelf.
TINDER = ("stone_light", "stone", "bare", "mud_dark")
TINDER_RIM = "sand_light"
POLYPORE = ("lime", "sand_light", "sand", "mud_dark")
# The colours of dead wood that snow lies on and frost rimes, for seasons.py.
DEAD_WOOD_LIT = {"stone_light", "stone", "bare_light", "sand_light", "lime"}


def _layer_onto(canvas, layer, where=None):
    """Draws the drawn pixels of `layer` over the canvas, only where `where` (a function of the
    colour under them) allows."""
    for y, row in enumerate(layer):
        for x, colour in enumerate(row):
            if colour is not None and (where is None or where(canvas[y][x])):
                canvas[y][x] = colour


def _is_clear(colour):
    return colour in (None, "shadow")


def _point(start, angle, length):
    return (start[0] + math.sin(angle) * length, start[1] - math.cos(angle) * length)


def dead_twigs(canvas, rng, x, y, angle, length, colours, forks, spread, broken=0.3):
    """Dead twigs as `trees.twigs` draws living ones, but stiff and crooked and fewer: each fork is
    broken off short by the chance `broken`, its end a pale splinter."""
    thickness = min(2, forks)
    for _ in range(length):
        x += math.sin(angle)
        y -= math.cos(angle)
        angle += rng.uniform(-0.1, 0.1)
        if rng.random() < 0.1:
            angle += rng.choice((-0.45, 0.45))
        px, py = round(x), round(y)
        if not (1 <= px < WIDTH - thickness - 1 and 1 <= py < HEIGHT):
            return
        for across in range(max(1, thickness)):
            canvas[py][px + across] = colours[0] if across == 0 and thickness > 1 else colours[1]
    if not forks:
        return
    for side in (-1, 1):
        child = angle + side * spread * rng.uniform(0.6, 1.2)
        if rng.random() < broken:
            dead_twigs(canvas, rng, x, y, child, max(2, round(length * 0.3)), colours, 0, spread, 0)
            end = _point((x, y), child, max(2, round(length * 0.3)) + 1)
            if 0 <= round(end[0]) < WIDTH and 0 <= round(end[1]) < HEIGHT:
                canvas[round(end[1])][round(end[0])] = SPLINTER[1]
        else:
            dead_twigs(canvas, rng, x, y, child, max(3, round(length * 0.68)), colours, forks - 1, spread, broken)


def dead_limb(canvas, rng, start, angle, length, bark, wood, radius=4.0, broken=False, forks=2, behind=False, bark_share=0.55):
    """A dead limb from `start` leaning `angle` (radians from straight up), thick and elbowed as a
    crown limb (trees.crown_limb), in `bark` near the trunk and in weathered `wood` from
    `bark_share` of its length on, forking into a few stiff, broken twigs, or broken off short, its
    end splintered. With `behind` it is drawn only where nothing is yet (behind the crown and the
    trunk). Returns its end."""
    layer = cell()
    elbow = angle + rng.uniform(-0.3, 0.3)
    middle = _point(start, angle, length * 0.55)
    reach = length * 0.45 * (rng.uniform(0.15, 0.55) if broken else 1)
    end = _point(middle, elbow, reach)
    whole = forms.capsule(WIDTH, HEIGHT, start, middle, radius, radius * 0.75)
    whole |= forms.capsule(WIDTH, HEIGHT, middle, end, radius * 0.75, max(1.2, radius * (0.55 if broken else 0.4)))
    xs, ys = forms.grid(WIDTH, HEIGHT)
    along = ((xs - start[0]) * math.sin(angle) - (ys - start[1]) * math.cos(angle)) / length
    inner = whole & (along < bark_share)
    outer = whole & ~inner
    forms.shade(layer, inner, (bark[3], bark[1], bark[0]), radius=2)
    forms.shade(layer, outer, (wood[3], wood[1], wood[0]), radius=2)
    forms.paint(layer, forms.edge(whole) & inner, bark[3])
    forms.paint(layer, forms.edge(whole) & outer, wood[3])
    twig_colours = (wood[1], wood[3])
    side = rng.choice((-1, 1))
    dead_twigs(layer, rng, middle[0], middle[1], elbow + side * 0.75, round(length * 0.3), twig_colours, 1, 0.5)
    if broken:
        _splinter(layer, end, elbow, radius * 0.5)
    else:
        dead_twigs(layer, rng, end[0], end[1], elbow, round(length * 0.34), twig_colours, forks, 0.5)
    _layer_onto(canvas, layer, _is_clear if behind else None)
    return end


def _splinter(canvas, end, angle, radius):
    """The pale, jagged end of a broken limb at `end`, pointing along `angle`."""
    x, y = end
    for step in range(3):
        px, py = round(x + math.sin(angle) * (step - 1)), round(y - math.cos(angle) * (step - 1))
        for dx, dy in ((0, 0), (-1, 0), (0, -1)):
            if canvas[py + dy][px + dx] is not None:
                canvas[py + dy][px + dx] = SPLINTER[0] if step < 2 else SPLINTER[1]
    tip = _point(end, angle, 2 + radius)
    canvas[round(tip[1])][round(tip[0])] = SPLINTER[1]


def peel(canvas, rng, bark, wood, box, count, size=(3, 7)):
    """Patches where the bark has fallen off a trunk, inside `box` (x0, y0, x1, y1): the wood under
    it shows, as lit as the bark was, under a dark lip where the bark's edge throws its shadow."""
    x0, y0, x1, y1 = box
    for _ in range(count):
        cx, cy = rng.uniform(x0, x1), rng.uniform(y0, y1)
        rx, ry = rng.uniform(size[0] * 0.6, size[0]), rng.uniform(size[1] * 0.6, size[1])
        patch = forms.ellipse(WIDTH, HEIGHT, cx, cy, rx, ry, rng.uniform(-15, 15))
        # Not the trunk's outline: the patch stays inside it.
        on_bark = forms.shrunk(np.array([[colour in bark for colour in row] for row in canvas]))
        patch &= on_bark
        for y, x in zip(*np.nonzero(patch)):
            canvas[y][x] = wood[(0, 1, 1, 1)[bark.index(canvas[y][x])]] if canvas[y][x] != bark[2] or bark[1] == bark[2] else wood[2]
        lip = patch & ~np.roll(patch, 1, axis=0)
        for y, x in zip(*np.nonzero(lip)):
            canvas[y][x] = bark[3]


def snap(canvas, rng, centre, top, half_width, slope=None, hollow=True, wood=SPLINTER, clear_above=False):
    """Breaks a trunk off at `top`: clears it above a jagged line across it (`half_width` either
    side of `centre`, sloping by `slope` per px), leaving pale splinters standing up, and on a
    hollow trunk its dark rotten heart. With `clear_above` everything above the break goes, the
    branches beside the trunk too."""
    slope = rng.choice((-0.6, -0.4, 0.4, 0.6)) if slope is None else slope
    left, right = math.floor(centre - half_width - 2), math.ceil(centre + half_width + 2)
    cut = {}
    for x in range(left, right + 1):
        cut[x] = round(top + slope * (x - centre) + rng.choice((0, 0, 1, 2)) - (rng.randint(3, 7) if rng.random() < 0.18 else 0))
    for x, y_cut in cut.items():
        for y in range(y_cut):
            canvas[y][x] = None
    if clear_above:
        for y in range(min(cut.values())):
            canvas[y] = [None] * WIDTH
    columns = [x for x in cut if canvas[cut[x]][x] is not None]
    for x in columns:
        y = cut[x]
        canvas[y][x] = wood[0] if x < centre else wood[1]
        is_heart = hollow and abs(x + 0.5 - centre) < half_width - 2.5
        if is_heart:
            canvas[y][x] = ROT[0]
            if canvas[y + 1][x] is not None:
                canvas[y + 1][x] = ROT[1] if abs(x + 0.5 - centre) < half_width - 4 else ROT[0]
    # The outline over the splinters: the side columns and the tips are rimmed dark.
    for x in columns:
        y = cut[x]
        if x - 1 not in cut or canvas[y][x - 1] is None or x + 1 not in cut or canvas[y][x + 1] is None:
            continue
        if cut[x - 1] > y + 1 and cut[x + 1] > y + 1:
            canvas[y][x] = wood[1]


# Bracket fungi as maps of their pixels, growing out to the right from the trunk at their left
# column: l lit top, m middle, d shaded, r the pale growing rim, u the dark underside, o outline.
_BRACKETS = {
    "small": (
        "..ooo..",
        ".olmmo.",
        "olmmmdo",
        "orrrrro",
        ".ouuuo.",
    ),
    "large": (
        "...oooo...",
        "..ollmmo..",
        ".olmmmmdo.",
        "olmmmmmddo",
        "orrrrrrrro",
        ".ouuuuuuo.",
    ),
}


def bracket(canvas, x, y, size="small", ramp=TINDER, rim=TINDER_RIM, side=1):
    """A bracket fungus whose foot is at (x, y) on the edge of a trunk, sticking out to `side`: a
    hoof lit on its rounded top, its pale growing rim and its dark underside (`ramp` is lit, middle,
    shaded and outline)."""
    colours = {"l": ramp[0], "m": ramp[1], "d": ramp[2], "o": ramp[3], "u": ramp[3], "r": rim}
    rows = _BRACKETS[size]
    for dy, row in enumerate(rows):
        for dx, letter in enumerate(row):
            if letter != ".":
                px = x + dx - 2 if side > 0 else x - dx + 2
                # Lit on the left either way: a bracket to the left is the same hoof, mirrored,
                # with its light kept on the left.
                if side < 0 and letter in "ld":
                    letter = "d" if letter == "l" else "l"
                canvas[y - len(rows) + 2 + dy][px] = colours[letter]


def hole(canvas, x, y, bark):
    """A woodpecker's hole or a knothole: a dark oval, its lower lip lit."""
    forms.paint(canvas, forms.ellipse(WIDTH, HEIGHT, x + 0.5, y + 0.5, 1.6, 2.2), ROT[1])
    for dx in (0, 1):
        canvas[y + 3][x + dx] = bark[0]
        canvas[y - 2][x + dx] = bark[3]


def _crown_mask(picture, colours):
    return np.array([[colour in colours for colour in row] for row in picture])


def _grow(mask, steps):
    grown = mask.copy()
    for _ in range(steps):
        grown = grown | np.roll(grown, 1, 0) | np.roll(grown, -1, 0) | np.roll(grown, 1, 1) | np.roll(grown, -1, 1)
    return grown


def _clear_dead_part(bare, living, half, colours, below):
    """Takes off a bare tree what the living tree of the same seed has in leaf and the half-dead one
    has not (and a little round it): the twigs of its dead side, above row `below`."""
    gone = _grow(_crown_mask(living, colours), 6) & ~_grow(_crown_mask(half, colours), 1)
    for y, x in zip(*np.nonzero(gone)):
        if y < below and bare[y][x] not in (None, "shadow"):
            bare[y][x] = None


# --- The oak --------------------------------------------------------------------------------

# The limbs of the bare oak (trees.bare_oak): their lean and length.
OAK_LIMBS = ((-0.95, 30), (-0.4, 40), (0.15, 44), (0.65, 38), (1.15, 26))


def dead_oak(variant):
    """A dead oak: its stout furrowed trunk and crooked limbs, grey where the bark has gone. Lately
    dead it still has all its limbs, a few broken; older, most are broken off at the elbow and the
    bark hangs in patches; the oldest is a hollow ruin with a few stubs of limbs."""
    rng = random.Random(f"dead_oak-{variant}")
    canvas = cell()
    ground_shadow(canvas, 28, rows=7)
    tree_trunk(canvas, rng, 100, 14)
    left = CENTRE - 7
    if variant == 0:
        for index, (angle, length) in enumerate(OAK_LIMBS):
            # Spread wider than the living oak's: no leaves weigh them, the eye goes to the limbs.
            angle = angle * 1.2 + rng.uniform(-0.12, 0.12)
            dead_limb(canvas, rng, (CENTRE + angle * 5, 104 + abs(angle) * 5), angle, length * 1.05, BARK, SILVER, broken=index == 3, bark_share=0.7)
        peel(canvas, rng, BARK, SILVER, (left + 2, 108, left + 12, 140), 2)
    elif variant == 1:
        for angle, length, broken in ((-1.0, 34, False), (-0.35, 44, True), (0.25, 46, False), (0.85, 36, True)):
            angle += rng.uniform(-0.1, 0.1)
            dead_limb(canvas, rng, (CENTRE + angle * 5, 104), angle, length, BARK, SILVER, radius=4.5, broken=broken, forks=1, bark_share=0.4)
        peel(canvas, rng, BARK, SILVER, (left + 1, 104, left + 13, 146), 4, (4, 9))
    else:
        for angle, length in ((-1.05, 26), (0.6, 22)):
            dead_limb(canvas, rng, (CENTRE + angle * 6, 106), angle, length, BARK, SILVER, radius=5, broken=True, bark_share=0.3)
        snap(canvas, rng, CENTRE, 94, 7, slope=0.5)
        peel(canvas, rng, BARK, SILVER, (left + 1, 104, left + 13, 146), 5, (4, 10))
        # The hollow foot, where the heart has rotted out.
        forms.paint(canvas, forms.ellipse(WIDTH, HEIGHT, CENTRE + 1, BOTTOM - 7, 3, 6) & (forms.grid(WIDTH, HEIGHT)[1] < BOTTOM - 1), ROT[1])
        bracket(canvas, CENTRE + 6, 122, "large")
    return canvas


def _oak_crown(variant):
    """The clumps of a half-dead oak's crown that are still in leaf: the right side gone, or the
    top (a stag-headed oak, its crown sunk round its dead antlers)."""
    def keep(clumps):
        (cx, cy, radius), *rest = clumps
        if variant == 0:
            return [(cx - 8, cy + 2, radius - 4)] + [clump for clump in rest if clump[0] < 60]
        return [(cx, cy + 10, radius - 3)] + [(x, y + 4, r) for x, y, r in rest if y > 70]
    return keep


# The living limbs of each half-dead oak in winter, and its dead ones: (lean, length, broken).
_OAK_LIVING = (((-0.95, 30), (-0.4, 40), (0.05, 36)), ((-0.95, 24), (-0.4, 28), (0.65, 28), (1.15, 22)))
_OAK_DEAD = (((0.6, 52, False), (0.25, 44, True)), ((-0.3, 60, False), (0.15, 62, True), (0.5, 52, False)))


def _oak_dead_part(canvas, rng, variant, behind):
    for angle, length, broken in _OAK_DEAD[variant]:
        dead_limb(canvas, rng, (CENTRE + angle * 5, 104), angle, length, BARK, SILVER, radius=3.5, broken=broken, behind=behind)


def half_dead_oak(variant):
    """A half-dead oak in leaf: one side of its crown dead, or its top (stag-headed)."""
    canvas = trees.oak(trees.OAK_SEEDS[variant], _oak_crown(variant))
    _oak_dead_part(canvas, random.Random(f"half_dead_oak-{variant}"), variant, behind=True)
    return canvas


def bare_half_dead_oak(variant):
    """The half-dead oak in winter: the living limbs of the bare oak where its crown is in leaf,
    and the same dead limbs."""
    rng = random.Random(trees.OAK_SEEDS[variant])
    canvas = cell()
    ground_shadow(canvas, 28, rows=7)
    tree_trunk(canvas, rng, 100, 14)
    for angle, length in _OAK_LIVING[variant]:
        trees.crown_limb(canvas, rng, (CENTRE + angle * 5, 104), angle + rng.uniform(-0.1, 0.1), length, BARK)
    _oak_dead_part(canvas, random.Random(f"half_dead_oak-{variant}"), variant, behind=False)
    return canvas


# --- The beech ------------------------------------------------------------------------------


def _beech_eyes(canvas, rng, top, count):
    """The dark eyes of beech bark where branches fell off, as beech._bole draws them."""
    left = CENTRE - beech.TRUNK_WIDTH // 2
    for _ in range(count):
        x, y = left + rng.randint(2, beech.TRUNK_WIDTH - 5), rng.randint(top + 10, 140)
        for dx, dy, colour in ((0, 0, "stone_dark"), (1, 0, "stone_dark"), (2, 0, "stone_dark"), (1, 1, "stone_dark"), (0, -1, "stone_light"), (1, -1, "stone_light")):
            canvas[y + dy][x + dx] = colour


def dead_beech(variant):
    """A dead beech: its smooth grey bole with tinder fungi on it, the bark coming off in sheets
    to brown wood; lately dead with its steep limbs, older with most of them broken, the oldest
    snapped off high up, a tall stump crowded with fungi."""
    rng = random.Random(f"dead_beech-{variant}")
    canvas = cell()
    bark = beech.BARK
    left = CENTRE - beech.TRUNK_WIDTH // 2
    if variant < 2:
        ground_shadow(canvas, 28, rows=7)
        tree_trunk(canvas, rng, beech.FORK_Y, beech.TRUNK_WIDTH, bark)
        _beech_eyes(canvas, rng, beech.FORK_Y, 2)
        limbs = ((-0.85, 44, False), (-0.35, 50, True), (0.15, 52, False), (0.65, 42, False)) if variant == 0 else ((-0.75, 30, True), (-0.2, 54, False), (0.5, 26, True))
        for angle, length, broken in limbs:
            angle += rng.uniform(-0.08, 0.08)
            dead_limb(canvas, rng, (CENTRE + angle * 5, beech.FORK_Y + 3), angle, length, bark, BEECH_DEAD, radius=3.5, broken=broken, bark_share=0.75 if variant == 0 else 0.45)
        peel(canvas, rng, bark, BEECH_DEAD, (left + 2, 106, left + 10, 140), 1 + 2 * variant, (4, 9))
        for y, side, size in ((118, 1, "large"), (134, -1, "small"), (126, -1, "small"))[: 2 + variant]:
            bracket(canvas, CENTRE + side * 6, y, size, side=side)
    else:
        ground_shadow(canvas, 24, rows=7)
        tree_trunk(canvas, rng, 56, beech.TRUNK_WIDTH, bark)
        _beech_eyes(canvas, rng, 56, 3)
        snap(canvas, rng, CENTRE, 62, beech.TRUNK_WIDTH / 2, slope=-0.6)
        peel(canvas, rng, bark, BEECH_DEAD, (left + 2, 70, left + 10, 140), 4, (4, 10))
        hole(canvas, CENTRE - 2, 84, bark)
        for y, side, size in ((92, 1, "small"), (102, -1, "large"), (112, 1, "large"), (124, -1, "small"), (134, 1, "small")):
            bracket(canvas, CENTRE + side * 6, y, size, side=side)
    return canvas


def _beech_crown(variant):
    """The clumps of a half-dead beech's crown still in leaf: the left side, or the top gone."""
    def keep(clumps):
        (cx, cy, radius), *rest = clumps
        if variant == 0:
            return [(cx + 8, cy + 3, radius - 6)] + [clump for clump in rest if clump[0] > 40]
        return [(cx, cy + 12, radius - 4)] + [(x, y + 6, r) for x, y, r in rest if y > 62]
    return keep


_BEECH_LIVING = ((0.15, 40), (0.6, 36)), ((-0.6, 28), (-0.1, 30), (0.4, 30), (0.8, 26))
_BEECH_DEAD = (((-0.75, 52, False), (-0.35, 46, True)), ((-0.2, 60, False), (0.2, 58, True)))


def _beech_dead_part(canvas, rng, variant, behind):
    for angle, length, broken in _BEECH_DEAD[variant]:
        dead_limb(canvas, rng, (CENTRE + angle * 5, beech.FORK_Y + 3), angle, length, beech.BARK, BEECH_DEAD, radius=3.2, broken=broken, behind=behind)


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
    for angle, length in _BEECH_LIVING[variant]:
        trees.crown_limb(canvas, rng, (CENTRE + angle * 5, beech.FORK_Y + 3), angle + rng.uniform(-0.1, 0.1), length, beech.BARK, forks=4, spread=0.34)
    _beech_dead_part(canvas, random.Random(f"half_dead_beech-{variant}"), variant, behind=False)
    return canvas


# --- The birch ------------------------------------------------------------------------------

# A dead birch's twigs: grey, without the purple-brown haze of the living ones.
BIRCH_DEAD_TWIGS = ("stone_light", "stone_dark")
# The birch polypore: a rounded shelf, light brown on top, its rim and underside white.
POLYPORE = ("sand_light", "sand", "mud", "mud_dark")
POLYPORE_RIM = "lime"


def _bark_curls(canvas, rng, centres, rows, count):
    """Strips of white bark curling off a birch trunk at its edges, between `rows` (top, bottom)."""
    for _ in range(count):
        y = rng.randint(*rows)
        side = rng.choice((-1, 1))
        x = round(centres[y]) + side * rng.randint(3, 4)
        for step in range(rng.randint(2, 3)):
            canvas[y - step // 2][x + side * step] = "lime"
            if canvas[y + 1 - step // 2][x + side * step] is None:
                canvas[y + 1 - step // 2][x + side * step] = "stone_dark"


def _polypores(canvas, centres, spots):
    for y, side, size in spots:
        bracket(canvas, round(centres[y]) + side * 4, y, size, POLYPORE, POLYPORE_RIM, side)


def dead_birch(variant):
    """A dead birch: its white bark holds on as a tube while the wood inside rots, so the top
    breaks off and birch polypores grow on it, and strips of bark curl off. Lately dead with its
    branches stiff and grey and its top broken; older snapped off half-way; the oldest a short
    hollow stump of white bark."""
    rng = random.Random(f"dead_birch-{variant}")
    canvas = cell()
    centres = birch._trunk(canvas, rng, variant)
    trees.outline_in_bark(canvas, birch.BARK[3])
    if variant == 0:
        side = rng.choice((-1, 1))
        for index, y in enumerate(range(birch.TOP + 18, 100, 11)):
            dead_twigs(canvas, rng, centres[y], y, side * rng.uniform(0.6, 0.95), 12 + 2 * index, BIRCH_DEAD_TWIGS, 2, 0.5, broken=0.4)
            side = -side
        snap(canvas, rng, centres[50], 50, 3, slope=0.8, hollow=False)
        _polypores(canvas, centres, ((96, 1, "small"), (112, -1, "small")))
        _bark_curls(canvas, rng, centres, (60, 130), 4)
    elif variant == 1:
        for y, angle in ((92, -0.9), (104, 0.8)):
            dead_twigs(canvas, rng, centres[y], y, angle, 8, BIRCH_DEAD_TWIGS, 1, 0.5, broken=0.8)
        snap(canvas, rng, centres[78], 78, 4, slope=-0.7)
        _polypores(canvas, centres, ((96, 1, "large"), (110, -1, "small"), (122, 1, "small")))
        _bark_curls(canvas, rng, centres, (84, 136), 5)
    else:
        snap(canvas, rng, centres[112], 112, 4, slope=0.7)
        _polypores(canvas, centres, ((124, 1, "large"), (134, -1, "small")))
        _bark_curls(canvas, rng, centres, (116, 140), 3)
    return canvas


def _birch_crown(variant, centres):
    """The clumps of a half-dead birch's crown still in leaf: the top gone, or the left side."""
    def keep(clumps):
        if variant == 0:
            return [clump for clump in clumps if clump[1] > 66]
        return [clump for clump in clumps if clump[0] > centres[max(birch.TOP, round(clump[1]))] - 3]
    return keep


def _birch_dead_part(canvas, rng, centres, variant, behind):
    layer = cell()
    if variant == 0:
        for y, angle, length in ((44, -0.6, 12), (52, 0.7, 14), (60, -0.8, 12)):
            dead_twigs(layer, rng, centres[y], y, angle, length, BIRCH_DEAD_TWIGS, 2, 0.5, broken=0.4)
    else:
        for y, length in ((54, 18), (72, 22), (90, 18)):
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
    for index, y in enumerate(range(birch.TOP + 12, 100, 11)):
        angle = side * rng.uniform(0.55, 0.9)
        if (variant == 0 and y > 64) or (variant == 1 and side > 0):
            twigs(canvas, rng, centres[y], y, angle, 14 + 2 * index, birch.TWIGS, 3, 0.5)
        side = -side
    if variant == 1:
        twigs(canvas, rng, centres[birch.TOP], birch.TOP, 0.2, 10, birch.TWIGS, 3, 0.4)
    birch._hanging_tips(canvas, rng, {birch.TWIGS[1]}, birch.TWIGS[1], 30)
    _birch_dead_part(canvas, random.Random(f"half_dead_birch-{variant}"), centres, variant, behind=False)
    return canvas


# --- The alder ------------------------------------------------------------------------------


def dead_alder(variant):
    """A dead alder: its straight dark stem with the short side branches in tiers, stiff and grey,
    the old cones still on some; older its top broken and most branches gone to stubs; the oldest
    snapped off low, hollow."""
    rng = random.Random(f"dead_alder-{variant}")
    canvas = cell()
    alder._stem(canvas, rng)
    bark = alder.BARK
    left = CENTRE - alder.TRUNK_WIDTH // 2
    if variant == 0:
        side = rng.choice((-1, 1))
        for y in range(alder.TOP + 6, 100, 8):
            length = 8 + (y - alder.TOP) // 5
            dead_twigs(canvas, rng, CENTRE + side * 2, y, side * rng.uniform(0.8, 1.1), length, (SILVER[1], SILVER[3]), 2, 0.5, broken=0.35)
            side = -side
        _cones(canvas, rng, (SILVER[1], SILVER[3]), 14)
        peel(canvas, rng, bark, SILVER, (left + 2, 104, left + 8, 140), 1)
    elif variant == 1:
        side = rng.choice((-1, 1))
        for y in range(62, 100, 8):
            dead_twigs(canvas, rng, CENTRE + side * 2, y, side * rng.uniform(0.9, 1.2), rng.randint(5, 9), (SILVER[1], SILVER[3]), 1, 0.5, broken=0.7)
            side = -side
        snap(canvas, rng, CENTRE, 58, 3, slope=0.8, hollow=False)
        peel(canvas, rng, bark, SILVER, (left + 2, 100, left + 8, 144), 3, (3, 8))
    else:
        snap(canvas, rng, CENTRE, 90, 5, slope=-0.6)
        dead_limb(canvas, rng, (CENTRE + 3, 100), 0.9, 16, bark, SILVER, radius=2.5, broken=True)
        peel(canvas, rng, bark, SILVER, (left + 2, 100, left + 8, 144), 3, (3, 8))
        bracket(canvas, CENTRE + 5, 116, "small")
    return canvas


def _cones(canvas, rng, ends, count):
    """Old black cones hanging from the tips of an alder's twigs (as alder.bare_alder hangs them)."""
    tips = [(x, y) for y in range(HEIGHT - 60) for x in range(1, WIDTH - 2) if canvas[y][x] == ends[1] and canvas[y + 1][x] is None]
    for x, y in rng.sample(tips, min(len(tips), count)):
        for dx, dy, colour in ((0, 1, "umber"), (1, 1, alder.CONE), (0, 2, alder.CONE), (1, 2, alder.CONE), (0, 3, alder.CONE)):
            if canvas[y + dy][x + dx] is None:
                canvas[y + dy][x + dx] = colour


def _alder_crown(variant):
    """The clumps of a half-dead alder's crown still in leaf: the top gone, or the right side."""
    def keep(clumps):
        if variant == 0:
            return [clump for clump in clumps if clump[1] > 68]
        return [clump for clump in clumps if clump[0] < CENTRE + 4]
    return keep


def _alder_dead_part(canvas, rng, variant, behind):
    layer = cell()
    if variant == 0:
        side = -1
        for y in range(alder.TOP + 6, 70, 8):
            dead_twigs(layer, rng, CENTRE + side * 2, y, side * rng.uniform(0.8, 1.1), 8 + (y - alder.TOP) // 5, (SILVER[1], SILVER[3]), 2, 0.5, broken=0.35)
            side = -side
    else:
        for y in range(alder.TOP + 10, 104, 9):
            dead_twigs(layer, rng, CENTRE + 2, y, rng.uniform(0.8, 1.1), 10 + (y - alder.TOP) // 4, (SILVER[1], SILVER[3]), 2, 0.5, broken=0.35)
    _layer_onto(canvas, layer, _is_clear if behind else None)


def half_dead_alder(variant):
    """A half-dead alder in leaf: its top dead (as alders die back from the top), or its right side."""
    canvas = alder.alder(alder.ALDER_SEEDS[variant], _alder_crown(variant))
    _alder_dead_part(canvas, random.Random(f"half_dead_alder-{variant}"), variant, behind=True)
    return canvas


def bare_half_dead_alder(variant):
    """The half-dead alder in winter: its living branches hung with cones and catkins, and the
    dead ones."""
    rng = random.Random(alder.ALDER_SEEDS[variant])
    canvas = cell()
    alder._stem(canvas, rng)
    side = rng.choice((-1, 1))
    for y in range(alder.TOP + 6, 100, 8):
        length = 8 + (y - alder.TOP) // 5
        if (variant == 0 and y > 70) or (variant == 1 and side < 0):
            twigs(canvas, rng, CENTRE + side * 2, y, side * rng.uniform(0.8, 1.1), length, alder.TWIGS, 3, 0.5)
        side = -side
    _cones(canvas, rng, alder.TWIGS, 18)
    _alder_dead_part(canvas, random.Random(f"half_dead_alder-{variant}"), variant, behind=False)
    return canvas


# --- The pollard willow ---------------------------------------------------------------------

# Dead rods: dark at their foot, weathered grey along them.
DEAD_RODS = ("mud_dark", "stone", "stone_light")


def _dead_rods(canvas, rng, feet, count, keeps=None, behind=False):
    """Dead rods from the willow's head: stiff and grey, many broken off short with a pale end.
    `keeps` picks the rods (each a list of points from its foot up) by their tip."""
    layer = cell()
    for rod in willow._rods(rng, feet, count):
        if not rod or (keeps and not keeps(rod[-1])):
            continue
        if rng.random() < 0.45:
            rod = rod[: max(3, round(len(rod) * rng.uniform(0.2, 0.55)))]
        for step, (x, y) in enumerate(rod):
            colour = DEAD_RODS[0] if step < 6 else DEAD_RODS[1]
            if layer[y][x] is None:
                layer[y][x] = colour
        x, y = rod[-1]
        layer[y][x] = SPLINTER[1]
    _layer_onto(canvas, layer, (lambda under: under is None or under in willow.RODS) if behind else lambda under: under not in willow.KNOBS)


def dead_willow(variant):
    """A dead pollard willow: its head with a few stiff grey rods left, many broken; older, not cut
    for years before it died, with a few thick dead poles; the oldest split down the middle, half
    of its head fallen away and the hollow inside showing."""
    rng = random.Random(f"dead_willow-{variant}")
    canvas = cell()
    feet = willow._trunk_and_head(canvas, rng)
    bark = willow.BARK
    left = CENTRE - willow.TRUNK_WIDTH // 2
    if variant == 0:
        _dead_rods(canvas, rng, feet, 26)
        peel(canvas, rng, bark, SILVER, (left + 3, willow.HEAD_Y + 6, left + 16, 150), 2)
    elif variant == 1:
        for angle, length, broken in ((-0.55, 46, False), (-0.15, 54, True), (0.25, 50, False), (0.6, 38, True)):
            foot = feet[round((angle + 0.7) / 1.4 * (len(feet) - 1))]
            dead_limb(canvas, rng, (foot[0], foot[1] + 2), angle, length, willow.KNOBS[::-1], SILVER, radius=2.6, broken=broken, forks=1, bark_share=0.3)
        _dead_rods(canvas, rng, feet, 10)
        peel(canvas, rng, bark, SILVER, (left + 3, willow.HEAD_Y + 6, left + 16, 150), 3)
    else:
        _split(canvas, rng)
        _dead_rods(canvas, rng, feet[: len(feet) // 2], 6)
    return canvas


def _split(canvas, rng):
    """Splits a willow's trunk and head down the middle: its right half fallen away, the dark
    hollow inside showing along the break."""
    x = CENTRE + 1.0
    edge = {}
    for y in range(BOTTOM - 16, -1, -1):
        x += rng.choice((-0.5, 0, 0, 0.5)) if y < BOTTOM - 20 else 0
        edge[y] = round(x)
    for y, x_edge in edge.items():
        top_part = y < willow.HEAD_Y + 4
        for x in range(x_edge, WIDTH):
            if canvas[y][x] is not None and canvas[y][x] != "shadow" and (top_part or x < x_edge + 4):
                canvas[y][x] = None if top_part else canvas[y][x]
        if canvas[y][x_edge - 1] is not None and canvas[y][x_edge - 1] != "shadow":
            # The hollow inside along the break, rimmed by the pale broken wood.
            canvas[y][x_edge - 1] = SPLINTER[0] if y < willow.HEAD_Y + 4 else canvas[y][x_edge - 1]
            for dx in range(2, 5):
                if y >= willow.HEAD_Y - 4 and canvas[y][x_edge - dx] not in (None, "shadow"):
                    canvas[y][x_edge - dx] = ROT[1] if dx < 4 else ROT[0]


def _willow_crown(variant, kept):
    """The clumps of a half-dead willow still in leaf: the right side gone, or the left (with a
    thick dead pole). Remembers them in `kept`."""
    def keep(clumps):
        kept.extend(clump for clump in clumps if (clump[0] < CENTRE + 2 if variant == 0 else clump[0] > CENTRE - 6))
        return list(kept)
    return keep


def _is_dead_side(variant, x):
    return x > CENTRE + 2 if variant == 0 else x < CENTRE - 6


def _willow_dead_part(canvas, variant, feet, behind):
    rng = random.Random(f"half_dead_willow-{variant}")
    if variant == 1:
        dead_limb(canvas, rng, (feet[2][0], feet[2][1] + 2), -0.35, 54, willow.KNOBS[::-1], SILVER, radius=2.4, forks=1, bark_share=0.3, behind=behind)
    _dead_rods(canvas, rng, feet, 34, lambda tip: _is_dead_side(variant, tip[0]), behind)


def half_dead_willow(variant):
    """A half-dead pollard willow in leaf: the rods of one side of its head dead and grey."""
    seed = willow.WILLOW_SEEDS[variant]
    kept = []
    canvas = willow.willow(seed, _willow_crown(variant, kept))
    # The leaves at the rods' tips that stood over the dead side's crown go with it.
    near = np.zeros((HEIGHT, WIDTH), bool)
    for cx, cy, radius in kept:
        near |= forms.ellipse(WIDTH, HEIGHT, cx, cy, radius + 2, radius + 2)
    for y in range(willow.HEAD_Y - 6):
        for x in range(WIDTH):
            if _is_dead_side(variant, x) and not near[y, x] and canvas[y][x] in willow.LEAVES + willow.RODS:
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
            colour = willow.RODS[0] if step < len(rod) * 0.5 else willow.RODS[1]
            if canvas[y][x] is None or canvas[y][x] in willow.RODS:
                canvas[y][x] = colour
    _willow_dead_part(canvas, variant, feet, behind=False)
    return canvas


# --- The Scots pine -------------------------------------------------------------------------

DEAD_PINE_SEEDS = (134, 135, 136)
PINE_DEAD_TWIGS = ("stone", "stone_dark")


def _pine_parts(seed, keep=lambda clumps: []):
    """A pine of `seed` with only the needle clumps `keep` picks, and all its clumps: the first is
    the top's, then those on the branches, and the two that fill out the top."""
    clumps = []

    def crown(all_clumps):
        clumps.extend(all_clumps)
        return keep(all_clumps)

    return trees.pine(seed, crown), clumps


def _trunk_middle(canvas, y):
    """The middle of the trunk on row `y`: of the run of drawn pixels nearest the cell's centre."""
    xs = [x for x in range(WIDTH) if canvas[y][x] not in (None, "shadow")]
    nearest = min(xs, key=lambda x: abs(x - CENTRE))
    left = right = nearest
    while left - 1 in xs:
        left -= 1
    while right + 1 in xs:
        right += 1
    return (left + right + 1) / 2


def _pine_twigs(canvas, rng, clumps, behind=False):
    """Dead twigs fanning up from the ends of the branches under the clumps that are gone."""
    layer = cell()
    for cx, cy, half_width in clumps:
        trunk = _trunk_middle(canvas, round(cy) + 6)
        side = 1 if cx >= trunk else -1
        for angle in (side * 0.35, side * 1.0, -side * 0.15):
            dead_twigs(layer, rng, cx, cy + 4, angle, round(half_width * 0.7), PINE_DEAD_TWIGS, 2, 0.5, broken=0.35)
    _layer_onto(canvas, layer, _is_clear if behind else None)


def dead_pine(variant):
    """A dead Scots pine: the tall trunk and the umbrella of branches without a needle, their twigs
    grey and broken; older, its top broken off with the upper branches, the bark coming off in
    plates; the oldest a tall snapped stem with woodpecker holes."""
    rng = random.Random(f"dead_pine-{variant}")
    canvas, clumps = _pine_parts(DEAD_PINE_SEEDS[variant])
    top_y = clumps[0][1] - 4
    if variant == 0:
        _pine_twigs(canvas, rng, clumps[1:-2])
        dead_twigs(canvas, rng, clumps[0][0], top_y, rng.uniform(-0.2, 0.2), 10, PINE_DEAD_TWIGS, 2, 0.5, broken=0.3)
        peel(canvas, rng, trees.PINE_BARK, FRESH_WOOD, (CENTRE - 6, 96, CENTRE + 6, 136), 2)
    elif variant == 1:
        cut = top_y + 22
        _pine_twigs(canvas, rng, [clump for clump in clumps[1:-2] if clump[1] > cut + 4])
        snap(canvas, rng, _trunk_middle(canvas, cut + 2), cut, 4, clear_above=True, hollow=False)
        peel(canvas, rng, trees.PINE_BARK, FRESH_WOOD, (CENTRE - 6, 90, CENTRE + 6, 150), 4, (3, 8))
    else:
        cut = 74
        middle = _trunk_middle(canvas, cut + 2)
        snap(canvas, rng, middle, cut, 5, clear_above=True)
        peel(canvas, rng, trees.PINE_BARK, FRESH_WOOD, (CENTRE - 6, 84, CENTRE + 6, 150), 5, (3, 9))
        hole(canvas, round(_trunk_middle(canvas, 92)) - 1, 92, trees.PINE_BARK)
        hole(canvas, round(_trunk_middle(canvas, 106)), 106, trees.PINE_BARK)
    return canvas


def _pine_keep(variant):
    """The needle clumps of a half-dead pine: those of one side gone, or the top's."""
    def keep(clumps):
        top, *branches = clumps
        branches, fill = branches[:-2], branches[-2:]
        if variant == 0:
            trunk_x = top[0]
            return [top] + fill + [clump for index, clump in enumerate(branches) if index < 2 or clump[0] < trunk_x]
        return branches[2:]
    return keep


def half_dead_pine(variant):
    """A half-dead pine: the branches of one side bare and grey, or its top dead."""
    seed = (131, 132, 133)[variant]
    canvas, clumps = _pine_parts(seed, _pine_keep(variant))
    kept = _pine_keep(variant)(clumps)
    rng = random.Random(f"half_dead_pine-{variant}")
    _pine_twigs(canvas, rng, [clump for clump in clumps[1:-2] if clump not in kept], behind=True)
    if variant == 1:
        dead_twigs(canvas, rng, clumps[0][0], clumps[0][1] - 4, rng.uniform(-0.2, 0.2), 10, PINE_DEAD_TWIGS, 2, 0.5, broken=0.3)
    return canvas


# --- The spruce -----------------------------------------------------------------------------

SPRUCE_STEM_TOP = 22
# The dead branches: grey-brown, lit on top, with dark twigs hanging from them.
SPRUCE_DEAD = ("stone", "bare", "mud_dark")


def _spruce_stem(canvas, top, bottom=130, behind=False):
    """The straight stem of a spruce from `top` down to `bottom`, thickening downwards."""
    for y in range(top, bottom):
        width = 2 + round(6 * (y - top) / (bottom - top))
        left = CENTRE - width // 2
        for x in range(left - 1, left + width + 1):
            if behind and canvas[y][x] is not None:
                continue
            canvas[y][x] = BARK[3] if x in (left - 1, left + width) else BARK[0] if x == left else BARK[1]


def _spruce_whorls(canvas, rng, top, bottom, reach, sides=(-1, 1), behind=False):
    """Dead branches of a spruce in whorls from `top` to `bottom`: each runs out from the stem
    `reach(y)` px and droops, lit on its upper side, with short dark twigs hanging from it."""
    layer = cell()
    y = top
    while y < bottom:
        for side in sides:
            length = max(2, round(reach(y) + rng.uniform(-2, 2)))
            for step in range(length):
                x = CENTRE + side * (1 + step)
                by = round(y + step * 0.32 + step * step * 0.008)
                if not (0 <= x < WIDTH and by < BOTTOM - 2):
                    break
                layer[by][x] = SPRUCE_DEAD[1]
                if layer[by - 1][x] is None:
                    layer[by - 1][x] = SPRUCE_DEAD[0] if step < length - 1 else None
                if step > 2 and step % 3 == rng.randint(0, 2):
                    for drop in range(1, rng.randint(2, 4)):
                        layer[by + drop][x + side * (drop // 2)] = SPRUCE_DEAD[2]
            if length > 2 and rng.random() < 0.4:
                layer[round(y + length * 0.32)][CENTRE + side * length] = SPLINTER[1]
        y += rng.randint(4, 6)
    _layer_onto(canvas, layer, _is_clear if behind else None)


def _spruce_reach(y):
    """How far a spruce's branches reach at row `y`, as its tiers (trees.spruce)."""
    return 4 + (y - SPRUCE_STEM_TOP) * 0.24


def dead_spruce(variant):
    """A dead spruce: a narrow grey cone of dead drooping branches in whorls round the straight
    stem; older, its top broken off and its lower branches gone to stubs; the oldest a bare stem
    of stubs snapped off half-way, the bark coming off."""
    rng = random.Random(f"dead_spruce-{variant}")
    canvas = cell()
    ground_shadow(canvas, 22, rows=6)
    tree_trunk(canvas, rng, 130, 9, flare=3)
    if variant == 0:
        _spruce_stem(canvas, SPRUCE_STEM_TOP)
        _spruce_whorls(canvas, rng, SPRUCE_STEM_TOP + 4, 128, _spruce_reach)
        peel(canvas, rng, BARK, SILVER, (CENTRE - 3, 134, CENTRE + 3, 152), 1)
    elif variant == 1:
        _spruce_stem(canvas, 36)
        _spruce_whorls(canvas, rng, 44, 104, _spruce_reach)
        _spruce_whorls(canvas, rng, 106, 128, lambda y: 3)
        snap(canvas, rng, CENTRE, 42, 2, hollow=False)
        peel(canvas, rng, BARK, SILVER, (CENTRE - 3, 132, CENTRE + 3, 152), 2)
    else:
        _spruce_stem(canvas, 56)
        _spruce_whorls(canvas, rng, 66, 128, lambda y: 3)
        snap(canvas, rng, CENTRE, 64, 3)
        peel(canvas, rng, BARK, SILVER, (CENTRE - 4, 132, CENTRE + 4, 152), 3, (3, 8))
        hole(canvas, CENTRE - 1, 140, BARK)
    return canvas


def half_dead_spruce(variant):
    """A half-dead spruce: its top dead (a grey spike over the green tiers), or its right side."""
    seed = (121, 122, 123)[variant]
    rng = random.Random(f"half_dead_spruce-{variant}")
    if variant == 0:
        canvas = trees.spruce(seed, lambda tier: tier[0] > 60)
        for y in range(0, 66):
            for x in range(WIDTH):
                if canvas[y][x] in ("green_dark", "green_deep"):
                    canvas[y][x] = None
        _spruce_stem(canvas, SPRUCE_STEM_TOP, 72, behind=True)
        _spruce_whorls(canvas, rng, SPRUCE_STEM_TOP + 4, 70, _spruce_reach, behind=True)
        return canvas
    canvas = trees.spruce(seed)
    greens = {"green_light", "green", "green_dark", "green_deep"}
    for y in range(HEIGHT):
        # The line between the living and the dead side wavers a little down the stem.
        boundary = CENTRE + 2 + (y // 5) % 3
        for x in range(boundary, WIDTH):
            if canvas[y][x] in greens:
                canvas[y][x] = None
        if canvas[y][boundary - 1] in greens:
            canvas[y][boundary - 1] = "green_deep"
    _spruce_stem(canvas, 28, behind=True)
    _spruce_whorls(canvas, rng, 30, 128, _spruce_reach, sides=(1,), behind=True)
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
# Each half-dead kind: its picture in leaf, and the bare one for winter (None for the evergreens,
# whose winter looks are their summer picture's, see seasons.py).
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
    """The sheets of the dead and the half-dead trees, as (kind, variants)."""
    result = []
    for kind in KINDS:
        if kind in DEAD:
            result.append((f"dead_{kind}", [DEAD[kind](variant) for variant in range(DEAD_VARIANTS)]))
    for kind in KINDS:
        if kind in HALF_DEAD:
            result.append((f"half_dead_{kind}", [HALF_DEAD[kind][0](variant) for variant in range(HALF_DEAD_VARIANTS)]))
    return result


def redraws():
    """The half-dead trees that are drawn anew for winter, bare: kind to a function of the variant."""
    return {f"half_dead_{kind}": draw[1] for kind, draw in HALF_DEAD.items() if draw[1] is not None}
