"""What the buildings share (assets/buildings/<id>.png, and <id>_lit.png with lit windows for the
night): the colours, the thatch and turf roofs, the walls, doors and windows. The buildings
themselves are in farmhouses.py, huts.py and hall_house.py, the church in church.py, and houses.py
collects them. They all look like this:

The North German and Danish countryside, seen from the front in 3/4 view: a huge, thick reed
thatch, weathered grey-brown with moss, hipped at both ends with soft rounded eaves and eyebrow
dormers swelling out of it; lime-washed or brick walls on a fieldstone base; green or teal doors
and shutters, white window frames; the small hut in tarred boards under turf; and the hall house,
which shows its half-timbered gable and big barn door to the front, its roof running back up
the picture. Light comes from the top left.

Drawn at 32 px per tile (canvas.GAME_TILE), after the Kate of the mockup in
review/resolution-mockup-2026-11-08. A picture is as wide as the footprint and its bottom edge
is the footprint's bottom edge; the roof rises above it. The doors are about 60 px high, so
the people (61 px) fit through them. data/buildings.cfg has the window light positions: a
pane of glass near the middle of each window here. Each drawing function returns the picture
(rows of palette colour names, as in canvas.py) and the set of (x, y) pixels that snow covers,
which seasons.house uses for the snow look.
"""

import math
import random

from canvas import rect

# The thatch, lit to dark: weathered grey-brown reed, darkest in the shadow under the eaves.
THATCH = ("sand", "bare_light", "bare", "mud_dark", "soil_dark")
# Moss on the thatch, lit to dark. These keep their green in every season (seasons.house).
MOSS = ("dry", "olive", "green_dark", "green_deep")
# The height of a course of thatch, in px.
COURSE = 7
# The rolled eaves: how many rows they take up at the foot of the roof, one shade of THATCH per
# row from the bottom up (the dark underside, the shaded round, the lit lip, the reed running
# into the first course), and the radius in px of their upturn at each corner.
EAVES_ROLL = (4, 4, 4, 3, 3, 3, 2, 2, 1, 1, 0, 1)
EAVES_ROWS = len(EAVES_ROLL)
EAVES_CORNER = 12
# The lime-washed walls: lit, and shaded at the right corner.
LIME = ("lime", "sand_light")
OAK = ("soil_mid", "soil", "soil_dark")
# Window glass: a pale glint, the sky in it, and darker to the bottom right; lit from inside,
# the warm light, brightest at the top left.
GLASS = ("foam", "water_light", "water", "water_deep")
LIT_GLASS = ("cream", "gold", "flame")
# The painted doors and shutters, lit to deep.
TEAL = ("water_light", "paint_teal", "water", "water_deep")
GREEN = ("green_light", "green", "green_dark", "green_deep")
OX_BLOOD = ("red_light", "rust", "rust_dark", "russet_deep")
# Bricks, red and buff, each brick one of them; the brick Kate's are all fresh red.
RED_BRICKS = ("rust", "rust", "red_light", "rust_dark")
KATE_BRICKS = ("rust", "rust", "red_light")
BUFF_BRICKS = ("sand_light", "sand_light", "straw", "sand")
# The lighter corner of a brick that catches the light.
BRICK_LIT = {"rust_dark": "rust", "rust": "red_light", "sand": "sand_light", "straw": "sand_light", "sand_light": "lime"}
# What the wall colours turn into in the shadow under the eaves.
SHADED = {
    "lime": "sand_light", "cream": "sand_light", "sand_light": "sand", "straw": "ochre_dark", "sand": "mud",
    "rust": "rust_dark", "red_light": "rust", "rust_dark": "russet_deep",
    "soil_light": "soil_mid", "soil_mid": "soil", "soil": "soil_dark",
    "snow_light": "lime", "stone_light": "stone", "stone": "stone_dark",
    "paint_teal": "water", "water_light": "water", "water": "water_deep",
    "green_light": "green", "green": "green_dark", "green_dark": "green_deep",
    "mud_dark": "soil_dark", "bare": "mud_dark", "bare_light": "bare",
}


