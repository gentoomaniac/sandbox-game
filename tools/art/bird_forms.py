"""Birds put together from rounded forms (forms.py), for the bird sheets of animals.py (the
sparrow), birds.py (the stork and the goose) and sea_birds.py.

A bird faces right. Standing (`standing`), it is a body (an egg turned by the pose), a tail, a
neck up to a round head with an eye and a bill, a folded wing on its side and two legs down to
the bottom row of the cell. Flying (`flying`) it is seen side on and a little from above: the
body level, the neck stretched, and the wings at the level of the beat, the far one behind the
body and the near one in front of it. Everything is shaded by the light from the top left;
the body, head and wings get a one pixel outline in the bird's outline colour, and the bill and
the legs are drawn over it, so that they keep their thickness.

A species is a `Bird`: its sizes (in pixels) and its colours. A ramp is 2 to 4 colours, dark to
light. Its markings beyond these (a bib, a cap, a bar on the wing) are drawn by `marks`, given
the picture and the `Parts` of the frame.
"""

import math
from collections import namedtuple

import numpy as np

import forms
from canvas import blank, outline

Bird = namedtuple(
    "Bird",
    [
        # Sizes: the half length and half height of the body, the neck's radius, the head's
        # radius, the bill's length and its radius at the root, how long the legs are from the
        # body's bottom to the ground and how thick (1 or 2 pixels), the tail's length, and the
        # wing's span (root to tip) and half its width at the root in flight.
        "body",
        "neck",
        "head",
        "bill",
        "legs",
        "leg_width",
        "tail",
        "span",
        "chord",
        # Colours: ramps of the body, of its lower and upper part (None: the body's), of the
        # head, of the folded wing and the open wing, and of the tail; single colours of the
        # outline, the eye, the bill and its shaded underside, the near and the far leg, the
        # tips of the open wing, its trailing edge (None for none) and the folded wing's tip.
        "ramp",
        "belly",
        "back",
        "head_ramp",
        "wing",
        "flight_wing",
        "tail_ramp",
        "outline",
        "eye",
        "bill_colours",
        "leg_colours",
        "wing_tip",
        "trailing_edge",
        "primaries",
        # A function(picture, parts) that draws the species' own markings, or None.
        "marks",
    ],
)

# Where the parts of a frame ended up, for `marks`: the masks of the body, the head, the folded
# wing (None in flight) and the wings (empty standing), the head's centre and radius, the bill's
# root and tip, and the body's centre and turn.
Parts = namedtuple("Parts", "body head wing wings head_centre head_radius bill_root bill_tip centre angle")


def turned(vector, angle):
    """A vector of the body (x forward, y down) turned with it by `angle` degrees."""
    x, y = vector
    turn = math.radians(angle)
    return (x * math.cos(turn) + y * math.sin(turn), -x * math.sin(turn) + y * math.cos(turn))


def plus(point, vector):
    return (point[0] + vector[0], point[1] + vector[1])


def line(picture, start, end, colour, width=1):
    """A straight stroke from start to end, 1 or 2 pixels thick (the second to the right and
    below), clipped to the picture."""
    (x0, y0), (x1, y1) = start, end
    steps = max(1, math.ceil(max(abs(x1 - x0), abs(y1 - y0)) * 2))
    points = set()
    for step in range(steps + 1):
        x = math.floor(x0 + (x1 - x0) * step / steps)
        y = math.floor(y0 + (y1 - y0) * step / steps)
        points.add((x, y))
        if width == 2:
            points.add((x + 1, y) if abs(y1 - y0) >= abs(x1 - x0) else (x, y + 1))
    forms.dots(picture, sorted(points), colour)


