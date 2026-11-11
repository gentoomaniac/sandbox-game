"""The player character (assets/character/<slot>_<variant>.png), drawn at 32 px per tile.

One sheet per layer and variant, all with the same layout: 32x64 frames, one row per facing
(down, up, left, right), columns idle, walk 1..4. Drawn for "right" and "left" is its mirror
image. Every layer is drawn on the same figure (`Figure`: where the head, the arms and the legs
are in a frame), so any combination lines up; game/state/appearance.gd says which are worn and
in what order.

The figure is 62 rows tall from the crown of a hat to the soles (y 2..62, the outline on row
63): the head 15 rows (y 10..24), the torso from the shoulders (y 26) to the hips (y 44), the
legs to the ankles (y 57) and the clogs (y 57..62). Its parts are rounded forms shaded by the
light from the top left (forms.py); only the outer silhouette has the ink outline, inside it
parts are told apart by the shades of their own colours. The face has eyes with a glint, brows,
a nose shadow, cheeks and a mouth.
"""

from collections import namedtuple

import forms
import tool_grades
from canvas import NEIGHBOURS, blank

CHARACTER_WIDTH = 32
CHARACTER_HEIGHT = 64
PLAYER_FACINGS = ("down", "up", "left", "right")
PLAYER_FRAMES = ("idle", "walk1", "walk2", "walk3", "walk4")

# A walk is two contact frames (walk 1 and 3: the hips sink, the legs spread) and two passing
# frames (walk 2 and 4: one leg swings through, its foot off the ground). `lift` is how far each
# of the two legs is raised (the far or left leg first), `stride` how far the near foot is ahead
# in a side view and `swing` how far the near hand swings against it.
POSES = {
    "idle": {"sink": 0, "lift": (0, 0), "stride": 0, "swing": 0},
    "walk1": {"sink": 1, "lift": (0, 0), "stride": 4, "swing": -4},
    "walk2": {"sink": 0, "lift": (3, 0), "stride": 0, "swing": 0},
    "walk3": {"sink": 1, "lift": (0, 0), "stride": -4, "swing": 4},
    "walk4": {"sink": 0, "lift": (0, 3), "stride": 0, "swing": 0},
}
# Passing out (see `collapse_sheet`): kneeling, the figure sinks onto its folded legs; asleep,
# its eye is shut.
KNEEL = POSES["idle"] | {"sink": 12, "kneel": True}
ASLEEP = POSES["idle"] | {"asleep": True}
# Riding (see `riding_sheet`): the figure sits astride a horse, its legs over the saddle.
RIDE = POSES["idle"] | {"ride": True}

# Rows of the figure standing upright; the upper body sinks with the pose.
SHOULDERS = 26
WAIST = 41
HIPS = 44
KNEES = 50
ANKLES = 57
# How thick a leg and an arm are, from their middle line.
LEG_RADIUS = 2.5
SLEEVE_RADII = (2.9, 2.5)

# A leg: its thigh, shin and foot as masks, the garter band at the knee (where breeches end), and
# whether it is the far one, drawn darker.
Leg = namedtuple("Leg", "thigh shin foot garter far")
# An arm: shoulder and hand, in pixels; the far one is drawn darker and behind the body.
Arm = namedtuple("Arm", "shoulder hand far")


def mask(function, *args):
    """A forms shape the size of a frame."""
    return function(CHARACTER_WIDTH, CHARACTER_HEIGHT, *args)