def thatch_course(rng, first, last):
    """The random make of one course of thatch along the positions first..last (columns of a
    roof seen from the eaves side, rows of one seen from its gable): how far its edge moves at
    each, in runs, wandering by a pixel at a time so it waves instead of stepping like brick;
    whether its lit edge shows there; and how far a reed end hangs out there, at every second
    to fourth position."""
    shift, lit, reed = {}, {}, {}
    at, drop = first, 0
    while at <= last:
        run = rng.randint(8, 18)
        shift.update(dict.fromkeys(range(at, at + run), drop))
        drop = max(-1, min(1, drop + rng.choice((-1, 1))))
        at += run
    at = first
    while at <= last:
        run = 1 if rng.random() < 0.2 else rng.randint(4, 14)
        lit.update(dict.fromkeys(range(at, at + run), run > 1))
        at += run
    at = first + rng.randrange(3)
    while at <= last:
        reed[at] = rng.choice((1, 2, 2, 3, 3, 4, 5))
        at += rng.choice((2, 2, 3, 3, 4))
    return shift, lit, reed


def moss_patches(rng, count, xs, ys):
    """`count` patches of moss, (x, y, radius), somewhere in the ranges xs and ys."""
    return [(rng.uniform(*xs), rng.uniform(*ys), rng.uniform(4, 7)) for _ in range(count)]


def mossy(rng, patches, x, y, squash):
    """Whether moss covers (x, y): inside a patch, ragged at its edge. `squash` flattens the
    patches along the courses."""
    for mx, my, radius in patches:
        distance = math.hypot((x - mx) * squash[0], (y - my) * squash[1])
        if distance < radius - 1.5 or (distance < radius and rng.random() < 0.5):
            return True
    return False