def _bill(picture, bird, root, angle, is_open):
    """The bill from its root, pointing at `angle` degrees below the horizontal: lit on top and
    shaded below, two halves apart when it is open. Returns the tip."""
    length, radius = bird.bill
    lit, shaded = bird.bill_colours
    height, width = len(picture), len(picture[0])
    halves = (-14, 14) if is_open else (0,)
    tip = root
    for spread in halves:
        turn = math.radians(angle + spread)
        tip = (root[0] + length * math.cos(turn), root[1] + length * math.sin(turn))
        mask = forms.capsule(width, height, root, tip, radius, 0.5)
        forms.paint(picture, mask, lit)
        # The lower edge, shaded.
        below = mask & ~np.roll(mask, -1, axis=0)
        forms.paint(picture, below & (np.arange(height)[:, None] > root[1] - 0.5), shaded)
    return tip


def _head(picture, bird, centre):
    height, width = len(picture), len(picture[0])
    head = forms.ellipse(width, height, centre[0], centre[1], bird.head, bird.head)
    forms.shade(picture, head, bird.head_ramp, radius=max(1, round(bird.head * 0.6)))
    return head


def _eye(picture, bird, centre, look_round=False):
    """The eye, drawn over the markings; looking round, it is in the middle of the head."""
    eye_x = centre[0] + (0.0 if look_round else bird.head * 0.35)
    forms.dots(picture, [(math.floor(eye_x), math.floor(centre[1] - bird.head * 0.25))], bird.eye)


def _legs(picture, bird, hips, steps, ground):
    """Two legs from the hips to the ground, each with the heel bent back a little and a toe
    forward. `steps` are (forward shift, lift) of the near and the far foot."""
    width = bird.leg_width
    near, far = bird.leg_colours
    for (hip_x, hip_y), (shift, lift), colour in reversed(list(zip(hips, steps, (near, far)))):
        foot = (hip_x + shift, ground - lift)
        heel = (hip_x + shift * 0.4 - 1.0, hip_y + (foot[1] - hip_y) * 0.45)
        line(picture, (hip_x, hip_y), heel, colour, width)
        line(picture, heel, foot, colour, width)
        line(picture, foot, (foot[0] + 1 + width, foot[1]), colour)


def _shade_part(picture, part, ramp, level):
    """Fills `part` in the colours of `ramp` by the light `level` of the form it is part of."""
    steps = sum((level > threshold).astype(int) for threshold in forms.THRESHOLDS[len(ramp)])
    for y, x in zip(*np.nonzero(part)):
        picture[y][x] = ramp[steps[y, x]]


def _body(picture, bird, centre, radii, angle):
    """The body, its belly and its back in their ramps. Returns its mask."""
    height, width = len(picture), len(picture[0])
    rx, ry = radii
    body = forms.ellipse(width, height, centre[0], centre[1], rx, ry, angle)
    radius = max(2, round(ry * 0.6))
    forms.shade(picture, body, bird.ramp, radius=radius)
    xs, ys = forms.grid(width, height)
    turn = math.radians(angle)
    across = (xs - centre[0]) * math.sin(turn) + (ys - centre[1]) * math.cos(turn)
    level = forms.light_level(body, radius)
    if bird.belly is not None:
        _shade_part(picture, body & (across > ry * 0.2), bird.belly, level)
    if bird.back is not None:
        _shade_part(picture, body & (across < -ry * 0.35), bird.back, level)
    return body


def _neck_and_head(picture, bird, shoulder, head_centre):
    height, width = len(picture), len(picture[0])
    neck = forms.capsule(width, height, shoulder, head_centre, bird.neck, bird.neck * 0.85)
    forms.shade(picture, neck, bird.head_ramp, radius=max(1, round(bird.neck * 0.7)))
    return _head(picture, bird, head_centre)


def _bill_root(bird, head_centre, bill_angle, reach=0.75):
    turn = math.radians(bill_angle)
    return (head_centre[0] + bird.head * reach * math.cos(turn), head_centre[1] + bird.head * reach * math.sin(turn))


