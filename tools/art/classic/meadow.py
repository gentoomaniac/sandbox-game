"""The tall grass of meadow.py as it was drawn for the classic 16 px plants (commit e303759), its
part of the module unchanged.
"""

import random

from canvas import OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, blank
from trees import dense_foot, ground_shadow

TALL_GRASS_SEEDS = (211, 212, 213)
# The lower part of a blade, as a fraction of its height, that is in the dark shades.
SHADED = 0.35


def tall_grass(seed, is_mown=False):
    """A clump of tall meadow grass about 16 px wide and 18 high: arching blades in a yellower,
    lighter green than the grass on the ground, some with a seed head, lit from the left. Or the
    stubble that is left once it is mown."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 9)
    if is_mown:
        for x in range(OBJECT_CENTRE - 7, OBJECT_CENTRE + 7):
            if rng.random() < 0.25:
                continue
            height = rng.randint(2, 4)
            for step in range(height):
                canvas[OBJECT_BOTTOM - step][x] = "olive" if step == 0 else "dry"
            canvas[OBJECT_BOTTOM - height + 1][x] = "straw" if x % 2 else "dry_light"
        # A few cut blades left lying.
        for _ in range(3):
            x = rng.randint(OBJECT_CENTRE - 7, OBJECT_CENTRE + 3)
            for step in range(rng.randint(3, 5)):
                canvas[OBJECT_BOTTOM - rng.choice((0, 1))][x + step] = "dry_light"
        return canvas
    # The dense foot of the clump, in the two darkest greens, rimmed with the darkest one so
    # the clump stands out from the ground. The blades above it are loose and have no rim.
    dense_foot(
        canvas,
        [(OBJECT_BOTTOM - 1 - step, 7 - step // 2, "green_deep" if step < 2 else "green_dark") for step in range(5)],
    )
    # The back blades first, darker, then the front ones over them. Their lower third is in
    # shade, in the dark greens; the light shades are on top.
    for row, shade, lights in ((0, "green_deep", ("dry", "dry", "dry_light")), (1, "green_dark", ("dry_light", "green_bright", "green_bright"))):
        for _ in range(7):
            base = OBJECT_CENTRE + rng.uniform(-6, 6)
            height = rng.randint(11, 15) if row == 0 else rng.randint(9, 14)
            # Blades arch away from the middle of the clump.
            bend = (base - OBJECT_CENTRE) / 6 * rng.uniform(2, 4) + rng.uniform(-1, 1)
            for step in range(height):
                t = step / height
                x = round(base + bend * t * t)
                colour = shade if t < SHADED else lights[min(2, int((t - SHADED) / (1 - SHADED) * 3))]
                # Light from the left: the left half of the clump is a step lighter.
                if x < OBJECT_CENTRE - 2 and colour == "dry":
                    colour = "dry_light"
                canvas[OBJECT_BOTTOM - step][x] = colour
            tip = round(base + bend)
            if rng.random() < 0.45:
                for head in range(1, 4):
                    canvas[OBJECT_BOTTOM - height - head + 1][tip] = "straw" if head < 3 else "sand_light"
    return canvas


def tall_grass_row():
    """The atlas row of tall grass: three tufts, then the same three mown."""
    return [tall_grass(seed) for seed in TALL_GRASS_SEEDS] + [
        tall_grass(seed, is_mown=True) for seed in TALL_GRASS_SEEDS
    ]
