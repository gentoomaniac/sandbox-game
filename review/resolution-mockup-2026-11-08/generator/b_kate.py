"""Version B Kate at 32 px per tile: 160x192, the same cottage as tools/art/buildings.py `kate`
with twice the pixels. The thatch keeps its courses, now 7 px high with a lit top, reed-end
strokes and a shadow under each; the rolled eaves are 12 rows deep; the windows have 3x3 real
panes with a glint; the door is a Klöntür of planks with strap hinges; the fieldstones are
round and each lit on its own."""

import math
import random

from b_core import NAMES, c, new

THATCH = ("sand", "bare_light", "bare", "mud_dark", "soil_dark")
MOSS = ("green_light", "dry", "olive", "green_dark")
COURSE = 7
EAVES_ROWS = 12
EAVES_CORNER = 12
GLASS = ("foam", "water_light", "water", "water_deep")


def rect(p, x0, y0, x1, y1, name):
    p[max(0, y0):y1 + 1, max(0, x0):x1 + 1] = c(name)


def setp(p, x, y, name):
    if 0 <= x < p.shape[1] and 0 <= y < p.shape[0]:
        p[y, x] = c(name)


def course_make(rng, first, last):
    """One course: how its lower edge waves, where its lit top shows, and the reed ends."""
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