def standing(size, bird, centre, angle=0.0, head_at=(0, 0), bill_angle=10.0, steps=((0, 0), (0, 0)),
             is_open=False, look_round=False, lift=0, swimming=False):
    """A standing, walking or pecking bird on a cell of `size`: its body's centre at `centre`
    (raised by `lift`), turned by `angle` degrees (head up for a positive angle), its head
    `head_at` from where the neck leaves the body, its bill at `bill_angle` degrees below the
    horizontal (open or shut). Looking round, the head is turned to the viewer and the bill
    is short. Swimming it has no legs. Returns the picture and its `Parts`."""
    width, height = size
    picture = blank(width, height)
    rx, ry = bird.body
    centre = (centre[0], centre[1] - lift)
    # The tail, behind the body: a wedge from its back end.
    tail = forms.polygon(width, height, [
        plus(centre, turned((-rx * 0.5, -ry * 0.55), angle)),
        plus(centre, turned((-rx - bird.tail, -ry * 0.15), angle)),
        plus(centre, turned((-rx - bird.tail, ry * 0.25), angle)),
        plus(centre, turned((-rx * 0.4, ry * 0.5), angle)),
    ])
    forms.shade(picture, tail, bird.tail_ramp, radius=1)
    shoulder = plus(centre, turned((rx * 0.6, -ry * 0.45), angle))
    head_centre = plus(shoulder, head_at)
    head = _neck_and_head(picture, bird, shoulder, head_centre)
    body = _body(picture, bird, centre, (rx, ry), angle)
    # The folded wing on its side, its long tip over the tail.
    wing_centre = plus(centre, turned((-rx * 0.15, -ry * 0.15), angle))
    wing = forms.ellipse(width, height, wing_centre[0], wing_centre[1], rx * 0.72, ry * 0.58, angle)
    if bird.primaries is not None:
        wing |= forms.polygon(width, height, [
            plus(wing_centre, turned((-rx * 0.2, -ry * 0.5), angle)),
            plus(wing_centre, turned((-rx * 0.9 - bird.tail * 0.6, -ry * 0.05), angle)),
            plus(wing_centre, turned((-rx * 0.2, ry * 0.45), angle)),
        ])
    forms.shade(picture, wing, bird.wing, radius=max(1, round(ry * 0.4)))
    if bird.primaries is not None:
        xs, _ = forms.grid(width, height)
        forms.paint(picture, wing & (xs < wing_centre[0] - rx * 0.45), bird.primaries)
    bill_root = _bill_root(bird, head_centre, bill_angle, 0.3 if look_round else 0.75)
    parts = Parts(body, head, wing, np.zeros_like(body), head_centre, bird.head, bill_root, None, centre, angle)
    if bird.marks is not None:
        bird.marks(picture, parts)
    _eye(picture, bird, head_centre, look_round)
    picture = outline(picture, bird.outline)
    bill = bird._replace(bill=(bird.bill[0] * 0.5, bird.bill[1])) if look_round else bird
    bill_tip = _bill(picture, bill, bill_root, bill_angle, is_open)
    if not swimming:
        hips = [plus(centre, turned((dx, ry * 0.75), angle)) for dx in (rx * 0.05, rx * 0.3)]
        _legs(picture, bird, hips, steps, height - 1)
    return picture, parts._replace(bill_tip=bill_tip)


# The open wings at each level of the beat: the tip of the near and of the far wing, as
# (backward, upward) shares of the span from the middle of the root; None hides that wing.
BEATS = {
    "up": ((0.45, 0.9), (0.25, 0.95)),
    "level": ((0.35, -0.5), (0.3, 0.4)),
    "down": ((0.3, -0.9), None),
    # A hover: the wings held high and spread forward, beating fast.
    "high": ((-0.05, 0.9), (-0.2, 0.95)),
}


