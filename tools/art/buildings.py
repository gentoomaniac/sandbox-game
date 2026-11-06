"""The buildings (assets/buildings/<id>.png, and <id>_lit.png with lit windows for the night).

The North German and Danish countryside, seen from the front in 3/4 view: a huge, thick reed
thatch, weathered grey-brown with moss, hipped at both ends with soft rounded eaves and eyebrow
dormers swelling out of it; lime-washed or brick walls on a fieldstone base; green or teal doors
and shutters, white window frames; the small hut in tarred boards under turf; and the hall house,
which shows its half-timbered gable and big barn door to the front, its roof running back up
the picture. Light comes from the top left.

A picture is as wide as the footprint (16 px per tile) and its bottom edge is the footprint's
bottom edge; the roof rises above it (see data/buildings.cfg, which also has the window light
positions: a pane of glass near the middle of each window here). Each drawing function returns
the picture (rows of palette colour names, as in canvas.py) and the set of (x, y) pixels that
snow covers, which seasons.house uses for the snow look.
"""

import math
import random

from canvas import TILE, blank, rect

# The thatch, lit to dark: weathered grey-brown reed, darkest in the shadow under the eaves.
THATCH = ("sand", "bare_light", "bare", "mud_dark", "soil_dark")
MOSS = ("dry", "olive", "green_dark")
# The grass of a turf roof, lit to dark, and where it has dried out.
TURF = ("green_bright", "green_light", "green", "green_dark", "green_deep")
DRY_TURF = ("dry_light", "dry", "olive", "green_dark", "green_deep")
# The height of a course of thatch, in px.
COURSE = 4
# The rolled eaves: how many rows they take up at the foot of the roof, and the radius in px of
# their upturn at each corner.
EAVES_ROWS = 6
EAVES_CORNER = 6
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


def thatch_course(rng, first, last):
    """The random make of one course of thatch along the positions first..last (columns of a
    roof seen from the eaves side, rows of one seen from its gable): how far its edge moves at
    each, in runs of a few, wandering by a pixel at a time so it waves instead of stepping like
    brick; whether its lit edge shows there; and how far a reed end hangs out there, at every
    second to fourth position."""
    shift, lit, reed = {}, {}, {}
    at, drop = first, 0
    while at <= last:
        run = rng.randint(6, 12)
        shift.update(dict.fromkeys(range(at, at + run), drop))
        drop = max(-1, min(1, drop + rng.choice((-1, 1))))
        at += run
    at = first
    while at <= last:
        run = 1 if rng.random() < 0.25 else rng.randint(3, 9)
        lit.update(dict.fromkeys(range(at, at + run), run > 1))
        at += run
    at = first + rng.randrange(3)
    while at <= last:
        reed[at] = rng.choice((1, 1, 2, 2, 3))
        at += rng.choice((2, 2, 3, 3, 4))
    return shift, lit, reed