class Figure:
    """Where the parts of the figure are in one frame of a facing ("down", "up" or "right") and a
    pose: the head's middle, the torso, the arms and the legs. Every layer draws on it."""

    def __init__(self, facing, pose):
        self.facing = facing
        self.pose = pose
        self.is_side = facing == "right"
        self.top = pose["sink"]
        top = self.top
        self.head = (16, 17.5 + top)
        # The row of the eyes; the brows, nose and mouth are drawn from it.
        self.eyes = 17 + top
        if self.is_side:
            self.torso = mask(forms.rounded_box, 11, SHOULDERS + top, 20, HIPS - 1 + top)
            self.hips = mask(forms.rounded_box, 11, WAIST + top, 21, HIPS + 2 + top)
        else:
            self.torso = mask(forms.rounded_box, 9, SHOULDERS + top, 22, HIPS - 1 + top)
            self.hips = mask(forms.rounded_box, 9, WAIST + top, 22, HIPS + 2 + top)
        self.arms = self._arms()
        self.legs = self._legs()

    def _arms(self):
        top, swing = self.top, self.pose["swing"]
        if self.is_side:
            # The far arm swings against the near one, behind the body.
            return [
                Arm((15.5, 29 + top), (15.5 - swing * 0.8, 41.5 + top), far=True),
                Arm((16.5, 29 + top), (16.5 + swing * 0.8, 41.5 + top), far=False),
            ]
        # From the front or behind the left arm holds the tool, the right one swings.
        return [
            Arm((7.5, 29 + top), (7.5, 41.5 + top), far=False),
            Arm((24.5, 29 + top), (24.5, 41.5 + top + swing // 2), far=False),
        ]

    def _legs(self):
        if self.pose.get("kneel"):
            return kneeling_legs()
        if self.pose.get("ride"):
            return riding_legs(self.is_side)
        legs = []
        for index, lift in enumerate(self.pose["lift"]):
            if self.is_side:
                far = index == 0
                stride = -self.pose["stride"] if far else self.pose["stride"]
                hip_x = 15.5 if far else 16.5
                if lift:
                    # Swinging through: the knee forward, the foot raised under the body.
                    knee, ankle = (hip_x + 3, KNEES - 1), (hip_x + 0.5, ANKLES - lift)
                else:
                    knee, ankle = (hip_x + stride / 2 + 0.5, KNEES + 1), (hip_x + stride, ANKLES)
                foot = side_clog(int(ankle[0]), int(ankle[1]))
            else:
                far = False
                hip_x = 12.5 if index == 0 else 19.5
                knee, ankle = (hip_x, KNEES - lift), (hip_x, ANKLES - lift)
                # Wider to the outside of each foot.
                left = int(hip_x) - (3 if index == 0 else 2)
                foot = mask(forms.rounded_box, left, int(ankle[1]), left + 5, int(ankle[1]) + 5)
            hip = (hip_x, HIPS + self.top)
            thigh = mask(forms.capsule, hip, knee, LEG_RADIUS + 0.4, LEG_RADIUS)
            # The garter is the thigh's last row.
            garter = thigh & ~mask(forms.capsule, hip, (knee[0], knee[1] - 1), LEG_RADIUS + 0.4, LEG_RADIUS)
            shin = mask(forms.capsule, knee, ankle, LEG_RADIUS, LEG_RADIUS - 0.3)
            legs.append(Leg(thigh, shin, foot, garter, far))
        return legs


def side_clog(x, y):
    """A foot seen from the side, facing right, its ankle at (x, y): a high heel and a long toe
    that narrows forward."""
    return mask(forms.polygon, [(x - 3, y), (x + 1, y), (x + 4, y + 2), (x + 5, y + 3), (x + 5, y + 5), (x - 3, y + 5)])


def kneeling_legs():
    """Legs folded under a kneeling figure seen from the side (facing right): the thigh forward
    to the knee on the ground, the shin back along the ground to the foot behind."""
    thigh = mask(forms.capsule, (15.5, 55.5), (22, 59.5), 3.2, 2.6)
    shin = mask(forms.capsule, (22, 60.5), (8, 60.5), 2.2, 2.0)
    foot = mask(forms.rounded_box, 2, 57, 8, 62)
    garter = thigh & mask(forms.ellipse, 22, 59.5, 1.6, 3)
    return [Leg(thigh, shin, foot, garter, far=False)]


def riding_legs(is_side):
    """Legs astride a horse, the seat on row 46. From the side (facing right) the near leg: the
    thigh forward along the saddle to the knee, the shin down the horse's flank and the foot in
    the stirrup; the far leg is behind the horse. From the front or behind both: the thighs spread
    over the saddle, the shins hanging outside the horse."""
    if is_side:
        thigh = mask(forms.capsule, (15.5, 47), (22, 48), 2.8, 2.4)
        shin = mask(forms.capsule, (22, 49), (21.5, 56.5), 2.4, 2.1)
        foot = mask(forms.rounded_box, 18, 57, 25, 61)
        garter = thigh & mask(forms.ellipse, 22, 48, 1.6, 3)
        return [Leg(thigh, shin, foot, garter, far=False)]
    legs = []
    for hip_x, knee_x, left in ((12.5, 6, 3), (19.5, 26, 24)):
        thigh = mask(forms.capsule, (hip_x, 46.5), (knee_x, 49.5), 2.8, 2.4)
        shin = mask(forms.capsule, (knee_x, 50), (knee_x, 56.5), 2.3, 2.1)
        foot = mask(forms.rounded_box, left, 57, left + 5, 61)
        garter = thigh & mask(forms.ellipse, knee_x, 49.5, 2.4, 1.8)
        legs.append(Leg(thigh, shin, foot, garter, far=False))
    return legs


def ramp(colours):
    """A colour set's shades, dark to light."""
    return (colours["shade"], colours["base"], colours["light"])


def far_ramp(shades):
    """The shades of a part on the far side, a step darker."""
    return (shades[0], shades[0], shades[1])


def shade_part(canvas, part_mask, shades, far=False, radius=2):
    forms.shade(canvas, part_mask, far_ramp(shades) if far else shades, radius)


def sleeve(arm, length=1.0):
    """The sleeve of an arm from the shoulder towards the wrist, `length` of the way."""
    (sx, sy), (hx, hy) = arm.shoulder, arm.hand
    end = (sx + (hx - sx) * 0.85 * length, sy + (hy - 3 - sy) * length)
    return mask(forms.capsule, (sx, sy), end, *SLEEVE_RADII)


def hand(arm):
    return mask(forms.ellipse, arm.hand[0], arm.hand[1], 2.3, 2.1)


def cuff(arm):
    """The gathered end of a long sleeve, at the wrist."""
    return sleeve(arm) & ~sleeve(arm, 0.82)


# The undershirt and shorts that the bare body wears.
UNDERSHIRT = ("sand", "sand_light", "sand_light")
SHORTS = ("mud_dark", "mud", "mud")
EYES = "ink"
GLINT = "lime"


def draw_body(facing, pose, skin="skin", shade="skin_shade", **_):
    """The figure in a linen undershirt and shorts: head, arms with hands, legs and bare feet.
    Worn clothes cover most of it, so this layer is also the silhouette that the outline
    follows."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    figure = Figure(facing, pose)
    skins = (shade, skin, skin)
    top = figure.top
    for arm in figure.arms:
        if arm.far:
            shade_part(canvas, sleeve(arm), skins, far=True)
            shade_part(canvas, hand(arm), skins, far=True)
    for leg in figure.legs:
        for part in (leg.shin, leg.foot):
            shade_part(canvas, part, skins, leg.far)
        shade_part(canvas, leg.thigh, SHORTS, leg.far)
    forms.shade(canvas, figure.hips, SHORTS, 2)
    forms.shade(canvas, figure.torso, UNDERSHIRT, 3)
    for arm in figure.arms:
        if not arm.far:
            shade_part(canvas, sleeve(arm), skins)
            shade_part(canvas, sleeve(arm, 0.35), UNDERSHIRT)
            shade_part(canvas, hand(arm), skins)
    forms.paint(canvas, mask(forms.box, 14, 22 + top, 17, SHOULDERS + top), shade)
    draw_head(canvas, figure, skin, shade)
    return canvas


def draw_head(canvas, figure, skin, shade):
    """The head and its face: from the front eyes with a glint, brows, the nose's shadow, cheeks
    and a mouth; from the side the same in profile, with the nose and an ear; from behind the
    back of the head with both ears."""
    cx, cy = figure.head
    eyes = figure.eyes
    brow = "soil_dark" if skin == "soil_light" else "soil"
    cheek = shade if skin == "soil_light" else "petal"
    mouth = "rust_dark" if skin in ("soil_light", "skin_shade") else "rust"
    if figure.is_side:
        forms.shade(canvas, mask(forms.ellipse, cx, cy, 7.3, 7.8), (shade, skin, skin), 3)
        # The nose, the chin, and the ear in the middle of the head.
        forms.dots(canvas, [(23, eyes + 1), (23, eyes + 2)], skin)
        forms.dots(canvas, [(22, eyes + 3)], shade)
        forms.dots(canvas, [(13, eyes), (13, eyes + 1), (14, eyes + 2)], shade)
        forms.dots(canvas, [(14, eyes), (14, eyes + 1)], skin)
        if figure.pose.get("asleep"):
            forms.dots(canvas, [(19, eyes + 1), (20, eyes + 1)], EYES)
        else:
            forms.dots(canvas, [(19, eyes), (20, eyes), (19, eyes + 1), (20, eyes + 1)], EYES)
            forms.dots(canvas, [(19, eyes)], GLINT)
        forms.dots(canvas, [(19, eyes - 2), (20, eyes - 2), (21, eyes - 2)], brow)
        forms.dots(canvas, [(18, eyes + 3), (19, eyes + 3)], cheek)
        forms.dots(canvas, [(20, eyes + 5), (21, eyes + 5)], mouth)
        return
    forms.shade(canvas, mask(forms.ellipse, cx, cy, 7.6, 7.8), (shade, skin, skin), 3)
    # The ears, the right one in shade.
    forms.dots(canvas, [(7, eyes), (7, eyes + 1)], skin)
    forms.dots(canvas, [(24, eyes), (24, eyes + 1)], shade)
    if figure.facing == "up":
        return
    for x in (11, 19):
        forms.dots(canvas, [(x, eyes), (x + 1, eyes), (x, eyes + 1), (x + 1, eyes + 1)], EYES)
        forms.dots(canvas, [(x, eyes)], GLINT)
        forms.dots(canvas, [(x - 1, eyes - 2), (x, eyes - 2), (x + 1, eyes - 2)], brow)
    forms.dots(canvas, [(9, eyes + 3), (10, eyes + 3), (21, eyes + 3), (22, eyes + 3)], cheek)
    forms.dots(canvas, [(16, eyes + 2), (16, eyes + 3)], shade)
    forms.dots(canvas, [(15, eyes + 5), (16, eyes + 5)], mouth)
    forms.dots(canvas, [(14, eyes + 5), (17, eyes + 5), (15, eyes + 6), (16, eyes + 6)], shade)


# The hair variants of the player: a base colour with a light and a shade, and the style (see
# `draw_hair`).
HAIR_STYLES = {
    "0": {"base": "soil", "light": "soil_light", "shade": "soil_dark", "style": "short"},
    "1": {"base": "straw", "light": "gold", "shade": "reed", "style": "long"},
    "2": {"base": "soil_mid", "light": "soil_light", "shade": "soil", "style": "tied"},
}
# The ribbon that ties back the "tied" hair, and the ones at the ends of plaits.
HAIR_RIBBON = "ink"
PLAIT_RIBBON = "rust"


def draw_hair(facing, pose, base, light, shade, style, **_):
    """Hair over the head, and from behind over the whole back of it: "short" with a fringe,
    "long" to the shoulders, "tied" back with a ribbon into a tail down the neck, parted and
    pinned up in a "bun" at the back, or parted into two "plaits" tied with red ribbons. The
    darkest shade is the line to the face."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    figure = Figure(facing, pose)
    hairs = (shade, base, light)
    top = figure.top
    cx, cy = figure.head
    if facing == "down":
        crown = mask(forms.ellipse, cx, cy - 2, 8.6, 8) & ~mask(forms.ellipse, cx, cy + 2, 7.2, 7.4)
        crown &= mask(forms.box, 0, 0, 31, 20 + top)
        if style == "long":
            crown |= mask(forms.rounded_box, 6, 15 + top, 9, 31 + top) | mask(forms.rounded_box, 22, 15 + top, 25, 31 + top)
        if style == "bun":
            forms.shade(canvas, mask(forms.ellipse, 16, 9 + top, 3.6, 2.2), hairs, 2)
        forms.shade(canvas, crown, hairs, 2)
        if style in ("short", "tied"):
            # A fringe over the forehead.
            forms.shade(canvas, mask(forms.polygon, [(10, 11 + top), (21, 11 + top), (19, 14 + top), (15, 13 + top), (12, 14 + top)]), hairs, 1)
        if style in ("bun", "plaits"):
            forms.dots(canvas, [(15, y + top) for y in range(9, 13)], shade)
        if style == "plaits":
            for x in (7.5, 24.5):
                draw_plait(canvas, (x, 20 + top), (x, 33 + top), base, shade)
    elif facing == "up":
        head = mask(forms.ellipse, cx, cy - 0.5, 8.4, 8.2) & mask(forms.box, 0, 0, 31, 24 + top)
        if style == "long":
            head |= mask(forms.rounded_box, 7, 16 + top, 24, 32 + top)
        forms.shade(canvas, head, hairs, 3)
        # Strands down the back of the head.
        forms.dots(canvas, [(12, 14 + top), (12, 15 + top), (19, 13 + top), (19, 14 + top), (15, 19 + top), (15, 20 + top)], shade)
        if style == "tied":
            forms.shade(canvas, mask(forms.capsule, (16, 23 + top), (16, 35 + top), 2.2, 1.4), hairs, 1)
            forms.paint(canvas, mask(forms.box, 14, 25 + top, 17, 26 + top), HAIR_RIBBON)
        if style == "bun":
            forms.shade(canvas, mask(forms.ellipse, 16, 19 + top, 4.2, 3.6), (shade, base, light), 2)
            forms.dots(canvas, [(14, 19 + top), (15, 20 + top), (17, 18 + top)], shade)
        if style == "plaits":
            for x in (12.5, 19.5):
                draw_plait(canvas, (x, 23 + top), (x, 37 + top), base, shade)
    else:
        head = mask(forms.ellipse, cx - 0.5, cy - 2, 8.4, 8) & ~mask(forms.ellipse, cx + 3.5, cy + 2.5, 6.5, 7.5)
        head &= mask(forms.box, 0, 0, 31, 24 + top)
        if style == "long":
            head |= mask(forms.rounded_box, 7, 16 + top, 13, 32 + top)
        forms.shade(canvas, head, hairs, 2)
        forms.dots(canvas, [(11, 13 + top), (12, 14 + top), (10, 18 + top), (11, 19 + top)], shade)
        if style == "tied":
            forms.shade(canvas, mask(forms.capsule, (9, 22 + top), (8, 34 + top), 2.2, 1.4), hairs, 1)
            forms.paint(canvas, mask(forms.box, 7, 24 + top, 10, 25 + top), HAIR_RIBBON)
        if style == "bun":
            forms.shade(canvas, mask(forms.ellipse, 8.5, 17 + top, 3, 3.6), hairs, 2)
            forms.dots(canvas, [(8, 18 + top), (9, 16 + top)], shade)
        if style == "plaits":
            draw_plait(canvas, (10, 22 + top), (10, 36 + top), base, shade)
    return canvas


def draw_plait(canvas, start, end, base, shade):
    """A plait from `start` to `end`, its strands crossing every other row, and a ribbon under
    its end."""
    plait = mask(forms.capsule, start, end, 1.8, 1.3)
    forms.paint(canvas, plait, base)
    for y, x in zip(*plait.nonzero()):
        if (x + y) % 3 == 0:
            canvas[y][x] = shade
    x, y = int(end[0]), int(end[1]) + 1
    forms.paint(canvas, mask(forms.box, x - 1, y, x + 1, y + 1), PLAIT_RIBBON)


# Knee breeches of brown wool, buttoned at the knee, and white knitted stockings: the pale
# lower legs below dark breeches are what reads as the period.
BREECHES = {"base": "soil_mid", "light": "soil_light", "shade": "soil", "band": "soil_dark"}
STOCKINGS = ("sand_light", "lime", "lime")
KNEE_BUTTON = "ochre"


def draw_legs(facing, pose, **colours):
    """Knee breeches and stockings; the feet are in stockings too, clogs go over them.
    `colours` replace those of BREECHES (the villagers wear other cloth)."""
    breeches = BREECHES | colours
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    figure = Figure(facing, pose)
    for leg in figure.legs:
        shade_part(canvas, leg.shin | leg.foot, STOCKINGS, leg.far)
        shade_part(canvas, leg.thigh, ramp(breeches), leg.far)
    forms.shade(canvas, figure.hips, ramp(breeches), 2)
    for leg in figure.legs:
        if not leg.far:
            forms.paint(canvas, leg.garter, breeches["band"])
            ys, xs = leg.garter.nonzero()
            if len(xs) and not figure.pose.get("kneel"):
                # The knee button on the outer side, or in front from the side.
                x = xs.max() - 1 if figure.is_side or xs.mean() > 16 else xs.min() + 1
                forms.dots(canvas, [(x, ys.min())], KNEE_BUTTON)
    if not figure.is_side and not figure.pose.get("ride"):
        # The fly, and the seam between the legs.
        forms.dots(canvas, [(15, y + figure.top) for y in range(WAIST + 1, HIPS + 3)], breeches["shade"])
    return canvas


# Wooden clogs, pale and wide, lit on top, the sole dark: the feet the art guide names as the
# period cue.
CLOGS = ("mud", "sand", "sand_light")
CLOG_SOLE = "mud_dark"
CLOG_LIT = "cream"


def draw_clogs(facing, pose, **_):
    """Wooden clogs over the stockinged feet; from the side their long toe points forward."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    figure = Figure(facing, pose)
    for leg in figure.legs:
        shade_part(canvas, leg.foot, CLOGS, leg.far)
        ys, xs = leg.foot.nonzero()
        bottom, top, left, right = ys.max(), ys.min(), xs.min(), xs.max()
        forms.dots(canvas, [(x, bottom) for x in range(left + 1, right)], CLOG_SOLE)
        if leg.far:
            continue
        if figure.is_side and not figure.pose.get("kneel"):
            # The opening at the heel where the stocking goes in, and the lit toe.
            forms.dots(canvas, [(left + 1, top), (left + 2, top)], "mud_dark")
            forms.dots(canvas, [(right - 2, top + 1), (right - 1, top + 2)], CLOG_LIT)
        else:
            forms.dots(canvas, [(left + 1, top + 1), (left + 2, top + 1)], CLOG_LIT)
    return canvas


# The linen shirt, and the waistcoat of madder-red wool with its row of tin buttons.
SHIRT = {"base": "lime", "light": "lime", "shade": "sand_light", "fold": "sand"}
WAISTCOAT = {"base": "rust", "light": "red_light", "shade": "rust_dark", "button": "stone_light"}


def draw_shirt(facing, pose, **_):
    """A linen shirt with full sleeves gathered at the wrist and a collar open at the neck,
    tucked into the breeches."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    figure = Figure(facing, pose)
    shirt = ramp(SHIRT)
    top = figure.top
    draw_sleeves(canvas, figure, shirt, far_only=True)
    forms.shade(canvas, figure.torso, shirt, 3)
    if figure.is_side:
        forms.dots(canvas, [(19, SHOULDERS + top), (20, SHOULDERS + 1 + top)], SHIRT["fold"])
    elif facing == "down":
        # The open neck between the collar's points.
        forms.dots(canvas, [(15, SHOULDERS + top), (16, SHOULDERS + top), (15, SHOULDERS + 1 + top), (16, SHOULDERS + 2 + top)], "skin_shade")
        forms.dots(canvas, [(13, SHOULDERS + top), (18, SHOULDERS + top), (14, SHOULDERS + 1 + top), (17, SHOULDERS + 1 + top)], SHIRT["shade"])
    draw_sleeves(canvas, figure, shirt)
    return canvas


def draw_sleeves(canvas, figure, shades, far_only=False, cuffs=SHIRT["fold"], fold=SHIRT["fold"]):
    """Long sleeves over the arms (only the far one with `far_only`, to go behind the body),
    gathered at the wrist, and a line in `fold` where each arm hangs beside or before the
    body."""
    for arm in figure.arms:
        if arm.far != far_only:
            continue
        shade_part(canvas, sleeve(arm), shades, arm.far)
        forms.paint(canvas, cuff(arm), shades[0] if arm.far else cuffs)
        if figure.is_side and not arm.far:
            # The arm's back edge, where it hangs in front of the body.
            back = forms.edge(sleeve(arm)) & ~mask(forms.box, int(arm.shoulder[0]) + 1, 0, 31, 63)
            forms.paint(canvas, back & figure.torso, fold)
        if not arm.far and not figure.is_side:
            inner = 9 if arm.shoulder[0] < 16 else 22
            forms.dots(canvas, [(inner, y + figure.top) for y in range(30, 39)], fold)


def draw_waistcoat(facing, pose, **colours):
    """The shirt under a red waistcoat, open at the neck in a V and buttoned down the front,
    its skirts over the hips, with two pockets. `colours` replace those of WAISTCOAT."""
    waistcoat = WAISTCOAT | colours
    shades = ramp(waistcoat)
    canvas = draw_shirt(facing, pose)
    figure = Figure(facing, pose)
    top = figure.top
    if figure.is_side:
        vest = mask(forms.polygon, [(11, 27 + top), (19, 27 + top), (21, 33 + top), (21, 45 + top), (11, 45 + top)])
        forms.shade(canvas, vest, shades, 3)
        for y in range(34, 44, 3):
            forms.dots(canvas, [(20, y + top)], waistcoat["button"])
        forms.dots(canvas, [(16, 39 + top), (17, 39 + top), (18, 39 + top)], waistcoat["shade"])
        draw_sleeves(canvas, figure, ramp(SHIRT))
        return canvas
    if facing == "down":
        vest = mask(forms.polygon, [(9, 27 + top), (14, 27 + top), (16, 33 + top), (18, 27 + top), (23, 27 + top), (23, 43 + top), (17, 45 + top), (16, 44 + top), (15, 45 + top), (9, 43 + top)])
        forms.shade(canvas, vest, shades, 3)
        forms.dots(canvas, [(15, y + top) for y in range(34, 44)], waistcoat["shade"])
        for y in range(34, 43, 3):
            forms.dots(canvas, [(16, y + top)], waistcoat["button"])
        for x0 in (11, 18):
            forms.dots(canvas, [(x, 39 + top) for x in range(x0, x0 + 3)], waistcoat["shade"])
    else:
        vest = mask(forms.rounded_box, 9, 27 + top, 22, 44 + top)
        forms.shade(canvas, vest, shades, 3)
        # The seam down the back and the strap that draws it in at the waist.
        forms.dots(canvas, [(16, y + top) for y in range(29, 44)], waistcoat["shade"])
        forms.dots(canvas, [(x, 40 + top) for x in range(12, 20)], waistcoat["shade"])
        forms.dots(canvas, [(13, 40 + top), (18, 40 + top)], waistcoat["button"])
    draw_sleeves(canvas, figure, ramp(SHIRT))
    return canvas


# The short jacket of indigo wool, worn open over the waistcoat.
JACKET = {"base": "water", "light": "water_light", "shade": "water_deep"}


def draw_jacket(facing, pose, **colours):
    """A short jacket with long sleeves and turned-back cuffs, worn open: from the front the
    waistcoat shows between its edges, from the side at the chest. `colours` replace those of
    JACKET."""
    jacket = JACKET | colours
    shades = ramp(jacket)
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    figure = Figure(facing, pose)
    top = figure.top
    draw_sleeves(canvas, figure, shades, far_only=True, cuffs=jacket["light"])
    if figure.is_side:
        body = mask(forms.polygon, [(10, 26 + top), (18, 26 + top), (19, 33 + top), (20, 46 + top), (10, 46 + top)])
        forms.shade(canvas, body, shades, 3)
        forms.dots(canvas, [(18, y + top) for y in range(27, 33)], jacket["light"])
    elif facing == "down":
        for points in (
            [(8, 26 + top), (14, 26 + top), (13, 36 + top), (14, 46 + top), (8, 46 + top)],
            [(18, 26 + top), (24, 26 + top), (24, 46 + top), (18, 46 + top), (19, 36 + top)],
        ):
            forms.shade(canvas, mask(forms.polygon, points), shades, 2)
        # The collar, turned down over the shoulders.
        forms.dots(canvas, [(x, 26 + top) for x in (9, 10, 11, 12, 13, 19, 20, 21, 22)], jacket["light"])
        forms.dots(canvas, [(13, 27 + top), (19, 27 + top)], jacket["light"])
    else:
        forms.shade(canvas, mask(forms.rounded_box, 8, 26 + top, 23, 46 + top), shades, 3)
        forms.dots(canvas, [(x, 26 + top) for x in range(10, 22)], jacket["light"])
        # The vent up the back.
        forms.dots(canvas, [(16, y + top) for y in range(38, 47)], jacket["shade"])
    draw_sleeves(canvas, figure, shades, cuffs=jacket["light"], fold=jacket["shade"])
    return canvas


def draw_shapes(canvas, figure, shapes, colours):
    """Shapes of a hat: each (kind, numbers, colour key, shading radius) with its rows given from
    the top of a standing figure; a radius of 0 fills the shape flat. The kinds: an "ellipse"
    (middle and radii), a "dome" (the top half of an ellipse: middle, bottom row and radii), a
    "box" with rounded corners and a "line" (from x, y to x, y), a "capsule" (start, end and
    their radii) and a "polygon" (its corners)."""
    for kind, numbers, key, radius in shapes:
        shape = forms_shape(kind, numbers, figure.top)
        if radius:
            forms.shade(canvas, shape, ramp_of(colours, key), radius)
        else:
            forms.paint(canvas, shape, colours[key])


def forms_shape(kind, numbers, top):
    if kind == "ellipse":
        cx, cy, rx, ry = numbers
        return mask(forms.ellipse, cx, cy + top, rx, ry)
    if kind == "box":
        x0, y0, x1, y1 = numbers
        return mask(forms.rounded_box, x0, y0 + top, x1, y1 + top)
    if kind == "line":
        x0, y0, x1, y1 = numbers
        return mask(forms.box, x0, y0 + top, x1, y1 + top)
    if kind == "dome":
        cx, bottom, rx, ry = numbers
        return mask(forms.ellipse, cx, bottom + 1 + top, rx, ry) & mask(forms.box, 0, 0, CHARACTER_WIDTH - 1, bottom + top)
    if kind == "capsule":
        start, end, r0, r1 = numbers
        return mask(forms.capsule, (start[0], start[1] + top), (end[0], end[1] + top), r0, r1)
    return mask(forms.polygon, [(x, y + top) for x, y in numbers])


def ramp_of(colours, key):
    """The shades of a part of a hat: its colour key's dark, middle and light."""
    return tuple(colours[f"{key}_{step}"] for step in ("shade", "base", "light"))


# Hats, drawn from shapes (see `draw_shapes`): from the front (also from behind) and from the
# side, facing right. The top of every hat is on row 2.
STRAW = {"brim_shade": "reed", "brim_base": "straw", "brim_light": "sand_light", "band": "umber", "weave": "reed"}
STRAW_HAT_SHAPES = {
    "front": (
        ("ellipse", (16, 10.5, 13.2, 3.6), "brim", 2),
        ("box", (10, 2, 21, 9), "brim", 3),
        ("line", (10, 8, 21, 9), "band", 0),
    ),
    "side": (
        ("ellipse", (16, 10.5, 13.2, 3.0), "brim", 2),
        ("box", (10, 2, 21, 9), "brim", 3),
        ("line", (10, 8, 21, 9), "band", 0),
    ),
}
# A black felt hat with a broad brim: the straw hat's shape in felt, with a band of ribbon.
FELT = {"brim_shade": "ink", "brim_base": "stone_dark", "brim_light": "stone", "band": "soil_dark", "weave": "ink"}
# The knitted stocking caps: red, the player's, and white. The tip flops over to the side and
# hangs down with a tassel.
KNITTED = {
    "red": {"cap_shade": "rust_dark", "cap_base": "rust", "cap_light": "red_light", "band": "russet_deep", "rib": "ember"},
    "white": {"cap_shade": "sand_light", "cap_base": "lime", "cap_light": "snow_light", "band": "sand", "rib": "cream"},
}
KNITTED_CAP_SHAPES = {
    "front": (
        ("capsule", ((20, 5), (26, 11), 3.4, 2.4), "cap", 2),
        ("capsule", ((26, 11), (26.5, 20), 2.4, 1.8), "cap", 2),
        ("dome", (16, 13, 8.8, 9.5), "cap", 3),
        ("line", (7, 12, 24, 13), "rib", 0),
        ("ellipse", (26.5, 21.5, 2, 2), "band", 0),
    ),
    "side": (
        ("capsule", ((12, 5), (6, 10), 3.4, 2.4), "cap", 2),
        ("capsule", ((6, 10), (5.5, 19), 2.4, 1.8), "cap", 2),
        ("dome", (15.5, 13, 8.6, 9.5), "cap", 3),
        ("line", (7, 12, 24, 13), "rib", 0),
        ("ellipse", (5.5, 20.5, 2, 2), "band", 0),
    ),
}


def draw_hat(facing, pose, shapes, colours, **_):
    """A hat from its shapes (see `draw_shapes`) in its colours; a straw or felt hat has its
    weave or nap in a few strokes, a knitted cap the ribbing of its band."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    figure = Figure(facing, pose)
    top = figure.top
    draw_shapes(canvas, figure, shapes["side" if figure.is_side else "front"], colours)
    if "weave" in colours:
        forms.dots(canvas, [(12, 4 + top), (15, 5 + top), (18, 4 + top), (20, 6 + top), (13, 6 + top)], colours["weave"])
        forms.dots(canvas, [(6, 10 + top), (24, 10 + top), (4, 11 + top), (27, 11 + top)], colours["weave"])
    if "rib" in colours:
        forms.dots(canvas, [(x, 13 + top) for x in range(7, 25, 2) if canvas[13 + top][x] is not None], colours["band"])
    return canvas


# The tools in the hand (assets/character/held_<tool>.png): a 2 px wooden handle and a hand-drawn
# head beside it, a map of letters in the colours of the tool's grade (tool_grades.py), as the
# icons are (tool_icons.py). Each head map is drawn pointing to the right, with the handle's two
# columns at the column `head` is told, and is mirrored to point the other way.
IRON = ("stone_dark", "stone", "stone_light")
HAND = ("skin_shade", "skin", "skin")
# The row of the hands of a standing figure.
HANDS_ROW = 41


def held_tool(draw_tool, is_long, grade=tool_grades.GRADES[0]):
    """The layer of a tool in the right hand, drawn by `draw_tool(canvas, x, y, outward, grade)`:
    `x` is the left column of the 2 px handle, `y` the row of the hand round it, and `outward`
    (1 or -1) the side away from the body, forward from the side. A long tool stands on the
    ground: from the front at the left of the picture, from behind at the right (behind the
    figure), from the side in front of it. A short one is held up by its handle in the hand that
    hangs at the side, and swings with the near hand when seen from the side."""

    def draw(facing, pose, **_):
        canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
        figure = Figure(facing, pose)
        if facing == "down":
            arm, outward = figure.arms[0], -1
        else:
            arm, outward = figure.arms[-1], 1
        x, y = int(arm.hand[0]), int(arm.hand[1])
        if is_long:
            x, y = (23 if figure.is_side else x), HANDS_ROW + figure.top
        draw_tool(canvas, x, y, outward, grade)
        if facing != "up":
            forms.shade(canvas, mask(forms.rounded_box, x - 1, y - 1, x + 2, y + 1), HAND, 1)
        return canvas

    draw.holds_tool = True
    return draw


def handle(canvas, x, top, bottom, grade):
    """The handle's two columns, the left one lit."""
    wood = tool_grades.keys(grade)
    forms.paint(canvas, mask(forms.box, x, top, x, bottom), wood["l"])
    forms.paint(canvas, mask(forms.box, x + 1, top, x + 1, bottom), wood["d"])


def head(canvas, x, top, outward, rows, handle_column, grade):
    """Stamps a head map whose handle columns are `handle_column` and the next, pointing right,
    over the handle at `x` from row `top` down; mirrored if `outward` points left."""
    if outward < 0:
        rows = [row[::-1] for row in rows]
        handle_column = len(rows[0]) - 2 - handle_column
    tool_grades.stamp(canvas, x - handle_column, top, rows, grade)


# fmt: off
HOE_HEAD = (
    "..mmmmm",
    "kkssssk",
    "..ssssk",
    "..eeeee",
)
SPADE_GRIP = ("lwwd",)
SPADE_BLADE = (
    ".kssk.",
    "mssssk",
    "mssssk",
    "mssssk",
    "mssssk",
    "mssssk",
    "mssssk",
    "mssssk",
    "mssssk",
    "eeeeek",
    ".eeee.",
)
SCYTHE_BLADE = (
    ".mmmmm..",
    "kkesssmm",
    "...eesss",
    ".....eee",
)
SCYTHE_NIB = (
    "..lw",
    "..ld",
)
AXE_HEAD = (
    "....mme",
    "kssssse",
    "kssssse",
    "kssssse",
    "....kke",
)
PICK_HEAD = (
    "..mmmm..",
    ".mskksm.",
    "ks....sk",
    "e......e",
)
HAMMER_HEAD = (
    "emmmmme",
    "essssse",
    "essssse",
    "ekkkkke",
)
CAN = (
    "..kk.....",
    ".kkkk....",
    "mmmmmm.mm",
    "mkkkkk.sk",
    "mssssk..s",
    "mkkkkk.s.",
    "mssssks..",
    "mssssk...",
    "mssssk...",
    "kkkkkk...",
)
# fmt: on


def hoe(canvas, x, y, outward, grade):
    """A long shaft, an iron neck off its top and the flat blade hanging from it outward."""
    handle(canvas, x, y - 17, 62, grade)
    head(canvas, x, y - 21, outward, HOE_HEAD, 0, grade)


def shovel(canvas, x, y, outward, grade):
    """A spade standing on its iron blade, a T grip at the top of the shaft."""
    handle(canvas, x, y - 13, 51, grade)
    head(canvas, x, y - 14, outward, SPADE_GRIP, 1, grade)
    head(canvas, x, 52, outward, SPADE_BLADE, 2, grade)


def scythe(canvas, x, y, outward, grade):
    """A snath taller than the figure with a nib, the blade off its top sweeping outward and
    down, its edge on the inner side."""
    handle(canvas, x, y - 27, 62, grade)
    head(canvas, x, y - 29, outward, SCYTHE_BLADE, 0, grade)
    head(canvas, x, y - 11, outward, SCYTHE_NIB, 0, grade)


def axe(canvas, x, y, outward, grade):
    """Held at the throat of the handle: the head just above the hand, its bit flaring outward
    to the edge, the poll behind, the handle down to the knee."""
    handle(canvas, x, y - 4, y + 10, grade)
    head(canvas, x, y - 9, outward, AXE_HEAD, 1, grade)


def pickaxe(canvas, x, y, outward, grade):
    """Held at the throat of the handle: the head across its top, both arms bent down to their
    points."""
    handle(canvas, x, y - 7, y + 10, grade)
    head(canvas, x, y - 9, outward, PICK_HEAD, 3, grade)


def hammer(canvas, x, y, outward, grade):
    """Held by the end of a short handle, the heavy head across its top with a striking face at
    each end."""
    handle(canvas, x, y - 3, y + 3, grade)
    head(canvas, x, y - 7, outward, HAMMER_HEAD, 2, grade)


def watering_can(canvas, x, y, outward, grade):
    """A can hanging from the hand by its hoop, its spout rising outward to the rose."""
    head(canvas, x, y + 1, outward, CAN, 2, grade)


# The horn lantern (its icon is in items.py): tin, and panes of horn that glow when it is lit.
HORN = ("mud", "sand", "sand_light")
LIT_HORN = ("ochre", "gold", "cream")


def lantern(is_lit):
    """The horn lantern hanging from the hand by the ring on its roof: a cone of tin, a pane of
    horn between two upright bars, and a wider foot. Lit, the horn glows and the flame shows
    through it; the light it throws is the game's (a PointLight2D)."""

    def draw(canvas, x, y, outward, _grade):
        forms.paint(canvas, mask(forms.box, x, y + 1, x + 1, y + 2), IRON[0])
        forms.shade(canvas, mask(forms.polygon, [(x + 0.5, y + 2), (x + 4.5, y + 6), (x - 3.5, y + 6)]), IRON, 1)
        forms.shade(canvas, mask(forms.box, x - 2, y + 6, x + 3, y + 13), LIT_HORN if is_lit else HORN, 2)
        if is_lit:
            forms.dots(canvas, [(x, y + 8), (x + 1, y + 9), (x, y + 9), (x, y + 10), (x + 1, y + 10)], "flame")
            forms.dots(canvas, [(x, y + 10), (x + 1, y + 11), (x, y + 11)], "cream")
        else:
            forms.paint(canvas, mask(forms.box, x, y + 9, x + 1, y + 12), "lime")
            forms.dots(canvas, [(x, y + 8)], "soil_dark")
        forms.paint(canvas, mask(forms.box, x - 2, y + 6, x - 2, y + 13) | mask(forms.box, x + 3, y + 6, x + 3, y + 13), IRON[1])
        forms.shade(canvas, mask(forms.box, x - 3, y + 14, x + 4, y + 15), IRON, 1)

    return draw


def held_tools(grade):
    """The held layer of each tool in one grade, by the tool's name."""
    return {
        "hoe": held_tool(hoe, True, grade),
        "shovel": held_tool(shovel, True, grade),
        "scythe": held_tool(scythe, True, grade),
        "axe": held_tool(axe, False, grade),
        "pickaxe": held_tool(pickaxe, False, grade),
        "hammer": held_tool(hammer, False, grade),
        "watering_can": held_tool(watering_can, False, grade),
    }


# The held layer of each tool by its sheet's name (see `held_tool`): the tools in their first
# grade, and the lantern.
HELD_TOOLS = held_tools(tool_grades.GRADES[0]) | {
    "lantern": held_tool(lantern(is_lit=False), is_long=False),
    "lantern_lit": held_tool(lantern(is_lit=True), is_long=False),
}


def mirrored(canvas):
    return [row[::-1] for row in canvas]


def outlined(canvas, skip):
    """Adds a 1 px ink outline around the drawing, except on pixels covered by `skip`: the
    body already outlines itself, and a layer drawn over it must not cut lines into it."""
    width, height = len(canvas[0]), len(canvas)
    covered = pixels_of(canvas)
    for x, y in covered:
        for dx, dy in NEIGHBOURS:
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in covered and (nx, ny) not in skip:
                canvas[ny][nx] = "ink"
    return canvas


def pixels_of(canvas):
    return {(x, y) for y, row in enumerate(canvas) for x, colour in enumerate(row) if colour is not None}


def worn(draw, facing, pose, variant_colours):
    """A layer drawn on the figure. The near hands are in front of everything worn, so every
    layer but the body and the held tool leaves them clear for the body's hands to show."""
    canvas = draw(facing, pose, **variant_colours)
    if draw is not draw_body and not getattr(draw, "holds_tool", False):
        for arm in Figure(facing, pose).arms:
            if not arm.far:
                forms.paint(canvas, hand(arm), None)
    return canvas


def character_sheet(draw, variant_colours, poses=tuple(POSES[frame] for frame in PLAYER_FRAMES)):
    """One layer's sheet: the layer drawn in every facing and pose (the frames of PLAYER_FRAMES),
    with its outline."""
    rows = []
    for facing in PLAYER_FACINGS:
        drawn_facing = "right" if facing == "left" else facing
        row = []
        for pose in poses:
            body_pixels = pixels_of(draw_body(drawn_facing, pose))
            canvas = worn(draw, drawn_facing, pose, variant_colours)
            canvas = outlined(canvas, set() if draw is draw_body else body_pixels)
            row.append(mirrored(canvas) if facing == "left" else canvas)
        rows.append(row)
    return rows


# Passing out (assets/character/collapse/<name>.png, one per layer sheet but the held tool,
# which is let go): one row of 64x64 frames, facing right (the game mirrors them for left),
# with the feet or the body on the bottom row: kneeling, tipping over forward, lying and
# asleep. Lying is the side view of the standing figure laid down head first, face up.
COLLAPSE_SIZE = 64
# How far each row of the kneeling figure leans forward, per row above the ground: slumped
# while kneeling, then tipping over.
SLUMP_LEAN = 0.12
TIP_LEAN = 0.45


def leaning(lean):
    """Places the 32x64 figure in the middle of the frame, each row moved forward by its
    height above the ground times `lean`. Whole pixel steps keep the art crisp; a wide brim
    tipped over that far is cut off at the frame's edge."""

    def place(canvas):
        frame = blank(COLLAPSE_SIZE)
        left = (COLLAPSE_SIZE - CHARACTER_WIDTH) // 2
        ground = CHARACTER_HEIGHT - 1
        for y, row in enumerate(canvas):
            shift = left + round((ground - y) * lean)
            for x, colour in enumerate(row):
                if colour is not None and x + shift < COLLAPSE_SIZE:
                    frame[y][x + shift] = colour
        return frame

    return place


def lying(canvas):
    """The standing figure laid down on the bottom half of the frame: its head to the right
    (forward), its front (face and toes) up."""
    frame = blank(COLLAPSE_SIZE)
    for y, row in enumerate(canvas):
        for x, colour in enumerate(row):
            if colour is not None:
                frame[COLLAPSE_SIZE - 1 - x][CHARACTER_HEIGHT - 1 - y] = colour
    return frame


COLLAPSE_FRAMES = (
    (KNEEL, leaning(SLUMP_LEAN)),
    (KNEEL, leaning(TIP_LEAN)),
    (POSES["idle"], lying),
    (ASLEEP, lying),
)


def collapse_sheet(draw, variant_colours):
    """One layer's passing-out frames, outlined after they are placed, like `character_sheet`."""
    row = []
    for pose, place in COLLAPSE_FRAMES:
        body_pixels = pixels_of(place(draw_body("right", pose)))
        canvas = place(worn(draw, "right", pose, variant_colours))
        row.append(outlined(canvas, set() if draw is draw_body else body_pixels))
    return [row]


def riding_sheet(draw, variant_colours):
    """One layer's riding frames (assets/character/riding/<name>.png, every layer but the held
    tool: the hands hold the reins): sitting astride, one frame per facing in the rows of
    `character_sheet`."""
    return character_sheet(draw, variant_colours, (RIDE,))


def layers():
    """The layer sheets by file name (assets/character/<name>.png, and the same names in
    collapse/ for passing out), each as the function that draws it and the colours of its
    variant."""
    result = {"body_0": (draw_body, {})}
    result["clothes_0"] = (draw_waistcoat, {})
    result["clothes_1"] = (draw_shirt, {})
    result["coat_jacket"] = (draw_jacket, {})
    for variant, colours in HAIR_STYLES.items():
        result[f"hair_{variant}"] = (draw_hair, colours)
    result["legs_0"] = (draw_legs, {})
    result["feet_clogs"] = (draw_clogs, {})
    result["head_straw_hat"] = (draw_hat, {"shapes": STRAW_HAT_SHAPES, "colours": STRAW})
    result["head_knitted_cap"] = (draw_hat, {"shapes": KNITTED_CAP_SHAPES, "colours": KNITTED["red"]})
    return result


def sleep_z():
    """The "z" that rises from a sleeping figure (assets/effects/sleep_z.png): a cream glyph,
    shaded under its strokes, with the ink outline around them."""
    keys = {"c": "cream", "s": "sand_light"}
    rows = (
        "..........",
        ".cccccccc.",
        ".sssssccs.",
        ".....ccs..",
        "....ccs...",
        "...ccs....",
        "..ccs.....",
        ".cccccccc.",
        ".ssssssss.",
        "..........",
    )
    return outlined([[keys.get(key) for key in line] for line in rows], set())


def outlined_effect(rows, keys):
    """A picture from a map of letters, with a clear margin of a pixel for its ink outline."""
    width = len(rows[0]) + 2
    canvas = [[None] * width] + [[None] + [keys.get(key) for key in row] + [None] for row in rows]
    canvas.append([None] * width)
    return outlined(canvas, set())


def pet_heart():
    """The heart over an animal that was petted (assets/effects/pet_heart.png): ember red lit
    from the top left with a petal-pink gleam, shaded dark red at the lower right."""
    keys = {"r": "ember", "p": "petal", "d": "soil"}
    rows = (
        ".rrr..rrr.",
        "rpprrrrrrd",
        "rprrrrrrrd",
        "rrrrrrrrrd",
        ".rrrrrrrd.",
        "..rrrrrd..",
        "...rrrd...",
        "....rd....",
    )
    return outlined_effect(rows, keys)


def pet_annoyed():
    """The anger mark over an animal that was petted while it slept (assets/effects/pet_annoyed.png),
    as in a comic: four thin black strokes, each bent round a corner towards the middle, round
    an empty cross, with a stone-grey gleam on their outer edge. Black is its own outline, so it
    has none."""
    rows = (
        "....c..c....",
        "...hc..ch...",
        "...hc..ch...",
        "..hcc..cch..",
        "hcccc..cccch",
        "............",
        "............",
        "hcccc..cccch",
        "..hcc..cch..",
        "...hc..ch...",
        "...hc..ch...",
        "....c..c....",
    )
    keys = {"c": "ink", "h": "stone"}
    return [[keys.get(key) for key in row] for row in rows]