def _open_wing(picture, bird, root, tip_share, darker):
    """One open wing from the middle of its root on the body: a long blade, its leading edge in
    front, narrowing to a pointed tip, shaded, its tip and its trailing edge coloured. Returns
    its mask."""
    height, width = len(picture), len(picture[0])
    back, up = tip_share
    tip = (root[0] - back * bird.span, root[1] - up * bird.span)
    chord = bird.chord

    def along(share, forward):
        return (root[0] + (tip[0] - root[0]) * share + forward, root[1] + (tip[1] - root[1]) * share)

    blade = [along(0, chord * 0.8), along(0.55, chord * 0.55), tip, along(0.6, -chord * 0.9), along(0, -chord)]
    mask = forms.polygon(width, height, blade)
    ramp = bird.flight_wing[:-1] if darker and len(bird.flight_wing) > 2 else bird.flight_wing
    forms.shade(picture, mask, ramp, radius=max(1, round(chord * 0.5)))
    xs, ys = forms.grid(width, height)
    reach = np.hypot(tip[0] - root[0], tip[1] - root[1]) or 1.0
    share = ((xs - root[0]) * (tip[0] - root[0]) + (ys - root[1]) * (tip[1] - root[1])) / reach**2
    # Pixels behind (towards the tail of) the line from the root to the tip, by how far.
    behind = (root[0] + (tip[0] - root[0]) * share) - xs
    if bird.trailing_edge is not None:
        forms.paint(picture, mask & (behind > chord * 0.15) & (share > 0.1), bird.trailing_edge)
    if bird.wing_tip is not None:
        forms.paint(picture, mask & (share > 0.65), bird.wing_tip)
    return mask


def flying(size, bird, centre, beat, bill_angle=0.0, legs_trailing=False):
    """A bird in flight on a cell of `size`, its body's centre at `centre`, the wings at the
    level `beat` of BEATS. Returns the picture and its `Parts`."""
    width, height = size
    picture = blank(width, height)
    rx, ry = bird.body[0] * 0.85, bird.body[1] * 0.8
    near_tip, far_tip = BEATS[beat]
    root = (centre[0] + rx * 0.15, centre[1] - ry * 0.3)
    wings = np.zeros((height, width), bool)
    if far_tip is not None:
        wings |= _open_wing(picture, bird, (root[0] + 1, root[1] - 1), far_tip, darker=True)
    # The tail, spread a little behind the body.
    tail = forms.polygon(width, height, [
        (centre[0] - rx * 0.5, centre[1] - ry * 0.4),
        (centre[0] - rx - bird.tail, centre[1] - ry * 0.5),
        (centre[0] - rx - bird.tail, centre[1] + ry * 0.3),
        (centre[0] - rx * 0.5, centre[1] + ry * 0.3),
    ])
    forms.shade(picture, tail, bird.tail_ramp, radius=1)
    shoulder = (centre[0] + rx * 0.75, centre[1] - ry * 0.2)
    head_centre = (shoulder[0] + bird.neck + bird.head * 0.6, shoulder[1] - ry * 0.25)
    head = _neck_and_head(picture, bird, shoulder, head_centre)
    body = _body(picture, bird, centre, (rx, ry), 0.0)
    if near_tip is not None:
        wings |= _open_wing(picture, bird, (root[0], root[1] + ry * 0.5), near_tip, darker=False)
    bill_root = _bill_root(bird, head_centre, bill_angle)
    parts = Parts(body, head, None, wings, head_centre, bird.head, bill_root, None, centre, 0.0)
    if bird.marks is not None:
        bird.marks(picture, parts)
    _eye(picture, bird, head_centre)
    picture = outline(picture, bird.outline)
    bill_tip = _bill(picture, bird, bill_root, bill_angle, False)
    if legs_trailing:
        start = (centre[0] - rx * 0.8, centre[1] + ry * 0.5)
        end = (centre[0] - rx - bird.tail - bird.legs * 0.4, centre[1] + ry * 0.6)
        line(picture, start, end, bird.leg_colours[0], bird.leg_width)
    return picture, parts._replace(bill_tip=bill_tip)
