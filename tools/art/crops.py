"""Art for the crops: a picture sheet per crop, drawn at the game's 32 px per tile.

A crop's sheet (assets/crops/<crop>.png, named by `sheet` in data/crops.cfg) has its four growth
stages and then the dead one side by side. Every cell is a tile wide and as tall as the sheet:
a tall crop (wheat, rye, buckwheat, peas, beans, flax) has a sheet two tiles tall, with its bottom on the bottom
of its tile. A crop looks the same in every season, so the seasons never touch these.

The plants stand on the lowest ridge of the tilled soil (terrain.py draws a crest every 8 rows,
the lowest at row 24 of a tile), their feet `FOOT` rows above the cell's bottom, on a shadow of
dark earth. Leaves, heads, roots and fruit are rounded forms lit from the top left (forms.py),
rimmed in the darkest shade of their own colours, never in ink: the dark soil around them sets
them off. Stalks, awns, flowers and tendrils are drawn over them without a rim.
"""

import math

import forms
from canvas import GAME_TILE, blank

STAGES = 4
WIDTH = GAME_TILE
SHORT = GAME_TILE
TALL = 2 * GAME_TILE
CENTRE = WIDTH / 2
# How far above a cell's bottom the plants stand: on the slope of the tile's lowest ridge.
FOOT = 4

# Ramps, dark to light, as forms.shade takes them.
GREENS = ("green_deep", "green_dark", "green", "green_light")
BRIGHT_GREENS = ("green_dark", "green", "green_light", "green_bright")
SHADED_GREENS = ("green_deep", "green_deep", "green_dark", "green")
SOIL = ("soil", "soil_mid", "soil_mid", "soil_light")
# Freshly turned earth: dark, with cream seeds and an outline, so it stands out on every moisture
# step of the bed (on the wettest the bed is darker; the seeds and the lit top carry it).
MOUND_SOIL = ("soil_dark", "soil", "soil", "soil_mid")
TUBER = ("mud", "sand", "sand_light")
WITHERING = ("olive", "dry", "dry_light", "straw")

# The darkest shade of each colour's own ramp: the rim of a form of that colour.
RIMS = {
    **dict.fromkeys(("green_bright", "green_light", "green", "green_dark", "olive"), "green_deep"),
    **dict.fromkeys(("meadow", "meadow_light"), "green_deep"),
    **dict.fromkeys(("dry", "dry_light"), "olive"),
    **dict.fromkeys(("soil_light", "soil_mid", "soil"), "soil_dark"),
    **dict.fromkeys(("sand_light", "sand", "mud"), "mud_dark"),
    **dict.fromkeys(("lime", "cream", "petal", "heather"), "heather_dark"),
    **dict.fromkeys(("gold", "flame", "ember"), "rust_dark"),
    **dict.fromkeys(("straw", "reed", "ochre", "ochre_dark"), "umber"),
    "red_light": "rust_dark",
}

# What the colours of a crop turn into when it dies: greens and flowers go brown and grey.
DEAD_COLOURS = {
    "green_bright": "sand",
    "green_light": "mud",
    "green": "mud_dark",
    "green_dark": "soil_dark",
    "green_deep": "soil_dark",
    "meadow_light": "mud",
    "meadow": "mud_dark",
    "olive": "mud_dark",
    "dry_light": "sand",
    "dry": "mud",
    "cream": "sand_light",
    "lime": "sand_light",
    "gold": "sand",
    "flame": "mud",
    "ember": "mud_dark",
    "heather": "mud_dark",
    "heather_dark": "soil_dark",
    "petal": "sand",
    "blossom": "sand_light",
    "foam": "sand_light",
    "water_light": "sand",
    "rust_dark": "soil_dark",
    "russet_deep": "soil_dark",
    "red_light": "mud",
}


# Drawing ----------------------------------------------------------------------------------------


def cell(height=SHORT):
    """A clear cell of a crop's sheet."""
    return blank(WIDTH, height)


def foot(picture):
    """The row the plants of a cell stand on."""
    return len(picture) - FOOT


def mask(picture, shape, *numbers):
    """The forms.py mask `shape` (a function) of the size of the picture."""
    return shape(len(picture[0]), len(picture), *numbers)


def pixel(picture, x, y, colour):
    forms.dots(picture, [(round(x), round(y))], colour)