def thatch_roof(p, rng, left, right, ridge_y, eaves_y, inset, swell=None):
    height = eaves_y - ridge_y
    hip_foot = round(inset * 0.5)
    eaves, lifts = {}, {}
    for x in range(left, right + 1):
        lift = 0
        if swell:
            cx, half, rise = swell
            if abs(x - cx) < half:
                lift = rise * math.cos((x - cx) / half * math.pi / 2) ** 2
        lifts[x] = lift
        corner = min(x - left, right - x)
        upturn = 0
        if corner < EAVES_CORNER:
            upturn = round(EAVES_CORNER - math.sqrt(EAVES_CORNER ** 2 - (EAVES_CORNER - corner) ** 2))
        eaves[x] = eaves_y - round(lift) - upturn
    courses = [course_make(rng, left, right) for _ in range(height // COURSE + 3)]
    ragged = {}
    x = left
    while x <= right:
        run = rng.randint(2, 5)
        ragged.update(dict.fromkeys(range(x, x + run), rng.randrange(3)))
        x += run
    patches = [(rng.uniform(left + 26, right - 26), rng.uniform(ridge_y + height * 0.5, eaves_y - 16),
                rng.uniform(4, 7)) for _ in range(6)]
    patch_noise = {}
    # Rows of the rolled eaves from the bottom up: the dark underside with a ragged hem, the
    # shadowed round, the lit lip, then the reed running into the first course.
    roll = (4, 4, 4, 3, 3, 3, 2, 2, 1, 1, 0, 1)
    for y in range(ridge_y, eaves_y + 1):
        t = (y - ridge_y) / height
        reach = inset * (1 - t) ** 1.5 + max(0, 3 - (y - ridge_y))
        hip = inset * (1 - t) ** 1.5 + hip_foot * t
        for x in range(left, right + 1):
            if x < left + reach or x > right - reach or y > eaves[x]:
                continue
            plane = 1 if x < left + hip else 3 if x > right - hip else 2
            from_eaves = eaves[x] - y
            if from_eaves < EAVES_ROWS:
                shade = roll[from_eaves]
                if from_eaves < 3 and ragged[x] < from_eaves:
                    shade = 4
                if plane == 3 and from_eaves > 3:
                    shade += 1
                if plane == 1 and from_eaves > 5:
                    shade -= 1
                name = THATCH[max(0, min(4, shade))]
            else:
                along = round(eaves_y - y - lifts[x] * t ** 5) - EAVES_ROWS
                along += courses[max(0, along) // COURSE][0][x]
                course, row = divmod(max(0, along), COURSE)
                _, lit, reed = courses[course]
                is_lit = (row == COURSE - 1 and lit[x]) or (plane == 1 and x + 1 >= left + hip)
                top_glint = row == COURSE - 2 and lit[x] and plane == 1
                # The reed ends of the course above hang over this one's shadow line in places,
                # so the line under each course is ragged, not ruled.
                shadow = row == 0 and reed.get(x, 0) < 4
                hangs = COURSE - 2 - row < reed.get(x, 0)
                tone = plane - 1 if is_lit or top_glint else plane
                if shadow:
                    tone = min(4, plane + 1)
                elif not is_lit and hangs and plane > 1:
                    tone = plane + 1
                name = THATCH[min(4, tone)]
                for mx, my, radius in patches:
                    d = math.hypot(x - mx, (y - my) * 1.6)
                    key = (x, y)
                    if key not in patch_noise:
                        patch_noise[key] = rng.random()
                    if d < radius - 1.5 or (d < radius and patch_noise[key] < 0.5):
                        name = MOSS[min(3, max(0, tone - (1 if row >= COURSE - 2 else 0)))]
            setp(p, x, y, name)
    return eaves


def crossed_ridge(p, left, right, y):
    """The ridge capped with straw and held by crossed split-oak sticks, every 12 px."""
    rect(p, left, y, right, y + 4, "umber")
    rect(p, left, y, right, y, "ochre_dark")
    rect(p, left, y + 5, right, y + 6, "soil_dark")
    for x in range(left + 2, right - 9, 12):
        for step in range(10):
            lit = step < 5
            for dx in (0, 1):
                setp(p, x + step + dx, y - 5 + step, "soil_light" if lit else "soil_mid")
                setp(p, x + 9 - step + dx, y - 5 + step, "soil_mid" if lit else "soil")
        setp(p, x + 4, y - 1, "soil_dark")
        setp(p, x + 5, y - 1, "soil_dark")


def chimney(p, left, top, bottom):
    """A square lime-washed chimney lit on the left, a cap of two courses, soot at the top."""
    rect(p, left, top, left + 11, bottom, "lime")
    rect(p, left, top, left + 2, bottom, "snow_light")
    rect(p, left + 9, top, left + 11, bottom, "sand_light")
    rect(p, left - 2, top, left + 13, top + 3, "snow_light")
    rect(p, left - 2, top + 2, left + 13, top + 3, "sand_light")
    rect(p, left + 11, top, left + 13, top + 3, "sand_light")
    rect(p, left + 1, top - 2, left + 10, top - 1, "stone_dark")
    rect(p, left + 3, top - 2, left + 8, top - 2, "ink")
    for y in range(top + 6, bottom, 5):
        rect(p, left + 3, y, left + 6, y, "sand_light")


def glass(x, y, x0, y0, w, h):
    """A pane: a pale glint in its top left corner, sky reflection, darker to the bottom right."""
    fx, fy = (x - x0) / w, (y - y0) / h
    if fx + fy < 0.35:
        return GLASS[0] if fx + fy < 0.18 else GLASS[1]
    if fx + fy < 1.1:
        return GLASS[2]
    return GLASS[3]


def window(p, left, top, size=19):
    """A white frame with 3x3 panes of 5 px in 1 px glazing bars, a sill, teal shutters."""
    rect(p, left - 2, top - 2, left + size + 1, top + size + 1, "soil_dark")
    rect(p, left - 1, top - 1, left + size, top + size, "snow_light")
    for y in range(top, top + size):
        for x in range(left, left + size):
            if (x - left) % 6 == 0 or (y - top) % 6 == 0:
                setp(p, x, y, "snow_light")
            else:
                px0 = left + (x - left) // 6 * 6 + 1
                py0 = top + (y - top) // 6 * 6 + 1
                setp(p, x, y, glass(x, y, px0, py0, 5, 5))
    # The frame's inner shade on the right and bottom.
    rect(p, left + size - 1, top, left + size - 1, top + size - 1, "lime")
    rect(p, left, top + size - 1, left + size - 1, top + size - 1, "lime")
    # Sill.
    rect(p, left - 4, top + size + 1, left + size + 3, top + size + 2, "snow_light")
    rect(p, left - 3, top + size + 3, left + size + 2, top + size + 3, "stone")
    for x0 in (left - 10, left + size + 2):
        rect(p, x0, top - 2, x0 + 7, top + size + 1, "paint_teal")
        rect(p, x0 + 6, top - 2, x0 + 7, top + size + 1, "water")
        rect(p, x0, top - 2, x0 + 7, top - 2, "water_light")
        for bx in (x0 + 2, x0 + 4):
            rect(p, bx, top - 1, bx, top + size + 1, "water")
        # The Z brace and the iron hinges.
        rect(p, x0, top + 2, x0 + 7, top + 3, "water")
        rect(p, x0, top + size - 4, x0 + 7, top + size - 3, "water")
        for k in range(size - 8):
            setp(p, x0 + 1 + k * 6 // (size - 8), top + size - 5 - k, "water")
        rect(p, x0 - 1, top - 2, x0 - 1, top + size + 1, "soil_dark")
        rect(p, x0 + 8, top - 2, x0 + 8, top + size + 1, "soil_dark")
        hinge_x = x0 + 6 if x0 < left else x0 + 1
        for hy in (top + 2, top + size - 4):
            setp(p, hinge_x, hy, "ink")


def door(p, left, top, bottom, width):
    """A Klöntür: a door of upright teal planks split in two halves, an iron strap hinge on each,
    a brass knob, a white frame and a stone step."""
    rect(p, left - 2, top - 2, left + width + 1, bottom, "snow_light")
    rect(p, left + width, top - 1, left + width + 1, bottom, "lime")
    for y in range(top, bottom + 1):
        for x in range(left, left + width):
            i = x - left
            name = "water" if i % 6 == 5 else "water_light" if i % 6 == 0 else "paint_teal"
            if i >= width - 3:
                name = "water"
            setp(p, x, y, name)
    mid = (top + bottom) // 2
    rect(p, left, mid, left + width - 1, mid, "water_deep")
    rect(p, left, mid + 1, left + width - 1, mid + 1, "water_light")
    for hy in (top + 5, mid + 6):
        rect(p, left, hy, left + width - 8, hy + 1, "stone_dark")
        rect(p, left, hy, left + width - 8, hy, "stone")
        setp(p, left + width - 8, hy + 1, "ink")
    rect(p, left + width - 5, mid - 4, left + width - 4, mid - 3, "gold")
    setp(p, left + width - 4, mid - 3, "ochre_dark")
    rect(p, left - 4, bottom + 1, left + width + 3, bottom + 2, "stone_light")
    rect(p, left - 4, bottom + 3, left + width + 3, bottom + 4, "stone")


def eyebrow(p, cx, bottom, width, roof):
    """The eyebrow dormer: the thatch swells in a wave over a half-round window with small
    panes; the swell is lit along its crest and shades the window."""
    half = width // 2
    arch = half * 2 // 3
    crest_rows = (THATCH[1], THATCH[0], THATCH[0], THATCH[1], THATCH[1], THATCH[2], THATCH[3], THATCH[3])
    for x in range(cx - half - 12, cx + half + 12):
        offset = min(1.0, abs(x + 0.5 - cx) / (half + 12))
        crest = bottom - arch - 4 - round(8 * math.cos(offset * math.pi / 2) ** 2)
        for row, name in enumerate(crest_rows):
            y = crest + row
            if roof[y, x] and y < bottom:
                if x >= cx + half:
                    name = THATCH[min(4, THATCH.index(name) + 1)]
                setp(p, x, y, name)
    for y in range(bottom - arch - 1, bottom + 1):
        for x in range(cx - half, cx + half):
            d = math.hypot(x + 0.5 - cx, (bottom - y) * half / (arch + 1))
            if d > half:
                continue
            if d > half - 2 or y >= bottom - 1 or (x - cx) % 5 == 2 or (bottom - y) % 5 == 4:
                setp(p, x, y, "snow_light")
            else:
                fx = (x - (cx - half)) / width
                fy = (y - (bottom - arch)) / arch
                setp(p, x, y, GLASS[1] if fx + fy < 0.5 else GLASS[2] if fx + fy < 1.1 else GLASS[3])
    # The shade the swell casts over the top of the window.
    for x in range(cx - half, cx + half):
        for y in range(bottom - arch - 3, bottom):
            d = math.hypot(x + 0.5 - cx, (bottom - y) * half / (arch + 1))
            if half - 3 < d <= half - 2 and y < bottom - arch // 2:
                setp(p, x, y, "stone")
    rect(p, cx - half - 1, bottom + 1, cx + half, bottom + 2, THATCH[4])


def fieldstones(p, rng, left, right, top, bottom):
    """Round fieldstones of mixed sizes in dark joints, each a little dome lit on its top left,
    a warm and a cool kind, moss low on a few."""
    rect(p, left, top, right, bottom, "mud_dark")
    y, row = top, 0
    while y <= bottom:
        sh = min(rng.randint(5, 7), bottom - y + 1)
        x = left + (row % 2) * 4 - 3
        while x <= right:
            sw = rng.randint(8, 13)
            warm = rng.random() < 0.35
            ramp = ("stone_dark", "bare", "bare_light", "stone_light") if warm else \
                ("stone_dark", "stone", "stone_light", "stone_light")
            cx, cy = x + (sw - 2) / 2, y + (sh - 2) / 2
            for sy in range(y, y + sh - 1):
                for sx in range(max(left, x), min(right, x + sw - 2) + 1):
                    dx, dy = (sx + 0.5 - cx) / ((sw - 1) / 2), (sy + 0.5 - cy) / ((sh - 1) / 2)
                    r = dx * dx + dy * dy
                    if r > 1.05:
                        continue
                    lit = -dx * 0.6 - dy * 0.8
                    shade = 3 if lit > 0.55 and r > 0.15 else 2 if lit > -0.1 else 1 if lit > -0.6 or r < 0.6 else 0
                    setp(p, sx, sy, ramp[shade])
            if rng.random() < 0.25 and sy > top + 4:
                setp(p, x + 1, y + sh - 3, "olive")
                setp(p, x + 2, y + sh - 2, "green_dark")
            x += sw
        y += sh
        row += 1


def kate():
    rng = random.Random(381)
    w, h = 160, 192
    p = new(w, h)
    wall_left, wall_right, wall_top, base_top = 6, w - 7, 118, 177
    rect(p, wall_left, wall_top, wall_right, base_top - 1, "lime")
    rect(p, wall_right - 3, wall_top, wall_right, base_top - 1, "sand_light")
    # Lime-wash: almost flat; a few flakes, and the splash of the rain darkening it low down.
    for _ in range(26):
        x, y = rng.randint(wall_left + 2, wall_right - 5), rng.randint(wall_top + 14, base_top - 2)
        setp(p, x, y, "sand_light")
        if rng.random() < 0.4:
            setp(p, x + 1, y, "sand_light")
    for x in range(wall_left, wall_right + 1):
        for y in range(base_top - 3, base_top):
            if rng.random() < 0.1 + (y - base_top + 3) * 0.25:
                setp(p, x, y, "sand_light")
    fieldstones(p, rng, wall_left, wall_right, base_top, h - 3)
    for wx in (25, 115):
        window(p, wx, 138)
    door(p, 68, 134, h - 6, 24)
    roof = new(w, h)
    eaves = thatch_roof(roof, rng, 0, w - 1, 22, 125, 44, swell=(80, 22, 4))
    on = roof >= 0
    p[on] = roof[on]
    crossed_ridge(p, 44, w - 45, 22)
    # Under the eaves the wall lies in their shadow: two shades right under them, one below.
    shaded = {"lime": "sand_light", "sand_light": "sand", "snow_light": "lime", "paint_teal": "water",
              "water_light": "water", "water": "water_deep"}
    for x in range(wall_left, wall_right + 1):
        for y, steps in ((eaves[x] + 1, 2), (eaves[x] + 2, 2), (eaves[x] + 3, 1), (eaves[x] + 4, 1),
                         (eaves[x] + 5, 1)):
            for _ in range(steps):
                v = p[y, x]
                if v >= 0 and NAMES[v] in shaded:
                    p[y, x] = c(shaded[NAMES[v]])
    eyebrow(p, 80, 92, 32, on)
    chimney(p, 104, 6, 28)
    p = outline_border(p, THATCH[4])
    # The ground shadow along the foot of the house.
    for x in range(2, w - 2):
        if p[h - 1, x] < 0:
            p[h - 1, x] = c("green_deep")
        if p[h - 2, x] < 0:
            p[h - 2, x] = c("green_deep")
    return p


def outline_border(p, name):
    """The picture's own border pixels (next to clear ones) take `name`; the bottom stays."""
    on = p >= 0
    inner = on.copy()
    inner[1:, :] &= on[:-1, :]
    inner[:-1, :] &= on[1:, :]
    inner[:, 1:] &= on[:, :-1]
    inner[:, :-1] &= on[:, 1:]
    border = on & ~inner
    border[-3:, :] = False
    out = p.copy()
    out[border] = c(name)
    return out

