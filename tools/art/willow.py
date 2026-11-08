"""Art for the pollard willow of the marsh ditches (Kopfweide): a short, gnarled, furrowed trunk
about a tile high, cut back every few years to a knobbly head wider than the trunk, from which a
crown of thin straight rods springs. In summer the rods carry narrow grey-green leaves, a dense,
rounded crown with an edge, the rods showing over and through it and a few leaves turning their
silver undersides; in winter the rods stand bare, brown at their foot, a muted yellow-olive along
them, with a few brighter tips.

Each picture is an object cell (96x160 at 32 px per tile, see trees.py) with its foot at the
bottom centre, in palette colour names. generate.py calls `willow_row` and draws the winter looks
with `bare_willow`.
"""

import math
import random

import forms
import numpy as np
from trees import BOTTOM, CENTRE, HEIGHT, WIDTH, cell, foliage, ground_shadow, tree_trunk

WILLOW_SEEDS = (321, 322, 323)
# Brown, deeply furrowed bark, lit to dark; the darkest also outlines it.
BARK = ("sand", "mud", "mud_dark", "soil_dark")
# The furrows in it.
FURROW = "soil_dark"
# The knobs of the head, where the rods were cut again and again: warmer than the trunk, so the
# head reads as wood and not as a stone.
KNOBS = ("mud_dark", "mud", "mud", "sand")
# The narrow grey-green leaves, lit to dark, the crown's edge, and their silvery undersides,
# which the wind shows. seasons.py turns them for spring and autumn.
LEAVES = ("dry_light", "dry", "olive", "green_dark")
LEAF_EDGE = "green_deep"
SILVER = "frost"
# The rods: brown at their foot, yellow-olive along them, a few brighter tips.
RODS = ("umber", "reed", "straw")
# The top of the trunk; the head sits on it and the rods spring from the head.
HEAD_Y = 124
TRUNK_WIDTH = 20


def _trunk_and_head(canvas, rng):
    """The gnarled trunk and the knobbly head it was cut back to. Returns the points on top of the
    head the rods spring from."""
    ground_shadow(canvas, 26, rows=7)
    tree_trunk(canvas, rng, HEAD_Y, TRUNK_WIDTH, BARK)
    left = CENTRE - TRUNK_WIDTH // 2
    # Deep furrows that wander up the trunk, lit on their left edge, and a dark hollow where a
    # limb rotted out.
    for start in range(left + 3, left + TRUNK_WIDTH - 2, 4):
        x = start + rng.uniform(-0.5, 0.5)
        for y in range(HEAD_Y + rng.randint(2, 6), BOTTOM - rng.randint(2, 5)):
            x += rng.choice((-0.4, 0, 0, 0, 0.4)) if left + 2 < x < left + TRUNK_WIDTH - 3 else 0
            canvas[y][round(x)] = FURROW
            if x < CENTRE and canvas[y][round(x) - 1] == BARK[1]:
                canvas[y][round(x) - 1] = BARK[0]
    hollow = forms.ellipse(WIDTH, HEIGHT, CENTRE + rng.uniform(-3, 4), HEAD_Y + rng.uniform(12, 18), 2.5, 4)
    forms.paint(canvas, hollow, "ink")
    forms.paint(canvas, forms.edge(hollow) & np.roll(hollow, 1, axis=0) & ~np.roll(hollow, -1, axis=0), BARK[2])
    # The trunk flares out into the head over its top rows.
    for y in range(HEAD_Y, HEAD_Y + 10):
        flare = (HEAD_Y + 10 - y) // 2
        for x in range(left - flare, left + TRUNK_WIDTH + flare):
            if canvas[y][x] is None:
                canvas[y][x] = BARK[1] if x < CENTRE else BARK[2]
    # The head: a cluster of knobs where the rods were cut back again and again, each lit on its
    # upper left; the lower ones are drawn first, so those above overlap them.
    head = np.zeros((HEIGHT, WIDTH), bool)
    knobs = []
    for _ in range(13):
        angle = rng.uniform(0, 2 * math.pi)
        distance = math.sqrt(rng.uniform(0, 1))
        knobs.append((CENTRE + math.cos(angle) * 12 * distance, HEAD_Y - 2 + math.sin(angle) * 5 * distance, rng.uniform(3.5, 5.5)))
    for cx, cy, radius in sorted(knobs, key=lambda knob: -knob[1]):
        knob = forms.ellipse(WIDTH, HEIGHT, cx, cy, radius, radius * 0.85)
        forms.shade(canvas, knob, KNOBS, radius=2)
        forms.paint(canvas, forms.edge(knob) & ~head & forms.ellipse(WIDTH, HEIGHT, cx + 1, cy + 1.5, radius, radius * 0.85), KNOBS[0])
        head |= knob
    forms.paint(canvas, forms.edge(head), BARK[3])
    tops = {}
    for y, x in zip(*np.nonzero(head)):
        tops[x] = min(y, tops.get(x, y))
    return sorted(tops.items())


