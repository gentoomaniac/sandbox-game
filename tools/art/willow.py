"""Art for the pollard willow of the marsh ditches (Kopfweide): a short, gnarled, furrowed trunk
about a tile high, cut back every few years to a knobbly head wider than the trunk, from which a
dense crown of thin straight rods springs. In summer the rods carry narrow silver-green leaves,
a loose and light crown; in winter they stand bare, a muted yellow-olive with a few brighter tips.

Each picture is an object cell (48x80, see canvas.py) with its foot at the bottom centre, in
palette colour names. generate.py calls `willow_row` and draws the winter looks with
`bare_willow`.
"""

import math
import random

from canvas import NEIGHBOURS, OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, blank
from trees import ground_shadow, tree_trunk

WILLOW_SEEDS = (321, 322, 323)
# Grey-brown, deeply furrowed bark, lit to dark; the darkest also outlines it.
BARK = ("bare_light", "bare_light", "bare", "soil_dark")
# The furrows in it.
FURROW = "mud_dark"
# The knobs of the head, where the rods were cut again and again: warmer than the trunk, so the
# head reads as wood and not as a stone.
KNOBS = ("sand", "mud", "mud_dark")
# The narrow grey-green leaves, lit to dark, and their silvery undersides, which the wind shows.
# seasons.py turns them for spring and autumn.
LEAVES = ("dry_light", "dry", "olive", "green_dark")
SILVER = "frost"
# The rods in winter: brown at their foot, yellow-olive along them, a few brighter tips.
RODS = ("umber", "reed", "straw")
# The top of the trunk; the head sits on it and the rods spring from the head.
HEAD_Y = 62
TRUNK_WIDTH = 10


def _trunk_and_head(canvas, rng):
    """The gnarled trunk and the knobbly head it was cut back to. Returns the points on top of the
    head the rods spring from."""
    ground_shadow(canvas, 11)
    tree_trunk(canvas, rng, HEAD_Y, TRUNK_WIDTH, BARK)
    left = OBJECT_CENTRE - TRUNK_WIDTH // 2
    # Deep furrows that wander up the trunk, and a dark hollow where a limb rotted out.
    for x in range(left + 2, left + TRUNK_WIDTH - 1, 3):
        for y in range(HEAD_Y + rng.randint(1, 4), OBJECT_BOTTOM - rng.randint(1, 3)):
            if rng.random() < 0.2:
                x += rng.choice((-1, 1)) if left < x < left + TRUNK_WIDTH - 2 else 0
            canvas[y][x] = FURROW if rng.random() < 0.8 else BARK[3]
    hollow_y = rng.randint(HEAD_Y + 5, HEAD_Y + 9)
    hollow_x = left + rng.randint(2, TRUNK_WIDTH - 4)
    canvas[hollow_y][hollow_x] = canvas[hollow_y + 1][hollow_x] = canvas[hollow_y][hollow_x + 1] = BARK[3]
    # The trunk flares out into the head over its top rows.
    for y in range(HEAD_Y, HEAD_Y + 5):
        flare = (HEAD_Y + 5 - y) // 2
        for x in range(left - flare, left + TRUNK_WIDTH + flare):
            if canvas[y][x] is None:
                canvas[y][x] = BARK[1] if x < OBJECT_CENTRE else BARK[2]
    # The head: a cluster of small knobs, where the rods were cut back again and again, each lit
    # on its upper left; the lower ones are drawn first, so those above overlap them.
    head = set()
    knobs = []
    for _ in range(11):
        angle = rng.uniform(0, 2 * math.pi)
        distance = math.sqrt(rng.uniform(0, 1))
        cx = OBJECT_CENTRE + math.cos(angle) * 6 * distance
        cy = HEAD_Y - 1 + math.sin(angle) * 2.5 * distance
        knobs.append((cx, cy, rng.uniform(1.8, 2.8)))
    for cx, cy, radius in sorted(knobs, key=lambda knob: -knob[1]):
        for y in range(math.floor(cy - radius), math.ceil(cy + radius) + 1):
            for x in range(math.floor(cx - radius), math.ceil(cx + radius) + 1):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                if dx * dx + dy * dy > radius * radius:
                    continue
                light = (dx * 0.7 + dy * 0.8) / radius
                canvas[y][x] = KNOBS[0] if light < -0.5 else KNOBS[1] if light < 0.3 else KNOBS[2]
                head.add((x, y))
    # Bark over the head too: short dark furrows running down between the knobs.
    for x, y in rng.sample(sorted(head), 10):
        for step in range(rng.randint(2, 4)):
            if canvas[y + step][x] in KNOBS[1:]:
                canvas[y + step][x] = FURROW
    for x, y in head:
        if any((x + dx, y + dy) not in head and canvas[y + dy][x + dx] is None for dx, dy in NEIGHBOURS):
            canvas[y][x] = BARK[3]
    for x, y in rng.sample(sorted(head), 6):
        if canvas[y][x] == KNOBS[1]:
            canvas[y][x] = BARK[3]
    tops = {}
    for x, y in head:
        tops[x] = min(y, tops.get(x, y))
    return sorted(tops.items())