def thatch_roof(picture, snowy, rng, left, right, ridge_y, eaves_y, inset, swells=(), moss=5):
    """A hipped thatch roof over the columns left..right, from the ridge at `ridge_y` down to the
    eaves at `eaves_y`. The ridge is `inset` px shorter than the eaves on each side, and the hips
    run down from its ends with a little belly, so the roof reads as steep planes: the front
    slope, and a narrow hip face at each end, the left one lit and the right one in shade, with a
    lit hip line. The eaves are a thick rolled edge, curling up at the corners and rising in a
    smooth wave over each swell (cx, half width, rise), e.g. over a door. The reed lies in
    courses about 4 px high with ragged edges, each lit along its top in broken runs, with reed
    ends of mixed length hanging below that; the low courses bend up with the eaves over a
    swell. Weathering crowds the reed ends in a few patches, and moss grows in a few patches low
    on the front. Returns the eaves row of each column."""
    height = eaves_y - ridge_y
    # How far in from the eaves' corners the hip lines meet the eaves.
    hip_foot = round(inset * 0.5)
    lifts = {}
    eaves = {}
    for x in range(left, right + 1):
        lift = 0
        for cx, half_width, rise in swells:
            if abs(x - cx) < half_width:
                lift += rise * math.cos((x - cx) / half_width * math.pi / 2) ** 2
        lifts[x] = lift
        corner = min(x - left, right - x)
        upturn = 0
        if corner < EAVES_CORNER:
            upturn = round(EAVES_CORNER - math.sqrt(EAVES_CORNER**2 - (EAVES_CORNER - corner) ** 2))
        eaves[x] = eaves_y - round(lift) - upturn
    # The courses, counted up from the eaves, each varying along the columns.
    courses = [thatch_course(rng, left, right) for _ in range(height // COURSE + 2)]
    # Under the dark underside of the rolled eaves, a ragged edge: one row more in runs of columns.
    ragged = {}
    x = left
    while x <= right:
        deeper = rng.random() < 0.5
        run = rng.randint(2, 4)
        ragged.update(dict.fromkeys(range(x, x + run), deeper))
        x += run
    weathered = [
        (rng.uniform(left + inset, right - inset), rng.uniform(ridge_y + 8, eaves_y - 14), rng.uniform(3, 5))
        for _ in range(3)
    ]
    # Not over a swell, where the bending courses are busy enough.
    weathered = [
        (wx, wy, radius) for wx, wy, radius in weathered
        if all(abs(wx - cx) > half_width + radius for cx, half_width, _ in swells)
    ]

    # The patches are flattened ellipses (0.6 squashes them vertically), so they lie along the courses.
    def is_weathered(x, y):
        return any(math.hypot(x - wx, (y - wy) * 0.6) < radius for wx, wy, radius in weathered)

    patches = [
        (rng.uniform(left + 10, right - 10), rng.uniform(ridge_y + height * 0.55, eaves_y - 6), rng.uniform(2.5, 4))
        for _ in range(moss)
    ]
    for y in range(ridge_y, eaves_y + 1):
        t = (y - ridge_y) / height
        # The ends of the ridge are rounded off by a pixel or two.
        reach = inset * (1 - t) ** 1.5 + max(0, 2 - (y - ridge_y))
        hip = inset * (1 - t) ** 1.5 + hip_foot * t
        for x in range(left, right + 1):
            if x < left + reach or x > right - reach or y > eaves[x]:
                continue
            # The planes, as steps of THATCH: the lit hip, the front, the hip in shade.
            if x < left + hip:
                plane = 1
            elif x > right - hip:
                plane = 3
            else:
                plane = 2
            from_eaves = eaves[x] - y
            if from_eaves < EAVES_ROWS:
                # The rolled eaves, one shade per row up from the bottom: a lit lip over a dark
                # underside, darker on the shaded hip.
                shade = (4, 4, 4 if ragged[x] else 3, 2, 1, 1)[from_eaves]
                if plane == 3 and from_eaves > 2:
                    shade += 1
                if plane == 1 and from_eaves > 3:
                    shade -= 1
                colour = THATCH[min(4, shade)]
            else:
                # Up the slope from the eaves. Over a swell the lowest courses bend up with the
                # eaves and the bend dies out fast above them, so the courses don't stack into steps.
                along = round(eaves_y - y - lifts[x] * t**5) - EAVES_ROWS
                # The edges wave: the course a pixel would be in moves it up or down a little.
                along += courses[along // COURSE][0][x]
                course, row = divmod(max(0, along), COURSE)
                _, lit, reed = courses[course]
                # The lit hip line and the lit top edge of each course, then the reed ends below it.
                is_lit = (row == COURSE - 1 and lit[x]) or (plane == 1 and x + 1 >= left + hip)
                hangs = COURSE - 1 - row <= reed.get(x, 0) or (x % 2 and is_weathered(x, y))
                tone = plane - 1 if is_lit else plane
                is_stroke = not is_lit and row < COURSE - 1 and plane > 1 and hangs
                colour = THATCH[tone + 1 if is_stroke else tone]
                # Moss covers the reed ends, a little ragged at its edge.
                for mx, my, radius in patches:
                    distance = math.hypot(x - mx, (y - my) * 1.5)
                    if distance < radius - 1 or (distance < radius and (x + y) % 2):
                        colour = MOSS[max(0, tone - 1)]
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
    # The crossings sit on the cap and the tips stand out above it, so the row of X's shows
    # against the sky; a stick is lit where it lies on the cap.
    for x in range(left + 1, right - 4, 6):
        for step in range(5):
            colour = "soil_light" if y <= y - 3 + step <= y + 1 else "soil_mid"
            picture[y - 3 + step][x + step] = colour
            picture[y - 3 + step][x + 4 - step] = colour


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


def kate(is_lit, ridge_sticks=True):
    """A small cottage on 5x3 tiles: white lime walls, teal door and shutters, a big eyebrow
    dormer in the middle of the roof and a small white chimney. The ridge is held by crossed
    sticks, or with `ridge_sticks` off capped with turf as in the west."""
    rng = random.Random(381)
    width, height = 5 * TILE, 96
    picture = blank(width, height)
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
    if ridge_sticks:
        crossed_ridge(picture, snowy, 22, width - 23, 12)
    else:
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
    picture = blank(width, height)
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
    picture = blank(width, height)
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


def tarred_boards(picture, rng, left, right, top, bottom):
    """A wall of upright boards tarred near-black, a batten over each joint: its raised edge
    catching the light in the blue-grey sheen of the tar, with a dark line where it shades the
    board to its right. A few streaks of the sheen and of darker grain run down the boards."""
    for x in range(left, right + 1):
        board = (x - left) % 5
        colour = ("mud_dark", "soil_dark", "ink", "ink", "ink")[board]
        rect(picture, x, top, x, bottom, colour)
        if board < 2:
            continue
        y = top + rng.randrange(6)
        while y <= bottom:
            run = rng.randint(3, 7)
            if board == 2 and rng.random() < 0.5:
                rect(picture, x, y, x, min(bottom, y + run - 1), "stone_dark")
            elif board == 3 and rng.random() < 0.3:
                rect(picture, x, y, x, min(bottom, y + run - 1), "soil_dark")
            y += run + rng.randint(3, 8)


def ledged_door(picture, left, top, bottom, width, colours):
    """A low door of upright planks painted in `colours` (light, middle, dark), held by two
    ledges and a brace between them, in a dark frame, with an iron latch and a stone step."""
    light, middle, dark = colours
    rect(picture, left - 1, top - 1, left + width, bottom, "ink")
    for x in range(left, left + width):
        colour = dark if (x - left) % 4 == 3 else light if x == left else middle
        rect(picture, x, top, x, bottom, colour)
    ledges = (top + 2, bottom - 3)
    for y in ledges:
        rect(picture, left, y, left + width - 1, y, light)
        rect(picture, left, y + 1, left + width - 1, y + 1, dark)
    span = ledges[1] - ledges[0] - 2
    for step in range(span):
        picture[ledges[1] - 1 - step][left + 1 + step * (width - 3) // span] = light
    rect(picture, left + width - 3, (top + bottom) // 2, left + width - 2, (top + bottom) // 2, "stone_light")
    rect(picture, left - 2, bottom + 1, left + width + 1, bottom + 2, "stone_light")
    rect(picture, left - 2, bottom + 2, left + width + 1, bottom + 2, "stone")


def shack(is_lit):
    """A small hut on 3x2 tiles, a fisherman's or herdsman's: tarred boards with battens on a
    low fieldstone base, a low ox-blood door on the middle tile and a small white window with an
    ox-blood shutter on the right, under a turf roof."""
    rng = random.Random(384)
    width, height = 3 * TILE, 64
    picture = blank(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 2, width - 3, 28, 58
    tarred_boards(picture, rng, wall_left, wall_right, wall_top, base_top - 1)
    # The corner posts, the right one in shade, and the sill beam they stand on.
    rect(picture, wall_left, wall_top, wall_left + 1, base_top - 1, "stone_dark")
    rect(picture, wall_left + 1, wall_top, wall_left + 1, base_top - 1, "soil_dark")
    rect(picture, wall_right - 1, wall_top, wall_right, base_top - 1, "ink")
    rect(picture, wall_left, base_top - 2, wall_right, base_top - 2, "stone_dark")
    rect(picture, wall_left, base_top - 1, wall_right, base_top - 1, "ink")
    fieldstone_base(picture, rng, wall_left, wall_right, base_top, height - 2)
    window(picture, 35, 34, 7, 10, is_lit)
    rect(picture, 31, 33, 33, 44, "rust_dark")
    rect(picture, 33, 33, 33, 44, "russet_deep")
    rect(picture, 31, 38, 33, 38, "russet_deep")
    rect(picture, 30, 33, 30, 44, "ink")
    ledged_door(picture, 18, 38, height - 4, 11, ("rust", "rust_dark", "russet_deep"))
    eaves = turf_roof(picture, snowy, rng, 0, width - 1, 9, 28)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    outline(picture, THATCH[4])
    ground_shadow(picture)
    return picture, snowy


def turf_roof(picture, snowy, rng, left, right, ridge_y, eaves_y):
    """A turf roof over the columns left..right, the grass growing on birch bark: a slope of
    grass in clumps, lit on top and on the left and darker towards the eaves and the right end,
    with a few patches of dry grass and a few flowers; a ragged crest of tufts on the ridge, and
    at the eaves a thick rounded lip of turf with blades hanging over the pale edge of the bark.
    Returns the lowest roof row of each column."""
    height = eaves_y - ridge_y
    # The ridge, a pixel higher in a few short runs, rounded off at the ends.
    crest = {}
    x = left
    while x <= right:
        lift = rng.random() < 0.35
        for column in range(x, min(right, x + rng.randint(1, 3)) + 1):
            crest[column] = ridge_y + max(0, 3 - min(column - left, right - column)) - lift
        x = column + 1
    dry = [
        (rng.uniform(left + 6, right - 6), rng.uniform(ridge_y + 4, eaves_y - 6), rng.uniform(2.5, 4))
        for _ in range(2)
    ]
    # The gaps between the clumps, in shade; darker towards the eaves.
    for x in range(left, right + 1):
        for y in range(crest[x], eaves_y + 1):
            picture[y][x] = TURF[3] if (y - ridge_y) / height < 0.6 else TURF[4]
            snowy.add((x, y))
    # The clumps lie in rows 2 px apart, each a pixel up or down, so they overlap in scallops
    # rather than stripes: a rounded lit top over a body that is darker on its right, one step
    # darker on the lower slope and at the right end.
    for y in range(ridge_y, eaves_y - 2, 2):
        x = left + rng.randrange(-3, 1)
        while x <= right:
            clump = rng.randint(3, 6)
            top = y + rng.choice((-1, 0, 0, 1))
            is_dry = any(math.hypot((x - dx) / 1.5, top - dy) < radius for dx, dy, radius in dry)
            ramp = DRY_TURF if is_dry else TURF
            step = (top - ridge_y > height * 0.55) + (x > right - 6)
            for cx in range(max(left, x), min(right, x + clump - 1) + 1):
                is_edge = cx in (x, x + clump - 1)
                for cy in range(max(crest[cx], top + is_edge), top + 3):
                    lit = 0 if cy == top + is_edge and cx < x + clump - 1 else 1
                    if cx == x + clump - 1 or cy == top + 2:
                        lit = 2
                    picture[cy][cx] = ramp[min(len(ramp) - 1, lit + step)]
            # A flower on a few clumps: daisies, buttercups, a pink campion.
            flower = min(right, x + 1)
            if rng.random() < 0.08 and not is_dry and top >= crest[flower]:
                picture[top][flower] = rng.choice(("cream", "cream", "gold", "petal"))
            x += clump - rng.choice((0, 1))
    # The lip of the turf at the eaves, thicker in some runs: a dark line where it stands out
    # from the slope, then rounded and lit along its top. Under it the edge of the birch bark
    # sticks out, pale with a few black marks and shaded below, and blades of grass hang over it.
    eaves = {}
    x = left
    while x <= right:
        lip_top = eaves_y - rng.choice((2, 2, 3))
        for column in range(x, min(right, x + rng.randint(3, 6)) + 1):
            shade = column > right - 4
            picture[lip_top - 1][column] = TURF[4]
            for y in range(lip_top, eaves_y + 1):
                picture[y][column] = TURF[min(4, 1 + y - lip_top + shade)]
            is_mark = rng.random() < 0.15
            picture[eaves_y + 1][column] = "ink" if is_mark else "stone" if shade else "stone_light"
            picture[eaves_y + 2][column] = "stone_dark" if shade else "stone"
            snowy.update(((column, eaves_y + 1), (column, eaves_y + 2)))
            eaves[column] = eaves_y + 2
        x = column + 1
    x = left + rng.randrange(2)
    while x <= right:
        for y in range(eaves_y + 1, eaves_y + 1 + rng.choice((1, 2, 2, 3))):
            picture[y][x] = TURF[3] if y == eaves_y + 1 else TURF[4]
            eaves[x] = max(eaves[x], y)
        x += rng.choice((2, 2, 3, 4))
    return eaves


def gable_roof(picture, snowy, rng, left, right, eaves_y, foot_y, hip_half, depth, moss=6):
    """A half-hipped thatch roof seen from its gable end, over the columns left..right: the
    gable's rakes rise from the eaves at `eaves_y` on both sides to the foot of the little hip at
    `foot_y`, `hip_half` px either side of the middle, and the roof runs back `depth` px from
    them, up the picture. Its two long planes show from above, the left one lit and the right
    one in shade, with a turf ridge between them. As the eaves run back along the sides, the
    courses of reed run up the picture: about 4 px wide, lit along their edge towards the ridge
    in broken runs, the reed ends hanging out towards the eaves, and the eaves are a thick
    rolled edge along both sides. At the front the reed is cut along the rakes; the hip faces
    the front in level courses over a rolled foot. White bargeboards lie along the rakes and
    cross over the hip, their ends carved into horse heads looking out. Moss grows in a few
    patches low on the shaded plane. Returns the top row of the gable wall in each column,
    below the boards and the hip."""
    centre = (left + right) / 2
    slope = (eaves_y - foot_y) / ((right - left) / 2 - hip_half)

    def rake(x):
        return round(eaves_y - min(x - left, right - x) * slope)

    # The courses, counted in from the eaves, each varying along the rows.
    courses = [thatch_course(rng, 0, len(picture) - 1) for _ in range(round((right - left) / 2) // COURSE + 2)]
    patches = [
        (rng.uniform(right - 24, right - 8), rng.uniform(eaves_y - depth, eaves_y - 10), rng.uniform(2.5, 4))
        for _ in range(moss)
    ]
    face_top = {}
    for x in range(left, right + 1):
        from_eaves = min(x - left, right - x)
        plane = 1 if x < centre else 3
        bottom = rake(x)
        for y in range(bottom - depth, bottom + 1):
            if from_eaves < EAVES_ROWS:
                # The rolled eaves, one shade per column in from the side: a lit lip over a dark
                # underside, darker on the shaded plane.
                shade = (4, 4, 3, 2, 1, 1)[from_eaves]
                if plane == 3 and from_eaves > 2:
                    shade += 1
                colour = THATCH[min(4, shade)]
            elif y > bottom - 2:
                # The cut ends of the reed along the rake.
                colour = THATCH[3] if plane == 1 and (x + y) % 3 else THATCH[4]
            else:
                along = from_eaves - EAVES_ROWS
                along += courses[along // COURSE][0][y]
                course, row = divmod(max(0, along), COURSE)
                _, lit, reed = courses[course]
                is_lit = row == COURSE - 1 and lit[y]
                hangs = COURSE - 1 - row <= reed.get(y, 0)
                tone = plane - 1 if is_lit else plane
                colour = THATCH[tone + 1 if not is_lit and row < COURSE - 1 and hangs else tone]
                for mx, my, radius in patches:
                    distance = math.hypot((x - mx) * 1.5, y - my)
                    if distance < radius - 1 or (distance < radius and (x + y) % 2):
                        colour = MOSS[max(0, tone - 1)]
            picture[y][x] = colour
            snowy.add((x, y))
        face_top[x] = bottom + 1
    # The hip at the front, under the boards: level courses over a rolled foot, lit on the left.
    for x in range(left, right + 1):
        if abs(x - centre) >= hip_half:
            continue
        for y in range(rake(x) + 1, foot_y + 1):
            from_foot = foot_y - y
            if from_foot < 4:
                shade = (4, 3, 1, 0)[from_foot]
            else:
                row = (from_foot - 4) % COURSE
                shade = 1 if row == COURSE - 1 and x % 5 else 3 if row < 2 and x % 2 else 2
            picture[y][x] = THATCH[shade + (x > centre and shade < 4)]
            snowy.add((x, y))
        face_top[x] = foot_y + 1
    # The turf ridge: a band 4 px wide, lit on the left, with tufts along its edges, rounded off
    # at both ends.
    ridge_top, ridge_bottom = rake(centre) - depth - 1, rake(centre) + 1
    for column, colour in enumerate(("dry", "green", "green_dark", "green_dark", "green_deep", "green_deep")):
        x = round(centre - 2.5) + column
        is_edge = column in (0, 5)
        for y in range(ridge_top + is_edge, ridge_bottom - is_edge):
            if not is_edge or rng.random() < 0.4:
                picture[y][x] = colour
                snowy.add((x, y))
    # The bargeboards: each runs from its eaves along the rake and on past the middle, so they
    # cross over the hip and end in horse heads, lit on top.
    for side in (-1, 1):
        start = left if side < 0 else right
        reach = round((right - left) / 2) + 6
        for step in range(1, reach + 1):
            x = start - side * step
            line = round(eaves_y - step * slope)
            for row, colour in enumerate(BOARD):
                picture[line + 1 + row][x] = colour
                snowy.discard((x, line + 1 + row))
            below = line + 1 + len(BOARD)
            if picture[below][x] not in BOARD:
                picture[below][x] = "soil_dark"
                snowy.discard((x, below))
            if abs(x - centre) >= hip_half:
                face_top[x] = max(face_top[x], below)
        horse_head(picture, snowy, start - side * reach, round(eaves_y - reach * slope), -side)
    return face_top


# The white-painted bargeboards and their horse heads: lit, body, shade, from the top down.
BOARD = ("snow_light", "lime", "lime", "sand_light")
# A horse head carved on a board's end, looking right, from its top row down; the board comes in
# at the bottom left. "#" is the board's body, "o" its lit edge, "x" its shade, "e" the eye.
HORSE_HEAD = (
    "..o.......",
    "..oo......",
    "..#e#o....",
    ".o####o...",
    ".o###x#o..",
    ".o#x.xx#o.",
    "o#x....xx.",
    "##x.......",
    "#x........",
)


def horse_head(picture, snowy, x, y, facing):
    """A horse head carved on the end of a bargeboard whose top edge ends at (x, y), looking
    right with `facing` 1 and left with -1, outlined in dark oak so it shows against the thatch
    and kept clear of snow."""
    colours = {"o": BOARD[0], "#": BOARD[1], "x": BOARD[3], "e": "soil_dark"}
    head = {}
    for row, line in enumerate(HORSE_HEAD):
        for column, mark in enumerate(line):
            if mark in colours:
                head[x + facing * column, y - len(HORSE_HEAD) + 2 + row] = colours[mark]
    for hx, hy in head:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (hx + dx, hy + dy) not in head and picture[hy + dy][hx + dx] not in BOARD:
                picture[hy + dy][hx + dx] = "soil_dark"
                snowy.discard((hx + dx, hy + dy))
    for (hx, hy), colour in head.items():
        picture[hy][hx] = colour
        snowy.discard((hx, hy))


def herringbone(picture, rng, pixels, bricks, mortar):
    """Bricks laid slanting in columns 4 px wide, leaning one way in one column and the other way
    in the next, so their joints zigzag: the herringbone of a decorated gable."""
    colours = {}
    for x, y in pixels:
        band, offset = divmod(x, 4)
        diagonal = y + offset if band % 2 else y - offset
        if diagonal % 3 == 0:
            picture[y][x] = mortar
        else:
            picture[y][x] = colours.setdefault((band, diagonal // 3), rng.choice(bricks))


def diagonal_bricks(picture, rng, pixels, bricks, mortar, rising):
    """Bricks laid slanting all one way, parallel to a rake: rising to the right, or to the left
    with `rising` -1; a joint every 5 px along each course."""
    colours = {}
    for x, y in pixels:
        course = y + rising * x
        if course % 3 == 0 or (x + course // 3 * 2) % 6 == 0:
            picture[y][x] = mortar
        else:
            picture[y][x] = colours.setdefault((course // 3, (x + course // 3 * 2) // 6), rng.choice(bricks))


def grote_door(picture, left, right, top, spring, bottom):
    """The Grote Door of a hall house: two tall leaves of upright planks painted green, under a
    flat arch rising from `spring` at the sides to `top` in the middle, in a white frame, each
    leaf held by ledges with iron hinges; a stone threshold below."""
    centre = (left + right) / 2
    half = (right - left + 1) / 2
    right_leaf = (left + right + 1) // 2
    for x in range(left, right + 1):
        arch = spring - round((spring - top) * math.sqrt(max(0.0, 1 - ((x - centre) / half) ** 2)))
        picture[arch - 1][x] = "snow_light"
        leaf_left = left if x < right_leaf else right_leaf
        if x in (left, right):
            colour = "green_dark"
        elif x in (right_leaf - 1, right_leaf) or (x - leaf_left) % 4 == 3:
            colour = "green_deep"
        else:
            colour = "green_light" if x == leaf_left + 1 else "green"
        rect(picture, x, arch, x, bottom, colour)
    for y in (spring + 4, (spring + bottom) // 2 + 4, bottom - 5):
        rect(picture, left + 1, y, right - 1, y, "green_light")
        rect(picture, left + 1, y + 1, right - 1, y + 1, "green_dark")
        rect(picture, left + 1, y, left + 3, y + 1, "stone_dark")
        rect(picture, right - 3, y, right - 1, y + 1, "stone_dark")
    rect(picture, left - 1, top - 1, left - 1, bottom, "snow_light")
    rect(picture, right + 1, top - 1, right + 1, bottom, "snow_light")
    rect(picture, right_leaf - 3, (spring + bottom) // 2, right_leaf - 2, (spring + bottom) // 2, "gold")
    rect(picture, left - 2, bottom + 1, right + 2, bottom + 2, "stone_light")
    rect(picture, left - 2, bottom + 2, right + 2, bottom + 2, "stone")


def hall_house(is_lit):
    """The Low German hall house (Niedersachsenhaus) on 7x5 tiles, its gable end to the front:
    the big arched barn door (Grote Door) in the middle under a carved oak beam, oak framing
    with red brick in it, laid in herringbone and slanting courses in the gable, and the top of
    the gable boarded, with the owl hole (Uhlenloch) under the little hip. A huge half-hipped
    thatch runs back from it, with a turf ridge, and white bargeboards cross over the hip in a
    pair of horse heads. Small stable windows to either side of the door."""
    rng = random.Random(385)
    width, height = 7 * TILE, 136
    picture = blank(width, height)
    snowy = set()
    # The rows of the gable, top down: the foot of the hip, where the gable starts; the beam
    # across the gable, with the boarded top above it; the beam over the door; the rail of the
    # side bays; the fieldstone base.
    gable_top = 54
    gable_beam = (64, 66)
    door_beam = (82, 85)
    rail = 104
    base_top = 128
    wall_left, wall_right = 3, width - 4
    # The posts of the oak frame, the stout posts either side of the door, and the door between.
    posts = (wall_left, 20, 55, 90, wall_right - 1)
    door_posts = (37, 71)
    door_left, door_right = 42, 69
    face_top = gable_roof(picture, snowy, rng, 0, width - 1, 106, gable_top, 13, 34)
    # The gable is drawn whole on a picture of its own, and shows below the roof and the boards.
    gable = blank(width, height)
    bricks = ("rust", "rust", "red_light", "rust_dark")
    brick_wall(gable, rng, wall_left, wall_right, gable_top, base_top - 1, bricks, "sand")
    # The upper gable, between its beams: brick in herringbone between the door posts, slanting
    # with the rakes in the bays beside them.
    panel_rows = range(gable_beam[1], door_beam[0])
    herringbone(gable, rng, [(x, y) for x in range(40, 72) for y in panel_rows], bricks, "sand")
    for x0, x1, rising in ((22, 37, 1), (74, 89, -1)):
        diagonal_bricks(gable, rng, [(x, y) for x in range(x0, x1 + 1) for y in panel_rows], bricks, "sand", rising)
    # The top of the gable boarded in oak, with the owl hole in it.
    for x in range(wall_left, wall_right + 1):
        rect(gable, x, gable_top, x, gable_beam[0] - 1, ("soil_light", "soil_mid", "soil_mid", "soil")[(x - wall_left) % 4])
    for row in range(5):
        rect(gable, 55 - row, gable_top + 3 + row, 56 + row, gable_top + 3 + row, "ink")
    # The oak frame: the sill, the posts, a rail in the side bays, short braces in the corner
    # bays, the beam over the door (carved) and the gable's beam.
    rect(gable, wall_left, base_top - 2, wall_right, base_top - 1, OAK[0])
    rect(gable, wall_left, base_top - 1, wall_right, base_top - 1, OAK[1])
    for x in posts:
        rect(gable, x, gable_beam[0], x + 1, base_top - 1, OAK[0])
        rect(gable, x + 1, gable_beam[0], x + 1, base_top - 1, OAK[1])
    for x in door_posts:
        rect(gable, x, gable_beam[0], x + 2, base_top - 1, OAK[0])
        rect(gable, x, gable_beam[0], x, base_top - 1, "soil_mid")
        rect(gable, x + 2, gable_beam[0], x + 2, base_top - 1, OAK[1])
    for x0, x1 in ((wall_left, door_posts[0]), (door_posts[1], wall_right)):
        rect(gable, x0, rail, x1, rail + 1, OAK[0])
        rect(gable, x0, rail + 1, x1, rail + 1, OAK[1])
    for x0, direction in ((5, -1), (92, 1)):
        for step in range(14):
            bx = x0 + step if direction > 0 else x0 + 13 - step
            gable[base_top - 5 - step][bx] = OAK[0]
            gable[base_top - 5 - step][bx + 1] = OAK[1]
    for top, bottom in (gable_beam, door_beam):
        rect(gable, wall_left, top, wall_right, bottom, OAK[0])
        rect(gable, wall_left, top, wall_right, top, "soil_mid")
        rect(gable, wall_left, bottom, wall_right, bottom, OAK[1])
    # A line cut into the door beam, as the farmer and his wife had their names and the year
    # carved there.
    x = door_left + 1
    while x < door_right - 1:
        letter = rng.randint(1, 3)
        rect(gable, x, door_beam[1] - 1, x + letter - 1, door_beam[1] - 1, "soil_light")
        if rng.random() < 0.5:
            gable[door_beam[1] - 2][x] = "soil_light"
        x += letter + rng.choice((1, 1, 3))
    fieldstone_base(gable, rng, wall_left, wall_right, base_top, height - 2)
    for left in (24, 78):
        window(gable, left, 90, 10, 10, is_lit, frame="green_dark")
    grote_door(gable, door_left, door_right, door_beam[1] + 2, door_beam[1] + 9, height - 4)
    for x, top in face_top.items():
        for y in range(top, height):
            if gable[y][x] is not None:
                picture[y][x] = gable[y][x]
    eaves_shadow(picture, {x: y - 1 for x, y in face_top.items()}, wall_left, wall_right)
    outline(picture, THATCH[4])
    ground_shadow(picture)
    return picture, snowy


# How to draw each building (is_lit to the picture and the pixels snow covers), by its id in
# data/buildings.cfg.
PICTURES = {"shack": shack, "kate": kate, "longhouse": longhouse, "barn": barn, "hall_house": hall_house}
