"""The buildings (assets/buildings/<id>.png, and <id>_lit.png with lit windows for the night).

The North German and Danish countryside, seen from the front in 3/4 view: a huge, thick reed
thatch, weathered grey-brown with moss, hipped at both ends with soft rounded eaves and eyebrow
dormers swelling out of it; lime-washed or brick walls on a fieldstone base; green or teal doors
and shutters, white window frames. Light comes from the top left.

A picture is as wide as the footprint (16 px per tile) and its bottom edge is the footprint's
bottom edge; the roof rises above it (see data/buildings.cfg, which also has the window light
positions: a pane of glass near the middle of each window here). Each drawing function returns
the picture (rows of palette colour names, as in generate.py) and the set of (x, y) pixels that
snow covers, which seasons.house uses for the snow look.
"""

import math
import random

TILE = 16

# The thatch, lit to dark: weathered grey-brown reed, darkest in the shadow under the eaves.
THATCH = ("sand", "bare_light", "bare", "mud_dark", "soil_dark")
MOSS = ("dry", "olive", "green_dark")
# The lime-washed walls: lit, and shaded at the right corner.
LIME = ("lime", "sand_light")
# Fieldstones: lit on top, and their body.
FIELDSTONE = ("stone_light", "stone")
OAK = ("soil", "soil_dark")
GLASS = ("water_light", "water", "water_deep")
LIT_GLASS = ("cream", "gold", "flame")
# What the wall colours turn into in the shadow under the eaves.
SHADED = {
    "lime": "sand_light", "cream": "sand_light", "sand_light": "sand", "straw": "ochre_dark", "sand": "mud",
    "rust": "rust_dark", "red_light": "rust", "rust_dark": "russet_deep",
    "soil_light": "soil_mid", "soil_mid": "soil", "soil": "soil_dark",
    "snow_light": "snow", "stone_light": "stone", "stone": "stone_dark",
}


def canvas(width, height):
    return [[None] * width for _ in range(height)]


def rect(picture, x0, y0, x1, y1, colour):
    """Fills x0..x1 and y0..y1, both ends included, clipped to the picture."""
    for y in range(max(0, y0), min(len(picture) - 1, y1) + 1):
        for x in range(max(0, x0), min(len(picture[0]) - 1, x1) + 1):
            picture[y][x] = colour


def thatch_roof(picture, snowy, rng, left, right, ridge_y, eaves_y, inset, swells=(), moss=5):
    """A hipped thatch roof over the columns left..right, from the ridge at `ridge_y` down to the
    eaves at `eaves_y`. The ridge is `inset` px shorter than the eaves on each side, and the hips
    round off into it, so the roof bulges like a thick, heavy thatch. The hips are their own
    faces, the left one lit, the right one in shade. The eaves are a thick rolled edge, curling up
    at the corners and rising in a smooth wave over each swell (cx, half width, rise), e.g. over
    a door. The reed shows as short vertical strokes and long darker streaks of weathering; moss
    grows in a few patches low on the front. Returns the eaves row of each column."""
    height = eaves_y - ridge_y
    width = len(picture[0])
    # Per column: where its strokes of reed start, and whether a streak of weathering runs down it.
    strokes = [rng.randrange(7) for _ in range(width)]
    streaks = [rng.random() < 0.12 for _ in range(width)]
    patches = [
        (rng.uniform(left + 10, right - 10), rng.uniform(ridge_y + height * 0.55, eaves_y - 6), rng.uniform(2.5, 4))
        for _ in range(moss)
    ]
    eaves = {}
    for x in range(left, right + 1):
        line = eaves_y
        for cx, half_width, rise in swells:
            if abs(x - cx) < half_width:
                line -= round(rise * math.cos((x - cx) / half_width * math.pi / 2) ** 2)
        corner = min(x - left, right - x)
        if corner < 6:
            line -= round(6 - math.sqrt(36 - (6 - corner) ** 2))
        eaves[x] = line
    for y in range(ridge_y, eaves_y + 1):
        t = (y - ridge_y) / height
        # In from the eaves by `inset` at the ridge, falling away fast at first: a rounded hip.
        reach = inset * (1 - t) ** 2.2
        for x in range(left, right + 1):
            if x < left + reach or x > right - reach or y > eaves[x]:
                continue
            # The hip lines run from the ridge's ends to a little inside the eaves' corners.
            hip = inset * (1 - t) ** 1.4 + 7 * t
            if x < left + hip:
                light = 0.18 + 0.2 * t
            elif x > right - hip:
                light = 0.62 + 0.15 * t
            else:
                light = 0.2 + 0.32 * t + 0.12 * (x - left) / (right - left)
            # The rolled eaves: a lit lip over a dark underside.
            from_eaves = eaves[x] - y
            if from_eaves <= 5:
                light = (0.95, 0.8, 0.62, 0.45, 0.3, 0.32)[from_eaves] + (0.12 if x > right - hip else 0)
            elif (y + strokes[x]) % 7 < 2 and x % 2:
                light -= 0.17
            elif (y + strokes[x] + 3) % 7 < 2 and not x % 2:
                light += 0.17
            if streaks[x] and from_eaves > 5:
                light += 0.18
            # Ragged edges between the shades, as the reed ends lie unevenly.
            light += (strokes[x] - 3) * 0.02
            colour = THATCH[min(len(THATCH) - 1, max(0, int(light * len(THATCH))))]
            for mx, my, radius in patches:
                distance = math.hypot(x - mx, (y - my) * 1.5)
                if from_eaves > 4 and colour in THATCH[1:4] and (distance < radius - 1 or (distance < radius and (x + y) % 2)):
                    colour = MOSS[THATCH.index(colour) - 1]
            picture[y][x] = colour
            snowy.add((x, y))
    return eaves