def line(picture, x0, y0, x1, y1, colour, bend=0.0):
    """A one pixel line, bowed sideways by `bend` pixels in its middle."""
    steps = math.ceil(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for step in range(steps + 1):
        t = step / steps
        pixel(picture, x0 + (x1 - x0) * t + bend * math.sin(t * math.pi), y0 + (y1 - y0) * t, colour)


def paste(picture, layer):
    """Draws the drawn pixels of `layer` (as big as the picture) over the picture."""
    for y, row in enumerate(layer):
        for x, colour in enumerate(row):
            if colour is not None:
                picture[y][x] = colour
    return picture


def rimmed(layer):
    """Gives the border pixels of `layer` the darkest shade of their own colours (RIMS)."""
    for y, x in zip(*forms.edge(forms.drawn(layer)).nonzero()):
        layer[y][x] = RIMS.get(layer[y][x], layer[y][x])
    return layer


def shadow(picture, half_width, centre=CENTRE):
    """A shadow of dark earth on the ground under a plant, its ends dithered; drawn first."""
    ground = foot(picture)
    for y in range(ground - 1, ground + 3):
        across = (y - ground - 0.5) / 2
        reach = half_width * math.sqrt(max(0.0, 1 - across * across))
        for x in range(math.floor(centre - reach), math.ceil(centre + reach)):
            if abs(x + 0.5 - centre) < reach - 1.5 or (x + y) % 2 == 0:
                pixel(picture, x, y, "soil_dark")


def leaf(picture, base, tip, width, ramp=GREENS, rib=None):
    """A leaf from its base to its tip, `width` px wide in the middle, shaded as a rounded form,
    with a midrib in `rib` from the base most of the way to the tip."""
    (x0, y0), (x1, y1) = base, tip
    length = math.hypot(x1 - x0, y1 - y0)
    angle = math.degrees(math.atan2(y0 - y1, x1 - x0))
    shape = mask(picture, forms.ellipse, (x0 + x1) / 2, (y0 + y1) / 2, length / 2 + 0.5, width / 2, angle)
    forms.shade(picture, shape, ramp, radius=2)
    if rib:
        line(picture, x0 + (x1 - x0) * 0.1, y0 + (y1 - y0) * 0.1, x0 + (x1 - x0) * 0.75, y0 + (y1 - y0) * 0.75, rib)


def fanned(picture, base, leaves, ramp=GREENS, rib=None):
    """Leaves fanning out of one base, each as (angle from upright in degrees, + to the right,
    length, width); drawn in order, so the last ones are in front."""
    x0, y0 = base
    for angle, length, width in leaves:
        turn = math.radians(angle)
        leaf(picture, base, (x0 + length * math.sin(turn), y0 - length * math.cos(turn)), width, ramp, rib)


def ball(picture, cx, cy, rx, ry, ramp, radius=3):
    """A round form (a root, a bulb, a fruit) shaded from the top left."""
    forms.shade(picture, mask(picture, forms.ellipse, cx, cy, rx, ry), ramp, radius=radius)


def blade(picture, x0, y0, height, lean, shades, droop=0.0):
    """A grass-like blade from its foot (x0, y0), curving over by `lean` and drooping by `droop`
    at its tip: two pixels wide in its lower half, its left side lit (`shades` are dark, mid
    and light), one pixel wide above."""
    dark, mid, light = shades
    steps = round(height * 1.5) + 1
    for step in range(steps):
        t = step / steps
        x, y = x0 + lean * t * t, y0 - height * t + droop * t**4
        if t < 0.5:
            pixel(picture, x, y, light if t > 0.15 else mid)
            pixel(picture, x + 1, y, dark)
        else:
            pixel(picture, x, y, mid if t < 0.85 else light)


def mound(picture, centre=CENTRE):
    """A low drill of dark, fresh earth over the seed, lit on its top left, so that sown soil
    reads against the bed at a glance."""
    ground = foot(picture)
    layer = cell(len(picture))
    forms.shade(layer, mask(layer, forms.ellipse, centre, ground + 0.5, 10.5, 4.0), MOUND_SOIL, radius=2)
    rimmed(layer)
    forms.dots(layer, [(round(centre) - 5, ground - 1), (round(centre) - 1, ground - 2), (round(centre) + 4, ground - 1)], "soil_light")
    paste(picture, layer)


def sown(height=SHORT):
    """The first stage of every crop: the seed under its mound."""
    picture = cell(height)
    mound(picture)
    forms.dots(picture, [(12, foot(picture)), (15, foot(picture) - 1), (18, foot(picture) + 1), (20, foot(picture))], "cream")
    return picture


def seedling(picture, x, size=1.3, ramp=BRIGHT_GREENS, stem="green"):
    """A sprout with its two seed leaves on the mound, `size` times the usual."""
    ground = foot(picture) - 1
    top = ground - round(4 * size)
    line(picture, x, ground, x, top, stem)
    layer = cell(len(picture))
    leaf(layer, (x, top), (x - 4 * size, top - 2 * size), 3 * size, ramp)
    leaf(layer, (x, top), (x + 4 * size, top - 2.5 * size), 3 * size, ramp)
    paste(picture, rimmed(layer))


def sprouts(height=SHORT, size=1.3, ramp=BRIGHT_GREENS, stem="green"):
    """Stage one of the leafy crops: the mound with a seedling on it."""
    picture = sown(height)
    seedling(picture, 16, size, ramp, stem)
    return picture


# The crops --------------------------------------------------------------------------------------


def turnip():
    """Rough bright leaves in a rosette, and at last the white root with its purple shoulder
    pushing out of the soil."""
    leaves = ((-62, 13, 6), (62, 13, 6), (-35, 16, 6), (35, 16, 6), (-10, 18, 7), (12, 17, 7))

    def rosette(picture, base, scale):
        layer = cell()
        shadow(picture, 9 * scale)
        fanned(layer, base, [(a, length * scale, width * min(1.0, scale + 0.2)) for a, length, width in leaves], GREENS, "green_light")
        paste(picture, rimmed(layer))

    young = sown()
    rosette(young, (16, foot(young) - 1), 0.6)
    leafy = cell()
    rosette(leafy, (16, foot(leafy) - 1), 1.0)
    ripe = cell()
    shadow(ripe, 11)
    root = cell()
    ball(root, 16, 22.5, 7, 6, ("sand_light", "lime", "lime", "cream"))
    # The shoulder that was in the light is purple, the part that was in the soil white.
    for y in range(16, 22):
        for x in range(9, 24):
            if root[y][x] is not None:
                root[y][x] = {"cream": "petal", "lime": "heather", "sand_light": "heather_dark"}.get(root[y][x], root[y][x])
    line(root, 16, 28, 16, 31, "cream")
    paste(ripe, rimmed(root))
    top = cell()
    fanned(top, (16, 17), [(a, length * 0.8, width) for a, length, width in leaves], GREENS, "green_light")
    paste(ripe, rimmed(top))
    return [sown(), young, leafy, ripe], 2


def potato():
    """A bush of small leaflets that flowers white and yellow, and when ripe dies back yellow,
    the tubers showing in the earth."""

    def bush(picture, half_width, height, ramp):
        """A dome of small leaflets, lit as one form, each leaflet's lower edge dark so that
        they stand apart; drawn from the top down, so the lower ones are in front."""
        ground = foot(picture)
        leaflets = []
        for row in range(5):
            t = row / 4
            y = ground - height * (0.8 - 0.65 * t)
            reach = half_width * (0.4 + 0.6 * math.sqrt(t))
            x = 16 - reach + (row % 2) * 2
            while x <= 16 + reach:
                leaflets.append(mask(picture, forms.ellipse, x, y, 3, 2.2, 25 if x < 16 else -25))
                x += 4
        dome = leaflets[0].copy()
        for leaflet in leaflets:
            dome |= leaflet
        level = forms.light_level(dome, 4)
        layer = cell(len(picture))
        for leaflet in leaflets:
            forms.shade_by_level(layer, leaflet, ramp, level)
            ys, xs = leaflet.nonzero()
            cy = ys.mean()
            for y, x in zip(*forms.edge(leaflet).nonzero()):
                if y > cy:
                    layer[y][x] = ramp[0]
        paste(picture, rimmed(layer))

    def tubers(picture):
        layer = cell()
        for x, rx in ((6, 3.5), (16, 4), (26, 3.5)):
            ball(layer, x, foot(layer) - 0.5, rx + 1, 3.2, TUBER, radius=2)
            pixel(layer, x + 1, foot(layer) + 2, "mud")
        paste(picture, rimmed(layer))

    young = sown()
    shadow(young, 7)
    bush(young, 7, 9, GREENS)
    flowering = cell()
    shadow(flowering, 13)
    bush(flowering, 13, 19, GREENS)
    leafy = [row[:] for row in flowering]
    for x, y in ((9, 12), (17, 10), (23, 14), (13, 16)):
        forms.dots(flowering, [(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], "lime")
        forms.dots(flowering, [(x, y)], "gold")
    ripe = cell()
    shadow(ripe, 13)
    bush(ripe, 11, 13, WITHERING)
    tubers(ripe)
    return [sown(), young, flowering, ripe], leafy


def carrot():
    """Feathery fronds, and when ripe the orange shoulders of the roots in the soil."""

    def fronds(picture, base, scale):
        x0, y0 = base
        for angle, length in ((-50, 14), (48, 13), (-25, 18), (22, 19), (-5, 21), (8, 16)):
            turn = math.radians(angle)
            x1, y1 = x0 + length * scale * math.sin(turn), y0 - length * scale * math.cos(turn)
            line(picture, x0, y0, x1, y1, "green", bend=angle / 25)
            # Fine leaflets off the stalk, lit on the left.
            for step in range(2, round(length * scale), 2):
                t = step / (length * scale)
                x, y = x0 + (x1 - x0) * t + angle / 25 * math.sin(t * math.pi), y0 + (y1 - y0) * t
                pixel(picture, x - 1, y - 1, "green_light" if step % 4 else "green_bright")
                pixel(picture, x + 1, y - 1, "green_dark")
            pixel(picture, x1, y1, "green_bright")

    young = sown()
    fronds(young, (16, foot(young) - 1), 0.45)
    leafy = cell()
    shadow(leafy, 9)
    fronds(leafy, (16, foot(leafy) - 1), 1.0)
    ripe = cell()
    shadow(ripe, 11)
    roots = cell()
    for x, top in ((10, 26), (21, 27)):
        forms.shade(roots, mask(roots, forms.ellipse, x, top + 1.5, 4.5, 3.5), ("ember", "flame", "flame", "gold"), radius=2)
    paste(ripe, rimmed(roots))
    for x in (10, 21):
        fronds(ripe, (x, 26), 0.75)
        forms.dots(ripe, [(x - 2, 29), (x + 1, 30)], "ember")
    return [sown(), young, leafy, ripe], 2


def cabbage():
    """Broad blue-green leaves spread wide, then cupped round a tight pale head."""

    def outer_leaves(layer, spread):
        for dx, dy, rx, ry, side in ((-8, -3, 7, 5, -1), (8, -3, 7, 5, 1), (-9, 2, 7, 5, -1), (9, 2, 7, 5, 1), (-4, 5, 7, 4.5, -1), (5, 5, 7, 4.5, 1)):
            far = dy < 0
            cx, cy = 16 + dx * spread, 22 + dy * spread
            forms.shade(layer, mask(layer, forms.ellipse, cx, cy, rx * spread, ry * spread), SHADED_GREENS if far else GREENS, radius=3)
            # A pale midrib out from the stalk, with two veins off it.
            for k in range(round(rx * spread) + 1):
                t = k / (rx * spread)
                x, y = 16 + dx * spread * (0.25 + 0.75 * t), 22 + dy * spread * (0.6 + 0.3 * t)
                pixel(layer, x, y, "green" if far else "green_light")
                if k in (2, 4):
                    pixel(layer, x + side, y - 1, "green" if far else "green_light")

    young = sprouts(size=1.2)
    leafy = cell()
    shadow(leafy, 12)
    layer = cell()
    outer_leaves(layer, 0.85)
    ball(layer, 16, 20, 4, 3.5, BRIGHT_GREENS, radius=2)
    paste(leafy, rimmed(layer))
    ripe = cell()
    shadow(ripe, 14)
    layer = cell()
    outer_leaves(layer, 1.0)
    head = mask(layer, forms.ellipse, 16, 18, 9.5, 8.2)
    forms.shade(layer, head, ("green", "green_light", "green_bright", "spring_pale"), radius=5)
    # The wrapper leaves' edges curling round the head.
    for r, start, end, colour in ((8.6, 2.0, 3.6, "green"), (6.4, 3.4, 5.4, "green_light"), (8.0, 0.0, 1.5, "green"), (4.5, 4.4, 6.0, "green")):
        for k in range(30):
            turn = start + (end - start) * k / 29
            pixel(layer, 16 + r * math.cos(turn), 18 + r * 0.86 * math.sin(turn), colour)
    for k in range(7):
        pixel(layer, 15 + k * 0.5, 12 + k, "spring_pale")
    paste(ripe, rimmed(layer))
    return [sown(), young, leafy, ripe], 2


def onion():
    """Hollow blue-green blades, and when ripe the golden bulbs sitting on the soil, their tops
    fallen over and yellowing."""

    def blades(picture, x, count, height, shades):
        for k in range(count):
            lean = (k - (count - 1) / 2) * 3
            blade(picture, x - 1 + k % 2, foot(picture) - 1, height - abs(lean) * 0.6, lean, shades)

    young = sown()
    blades(young, 16, 3, 9, ("green", "green_light", "green_bright"))
    leafy = cell()
    shadow(leafy, 7)
    blades(leafy, 16, 7, 21, ("green_dark", "green", "green_light"))
    ripe = cell()
    shadow(ripe, 13)
    bulbs = cell()
    for x in (7, 16, 25):
        ball(bulbs, x, 24, 5, 4.6, ("ochre_dark", "ochre", "gold", "cream"), radius=3)
    paste(ripe, rimmed(bulbs))
    for x, lean in ((7, -5), (16, 6), (25, 4)):
        # The neck, and the top fallen over on the soil.
        line(ripe, x, 20, x, 17, "straw")
        blade(ripe, x, 18, 7, lean, ("reed", "dry_light", "straw"), droop=6)
        forms.dots(ripe, [(x - 1, 22), (x - 2, 23)], "cream")
    return [sown(), young, leafy, ripe], 2


def ear(picture, x, y, length, grains, awn=None):
    """An ear of grain hanging from (x, y) down: paired grains `length` rows long, lit on the
    left (`grains` are light, mid and dark), with awns up from its top if given."""
    light, mid, dark = grains
    x, y = round(x), round(y)
    for row in range(0, length, 2):
        gy = y + 1 + row
        forms.dots(picture, [(x - 1, gy)], light)
        forms.dots(picture, [(x, gy)], light if row % 4 else mid)
        forms.dots(picture, [(x + 1, gy), (x - 1, gy + 1)], mid)
        forms.dots(picture, [(x, gy + 1), (x + 1, gy + 1)], dark)
    if awn:
        line(picture, x - 1, y + 2, x - 4, y - 5, awn)
        line(picture, x + 1, y + 2, x + 4, y - 4, awn)
        line(picture, x, y, x, y - 5, awn)


def stand(picture, stalks, colours, leaves=None, ears=None):
    """A stand of grain: `stalks` as (x, height, lean), the back ones (the first third) a shade
    darker; `colours` are the stalk's, front and back. Each stalk gets a leaf or two, and an
    ear by `ears(picture, x, y, is_back)` at its top."""
    ground = foot(picture)
    back_count = len(stalks) // 3
    for index, (x, height, lean) in enumerate(stalks):
        is_back = index < back_count
        top_x, top_y = x + lean, ground - height
        line(picture, x, ground, top_x, top_y, colours[1] if is_back else colours[0])
        if leaves:
            side = 1 if index % 2 else -1
            y = ground - height * (0.3 + 0.2 * (index % 3) / 2)
            dark, mid, light = leaves
            line(picture, x + lean * (ground - y) / height, y, x + lean * (ground - y) / height + side * 5, y + 3 + index % 2, mid if not is_back else dark)
            pixel(picture, x + lean * (ground - y) / height + side, y, light)
        if ears:
            ears(picture, top_x, top_y, is_back)


# The stalks of a stand of grain, back to front: (x, height, lean).
GRAIN_STALKS = ((5, 40, -1), (13, 44, 1), (22, 41, 0), (27, 38, 2), (2, 36, -2), (8, 42, 1), (11, 39, -1), (16, 45, 1), (19, 40, -2), (25, 43, 1), (29, 37, 0))


def grain(scale, colours, leaves=None, ears=None):
    """A cell with a stand of grain GRAIN_STALKS high, times `scale`."""
    picture = cell(TALL)
    shadow(picture, 14)
    stand(picture, [(x, height * scale, lean * scale) for x, height, lean in GRAIN_STALKS], colours, leaves, ears)
    return picture


def young_blades(ramp):
    """Young grain: a tuft of blades on its drill."""
    picture = sown(TALL)
    for k, (x, height, lean) in enumerate(((11, 9, -3), (14, 12, -1), (16, 13, 1), (19, 10, 3), (13, 7, -4), (21, 8, 4))):
        blade(picture, x, foot(picture) - 1, height, lean, ramp if k < 4 else ramp[:1] * 3)
    return picture


def wheat():
    """Young blades, a green stand with green ears, and ripe golden wheat: ears of paired
    grains with long awns, as in the mockup."""

    def green_ears(picture, x, y, is_back):
        ear(picture, x, y, 8, ("green_light", "green", "green_dark") if not is_back else ("green", "green_dark", "green_deep"))

    def golden_ears(picture, x, y, is_back):
        grains = ("ochre", "ochre_dark", "umber") if is_back else ("gold", "ochre", "ochre_dark")
        ear(picture, x, y, 12, grains, "straw" if is_back else "sand_light")

    young = young_blades(("green_dark", "green", "green_light"))
    leafy = grain(0.8, ("green_light", "green"), ("green_dark", "green", "green_light"), green_ears)
    ripe = grain(1.0, ("straw", "reed"), ("reed", "straw", "sand_light"), golden_ears)
    return [sown(TALL), young, leafy, ripe], 2


def rye():
    """The grain of the sandy Geest: taller than wheat, blue-green when young, ripe a pale
    grey-yellow with long slim ears that nod over, bristling with awns."""

    def nodding(picture, x, y, grains, awn):
        # The ear hangs a little to the right of its stalk's top.
        light, mid, dark = grains
        x, y = round(x), round(y)
        for row in range(14):
            gx, gy = x + row // 5, y + row
            forms.dots(picture, [(gx - 1, gy)], light if row % 2 == 0 else mid)
            forms.dots(picture, [(gx, gy)], mid if row % 2 == 0 else dark)
            if awn and row % 4 == 1:
                side = -1 if row % 8 == 1 else 1
                line(picture, gx + (side - 1) / 2, gy, gx + (side - 1) / 2 + side * 2, gy - 4, awn)

    def green_ears(picture, x, y, is_back):
        nodding(picture, x, y, ("meadow_light", "meadow", "green_deep"), None)

    def ripe_ears(picture, x, y, is_back):
        grains = ("sand", "mud", "mud_dark") if is_back else ("sand_light", "sand", "mud")
        nodding(picture, x, y, grains, "straw" if not is_back else "reed")

    young = young_blades(("green_deep", "meadow", "meadow_light"))
    leafy = grain(0.9, ("meadow_light", "meadow"), ("green_deep", "meadow", "meadow_light"), green_ears)
    ripe = grain(1.15, ("straw", "reed"), ("reed", "straw", "sand_light"), ripe_ears)
    return [sown(TALL), young, leafy, ripe], 2


def buckwheat():
    """The other grain of the Geest: red stems with arrow-shaped leaves, foaming with white and
    pink flowers, and ripe with dark three-cornered seeds among the last flowers."""
    stems = ((9, 30, -3), (16, 36, 0), (23, 31, 3), (12, 25, -1), (20, 27, 2))

    def plant(picture, scale, flowers, seeds):
        ground = foot(picture)
        shadow(picture, 12)
        layer = cell(TALL)
        for index, (x, height, lean) in enumerate(stems):
            top_x, top_y = x + lean * scale, ground - height * scale
            line(picture, x, ground, top_x, top_y, "rust_dark" if index < 3 else "russet_deep")
            for k in range(1, 3):
                y = ground - height * scale * k / 3
                stem_x = x + lean * scale * k / 3
                side = 1 if (index + k) % 2 else -1
                leaf(layer, (stem_x, y), (stem_x + side * 6 * scale, y - 3 * scale), 4 * scale, GREENS)
        paste(picture, rimmed(layer))
        for index, (x, height, lean) in enumerate(stems):
            top_x, top_y = round(x + lean * scale), round(ground - height * scale)
            if flowers:
                for dx, dy in ((0, 0), (-2, 1), (2, 1), (-1, 2), (1, -1), (-3, 3), (3, 2), (0, 2), (-1, -1), (1, 3), (-2, 3)):
                    forms.dots(picture, [(top_x + dx, top_y + dy)], "blossom" if (dx + dy) % 3 else "lime")
                forms.dots(picture, [(top_x, top_y + 1), (top_x + 2, top_y + 3)], "petal")
            if seeds:
                for dx, dy in ((-1, 2), (2, 0), (0, 4)):
                    forms.dots(picture, [(top_x + dx, top_y + dy), (top_x + dx + 1, top_y + dy)], "umber")
                    forms.dots(picture, [(top_x + dx, top_y + dy + 1)], "russet_deep")
        return picture

    young = sprouts(TALL, 1.1, BRIGHT_GREENS, "rust")
    leafy = plant(cell(TALL), 0.8, flowers=True, seeds=False)
    ripe = plant(cell(TALL), 1.0, flowers=True, seeds=True)
    dying = plant(cell(TALL), 0.8, flowers=False, seeds=False)
    return [sown(TALL), young, leafy, ripe], dying


def pod(picture, x, y, length):
    """A hanging pod from (x, y) down, two pixels wide and bowed a little: lit on its left, its
    tip darker. Too thin for a rim, it is pale against the leaves instead."""
    for step in range(length):
        bow = round(math.sin(step / (length - 1) * math.pi))
        is_tip = step >= length - 2
        forms.dots(picture, [(x - bow, y + step)], "green_light" if is_tip else "green_bright")
        forms.dots(picture, [(x + 1 - bow, y + step)], "green" if is_tip else "green_light")


def pea_sticks(picture, top):
    """Twiggy brushwood stuck in the row for the peas to climb, up to y = top."""
    ground = foot(picture)
    for x0, lean in ((9, -3), (16, 1), (23, 3)):
        line(picture, x0, ground, x0 + lean, top, "soil_mid")
        line(picture, x0 + 1, ground, x0 + 1 + lean, top + 2, "soil")
        for k in range(1, 4):
            y = ground - (ground - top) * k / 4
            x = x0 + lean * k / 4
            side = -1 if k % 2 else 1
            line(picture, x, y, x + side * 4, y - 4, "soil_mid")


def peas():
    """Peas climbing their sticks: pairs of round leaflets and curling tendrils, white flowers,
    and full pods, pale against the dark leaves and lit on their left."""
    leaflets = ((7, 50), (24, 48), (12, 42), (21, 38), (8, 33), (17, 30), (25, 27), (11, 22), (20, 19), (14, 12), (6, 15))

    def vines(picture, upto):
        layer = cell(TALL)
        for x, y in leaflets[:upto]:
            leaf(layer, (x - 1, y), (x - 4.5, y - 3), 4, GREENS)
            leaf(layer, (x + 1, y), (x + 4.5, y - 3.5), 4, GREENS)
        paste(picture, rimmed(layer))
        for x, y in leaflets[:upto:2]:
            line(picture, x, y - 2, x + 2, y - 6, "green_light", bend=1.5)

    young = cell(TALL)
    shadow(young, 9)
    pea_sticks(young, 40)
    vines(young, 4)
    flowering = cell(TALL)
    shadow(flowering, 12)
    pea_sticks(flowering, 8)
    vines(flowering, len(leaflets))
    for x, y in ((10, 46), (19, 41), (27, 33), (5, 28), (15, 25), (23, 16), (9, 10)):
        forms.dots(flowering, [(x, y), (x + 1, y), (x, y + 1)], "lime")
        forms.dots(flowering, [(x + 1, y + 1)], "cream")
    ripe = cell(TALL)
    shadow(ripe, 12)
    pea_sticks(ripe, 8)
    vines(ripe, len(leaflets))
    for x, y in ((4, 44), (17, 46), (27, 39), (9, 34), (22, 28), (14, 21), (5, 18), (25, 13)):
        pod(ripe, x, y, 7)
    return [sown(TALL), young, flowering, ripe], 2


def beans():
    """Runner beans winding up a pole: three-lobed leaves, lilac flowers, and long pods."""

    def pole(picture):
        line(picture, 15, foot(picture) + 1, 15, 3, "soil_mid")
        line(picture, 16, foot(picture) + 1, 16, 3, "soil")
        forms.dots(picture, [(15, 3), (16, 3)], "soil_light")

    def vine(picture, top):
        ground = foot(picture)
        for y in range(ground, top, -1):
            pixel(picture, 15.5 + 2.6 * math.sin(y / 3), y, "green_dark" if math.cos(y / 3) < 0 else "green")
        layer = cell(TALL)
        for index, y in enumerate(range(ground - 4, top + 2, -7)):
            side = 1 if index % 2 else -1
            x = 16 + side * 3
            fanned(layer, (x, y), ((side * 55, 7, 5), (side * 100, 6, 4), (side * 15, 7, 5)), BRIGHT_GREENS)
        paste(picture, rimmed(layer))

    young = cell(TALL)
    shadow(young, 8)
    pole(young)
    vine(young, 40)
    flowering = cell(TALL)
    shadow(flowering, 12)
    pole(flowering)
    vine(flowering, 8)
    for x, y in ((8, 44), (24, 36), (9, 28), (23, 21), (10, 14)):
        forms.dots(flowering, [(x, y), (x + 1, y), (x + 1, y + 1), (x - 1, y + 1), (x, y + 2)], "heather")
        forms.dots(flowering, [(x, y + 1)], "petal")
    ripe = cell(TALL)
    shadow(ripe, 12)
    pole(ripe)
    vine(ripe, 8)
    for x, y in ((7, 41), (25, 34), (8, 26), (24, 18), (11, 12)):
        pod(ripe, x, y, 10)
    return [sown(TALL), young, flowering, ripe], 2


def flax():
    """A dense stand of thin stalks with narrow leaves: young and green, then flowering sky-blue,
    and ripe turning straw-yellow, with round seed bolls and the last flowers."""
    columns = (3, 6, 8, 11, 14, 16, 19, 22, 24, 27, 29)
    heights = (34, 40, 31, 43, 37, 45, 33, 41, 38, 32, 36)

    def stalks(scale, colour, shade):
        picture = cell(TALL)
        shadow(picture, 14)
        ground = foot(picture)
        for index, (x, height) in enumerate(zip(columns, heights)):
            top = ground - height * scale
            line(picture, x, ground, x + (index % 3 - 1), top, shade if index % 3 == 1 else colour)
            # Narrow leaves up the stalk.
            for y in range(ground - 4, round(top) + 3, -5):
                side = 1 if (index + y) % 2 else -1
                line(picture, x + side, y, x + 2 * side, y - 2, shade)
        return picture

    def tops(picture, scale):
        ground = foot(picture)
        return [(x + (index % 3 - 1), round(ground - height * scale)) for index, (x, height) in enumerate(zip(columns, heights))]

    young = stalks(0.4, "green_light", "green")
    flowering = stalks(1.0, "green_light", "green")
    for index, (x, y) in enumerate(tops(flowering, 1.0)):
        if index % 3 != 2:
            ring = [(x + dx, y - 2 + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy]
            forms.dots(flowering, ring, "water_light")
            forms.dots(flowering, [(x - 1, y - 3), (x, y - 3), (x - 1, y - 2)], "foam")
            forms.dots(flowering, [(x, y - 2)], "cream")
        else:
            forms.dots(flowering, [(x, y - 1)], "foam")
    ripe = stalks(1.0, "straw", "reed")
    for index, (x, y) in enumerate(tops(ripe, 1.0)):
        ball(ripe, x, y - 1.5, 1.6, 1.6, ("reed", "straw", "sand_light"), radius=1)
        if index % 4 == 2:
            forms.dots(ripe, [(x - 2, y - 4), (x - 1, y - 4)], "water_light")
    return [sown(TALL), young, flowering, ripe], 2


def strawberries():
    """Wild strawberries: low tufts of three-lobed leaves, small white flowers, and small red
    berries, lit and seeded, hanging among the leaves."""
    tufts = ((8, 24), (21, 26), (14, 19), (26, 20), (5, 17))

    def leaves(picture, upto):
        layer = cell()
        for x, y in tufts[:upto]:
            fanned(layer, (x, y + 4), ((-40, 5, 4.5), (40, 5, 4.5), (0, 6, 4.5)), GREENS, "green_light")
        paste(picture, rimmed(layer))

    young = sown()
    leaves(young, 2)
    flowering = cell()
    shadow(flowering, 13)
    leaves(flowering, len(tufts))
    for x, y in ((11, 15), (24, 16), (4, 22), (17, 24)):
        forms.dots(flowering, [(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], "lime")
        forms.dots(flowering, [(x, y)], "gold")
    ripe = cell()
    shadow(ripe, 13)
    leaves(ripe, len(tufts))
    berries = cell()
    for x, y in ((10, 26), (18, 22), (25, 25), (3, 21), (13, 15), (28, 16)):
        forms.shade(berries, mask(berries, forms.ellipse, x, y, 2.4, 2.8), ("ember", "red_light", "red_light", "cream"), radius=2)
    rimmed(berries)
    for x, y in ((10, 26), (18, 22), (25, 25), (3, 21), (13, 15), (28, 16)):
        forms.dots(berries, [(x, y + 1)], "gold")
        forms.dots(berries, [(x - 1, y - 3), (x, y - 3)], "green_light")
    paste(ripe, berries)
    return [sown(), young, flowering, ripe], 2


def pumpkin():
    """A small green garden squash, ribbed and a little mottled, on its vine with big round
    leaves (the crop id stays pumpkin)."""

    def vine(picture, scale):
        layer = cell()
        for x, y, size in ((7, 19, 6.5), (25, 18, 6), (11, 25, 5.5), (23, 25, 5)):
            leaf(layer, (x - size * scale, y), (x + size * scale, y), size * 1.6 * scale, GREENS)
            line(layer, x, y + size * 0.6 * scale, x, y - size * 0.4 * scale, "green_light")
            line(layer, x, y, x - size * 0.6 * scale, y - size * 0.4 * scale, "green_light")
        paste(picture, rimmed(layer))
        line(picture, 3, 27, 29, 27, "green", bend=-2)

    young = sprouts(size=1.3)
    sprawling = cell()
    shadow(sprawling, 14)
    vine(sprawling, 0.8)
    forms.shade(sprawling, mask(sprawling, forms.ellipse, 18, 24, 3, 2.5), ("olive", "green", "green_light"), radius=1)
    forms.dots(sprawling, [(8, 25), (9, 24), (7, 24), (8, 23)], "gold")
    forms.dots(sprawling, [(8, 24)], "flame")
    ripe = cell()
    shadow(ripe, 14)
    vine(ripe, 0.7)
    squash = cell()
    forms.shade(squash, mask(squash, forms.ellipse, 16, 21.5, 10, 7.5), ("green_deep", "olive", "dry", "dry_light"), radius=4)
    for x in (11, 16, 21):
        line(squash, x, 16, x, 27, "green_deep", bend=(x - 16) / 3)
    paste(ripe, rimmed(squash))
    forms.dots(ripe, [(9, 19), (13, 23), (18, 20), (20, 25), (14, 17)], "straw")
    forms.dots(ripe, [(15, 13), (16, 13), (16, 12), (17, 11)], "green_dark")
    return [sown(), young, sprawling, ripe], 2


# Each crop's art: a function giving its four growth stages, and its dead look as the index of
# the stage it is made from (the grown plant without its produce) or a picture of its own.
ARTISTS = {
    "turnip": turnip,
    "potato": potato,
    "carrot": carrot,
    "cabbage": cabbage,
    "onion": onion,
    "wheat": wheat,
    "rye": rye,
    "buckwheat": buckwheat,
    "peas": peas,
    "beans": beans,
    "flax": flax,
    "strawberries": strawberries,
    "pumpkin": pumpkin,
}


def dead(picture):
    """The plant withered: its colours gone brown and grey."""
    return [[DEAD_COLOURS.get(colour, colour) for colour in row] for row in picture]


def sheet_rows(crop):
    """The picture of a crop's sheet as a row of cells: four stages and the dead one."""
    stages, dead_from = ARTISTS[crop]()
    assert len(stages) == STAGES, f"{crop}: {len(stages)} stages"
    assert all(len(stage) == len(stages[0]) and len(stage[0]) == WIDTH for stage in stages), crop
    withered = stages[dead_from] if isinstance(dead_from, int) else dead_from
    return stages + [dead(withered)]


def sheets():
    """{crop id: its sheet as a row of cells} for every crop."""
    return {crop: sheet_rows(crop) for crop in ARTISTS}