def thatch_roof(picture, snowy, rng, left, right, ridge_y, eaves_y, inset, swells=(), moss=6):
    """A hipped thatch roof over the columns left..right, from the ridge at `ridge_y` down to the
    eaves at `eaves_y`. The ridge is `inset` px shorter than the eaves on each side, and the hips
    run down from its ends with a little belly, so the roof reads as steep planes: the front
    slope, and a narrow hip face at each end, the left one lit and the right one in shade, with a
    lit hip line. The eaves are a thick rolled edge (EAVES_ROLL) with a ragged dark hem, curling
    up at the corners and rising in a smooth wave over each swell (cx, half width, rise), e.g.
    over a door. The reed lies in courses 7 px high with wavy edges: each lit along its top in
    broken runs, reed ends of mixed length hanging below that, and a shadow line at its foot that
    the longest reed ends break. The low courses bend up with the eaves over a swell. Weathering
    crowds the reed ends in a few patches, and moss grows in a few patches low on the front.
    Returns the eaves row of each column."""
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
    courses = [thatch_course(rng, left, right) for _ in range(height // COURSE + 3)]
    # How deep the dark hem under the rolled eaves reaches, in runs of columns.
    hem = {}
    x = left
    while x <= right:
        run = rng.randint(2, 5)
        hem.update(dict.fromkeys(range(x, x + run), rng.randrange(3)))
        x += run
    weathered = [
        (rng.uniform(left + inset, right - inset), rng.uniform(ridge_y + 16, eaves_y - 28), rng.uniform(6, 10))
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

    patches = moss_patches(rng, moss, (left + 26, right - 26), (ridge_y + height * 0.5, eaves_y - 16))
    for y in range(ridge_y, eaves_y + 1):
        t = (y - ridge_y) / height
        # The ends of the ridge are rounded off by a few pixels.
        reach = inset * (1 - t) ** 1.5 + max(0, 3 - (y - ridge_y))
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
                shade = EAVES_ROLL[from_eaves]
                if from_eaves < 3 + hem[x]:
                    shade = 4
                if plane == 3 and from_eaves > 3:
                    shade += 1
                if plane == 1 and from_eaves > 5:
                    shade -= 1
                colour = THATCH[max(0, min(4, shade))]
            else:
                # Up the slope from the eaves. Over a swell the lowest courses bend up with the
                # eaves and the bend dies out fast above them, so the courses don't stack into steps.
                along = round(eaves_y - y - lifts[x] * t**5) - EAVES_ROWS
                # The edges wave: the course a pixel would be in moves it up or down a little.
                along += courses[max(0, along) // COURSE][0][x]
                course, row = divmod(max(0, along), COURSE)
                _, lit, reed = courses[course]
                # The lit hip line and the lit top edge of each course, then the reed ends below it.
                is_lit = (row == COURSE - 1 and lit[x]) or (plane == 1 and x + 2 >= left + hip)
                hangs = COURSE - 2 - row < reed.get(x, 0) or (x % 2 and is_weathered(x, y))
                tone = plane - 1 if is_lit else plane
                if row == 0 and reed.get(x, 0) < 4:
                    tone = plane + 1
                elif not is_lit and hangs and plane > 1:
                    tone = plane + 1
                colour = THATCH[min(4, tone)]
                if mossy(rng, patches, x, y, (1, 1.6)):
                    colour = MOSS[min(3, tone)]
            picture[y][x] = colour
            snowy.add((x, y))
    return eaves


def turf_ridge(picture, snowy, left, right, y):
    """A ridge capped with turf: a rounded band of grass along the top of the roof, lit on top,
    with a ragged crest of tufts."""
    rng = random.Random(left * 1000 + y)
    shades = ("dry_light", "dry_light", "dry", "dry", "olive", "olive", "green_dark", "green_dark", "green_deep", "green_deep")
    for x in range(left, right + 1):
        end = min(x - left, right - x)
        top = y - 4 + max(0, 6 - end) - (rng.random() < 0.3)
        for row in range(top, y + 6):
            picture[row][x] = shades[max(0, row - y + 4)]
            snowy.add((x, row))


def glass(across, down, is_lit):
    """The colour of window glass `across` and `down` a pane or a window (0 to 1 from its top
    left): a glint in the top left corner, the sky, darker to the bottom right; or the warm
    light from inside, brightest at the top left."""
    if is_lit:
        return LIT_GLASS[0] if across + down < 0.5 else LIT_GLASS[1] if across + down < 1.3 else LIT_GLASS[2]
    if across + down < 0.35:
        return GLASS[0] if across + down < 0.18 else GLASS[1]
    return GLASS[2] if across + down < 1.1 else GLASS[3]


def window(picture, left, top, columns, rows, is_lit, frame="snow_light", shutters=None):
    """A window of `columns` x `rows` panes in a `frame`, white by default, with a sill; with
    `shutters` (a ramp like TEAL) a braced shutter on each side, on iron hinges. The panes are 5
    px square in white glazing bars, as glass came in small pieces: a window of 3x3 panes is 19
    px square. Lit, each pane glows in one colour, brighter towards the top left of the window,
    with a glint in its corner."""
    width, height = 6 * columns + 1, 6 * rows + 1
    rect(picture, left - 2, top - 2, left + width + 1, top + height + 1, "soil_dark")
    rect(picture, left - 1, top - 1, left + width, top + height, frame)
    for y in range(top, top + height):
        for x in range(left, left + width):
            column, across = divmod(x - left, 6)
            row, down = divmod(y - top, 6)
            if across == 0 or down == 0:
                picture[y][x] = "snow_light"
            elif is_lit:
                corner = across == 1 and down == 1
                picture[y][x] = "cream" if corner else glass(column / columns, row / rows, True)
            else:
                picture[y][x] = glass((across - 1) / 5, (down - 1) / 5, False)
    # The bars' inner shade on the right and at the bottom.
    rect(picture, left + width - 1, top, left + width - 1, top + height - 1, "lime")
    rect(picture, left, top + height - 1, left + width - 1, top + height - 1, "lime")
    rect(picture, left - 4, top + height + 1, left + width + 3, top + height + 2, "snow_light")
    rect(picture, left - 3, top + height + 3, left + width + 2, top + height + 3, "stone")
    if shutters:
        light, middle, dark, deep = shutters
        bottom = top + height + 1
        for x0 in (left - 10, left + width + 2):
            rect(picture, x0, top - 2, x0 + 7, bottom, middle)
            rect(picture, x0 + 6, top - 2, x0 + 7, bottom, dark)
            rect(picture, x0, top - 2, x0 + 7, top - 2, light)
            for bx in (x0 + 2, x0 + 4):
                rect(picture, bx, top - 1, bx, bottom, dark)
            # The ledges and the brace of a Z between them.
            for ledge in (top + 2, top + height - 4):
                rect(picture, x0, ledge, x0 + 7, ledge + 1, dark)
                rect(picture, x0, ledge, x0 + 5, ledge, light)
            span = height - 8
            for step in range(span):
                picture[top + height - 5 - step][x0 + 1 + step * 6 // span] = light
            rect(picture, x0 - 1, top - 2, x0 - 1, bottom, deep)
            rect(picture, x0 + 8, top - 2, x0 + 8, bottom, deep)
            hinge = x0 + 6 if x0 < left else x0 + 1
            for ledge in (top + 2, top + height - 4):
                picture[ledge][hinge] = "ink"


def door(picture, left, top, bottom, width, colours, frame=("snow_light", "lime"), arched=False, split=True):
    """A door of upright planks 6 px wide in `colours` (light, middle, dark, deep), lit on the
    left and shaded at its right, in a `frame` (lit, shade) and on a stone step. A split door
    (Klöntür) has its upper and lower halves parted by a rail; each half hangs on an iron strap
    hinge, and a brass knob sits on the right. An arched door has a round top, and its two
    leaves meet in the middle."""
    light, middle, dark, deep = colours
    half = width / 2
    for y in range(top - 2, bottom + 1):
        for x in range(left - 2, left + width + 2):
            # How far out of the round top of an arched door; 0 below it, and on a square door.
            arch = 0.0
            if arched and y < top + half:
                arch = math.hypot(x + 0.5 - left - half, y + 0.5 - top - half) - half
            if arch > 2:
                continue
            plank = (x - left) % 6
            if arch > 0 or x < left or x >= left + width or y < top:
                colour = frame[1] if x >= left + width else frame[0]
            elif x >= left + width - 3:
                colour = dark
            else:
                colour = dark if plank == 5 else light if plank == 0 else middle
            picture[y][x] = colour
    centre = left + width // 2
    if arched:
        rect(picture, centre - 1, top + 2, centre, bottom, deep)
        rect(picture, centre + 1, top + 2, centre + 1, bottom, light)
    rails = (top + 6, (top + bottom) // 2, bottom - 7) if arched else (top + 5, bottom - 8)
    if split:
        middle_row = (top + bottom) // 2
        rect(picture, left, middle_row, left + width - 1, middle_row, deep)
        rect(picture, left, middle_row + 1, left + width - 1, middle_row + 1, light)
        rails = (top + 5, middle_row + 6)
    for y in rails:
        for x0, x1 in ((left, centre - 6), (centre + 6, left + width - 1)) if arched else ((left, left + width - 8),):
            rect(picture, x0, y, x1, y + 1, "stone_dark")
            rect(picture, x0, y, x1, y, "stone")
    knob_x = centre - 4 if arched else left + width - 5
    knob_y = (top + bottom) // 2 - 4
    rect(picture, knob_x, knob_y, knob_x + 1, knob_y + 1, "gold")
    picture[knob_y + 1][knob_x + 1] = "ochre_dark"
    rect(picture, left - 4, bottom + 1, left + width + 3, bottom + 2, "stone_light")
    rect(picture, left - 4, bottom + 3, left + width + 3, bottom + 4, "stone")


def fieldstone_base(picture, rng, left, right, top, bottom):
    """A base of round fieldstones of mixed sizes in dark joints, each a little dome lit on its
    top left, mostly grey granite and some warmer; moss low on a few."""
    rect(picture, left, top, right, bottom, "mud_dark")
    y, row = top, 0
    while y <= bottom:
        stone_height = min(rng.randint(5, 7), bottom - y + 1)
        x = left + (row % 2) * 4 - 3
        while x <= right:
            stone_width = rng.randint(8, 13)
            warm = rng.random() < 0.35
            ramp = ("stone_dark", "bare", "bare_light", "stone_light") if warm else ("stone_dark", "stone", "stone_light", "stone_light")
            cx, cy = x + (stone_width - 2) / 2, y + (stone_height - 2) / 2
            for sy in range(y, y + stone_height - 1):
                for sx in range(max(left, x), min(right, x + stone_width - 2) + 1):
                    dx = (sx + 0.5 - cx) / ((stone_width - 1) / 2)
                    dy = (sy + 0.5 - cy) / max(1, (stone_height - 1) / 2)
                    distance = dx * dx + dy * dy
                    if distance > 1.05:
                        continue
                    lit = -dx * 0.6 - dy * 0.8
                    shade = 3 if lit > 0.55 and distance > 0.15 else 2 if lit > -0.1 else 1 if lit > -0.6 or distance < 0.6 else 0
                    picture[sy][sx] = ramp[shade]
            if rng.random() < 0.25 and y > top + 4 and x + 2 <= right:
                picture[y + stone_height - 3][max(left, x + 1)] = "olive"
                picture[y + stone_height - 2][max(left, x + 2)] = "green_dark"
            x += stone_width
        y += stone_height
        row += 1


def eaves_shadow(picture, eaves, wall_left, wall_right):
    """Darkens the wall in the shadow under the eaves: two shades right under them, fading out
    below."""
    for x in range(wall_left, wall_right + 1):
        for below, steps in ((1, 2), (2, 2), (3, 1), (4, 1), (5, 1)):
            y = eaves[x] + below
            for _ in range(steps):
                if picture[y][x] in SHADED:
                    picture[y][x] = SHADED[picture[y][x]]


def ground_shadow(picture):
    """A shadow on the ground along the bottom of the building, two rows deep."""
    width, height = len(picture[0]), len(picture)
    for y in (height - 2, height - 1):
        for x in range(2, width - 2):
            if picture[y][x] is None:
                picture[y][x] = "shadow"


def lime_wall(picture, rng, left, right, top, bottom):
    """A lime-washed wall, almost flat: shaded round the right corner, a few flakes, and the
    rain's splash darkening it at its foot."""
    rect(picture, left, top, right, bottom, LIME[0])
    rect(picture, right - 3, top, right, bottom, LIME[1])
    for _ in range((right - left) // 6):
        x, y = rng.randint(left + 2, right - 5), rng.randint(top + 14, bottom - 1)
        picture[y][x] = LIME[1]
        if rng.random() < 0.4:
            picture[y][x + 1] = LIME[1]
    for x in range(left, right + 1):
        for y in range(bottom - 2, bottom + 1):
            if rng.random() < 0.1 + (y - bottom + 2) * 0.25:
                picture[y][x] = LIME[1]


def brick_wall(picture, rng, left, right, top, bottom, bricks, mortar):
    """Courses of bricks 8 px long and 2 high in 1 px `mortar` joints, each course offset by
    half a brick from the one below; each brick one of the colours `bricks`, a few with a
    lighter corner where they catch the light."""
    rect(picture, left, top, right, bottom, mortar)
    for row, y in enumerate(range(bottom - 1, top - 3, -3)):
        for x in range(left - (row % 2) * 4, right + 1, 9):
            colour = rng.choice(bricks)
            rect(picture, max(left, x), max(top, y), min(right, x + 7), min(bottom, y + 1), colour)
            if rng.random() < 0.25 and left <= x and top <= y:
                picture[y][x] = BRICK_LIT.get(colour, colour)