def _rods(rng, feet, count):
    """The rods springing from the top of the head, as lists of (x, y) from their foot up:
    straight, 1 px wide, fanning upwards and a little outwards, of mixed lengths."""
    rods = []
    for index in range(count):
        spread = (index + rng.uniform(0, 1)) / count * 2 - 1
        foot_x, foot_y = feet[min(len(feet) - 1, max(0, round((spread + 1) / 2 * (len(feet) - 1))))]
        angle = spread * math.radians(36) + rng.uniform(-0.1, 0.1)
        length = rng.uniform(12, 34) * (1 - 0.3 * abs(spread))
        rod = []
        for step in range(1, round(length)):
            point = (round(foot_x + math.sin(angle) * step), round(foot_y - math.cos(angle) * step))
            if not rod or point != rod[-1]:
                rod.append(point)
        rods.append(rod)
    return rods


def _rod_count(seed):
    return 30 + seed % 3 * 4


def bare_willow(seed):
    """The willow in winter: the same trunk and head, the rods bare."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    feet = _trunk_and_head(canvas, rng)
    for rod in _rods(rng, feet, _rod_count(seed)):
        bright = rng.random() < 0.25
        for step, (x, y) in enumerate(rod):
            if step < 2:
                colour = RODS[0]
            elif bright and step >= len(rod) - 3:
                colour = RODS[2]
            else:
                colour = RODS[1]
            if canvas[y][x] is None or canvas[y][x] in RODS:
                canvas[y][x] = colour
    return canvas


def willow(seed):
    """The willow in leaf: the same rods, each with narrow leaves along it, silvery on the lit
    side, so the crown is loose and light, the rods showing through."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    feet = _trunk_and_head(canvas, rng)
    rods = _rods(rng, feet, _rod_count(seed))
    for rod in rods:
        for x, y in rod:
            if canvas[y][x] is None:
                canvas[y][x] = LEAVES[2]
    for rod in rods:
        for step, (x, y) in enumerate(rod):
            if step < 3 or rng.random() < 0.2:
                continue
            # Narrow leaves slant up and out from the rod to either side: silvery and light on
            # the lit left and at the top, grey-green on the right, dark low in the crown.
            for side in (-1, 1):
                for leaf_x, leaf_y in ((x + side, y), (x + 2 * side, y - 1)):
                    if not 0 <= leaf_x < OBJECT_CELL_WIDTH or canvas[leaf_y][leaf_x] not in (None, LEAVES[2]):
                        continue
                    if step < 6:
                        canvas[leaf_y][leaf_x] = LEAVES[3]
                    elif leaf_x < OBJECT_CENTRE or step > len(rod) * 0.8:
                        canvas[leaf_y][leaf_x] = SILVER if rng.random() < 0.25 else LEAVES[0]
                    else:
                        canvas[leaf_y][leaf_x] = LEAVES[1] if rng.random() < 0.7 else LEAVES[2]
    return canvas


def willow_row():
    """The atlas row of the willow: three trees."""
    return [willow(seed) for seed in WILLOW_SEEDS]