def turf_ridge(picture, snowy, left, right, y):
    """A ridge capped with turf: a rounded green band along the top of the roof."""
    for x in range(left, right + 1):
        end = min(x - left, right - x)
        top = y - 2 + max(0, 3 - end)
        for row in range(top, y + 4):
            colour = ("dry_light", "dry", "olive", "olive", "green_dark", "green_deep")[row - y + 2]
            picture[row][x] = colour
            snowy.add((x, row))


def crossed_ridge(picture, snowy, left, right, y):
    """A ridge held down by crossed wooden sticks: a dark cap with a row of X shapes on it."""
    rect(picture, left, y, right, y + 2, "umber")
    rect(picture, left, y + 3, right, y + 3, "soil_dark")
    for x in range(left, right + 1):
        snowy.update(((x, y), (x, y + 1)))
    for x in range(left + 1, right - 3, 5):
        for step in range(4):
            picture[y - 2 + step][x + step] = "soil_light" if step < 2 else "soil_mid"
            picture[y - 2 + step][x + 3 - step] = "soil_mid"


def chimney(picture, snowy, left, top, bottom, colours):
    """A square chimney from `top` down into the roof at `bottom`, lit on the left, with a cap."""
    light, middle, dark = colours
    rect(picture, left, top, left + 5, bottom, middle)
    rect(picture, left, top, left + 1, bottom, light)
    rect(picture, left + 5, top, left + 5, bottom, dark)
    rect(picture, left - 1, top, left + 6, top + 1, light)
    rect(picture, left - 1, top + 1, left + 6, top + 1, dark)
    rect(picture, left + 1, top - 1, left + 4, top - 1, "soil_dark")
    for x in range(left - 1, left + 7):
        snowy.add((x, top))


def eyebrow(picture, snowy, cx, bottom, width, is_lit):
    """An eyebrow dormer: the thatch swells up in a smooth wave over a half-round window in the
    roof. The swell is lit along its crest and casts a dark line over the window."""
    half = width // 2
    arch = half * 2 // 3
    for x in range(cx - half - 6, cx + half + 6):
        offset = min(1.0, abs(x + 0.5 - cx) / (half + 6))
        crest = bottom - arch - 2 - round(4 * math.cos(offset * math.pi / 2) ** 2)
        for row, colour in enumerate((THATCH[1], THATCH[0], THATCH[0], THATCH[1], THATCH[3])):
            y = crest + row
            if (x, y) in snowy and y < bottom:
                picture[y][x] = colour if x < cx + half else THATCH[min(4, THATCH.index(colour) + 1)]
    # The window: flat at the bottom, arched on top, in a white frame with glazing bars round
    # small panes.
    for y in range(bottom - arch - 1, bottom + 1):
        for x in range(cx - half, cx + half):
            distance = math.hypot(x + 0.5 - cx, (bottom - y) * half / (arch + 1))
            if distance > half:
                continue
            snowy.discard((x, y))
            if distance > half - 1.3 or y == bottom or (x - cx) % 3 == 1 or (bottom - y) % 3 == 2:
                picture[y][x] = "snow_light"
            else:
                picture[y][x] = glass(x, y, cx, bottom - 2, is_lit)
    for x in range(cx - half, cx + half):
        for y in range(bottom - arch - 3, bottom):
            if (x, y) in snowy and picture[y + 1][x] == "snow_light" and math.hypot(x + 0.5 - cx, (bottom - y - 1) * half / (arch + 1)) > half - 1.3:
                picture[y][x] = THATCH[4]
    rect(picture, cx - half - 1, bottom + 1, cx + half, bottom + 1, THATCH[4])


