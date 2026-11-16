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


def tarred_foot(picture, rng, left, right, top, bottom):
    """The foot of a wall tarred black against the splash, as on the Geest instead of
    fieldstones: a lit lip along its top, and runs of the tar's blue-grey sheen and of thinner,
    browner tar across it."""
    rect(picture, left, top, right, bottom, "ink")
    rect(picture, left, top, right, top, "stone_dark")
    rect(picture, left, top + 1, right, top + 1, "mud_dark")
    for y in range(top + 3, bottom + 1, 2):
        x = left + rng.randrange(8)
        while x <= right:
            run = rng.randint(4, 12)
            colour = "stone_dark" if rng.random() < 0.5 else "soil_dark"
            rect(picture, x, y, min(right, x + run - 1), y, colour)
            x += run + rng.randint(8, 20)


def kate(is_lit, walls="fieldstone"):
    """A small cottage on 5x3 tiles, a big eyebrow dormer in the middle of the roof, the thatch
    swelling up over the door. `walls` gives its look: "fieldstone", white lime walls on
    fieldstones, a teal split door and braced teal shutters, a small white chimney and crossed
    sticks on the ridge; "brick", red brick in sand joints on the fieldstones with white frames,
    green door and shutters and a brick chimney; "geest", the lime wash over a black tarred foot
    under a turf ridge."""
    rng = random.Random(381)
    width, height = 5 * GAME_TILE, 192
    picture = blank(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 6, width - 7, 102, height - 14
    if walls == "brick":
        bottom = base_top - 1
        brick_wall(picture, rng, wall_left, wall_right, wall_top, bottom, KATE_BRICKS, "sand")
    else:
        lime_wall(picture, rng, wall_left, wall_right, wall_top, base_top - 1)
    if walls == "geest":
        tarred_foot(picture, rng, wall_left, wall_right, base_top, height - 3)
    else:
        fieldstone_base(picture, rng, wall_left, wall_right, base_top, height - 3)
    paint = GREEN if walls == "brick" else TEAL
    for left in (25, 116):
        window(picture, left, 140, 3, 3, is_lit, shutters=paint)
    door(picture, 67, 126, height - 6, 26, paint)
    eaves = thatch_roof(picture, snowy, rng, 0, width - 1, 22, 122, 44, swells=((80, 26, 12),))
    if walls == "geest":
        turf_ridge(picture, snowy, 44, width - 45, 22)
    else:
        crossed_ridge(picture, snowy, 44, width - 45, 22)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    eyebrow(picture, snowy, 80, 86, 32, is_lit)
    if walls == "brick":
        brick_chimney = ("red_light", "rust", "rust_dark")
        chimney(picture, snowy, 104, 6, 30, brick_chimney, bricks=KATE_BRICKS)
    else:
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


# How to draw each building (is_lit to the picture and the pixels snow covers), by its id in
# data/buildings.cfg; a style's as <building>_<style>.
PICTURES = {
    "kate": kate,
    "kate_brick": lambda is_lit: kate(is_lit, walls="brick"),
    "kate_geest": lambda is_lit: kate(is_lit, walls="geest"),
    "longhouse": longhouse,
    "barn": barn,
}