def _rods(rng, feet, count):
    """The rods springing from the top of the head, as lists of (x, y) from their foot up:
    straight, 1 px wide, fanning upwards and a little outwards, of mixed lengths."""
    rods = []
    for index in range(count):
        spread = (index + rng.uniform(0, 1)) / count * 2 - 1
        foot_x, foot_y = feet[min(len(feet) - 1, max(0, round((spread + 1) / 2 * (len(feet) - 1))))]
        angle = spread * math.radians(40) + rng.uniform(-0.08, 0.08)
        length = rng.uniform(48, 78) * (1 - 0.3 * abs(spread))
        rod = []
        for step in range(1, round(length)):
            point = (round(foot_x + math.sin(angle) * step), round(foot_y - math.cos(angle) * step))
            if not 0 <= point[0] < WIDTH or point[1] < 1:
                break
            if not rod or point != rod[-1]:
                rod.append(point)
        rods.append(rod)
    return rods


def _rod_count(seed):
    return 60 + seed % 3 * 8


def bare_willow(seed):
    """The willow in winter: the same trunk and head, the rods bare, dark at their foot and up to
    the middle, so the crown does not fade into pale ground."""
    rng = random.Random(seed)
    canvas = cell()
    feet = _trunk_and_head(canvas, rng)
    for rod in _rods(rng, feet, _rod_count(seed)):
        bright = rng.random() < 0.25
        for step, (x, y) in enumerate(rod):
            if step < len(rod) * 0.5:
                colour = RODS[0]
            elif bright and step >= len(rod) - 6:
                colour = RODS[2]
            else:
                colour = RODS[1]
            if canvas[y][x] is None or canvas[y][x] in RODS:
                canvas[y][x] = colour
    return canvas


def willow(seed):
    """The willow in leaf: the same rods, their upper parts in a dense, rounded crown of narrow
    leaves with a dark edge and a shaded underside, the rods showing below it and over it."""
    rng = random.Random(seed)
    canvas = cell()
    feet = _trunk_and_head(canvas, rng)
    rods = _rods(rng, feet, _rod_count(seed))
    # The crown: bunches of leaves along the upper part of every rod, one dense mass.
    clumps = []
    for rod in rods:
        for share in (0.32, 0.48, 0.64, 0.8):
            if len(rod) > 8 and rng.random() < 0.6:
                x, y = rod[min(len(rod) - 1, round(len(rod) * share))]
                clumps.append((x, y, rng.uniform(4.5, 7)))
    crown = cell()
    foliage(crown, rng, clumps, LEAVES, LEAF_EDGE, leaf_size=2.4, holes=6)
    # The rods below the crown and through it: brown at their foot, the shaded right ones darker.
    for index, rod in enumerate(rods):
        for step, (x, y) in enumerate(rod[: len(rod) // 2]):
            if canvas[y][x] is None and (index % 2 or step < 4):
                canvas[y][x] = RODS[0] if x > CENTRE or step < 6 else RODS[1]
    for y, row in enumerate(crown):
        for x, colour in enumerate(row):
            if colour is not None and canvas[y][x] not in KNOBS:
                canvas[y][x] = colour
    # Narrow leaves over the crown, slanting off the rods: lit or shaded as the crown is where they
    # sit, a few turned to show their silver side.
    for rod in rods:
        for step in range(len(rod) // 2, len(rod), 3):
            x, y = rod[step]
            under = crown[y][x]
            if under is None or under == LEAF_EDGE:
                continue
            index = LEAVES.index(under)
            shade = LEAVES[max(0, index - 1)] if rng.random() < 0.6 else under
            if rng.random() < 0.06 and index < 2:
                shade = SILVER
            side = 1 if step % 2 else -1
            for k in range(1, 3):
                lx, ly = x + side * k, y + (k - 1)
                if 0 <= lx < WIDTH and crown[ly][lx] not in (None, LEAF_EDGE):
                    canvas[ly][lx] = shade
    # Every third rod shows over the leaves, a dark line up to its tip.
    for rod in rods[::3]:
        for x, y in rod[round(len(rod) * 0.4) : round(len(rod) * 0.8)]:
            if crown[y][x] not in (None, LEAF_EDGE) and rng.random() < 0.8:
                canvas[y][x] = LEAVES[2] if crown[y][x] in LEAVES[:2] else LEAVES[3]
    # The tips of the longest rods stand out over the crown, bare and thin.
    for rod in rods:
        for x, y in rod[round(len(rod) * 0.8) :]:
            if canvas[y][x] is None and y + 1 < HEIGHT and crown[y + 1][x] is not None:
                canvas[y][x] = LEAVES[2]
            elif canvas[y][x] is None and rng.random() < 0.7:
                canvas[y][x] = LEAVES[1]
    return canvas


def willow_row():
    """The atlas row of the willow: three trees."""
    return [willow(seed) for seed in WILLOW_SEEDS]