def glass(x, y, cx, cy, is_lit):
    """The colour of window glass at (x, y) in a window whose middle is (cx, cy): dark glass with
    a glint at the top left, or the warm light from inside, brightest at the top left."""
    if is_lit:
        return LIT_GLASS[0] if x < cx and y < cy else LIT_GLASS[1] if x < cx or y < cy else LIT_GLASS[2]
    return GLASS[0] if x < cx and y < cy - 1 else GLASS[1] if y < cy else GLASS[2]


def window(picture, left, top, width, height, is_lit, frame="snow_light", shutters=None):
    """A window in a `frame`, white by default, with a sill; with `shutters` (light, dark) a
    shutter on each side. Small panes of 2x2 px in white glazing bars, as glass came in small
    pieces: a window 10 px square has 3x3 panes. Width and height are 3 times the panes + 1."""
    assert width % 3 == 1 and height % 3 == 1, f"window {width}x{height} does not divide into panes"
    rect(picture, left - 1, top - 1, left + width, top + height, "soil_dark")
    rect(picture, left, top, left + width - 1, top + height - 1, frame)
    cx, cy = left + width // 2, top + height // 2
    for y in range(top + 1, top + height - 1):
        for x in range(left + 1, left + width - 1):
            if (x - left) % 3 == 0 or (y - top) % 3 == 0:
                picture[y][x] = "snow_light"
            elif is_lit:
                # Each lit pane glows in one colour, from the light at its top left pixel.
                picture[y][x] = glass(x - (x - left - 1) % 3, y - (y - top - 1) % 3, cx, cy, is_lit)
            else:
                picture[y][x] = glass(x, y, cx, cy, is_lit)
    rect(picture, left - 2, top + height, left + width + 1, top + height, "snow_light")
    rect(picture, left - 1, top + height + 1, left + width, top + height + 1, "stone")
    if shutters:
        light, dark = shutters
        for x0 in (left - 5, left + width + 1):
            rect(picture, x0, top - 1, x0 + 3, top + height, light)
            rect(picture, x0 + 3, top - 1, x0 + 3, top + height, dark)
            rect(picture, x0, top + height // 2, x0 + 3, top + height // 2, dark)
            rect(picture, x0 - 1, top - 1, x0 - 1, top + height, "soil_dark")
            rect(picture, x0 + 4, top - 1, x0 + 4, top + height, "soil_dark")


def plank_door(picture, left, top, bottom, width, colours, arched=False):
    """A door of upright planks, lit on the left, a handle on the right, under a white frame; an
    arched one has a round top. Below it a step of stone."""
    light, middle, dark = colours
    half = width / 2
    for y in range(top - 1, bottom + 1):
        for x in range(left - 1, left + width + 1):
            # How far out of the round top of an arched door; 0 below it, and on a square door.
            arch = 0.0
            if arched and y < top + half:
                arch = math.hypot(x + 0.5 - left - half, y + 0.5 - top - half) - half
            if arch > 1:
                continue
            if arch > 0 or x in (left - 1, left + width) or y == top - 1:
                picture[y][x] = "snow_light"
            else:
                picture[y][x] = dark if (x - left) % 4 == 3 else light if x - left < 2 else middle
    rect(picture, left + width - 4, (top + bottom) // 2 + 2, left + width - 3, (top + bottom) // 2 + 2, "gold")
    rect(picture, left - 2, bottom + 1, left + width + 1, bottom + 2, "stone_light")
    rect(picture, left - 2, bottom + 2, left + width + 1, bottom + 2, "stone")


def fieldstone_base(picture, rng, left, right, top, bottom):
    """A base of rounded fieldstones of mixed sizes in dark joints, each lit on its top left."""
    rect(picture, left, top, right, bottom, "mud_dark")
    y = top
    row = 0
    while y <= bottom:
        stone_height = min(rng.randint(3, 4), bottom - y + 1)
        x = left + (row % 2) * 2 - 1
        while x <= right:
            stone_width = rng.randint(4, 7)
            for sy in range(y, y + stone_height - 1):
                for sx in range(max(left, x), min(right, x + stone_width - 2) + 1):
                    corner = sx in (x, x + stone_width - 2) and sy in (y, y + stone_height - 2)
                    if corner:
                        continue
                    picture[sy][sx] = FIELDSTONE[0] if sy == y and sx < x + stone_width - 3 else FIELDSTONE[1]
            x += stone_width
        y += stone_height
        row += 1


def eaves_shadow(picture, eaves, wall_left, wall_right):
    """Darkens the wall in the shadow under the eaves: two steps right under them, one below."""
    for x in range(wall_left, wall_right + 1):
        for y, steps in ((eaves[x] + 1, 2), (eaves[x] + 2, 1), (eaves[x] + 3, 1)):
            for _ in range(steps):
                if picture[y][x] in SHADED:
                    picture[y][x] = SHADED[picture[y][x]]


def ground_shadow(picture):
    """A shadow on the ground along the bottom of the building."""
    width, height = len(picture[0]), len(picture)
    for x in range(1, width - 1):
        if picture[height - 1][x] is None:
            picture[height - 1][x] = "shadow"


def outline(picture, colour):
    """Gives the picture's border (pixels next to clear ones or the picture's sides and top)
    `colour`; the bottom row stands on the ground and keeps its colours."""
    height, width = len(picture), len(picture[0])
    border = []
    for y in range(height - 1):
        for x in range(width):
            if picture[y][x] is None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < width and 0 <= ny < height) or picture[ny][nx] is None:
                    border.append((x, y))
                    break
    for x, y in border:
        picture[y][x] = colour


def kate(is_lit):
    """A small cottage on 5x3 tiles: white lime walls, teal door and shutters, a big eyebrow
    dormer in the middle of the roof and a small white chimney."""
    rng = random.Random(381)
    width, height = 5 * TILE, 96
    picture = canvas(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 3, width - 4, 60, 89
    rect(picture, wall_left, wall_top, wall_right, base_top - 1, LIME[0])
    rect(picture, wall_right - 1, wall_top, wall_right, base_top - 1, LIME[1])
    fieldstone_base(picture, rng, wall_left, wall_right, base_top, height - 2)
    teal = ("paint_teal", "paint_teal", "water")
    for left in (12, 57):
        window(picture, left, 70, 10, 10, is_lit, shutters=("paint_teal", "water"))
    plank_door(picture, 34, 68, height - 4, 12, teal)
    eaves = thatch_roof(picture, snowy, rng, 0, width - 1, 12, 63, 22)
    turf_ridge(picture, snowy, 22, width - 23, 12)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    eyebrow(picture, snowy, 40, 46, 16, is_lit)
    chimney(picture, snowy, 52, 3, 14, ("snow_light", "lime", "sand_light"))
    outline(picture, THATCH[4])
    ground_shadow(picture)
    return picture, snowy


def brick_wall(picture, rng, left, right, top, bottom, bricks, mortar):
    """Courses of bricks 5 px long and 2 high in `mortar` joints, each course offset from the one
    below; each brick one of the colours `bricks`."""
    rect(picture, left, top, right, bottom, mortar)
    for row, y in enumerate(range(bottom - 1, top - 2, -3)):
        for x in range(left - (row % 2) * 3, right + 1, 6):
            colour = rng.choice(bricks)
            rect(picture, max(left, x), max(top, y), min(right, x + 4), y + 1, colour)


def climbing_rose(picture, rng, x, top, bottom):
    """A climbing rose up the wall: a column of dark leaves with red flowers."""
    for y in range(top, bottom + 1):
        reach = 1 if y < top + 3 else 2
        for dx in range(-reach + (y % 2), reach + 1):
            picture[y][x + dx] = "green_dark" if (dx + y) % 3 else "green"
    for _ in range((bottom - top) // 3):
        fx, fy = x + rng.randint(-1, 1), rng.randint(top + 1, bottom - 1)
        picture[fy][fx] = "red_light"
        picture[fy + 1][fx] = "ember"


def longhouse(is_lit):
    """A long, low North German farmhouse on 7x3 tiles: buff brick on a granite base, a huge
    thatch with crossed sticks on its ridge, two brick chimneys and two eyebrow dormers. The big
    arched barn door of the hall house is in the middle, the thatch sweeping up over it; white
    windows in dark green frames to either side, roses climbing the wall."""
    rng = random.Random(382)
    width, height = 7 * TILE, 96
    picture = canvas(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 3, width - 4, 56, 88
    brick_wall(picture, rng, wall_left, wall_right, wall_top, base_top - 1, ("sand_light", "sand_light", "straw"), "sand")
    rect(picture, wall_right - 1, wall_top, wall_right, base_top - 1, "sand")
    fieldstone_base(picture, rng, wall_left, wall_right, base_top, height - 2)
    for left in (8, 26, 76, 94):
        window(picture, left, 71, 10, 10, is_lit, frame="green_dark")
    climbing_rose(picture, rng, 41, 70, base_top - 1)
    climbing_rose(picture, rng, 70, 72, base_top - 1)
    plank_door(picture, 45, 62, height - 4, 22, ("green", "green_dark", "green_deep"), arched=True)
    rect(picture, 55, 70, 56, height - 4, "green_deep")
    eaves = thatch_roof(picture, snowy, rng, 0, width - 1, 14, 69, 30, swells=((56, 22, 11),), moss=8)
    crossed_ridge(picture, snowy, 30, width - 31, 14)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    for cx in (26, 86):
        eyebrow(picture, snowy, cx, 47, 14, is_lit)
    for left in (36, 70):
        chimney(picture, snowy, left, 5, 16, ("red_light", "rust", "rust_dark"))
    outline(picture, THATCH[4])
    ground_shadow(picture)
    return picture, snowy


def half_timbering(picture, left, right, top, bottom, posts, braces):
    """Dark oak beams: a sill and a head beam, upright posts at `posts`, and a diagonal brace in
    each panel of `braces` (left edge, width, and +1 to rise to the right or -1 to the left)."""
    rect(picture, left, top, right, top + 1, OAK[0])
    rect(picture, left, bottom - 1, right, bottom, OAK[0])
    rect(picture, left, top + 1, right, top + 1, OAK[1])
    for x in posts:
        rect(picture, x, top, x + 1, bottom, OAK[0])
        rect(picture, x + 1, top, x + 1, bottom, OAK[1])
    for x, panel_width, direction in braces:
        rise = bottom - top - 3
        for step in range(rise):
            offset = step * panel_width // rise
            bx = x + offset if direction > 0 else x + panel_width - 1 - offset
            y = bottom - 2 - step
            picture[y][bx] = OAK[0]
            picture[y][bx + 1] = OAK[1]


def barn(is_lit):
    """A barn on 6x3 tiles: half-timbered with red brick in dark oak beams, big plank double
    doors with braces on the third tile, a thatch roof with a turf ridge, no windows. `is_lit`
    changes nothing: a barn has no windows to light."""
    rng = random.Random(383)
    width, height = 6 * TILE, 96
    picture = canvas(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 3, width - 4, 58, 89
    brick_wall(picture, rng, wall_left, wall_right, wall_top, base_top - 1, ("rust", "rust", "red_light", "rust_dark"), "sand")
    half_timbering(picture, wall_left, wall_right, wall_top, base_top - 1, (3, 22, 60, 76, wall_right - 1), ((5, 17, -1), (62, 14, 1), (78, 13, 1)))
    fieldstone_base(picture, rng, wall_left, wall_right, base_top, height - 2)
    # The doors: two leaves of planks with a Z of braces each and iron hinges, in an oak frame.
    door_left, door_right, door_top = 26, 53, 64
    rect(picture, door_left - 2, door_top - 2, door_right + 2, height - 3, OAK[1])
    leaf_width = (door_right - door_left + 1) // 2
    for leaf_left in (door_left, door_left + leaf_width):
        leaf_right = leaf_left + leaf_width - 1
        for x in range(leaf_left, leaf_right + 1):
            colour = "soil_dark" if (x - leaf_left) % 4 == 3 else "soil_light" if x == leaf_left else "soil_mid"
            rect(picture, x, door_top, x, height - 4, colour)
        bars = (door_top + 2, height - 7)
        for y in bars:
            rect(picture, leaf_left, y, leaf_right, y, "soil_light")
            rect(picture, leaf_left, y + 1, leaf_right, y + 1, "soil")
            rect(picture, leaf_left + 1, y, leaf_left + 3, y, "stone_dark")
        span = bars[1] - bars[0] - 2
        for step in range(span):
            picture[bars[1] - 1 - step][leaf_left + step * (leaf_width - 1) // span] = "soil_light"
    rect(picture, door_left - 2, height - 3, door_right + 2, height - 2, "stone")
    eaves = thatch_roof(picture, snowy, rng, 0, width - 1, 13, 62, 26, swells=((40, 20, 5),))
    turf_ridge(picture, snowy, 26, width - 27, 13)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    outline(picture, THATCH[4])
    ground_shadow(picture)
    return picture, snowy


def shack(is_lit):
    """A small plank hut on 3x2 tiles: a roof of weathered boards, a low door on the middle tile
    and a small window with a shutter on the right."""
    rng = random.Random(384)
    width, height = 3 * TILE, 64
    picture = canvas(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, wall_bottom = 2, width - 3, 28, height - 3
    for x in range(wall_left, wall_right + 1):
        board = (x - wall_left) % 4
        colour = "soil" if board == 3 else "soil_light" if board == 0 else "soil_mid"
        rect(picture, x, wall_top, x, wall_bottom, colour)
    for x in (wall_left, wall_right - 1):
        rect(picture, x, wall_top, x + 1, wall_bottom, OAK[0])
    rect(picture, wall_left, wall_bottom - 2, wall_right, wall_bottom, "stone")
    rect(picture, wall_left, wall_bottom - 2, wall_right, wall_bottom - 2, "stone_light")
    window(picture, 35, 34, 7, 10, is_lit, frame="soil_light")
    rect(picture, 31, 33, 33, 44, "soil_mid")
    rect(picture, 33, 33, 33, 44, "soil")
    # The door: planks under a lintel, a latch on the right.
    rect(picture, 17, 36, 30, wall_bottom, OAK[1])
    for x in range(18, 30):
        rect(picture, x, 38, x, wall_bottom, "soil" if (x - 18) % 4 == 3 else "soil_mid")
    rect(picture, 18, 38, 29, 38, "soil_light")
    rect(picture, 18, 50, 29, 50, "soil_light")
    rect(picture, 27, 46, 28, 46, "stone_light")
    rect(picture, 16, wall_bottom + 1, 31, wall_bottom + 1, "stone")
    # The roof: courses of overlapping boards, lit at their top edge, the joints staggered.
    roof_top, roof_bottom = 9, 31
    for y in range(roof_top, roof_bottom + 1):
        inset = max(0, 3 - (y - roof_top))
        course = (roof_bottom - y) // 4
        in_course = (roof_bottom - y) % 4
        for x in range(inset, width - inset):
            colour = ("soil_dark", "mud_dark", "bare", "bare_light")[in_course]
            if in_course and (x + course * 5) % 9 == 0:
                colour = "mud_dark"
            if x > width - 10 and colour in ("bare_light", "bare"):
                colour = "bare" if colour == "bare_light" else "mud_dark"
            picture[y][x] = colour
            snowy.add((x, y))
    for _ in range(3):
        mx, my = rng.randint(6, width - 8), rng.randint(roof_top + 6, roof_bottom - 4)
        rect(picture, mx, my, mx + 2, my, "olive")
        picture[my - 1][mx + 1] = "dry"
    eaves_shadow(picture, {x: roof_bottom for x in range(width)}, wall_left, wall_right)
    outline(picture, THATCH[4])
    ground_shadow(picture)
    return picture, snowy


# How to draw each building (is_lit to the picture and the pixels snow covers), by its id in
# data/buildings.cfg.
PICTURES = {"shack": shack, "kate": kate, "longhouse": longhouse, "barn": barn}
