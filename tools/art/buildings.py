"""The buildings (assets/buildings/<id>.png, and <id>_lit.png with lit windows for the night).

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

from canvas import GAME_TILE, blank, outline_edge, rect

# The thatch, lit to dark: weathered grey-brown reed, darkest in the shadow under the eaves.
THATCH = ("sand", "bare_light", "bare", "mud_dark", "soil_dark")
# Moss on the thatch, lit to dark. These keep their green in every season (seasons.house).
MOSS = ("dry", "olive", "green_dark", "green_deep")
# The grass of a turf roof, lit to dark, and where it has dried out.
TURF = ("green_bright", "green_light", "green", "green_dark", "green_deep")
DRY_TURF = ("dry_light", "dry", "olive", "green_dark", "green_deep")
# The height of a course of thatch, in px.
COURSE = 7
# The rolled eaves: how many rows they take up at the foot of the roof, one shade of THATCH per
# row from the bottom up (the dark underside, the shaded round, the lit lip, the reed running
# into the first course), and the radius in px of their upturn at each corner.
EAVES_ROLL = (4, 4, 4, 3, 3, 3, 2, 2, 1, 1, 0, 1)
EAVES_ROWS = len(EAVES_ROLL)
EAVES_CORNER = 12
# The ridge of a roof seen from its gable: how far short of the back of the roof it ends, and
# every how many rows it is bound, in px.
RIDGE_SHORT = 12
RIDGE_BINDING = 9
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
# Bricks, red and buff, each brick one of them.
RED_BRICKS = ("rust", "rust", "red_light", "rust_dark")
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


def crossed_ridge(picture, snowy, left, right, y):
    """A ridge capped with straw and held down by crossed split-oak sticks every 12 px: the
    crossings lie on the cap and the tips stand out above it, so the row of X's shows against
    the sky; a stick is lit where it lies on the cap."""
    rect(picture, left, y, right, y + 4, "umber")
    rect(picture, left, y, right, y, "ochre_dark")
    rect(picture, left, y + 5, right, y + 6, "soil_dark")
    for x in range(left, right + 1):
        snowy.update(((x, y), (x, y + 1), (x, y + 2)))
    for x in range(left + 2, right - 9, 12):
        for step in range(10):
            on_cap = step >= 5
            for dx in (0, 1):
                picture[y - 5 + step][x + step + dx] = "soil_light" if on_cap else "soil_mid"
                picture[y - 5 + step][x + 9 - step + dx] = "soil_mid" if on_cap else "soil"
        rect(picture, x + 4, y - 1, x + 5, y - 1, "soil_dark")


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


def chimney(picture, snowy, left, top, bottom, colours, bricks=None):
    """A square chimney 12 px wide from `top` down into the roof at `bottom`, lit on the left,
    with a cap of two courses and soot at the top: lime-washed in `colours` (light, middle,
    dark), or of `bricks` in courses."""
    light, middle, dark = colours
    rect(picture, left, top, left + 11, bottom, middle)
    if bricks:
        brick_wall(picture, random.Random(left), left, left + 11, top, bottom, bricks, "sand")
    rect(picture, left, top, left + 1, bottom, light)
    rect(picture, left + 10, top, left + 11, bottom, dark)
    rect(picture, left - 2, top, left + 13, top + 3, light)
    rect(picture, left - 2, top + 2, left + 13, top + 3, dark)
    rect(picture, left + 1, top - 2, left + 10, top - 1, "stone_dark")
    rect(picture, left + 3, top - 2, left + 8, top - 2, "ink")
    for x in range(left - 2, left + 14):
        snowy.add((x, top))


def eyebrow(picture, snowy, cx, bottom, width, is_lit):
    """An eyebrow dormer: the thatch swells up in a smooth wave over a half-round window in the
    roof. The swell is lit along its crest and shades the top of the window."""
    half = width // 2
    arch = half * 2 // 3
    crest_rows = (THATCH[1], THATCH[0], THATCH[0], THATCH[1], THATCH[1], THATCH[2], THATCH[3], THATCH[3])
    for x in range(cx - half - 12, cx + half + 12):
        offset = min(1.0, abs(x + 0.5 - cx) / (half + 12))
        crest = bottom - arch - 4 - round(8 * math.cos(offset * math.pi / 2) ** 2)
        for row, colour in enumerate(crest_rows):
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
            if distance > half - 2 or y >= bottom - 1 or (x - cx) % 5 == 2 or (bottom - y) % 5 == 4:
                picture[y][x] = "snow_light"
            else:
                picture[y][x] = glass((x - cx + half) / width, (y - bottom + arch) / arch, is_lit)
            # The shade the swell casts over the top of the frame.
            if half - 3 < distance <= half - 2 and y < bottom - arch // 2:
                picture[y][x] = "stone"
    rect(picture, cx - half - 1, bottom + 1, cx + half, bottom + 2, THATCH[4])


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


def kate(is_lit):
    """A small cottage on 5x3 tiles: white lime walls on fieldstones, a teal split door and
    braced teal shutters, a big eyebrow dormer in the middle of the roof, the thatch swelling up
    over the door, and a small white chimney; the ridge held by crossed sticks."""
    rng = random.Random(381)
    width, height = 5 * GAME_TILE, 192
    picture = blank(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 6, width - 7, 102, height - 14
    lime_wall(picture, rng, wall_left, wall_right, wall_top, base_top - 1)
    fieldstone_base(picture, rng, wall_left, wall_right, base_top, height - 3)
    for left in (25, 116):
        window(picture, left, 140, 3, 3, is_lit, shutters=TEAL)
    door(picture, 67, 126, height - 6, 26, TEAL)
    eaves = thatch_roof(picture, snowy, rng, 0, width - 1, 22, 122, 44, swells=((80, 26, 12),))
    crossed_ridge(picture, snowy, 44, width - 45, 22)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    eyebrow(picture, snowy, 80, 86, 32, is_lit)
    chimney(picture, snowy, 104, 6, 30, ("snow_light", "lime", "sand_light"))
    outline_edge(picture, THATCH[4], keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


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



def climbing_rose(picture, rng, x, top, bottom):
    """A climbing rose up the wall: a column of dark leaves, lit in places, with red flowers."""
    for y in range(top, bottom + 1):
        reach = 2 if y < top + 6 else 4
        wobble = round(math.sin(y / 5))
        for dx in range(-reach + wobble + (y % 2), reach + wobble + 1):
            picture[y][x + dx] = "green" if (dx + y) % 4 == 0 else "green_dark" if (dx * 3 + y) % 5 else "green_deep"
    for _ in range((bottom - top) // 4):
        fx, fy = x + rng.randint(-3, 2), rng.randint(top + 2, bottom - 2)
        rect(picture, fx, fy, fx + 1, fy, "red_light")
        rect(picture, fx, fy + 1, fx + 1, fy + 1, "ember")


def longhouse(is_lit):
    """A long, low North German farmhouse on 7x3 tiles (a Geesthardenhaus, entered on the eaves
    side): buff brick on a fieldstone base, a huge thatch with crossed sticks on its ridge, two
    brick chimneys and two eyebrow dormers. The big arched door of green planks is in the middle
    of the long side, the thatch sweeping up over it; white windows in dark green frames to
    either side, roses climbing the wall."""
    rng = random.Random(382)
    width, height = 7 * GAME_TILE, 192
    picture = blank(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 6, width - 7, 104, height - 14
    brick_wall(picture, rng, wall_left, wall_right, wall_top, base_top - 1, BUFF_BRICKS, "sand")
    rect(picture, wall_right - 2, wall_top, wall_right, base_top - 1, "sand")
    fieldstone_base(picture, rng, wall_left, wall_right, base_top, height - 3)
    for left in (14, 50, 155, 191):
        window(picture, left, 142, 3, 3, is_lit, frame="green_dark")
    climbing_rose(picture, rng, 80, 134, base_top - 1)
    climbing_rose(picture, rng, 144, 138, base_top - 1)
    door(picture, 90, 120, height - 6, 44, GREEN, arched=True, split=False)
    eaves = thatch_roof(picture, snowy, rng, 0, width - 1, 26, 130, 60, swells=((112, 44, 22),), moss=9)
    crossed_ridge(picture, snowy, 60, width - 61, 26)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    for cx in (52, 172):
        eyebrow(picture, snowy, cx, 90, 28, is_lit)
    for left in (72, 140):
        chimney(picture, snowy, left, 8, 34, ("red_light", "rust", "rust_dark"), RED_BRICKS)
    outline_edge(picture, THATCH[4], keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


def half_timbering(picture, left, right, top, bottom, posts, braces):
    """Dark oak beams 4 px thick, lit on their top or left edge: a sill and a head beam, upright
    posts at `posts`, and a diagonal brace in each panel of `braces` (left edge, width, and +1
    to rise to the right or -1 to the left)."""
    for y0 in (top, bottom - 3):
        rect(picture, left, y0, right, y0 + 3, OAK[1])
        rect(picture, left, y0, right, y0, OAK[0])
        rect(picture, left, y0 + 3, right, y0 + 3, OAK[2])
    for x in posts:
        rect(picture, x, top, x + 3, bottom, OAK[1])
        rect(picture, x, top + 1, x, bottom - 4, OAK[0])
        rect(picture, x + 3, top + 4, x + 3, bottom - 4, OAK[2])
    for x, panel_width, direction in braces:
        rise = bottom - top - 7
        for step in range(rise):
            offset = step * panel_width // rise
            bx = x + offset if direction > 0 else x + panel_width - 3 - offset
            y = bottom - 4 - step
            picture[y][bx] = OAK[0]
            picture[y][bx + 1] = OAK[1]
            picture[y][bx + 2] = OAK[1]
            picture[y][bx + 3] = OAK[2]


def barn(is_lit):
    """A barn on 6x3 tiles: half-timbered with red brick in dark oak beams, big plank double
    doors with braces on the third tile, a thatch roof with a turf ridge, no windows. `is_lit`
    changes nothing: a barn has no windows to light."""
    rng = random.Random(383)
    width, height = 6 * GAME_TILE, 192
    picture = blank(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 6, width - 7, 104, height - 14
    brick_wall(picture, rng, wall_left, wall_right, wall_top, base_top - 1, RED_BRICKS, "sand")
    half_timbering(
        picture, wall_left, wall_right, wall_top, base_top - 1,
        (wall_left, 42, 116, 150, wall_right - 3), ((10, 32, -1), (120, 30, 1), (154, 30, 1)),
    )
    fieldstone_base(picture, rng, wall_left, wall_right, base_top, height - 3)
    # The doors: two leaves of planks with a Z of braces each and iron hinges, in an oak frame.
    door_left, door_right, door_top = 52, 107, 120
    rect(picture, door_left - 4, door_top - 4, door_right + 4, height - 5, OAK[2])
    rect(picture, door_left - 4, door_top - 4, door_left - 3, height - 5, OAK[0])
    leaf_width = (door_right - door_left + 1) // 2
    for leaf_left in (door_left, door_left + leaf_width):
        leaf_right = leaf_left + leaf_width - 1
        for x in range(leaf_left, leaf_right + 1):
            plank = (x - leaf_left) % 7
            colour = "soil_dark" if plank == 6 else "soil_light" if plank == 0 else "soil_mid"
            rect(picture, x, door_top, x, height - 7, colour)
        bars = (door_top + 4, height - 14)
        for y in bars:
            rect(picture, leaf_left, y, leaf_right, y + 2, "soil_mid")
            rect(picture, leaf_left, y, leaf_right, y, "soil_light")
            rect(picture, leaf_left, y + 3, leaf_right, y + 3, "soil")
            hinge = (leaf_left, leaf_left + 7) if leaf_left == door_left else (leaf_right - 7, leaf_right)
            rect(picture, hinge[0], y + 1, hinge[1], y + 1, "stone_dark")
        span = bars[1] - bars[0] - 4
        for step in range(span):
            bx = leaf_left + 1 + step * (leaf_width - 5) // span
            y = bars[1] - 1 - step
            rect(picture, bx, y, bx + 2, y, "soil_mid")
            picture[y][bx] = "soil_light"
            picture[y][bx + 3] = "soil"
    rect(picture, door_left + leaf_width - 1, door_top, door_left + leaf_width, height - 7, "soil_dark")
    rect(picture, door_left - 4, height - 6, door_right + 4, height - 5, "stone_light")
    rect(picture, door_left - 4, height - 4, door_right + 4, height - 3, "stone")
    eaves = thatch_roof(picture, snowy, rng, 0, width - 1, 26, 128, 52, swells=((80, 40, 20),))
    turf_ridge(picture, snowy, 52, width - 53, 26)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    outline_edge(picture, THATCH[4], keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


def tarred_boards(picture, rng, left, right, top, bottom):
    """A wall of upright boards 10 px wide tarred near-black, a batten over each joint: its
    raised edge catching the light in the blue-grey sheen of the tar, with a dark line where it
    shades the board to its right. Streaks of the sheen and of darker grain run down the
    boards."""
    for x in range(left, right + 1):
        board = (x - left) % 10
        colour = ("mud_dark", "stone_dark", "soil_dark", "ink")[board] if board < 4 else "ink"
        rect(picture, x, top, x, bottom, colour)
        if board < 4:
            continue
        y = top + rng.randrange(10)
        while y <= bottom:
            run = rng.randint(5, 14)
            if board in (4, 7) and rng.random() < 0.4:
                rect(picture, x, y, x, min(bottom, y + run - 1), "stone_dark")
            elif board in (5, 8) and rng.random() < 0.3:
                rect(picture, x, y, x, min(bottom, y + run - 1), "soil_dark")
            y += run + rng.randint(5, 14)


def ledged_door(picture, left, top, bottom, width, colours):
    """A door of upright planks painted in `colours` (light, middle, dark, deep), held by two
    ledges and a brace between them, in a dark frame, with an iron latch and a stone step."""
    light, middle, dark, deep = colours
    rect(picture, left - 2, top - 2, left + width + 1, bottom, "ink")
    for x in range(left, left + width):
        plank = (x - left) % 7
        colour = dark if plank == 6 else light if plank == 0 else middle
        rect(picture, x, top, x, bottom, colour)
    rect(picture, left + width - 2, top, left + width - 1, bottom, dark)
    ledges = (top + 4, bottom - 8)
    for y in ledges:
        rect(picture, left, y, left + width - 1, y + 2, middle)
        rect(picture, left, y, left + width - 1, y, light)
        rect(picture, left, y + 3, left + width - 1, y + 3, deep)
    span = ledges[1] - ledges[0] - 4
    for step in range(span):
        bx = left + 1 + step * (width - 5) // span
        y = ledges[1] - 1 - step
        rect(picture, bx, y, bx + 2, y, middle)
        picture[y][bx] = light
        picture[y][bx + 3] = deep
    latch_y = (top + bottom) // 2
    rect(picture, left + width - 6, latch_y, left + width - 3, latch_y + 1, "stone_light")
    picture[latch_y + 1][left + width - 3] = "stone_dark"
    rect(picture, left - 4, bottom + 1, left + width + 3, bottom + 2, "stone_light")
    rect(picture, left - 4, bottom + 3, left + width + 3, bottom + 4, "stone")


def boarded_hut(picture, rng, wall_left, wall_right, wall_top, base_top, bottom):
    """The walls of a hut of tarred boards on a low fieldstone base: the corner posts, the right
    one in shade, and the sill beam they stand on."""
    tarred_boards(picture, rng, wall_left, wall_right, wall_top, base_top - 1)
    rect(picture, wall_left, wall_top, wall_left + 3, base_top - 1, "stone_dark")
    rect(picture, wall_left + 2, wall_top, wall_left + 3, base_top - 1, "soil_dark")
    rect(picture, wall_left, wall_top, wall_left, base_top - 1, "stone")
    rect(picture, wall_right - 3, wall_top, wall_right, base_top - 1, "ink")
    rect(picture, wall_left, base_top - 4, wall_right, base_top - 3, "stone_dark")
    rect(picture, wall_left, base_top - 2, wall_right, base_top - 1, "ink")
    fieldstone_base(picture, rng, wall_left, wall_right, base_top, bottom)


def shack(is_lit):
    """A small hut on 3x2 tiles, a fisherman's or herdsman's: tarred boards with battens on a
    low fieldstone base, a low ox-blood door on the middle tile and a small white window with an
    ox-blood shutter on the right, under a turf roof."""
    rng = random.Random(384)
    width, height = 3 * GAME_TILE, 128
    picture = blank(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 4, width - 5, 54, height - 11
    boarded_hut(picture, rng, wall_left, wall_right, wall_top, base_top, height - 3)
    window(picture, 72, 70, 2, 3, is_lit)
    # The shutter, folded back to the left of the window.
    rect(picture, 62, 68, 68, 90, "rust_dark")
    rect(picture, 62, 68, 62, 90, "rust")
    rect(picture, 68, 68, 68, 90, "russet_deep")
    rect(picture, 62, 73, 68, 73, "russet_deep")
    rect(picture, 62, 84, 68, 84, "russet_deep")
    rect(picture, 61, 68, 61, 90, "ink")
    ledged_door(picture, 37, 62, height - 6, 22, OX_BLOOD)
    eaves = turf_roof(picture, snowy, rng, 0, width - 1, 12, 52)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    outline_edge(picture, THATCH[4], keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


def fisher_hut(is_lit):
    """The fisherman's hut (Fischerkate) on 4x2 tiles, the shack's kin at the landing: low walls
    of tarred boards on fieldstones, a hipped reed thatch with a turf ridge, a low door in faded
    teal on the second tile, one small window and an oar leant against the wall between them."""
    rng = random.Random(386)
    width, height = 4 * GAME_TILE, 128
    picture = blank(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 4, width - 5, 52, height - 11
    boarded_hut(picture, rng, wall_left, wall_right, wall_top, base_top, height - 3)
    window(picture, 90, 68, 2, 3, is_lit)
    ledged_door(picture, 37, 60, height - 6, 22, TEAL)
    # The oar, its blade up under the eaves: a pale shaft lit on the left, a dark edge on the right.
    for y in range(58, 116):
        x = 70 + (115 - y) // 9
        is_blade = y < 74
        picture[y][x] = "sand" if is_blade else "soil_light"
        picture[y][x + 1] = "sand" if is_blade else "soil_mid"
        picture[y][x + 2] = "mud" if is_blade else "soil"
        if is_blade:
            picture[y][x - 1] = "sand_light"
            picture[y][x + 3] = "mud"
    eaves = thatch_roof(picture, snowy, rng, 0, width - 1, 10, 58, 32, moss=4)
    turf_ridge(picture, snowy, 32, width - 33, 10)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    outline_edge(picture, THATCH[4], keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


def turf_roof(picture, snowy, rng, left, right, ridge_y, eaves_y):
    """A turf roof over the columns left..right, the grass growing on birch bark: a slope of
    grass in clumps, lit on top and on the left and darker towards the eaves and the right end,
    with a few patches of dry grass and a few flowers; a ragged crest of tufts on the ridge, and
    at the eaves a thick rounded lip of turf with blades hanging over the pale edge of the bark.
    Returns the lowest roof row of each column."""
    height = eaves_y - ridge_y
    # The ridge, a pixel or two higher in a few short runs, rounded off at the ends.
    crest = {}
    x = left
    while x <= right:
        lift = rng.choice((0, 0, 1, 2))
        for column in range(x, min(right, x + rng.randint(1, 4)) + 1):
            crest[column] = ridge_y + max(0, 6 - min(column - left, right - column)) - lift
        x = column + 1
    dry = [
        (rng.uniform(left + 12, right - 12), rng.uniform(ridge_y + 8, eaves_y - 12), rng.uniform(5, 8))
        for _ in range(2)
    ]
    # The gaps between the clumps, in shade; darker towards the eaves.
    for x in range(left, right + 1):
        for y in range(crest[x], eaves_y + 1):
            picture[y][x] = TURF[3] if (y - ridge_y) / height < 0.6 else TURF[4]
            snowy.add((x, y))
    # The clumps lie in rows 3 px apart, each a pixel or two up or down, so they overlap in
    # scallops rather than stripes: a rounded lit top over a body that is darker on its right,
    # one step darker on the lower slope and at the right end, with a blade or two standing up.
    for y in range(ridge_y, eaves_y - 4, 3):
        x = left + rng.randrange(-5, 1)
        while x <= right:
            clump = rng.randint(5, 10)
            top = y + rng.choice((-1, 0, 0, 1, 2))
            is_dry = any(math.hypot((x - dx) / 1.5, top - dy) < radius for dx, dy, radius in dry)
            ramp = DRY_TURF if is_dry else TURF
            step = (top - ridge_y > height * 0.55) + (x > right - 12)
            for cx in range(max(left, x), min(right, x + clump - 1) + 1):
                # The clump's rounded top: its ends a row or two lower.
                rounding = 2 if cx in (x, x + clump - 1) else 1 if cx in (x + 1, x + clump - 2) else 0
                for cy in range(max(crest[cx], top + rounding), top + 5):
                    lit = 0 if cy <= top + rounding and cx < x + clump - 2 else 1
                    if cx >= x + clump - 2 or cy >= top + 4:
                        lit = 2
                    picture[cy][cx] = ramp[min(len(ramp) - 1, lit + step)]
            blade = max(left, min(right, x + rng.randrange(1, clump)))
            if top - 2 >= crest[blade]:
                rect(picture, blade, top - 2, blade, top - 1, ramp[min(4, 1 + step)])
            # A flower on a few clumps: daisies, buttercups, a pink campion.
            flower = max(left, min(right - 1, x + 2))
            if rng.random() < 0.08 and not is_dry and top >= crest[flower]:
                rect(picture, flower, top, flower + 1, top, rng.choice(("cream", "cream", "gold", "petal")))
            x += clump - rng.choice((0, 1, 2))
    # The lip of the turf at the eaves, thicker in some runs: a dark line where it stands out
    # from the slope, then rounded and lit along its top. Under it the edge of the birch bark
    # sticks out, pale with a few black marks and shaded below, and blades of grass hang over it.
    eaves = {}
    x = left
    while x <= right:
        lip_top = eaves_y - rng.choice((4, 4, 5, 6))
        for column in range(x, min(right, x + rng.randint(5, 10)) + 1):
            shade = column > right - 8
            picture[lip_top - 1][column] = TURF[4]
            for y in range(lip_top, eaves_y + 1):
                picture[y][column] = TURF[min(4, 1 + (y - lip_top) // 2 + shade)]
            is_mark = rng.random() < 0.15
            picture[eaves_y + 1][column] = "ink" if is_mark else "stone" if shade else "stone_light"
            picture[eaves_y + 2][column] = "ink" if is_mark else "stone" if shade else "stone_light"
            picture[eaves_y + 3][column] = "stone_dark" if shade else "stone"
            snowy.update(((column, eaves_y + 1), (column, eaves_y + 2), (column, eaves_y + 3)))
            eaves[column] = eaves_y + 3
        x = column + 1
    x = left + rng.randrange(3)
    while x <= right:
        for y in range(eaves_y + 1, eaves_y + 1 + rng.choice((2, 3, 4, 5))):
            picture[y][x] = TURF[3] if y < eaves_y + 3 else TURF[4]
            eaves[x] = max(eaves[x], y)
        x += rng.choice((2, 3, 3, 4, 5))
    return eaves


def gable_roof(picture, snowy, rng, left, right, eaves_y, foot_y, hip_half, depth, moss=7):
    """A half-hipped thatch roof seen from its gable end, over the columns left..right: the
    gable's rakes rise from the eaves at `eaves_y` on both sides to the foot of the little hip at
    `foot_y`, `hip_half` px either side of the middle, and the roof runs back `depth` px from
    them, up the picture. Its two long planes show from above, the left one lit and the right
    one in shade, with a reed ridge between them. As the eaves run back along the sides, the
    courses of reed run up the picture: 7 px wide, lit along their edge towards the ridge in
    broken runs, the reed ends hanging out towards the eaves over a shadow line, and the eaves
    are a thick rolled edge along both sides. At the front the reed is cut along the rakes; the
    hip faces the front in level courses over a rolled foot. White bargeboards lie along the
    rakes and cross over the hip, their ends carved into horse heads looking out. Moss grows in
    a few patches low on the shaded plane. Returns the top row of the gable wall in each column,
    below the boards and the hip."""
    centre = (left + right) / 2
    slope = (eaves_y - foot_y) / ((right - left) / 2 - hip_half)

    def rake(x):
        return round(eaves_y - min(x - left, right - x) * slope)

    # The courses, counted in from the eaves, each varying along the rows.
    courses = [thatch_course(rng, 0, len(picture) - 1) for _ in range(round((right - left) / 2) // COURSE + 2)]
    patches = moss_patches(rng, moss, (right - 48, right - 16), (eaves_y - depth, eaves_y - 20))
    face_top = {}
    for x in range(left, right + 1):
        from_eaves = min(x - left, right - x)
        plane = 1 if x < centre else 3
        bottom = rake(x)
        for y in range(bottom - depth, bottom + 1):
            if from_eaves < EAVES_ROWS:
                # The rolled eaves, one shade per column in from the side, darker on the
                # shaded plane.
                shade = EAVES_ROLL[from_eaves]
                if plane == 3 and from_eaves > 3:
                    shade += 1
                colour = THATCH[min(4, shade)]
            elif y > bottom - 4:
                # The cut ends of the reed along the rake.
                colour = THATCH[3] if plane == 1 and (x + y) % 3 else THATCH[4]
            else:
                along = from_eaves - EAVES_ROWS
                along += courses[along // COURSE][0][y]
                course, row = divmod(max(0, along), COURSE)
                _, lit, reed = courses[course]
                is_lit = row == COURSE - 1 and lit[y]
                hangs = COURSE - 2 - row < reed.get(y, 0)
                tone = plane - 1 if is_lit else plane
                if row == 0 and reed.get(y, 0) < 4:
                    tone = plane + 1
                elif not is_lit and hangs:
                    tone = plane + 1
                colour = THATCH[min(4, tone)]
                if mossy(rng, patches, x, y, (1.6, 1)):
                    colour = MOSS[min(3, tone)]
            picture[y][x] = colour
            snowy.add((x, y))
        face_top[x] = bottom + 1
    # The hip at the front, under the boards: level courses over a rolled foot, lit on the left.
    for x in range(left, right + 1):
        if abs(x - centre) >= hip_half:
            continue
        for y in range(rake(x) + 1, foot_y + 1):
            from_foot = foot_y - y
            if from_foot < 7:
                shade = (4, 4, 3, 3, 1, 0, 1)[from_foot]
            else:
                row = (from_foot - 7) % COURSE
                shade = 1 if row == COURSE - 1 and x % 9 else 3 if row == 0 or (row < 3 and x % 3 == 0) else 2
            picture[y][x] = THATCH[min(4, shade + (x > centre and shade < 4))]
            snowy.add((x, y))
        face_top[x] = foot_y + 1
    # The ridge: a roll of reed lying along the top of the roof, lit on its left, bound every few
    # rows. It narrows as it runs back into the picture and ends short of the back of the roof,
    # so it lies on the roof rather than standing up out of it.
    ridge_front, ridge_back = rake(centre), rake(centre) - depth + RIDGE_SHORT
    for y in range(ridge_back, ridge_front + 1):
        half_width = 2 + 4 * (y - ridge_back) / (ridge_front - ridge_back)
        is_binding = (ridge_front - y) % RIDGE_BINDING >= RIDGE_BINDING - 2
        for x in range(left, right + 1):
            offset = x - centre
            if abs(offset) > half_width:
                continue
            shade = 0 if offset < -half_width / 3 else 1 if offset < half_width / 3 else 3
            picture[y][x] = THATCH[min(4, shade + is_binding)]
            snowy.add((x, y))
    # The bargeboards: each runs from its eaves along the rake and on past the middle, so they
    # cross over the hip and end in horse heads.
    for side in (-1, 1):
        start = left if side < 0 else right
        reach = round((right - left) / 2) + 12
        for step in range(1, reach + 1):
            x = start - side * step
            line = round(eaves_y - step * slope)
            for row, colour in enumerate(BOARD):
                picture[line + 1 + row][x] = colour
                snowy.discard((x, line + 1 + row))
            below = line + 1 + len(BOARD)
            for shadow in (below, below + 1):
                if picture[shadow][x] not in BOARD:
                    picture[shadow][x] = "soil_dark"
                    snowy.discard((x, shadow))
            if abs(x - centre) >= hip_half:
                face_top[x] = max(face_top[x], below + 1)
        horse_head(picture, snowy, start - side * reach, round(eaves_y - reach * slope), -side)
    return face_top


# The white-painted bargeboards and their horse heads: lit, body, shade, from the top down.
BOARD = ("snow_light", "snow_light", "lime", "lime", "lime", "sand_light", "sand")
# A horse head carved on a board's end, looking right, from its top row down; the board comes in
# at the bottom left. "#" is the board's body, "o" its lit edge, "x" its shade, "e" the eye,
# "n" the nostril.
HORSE_HEAD = (
    "....oo...........",
    "....o#o..........",
    "....o##o.........",
    "...o####oo.......",
    "...o#ee####o.....",
    "..o#########o....",
    "..o##########oo..",
    ".o####xx#######o.",
    ".o###x..xx#####x.",
    "o###x.....xx#n#x.",
    "o###x.......xxxx.",
    "####x............",
    "###x.............",
    "##x..............",
    "#x...............",
)


def horse_head(picture, snowy, x, y, facing):
    """A horse head carved on the end of a bargeboard whose top edge ends at (x, y), looking
    right with `facing` 1 and left with -1, outlined in dark oak so it shows against the thatch
    and kept clear of snow."""
    colours = {"o": BOARD[0], "#": BOARD[2], "x": BOARD[6], "e": "soil_dark", "n": "sand"}
    head = {}
    for row, line in enumerate(HORSE_HEAD):
        for column, mark in enumerate(line):
            if mark in colours:
                head[x + facing * column, y - len(HORSE_HEAD) + 4 + row] = colours[mark]
    for hx, hy in head:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (hx + dx, hy + dy) not in head and picture[hy + dy][hx + dx] not in BOARD:
                picture[hy + dy][hx + dx] = "soil_dark"
                snowy.discard((hx + dx, hy + dy))
    for (hx, hy), colour in head.items():
        picture[hy][hx] = colour
        snowy.discard((hx, hy))


def herringbone(picture, rng, pixels, bricks, mortar):
    """Bricks laid slanting in columns 8 px wide, leaning one way in one column and the other way
    in the next, so their joints zigzag: the herringbone of a decorated gable."""
    colours = {}
    for x, y in pixels:
        band, offset = divmod(x, 8)
        if offset == 7:
            picture[y][x] = mortar
            continue
        diagonal = y + offset if band % 2 else y - offset
        if diagonal % 4 == 0:
            picture[y][x] = mortar
        else:
            picture[y][x] = colours.setdefault((band, diagonal // 4), rng.choice(bricks))


def diagonal_bricks(picture, rng, pixels, bricks, mortar, rising):
    """Bricks laid slanting all one way, parallel to a rake: rising to the right, or to the left
    with `rising` -1; a joint every 9 px along each course."""
    colours = {}
    for x, y in pixels:
        course = y + rising * x
        along = x + course // 3 * 4
        if course % 3 == 0 or along % 9 == 0:
            picture[y][x] = mortar
        else:
            picture[y][x] = colours.setdefault((course // 3, along // 9), rng.choice(bricks))


def grote_door(picture, left, right, top, spring, bottom):
    """The Grote Door of a hall house: two tall leaves of upright planks painted green, under a
    flat arch rising from `spring` at the sides to `top` in the middle, in a white frame, each
    leaf held by ledges with iron hinges; a stone threshold below."""
    centre = (left + right) / 2
    half = (right - left + 1) / 2
    right_leaf = (left + right + 1) // 2
    for x in range(left, right + 1):
        arch = spring - round((spring - top) * math.sqrt(max(0.0, 1 - ((x - centre) / half) ** 2)))
        rect(picture, x, arch - 2, x, arch - 1, "snow_light")
        leaf_left = left if x < right_leaf else right_leaf
        if x in (left, left + 1, right - 1, right):
            colour = "green_dark"
        elif x in (right_leaf - 1, right_leaf) or (x - leaf_left) % 7 == 6:
            colour = "green_deep"
        else:
            colour = "green_light" if (x - leaf_left) % 7 == 0 else "green"
        rect(picture, x, arch, x, bottom, colour)
    for y in (spring + 8, (spring + bottom) // 2 + 6, bottom - 10):
        rect(picture, left + 2, y, right - 2, y + 2, "green")
        rect(picture, left + 2, y, right - 2, y, "green_light")
        rect(picture, left + 2, y + 3, right - 2, y + 3, "green_deep")
        rect(picture, left + 2, y + 1, left + 9, y + 1, "stone_dark")
        rect(picture, right - 9, y + 1, right - 2, y + 1, "stone_dark")
    rect(picture, left - 3, top - 2, left - 1, bottom, "snow_light")
    rect(picture, right + 1, top - 2, right + 3, bottom, "lime")
    rect(picture, right_leaf - 6, (spring + bottom) // 2, right_leaf - 4, (spring + bottom) // 2 + 1, "gold")
    rect(picture, left - 4, bottom + 1, right + 4, bottom + 2, "stone_light")
    rect(picture, left - 4, bottom + 3, right + 4, bottom + 4, "stone")


def hall_house(is_lit):
    """The Low German hall house (Niedersachsenhaus) on 7x5 tiles, its gable end to the front:
    the big arched barn door (Grote Door) in the middle under a carved oak beam, oak framing
    with red brick in it, laid in herringbone and slanting courses in the gable, and the top of
    the gable boarded, with the owl hole (Uhlenloch) under the little hip. A huge half-hipped
    thatch runs back from it, with a reed ridge, and white bargeboards cross over the hip in a
    pair of horse heads. Small stable windows to either side of the door."""
    rng = random.Random(385)
    width, height = 7 * GAME_TILE, 272
    picture = blank(width, height)
    snowy = set()
    # The rows of the gable, top down: the foot of the hip, where the gable starts; the beam
    # across the gable, with the boarded top above it; the beam over the door; the rail of the
    # side bays; the fieldstone base.
    gable_top = 108
    gable_beam = (128, 133)
    door_beam = (164, 171)
    rail = 208
    base_top = height - 14
    wall_left, wall_right = 6, width - 7
    # The posts of the oak frame, the stout posts either side of the door, and the door between.
    posts = (wall_left, 40, 110, 180, wall_right - 3)
    door_posts = (74, 144)
    door_left, door_right = 84, 139
    face_top = gable_roof(picture, snowy, rng, 0, width - 1, 212, gable_top, 26, 68)
    # The gable is drawn whole on a picture of its own, and shows below the roof and the boards.
    gable = blank(width, height)
    brick_wall(gable, rng, wall_left, wall_right, gable_top, base_top - 1, RED_BRICKS, "sand")
    # The upper gable, between its beams: brick in herringbone between the door posts, slanting
    # with the rakes in the bays beside them.
    panel_rows = range(gable_beam[1], door_beam[0])
    herringbone(gable, rng, [(x, y) for x in range(80, 144) for y in panel_rows], RED_BRICKS, "sand")
    for x0, x1, rising in ((44, 74, 1), (148, 178, -1)):
        diagonal_bricks(gable, rng, [(x, y) for x in range(x0, x1 + 1) for y in panel_rows], RED_BRICKS, "sand", rising)
    # The top of the gable boarded in oak, with the owl hole in it.
    for x in range(wall_left, wall_right + 1):
        board = (x - wall_left) % 8
        colour = "soil_light" if board == 0 else "soil" if board == 7 else "soil_mid"
        rect(gable, x, gable_top, x, gable_beam[0] - 1, colour)
    for row in range(10):
        rect(gable, 111 - row, gable_top + 5 + row, 112 + row, gable_top + 5 + row, "ink")
    rect(gable, 101, gable_top + 15, 122, gable_top + 15, "soil_light")
    # The oak frame: the sill, the posts, a rail in the side bays, short braces in the corner
    # bays, the beam over the door (carved) and the gable's beam.
    rect(gable, wall_left, base_top - 4, wall_right, base_top - 1, OAK[1])
    rect(gable, wall_left, base_top - 4, wall_right, base_top - 4, OAK[0])
    rect(gable, wall_left, base_top - 1, wall_right, base_top - 1, OAK[2])
    for x in posts:
        rect(gable, x, gable_beam[0], x + 3, base_top - 1, OAK[1])
        rect(gable, x, gable_beam[0], x, base_top - 1, OAK[0])
        rect(gable, x + 3, gable_beam[0], x + 3, base_top - 1, OAK[2])
    for x in door_posts:
        rect(gable, x, gable_beam[0], x + 5, base_top - 1, OAK[1])
        rect(gable, x, gable_beam[0], x + 1, base_top - 1, OAK[0])
        rect(gable, x + 5, gable_beam[0], x + 5, base_top - 1, OAK[2])
    for x0, x1 in ((wall_left, door_posts[0]), (door_posts[1], wall_right)):
        rect(gable, x0, rail, x1, rail + 3, OAK[1])
        rect(gable, x0, rail, x1, rail, OAK[0])
        rect(gable, x0, rail + 3, x1, rail + 3, OAK[2])
    for x0, direction in ((10, -1), (184, 1)):
        for step in range(28):
            bx = x0 + step if direction > 0 else x0 + 27 - step
            for dx, colour in enumerate((OAK[0], OAK[1], OAK[1], OAK[2])):
                gable[base_top - 6 - step][bx + dx] = colour
    for top, bottom in (gable_beam, door_beam):
        rect(gable, wall_left, top, wall_right, bottom, OAK[1])
        rect(gable, wall_left, top, wall_right, top, OAK[0])
        rect(gable, wall_left, bottom, wall_right, bottom, OAK[2])
    # A line cut into the door beam, as the farmer and his wife had their names and the year
    # carved there.
    x = door_left + 2
    while x < door_right - 2:
        letter = rng.randint(2, 4)
        rect(gable, x, door_beam[1] - 3, x + letter - 1, door_beam[1] - 3, "soil_light")
        if rng.random() < 0.6:
            rect(gable, x, door_beam[1] - 5, x, door_beam[1] - 4, "soil_light")
        if rng.random() < 0.3:
            gable[door_beam[1] - 5][x + letter - 1] = "soil_light"
        x += letter + rng.choice((1, 2, 2, 4))
    fieldstone_base(gable, rng, wall_left, wall_right, base_top, height - 3)
    for left in (48, 156):
        window(gable, left, 180, 3, 3, is_lit, frame="green_dark")
    grote_door(gable, door_left, door_right, door_beam[1] + 4, door_beam[1] + 18, height - 6)
    for x, top in face_top.items():
        for y in range(top, height):
            if gable[y][x] is not None:
                picture[y][x] = gable[y][x]
    eaves_shadow(picture, {x: y - 1 for x, y in face_top.items()}, wall_left, wall_right)
    outline_edge(picture, THATCH[4], keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


# How to draw each building (is_lit to the picture and the pixels snow covers), by its id in
# data/buildings.cfg.
PICTURES = {
    "shack": shack,
    "fisher_hut": fisher_hut,
    "kate": kate,
    "longhouse": longhouse,
    "barn": barn,
    "hall_house": hall_house,
}
