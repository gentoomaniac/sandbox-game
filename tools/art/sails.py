"""The four sails of the windmill (windmill.py, classic/windmill.py), drawn for both arts from one
geometry at the size each art gives (`Sails`).

The mill is seen from behind (see windmill.py), so the sails turn clockwise in the picture and
the lattice of each sail lies in front of its cloth. Each sail is a common sail of the period:
the stock (the long beam through the hub) with a lattice on its trailing side (sail bars across
it, an uplong or two along it, the hemlath along its outer edge) and a narrow board on its
leading side. With the wind the cloth is spread over the lattice; without it the cloth is furled
into a roll along the stock and the lattice stands bare.

Each frame is drawn anew from the geometry at its angle (no pixels are turned), so the bars stay
one pixel lines at every angle: a pixel belongs to a line when its middle is within half a pixel
of it, measured along the rows or columns the line crosses.
"""

import math
from dataclasses import dataclass

from canvas import blank

# The wood of the stocks, lit to dark, and of the lattice and the hemlath.
STOCK = ("soil_light", "soil_mid", "soil", "soil_dark")
BAR = "soil"
HEMLATH = "soil_dark"
# The cloth, spread: lit, and in the shadow a bar casts on it (to the bottom right of it, away
# from the light). Furled: the roll lit along its top, its body, and the shadow under it.
CLOTH = ("cream", "sand_light")
ROLL = ("cream", "sand_light", "sand")
# The hub, where the stocks cross: an oak block.
HUB = ("soil_mid", "soil_dark")
# The light comes from the top left.
LIGHT = (-1 / math.sqrt(2), -1 / math.sqrt(2))


@dataclass(frozen=True)
class Sails:
    """The size of the sails in one art, in px: `radius` from the hub to a sail's tip, the lattice
    from `inner` out to the tip and `width` wide on the trailing side, the board `lead` wide on
    the leading side, sail bars every `bar_step`, `uplongs` laths along it, the stock
    `stock` px thick, the furled roll `roll` px thick and the hub `hub` px across."""

    radius: int
    inner: int
    width: int
    lead: int
    bar_step: int
    uplongs: int
    stock: int
    roll: int
    hub: int

    @property
    def size(self):
        """The width and height of a frame: the hub is in its middle."""
        return 2 * self.radius + 5


def _on_line(distance, normal, thickness=1):
    """Whether a pixel whose middle is `distance` from a line (with `normal`) belongs to a line
    `thickness` px thick: within half that, counted along the rows or columns the line crosses."""
    return abs(distance) < thickness * max(abs(normal[0]), abs(normal[1])) / 2


def frame(sails, degrees, spread):
    """The sails turned `degrees` clockwise from upright and level (a cross like +), with the
    cloth spread or furled."""
    size = sails.size
    centre = size // 2
    picture = blank(size, size)
    kinds = {}
    for arm in range(4):
        angle = math.radians(degrees + 90 * arm)
        # Out along the arm, and across it towards the trailing side: the sails turn clockwise,
        # so the side that follows is the one an arm turns away from.
        along = (math.sin(angle), -math.cos(angle))
        across = (-math.cos(angle), -math.sin(angle))
        # Which side of the stock faces the light.
        lit_side = 1 if across[0] * LIGHT[0] + across[1] * LIGHT[1] > 0 else -1
        for y in range(size):
            for x in range(size):
                dx, dy = x - centre, y - centre
                u = dx * along[0] + dy * along[1]
                v = dx * across[0] + dy * across[1]
                kind = _part(sails, u, v, along, across, spread, lit_side)
                if kind is not None and _rank(kind) > _rank(kinds.get((x, y))):
                    kinds[(x, y)] = kind
    for (x, y), kind in kinds.items():
        picture[y][x] = kind
    # The cloth in the shadow of the wood above and left of it.
    for (x, y), kind in kinds.items():
        if spread and kind == CLOTH[0] and any(kinds.get((x - dx, y - dy)) in (*STOCK, BAR, HEMLATH) for dx, dy in ((1, 0), (0, 1), (1, 1))):
            picture[y][x] = CLOTH[1]
    # The hub, a square block lit on its top left.
    half = sails.hub // 2
    for y in range(centre - half, centre - half + sails.hub):
        for x in range(centre - half, centre - half + sails.hub):
            edge = x == centre - half + sails.hub - 1 or y == centre - half + sails.hub - 1
            picture[y][x] = HUB[1] if edge else HUB[0]
    return picture


# What lies over what: the stock over the lattice, the lattice over the cloth.
_RANKS = {CLOTH[0]: 1, ROLL[2]: 2, ROLL[1]: 2, ROLL[0]: 2, BAR: 3, HEMLATH: 4, **{colour: 5 + i for i, colour in enumerate(STOCK)}}


def _rank(kind):
    return _RANKS.get(kind, 0)


def _part(sails, u, v, along, across, spread, lit_side):
    """The colour of the point `u` out along an arm and `v` across it (positive to the trailing
    side), or None where the arm has nothing."""
    if u < -0.5 or u > sails.radius + 0.5:
        return None
    # The stock, lit on the side towards the light, dark on the other.
    if _on_line(v, across, sails.stock) and u <= sails.radius:
        band = v * lit_side / max(abs(across[0]), abs(across[1]))
        if band > sails.stock / 2 - 1:
            return STOCK[0]
        if band < -(sails.stock / 2 - 1):
            return STOCK[3] if sails.stock > 2 else STOCK[2]
        return STOCK[1]
    if u < sails.inner - 0.5:
        return None
    if not -sails.lead - 0.5 < v < sails.width + 0.5:
        return None
    # The hemlath along the outer edge and the edge of the leading board.
    if _on_line(v - sails.width, across) or _on_line(v + sails.lead, across):
        return HEMLATH
    # The sail bars across, the outermost at the tip.
    from_inner = u - sails.inner
    nearest = round(from_inner / sails.bar_step) * sails.bar_step
    if (_on_line(from_inner - nearest, along) and nearest <= sails.radius - sails.inner) or _on_line(u - sails.radius, along):
        return BAR
    if v < 0:
        return BAR if sails.lead > 1 else HEMLATH
    for lath in range(1, sails.uplongs + 1):
        if _on_line(v - sails.width * lath / (sails.uplongs + 1), across):
            return BAR
    if spread:
        return CLOTH[0]
    stock_edge = sails.stock / 2
    if v < stock_edge + sails.roll:
        depth = (v - stock_edge) / sails.roll
        return ROLL[0] if depth < 0.34 else ROLL[1] if depth < 0.75 else ROLL[2]
    return None


def strip(sails, frames, spread=True):
    """The sails turning, a quarter turn in `frames` steps side by side (the sails look the same
    after a quarter turn, so the strip loops), the first upright and level."""
    pictures = [frame(sails, 90 * step / frames, spread) for step in range(frames)]
    return [sum((picture[y] for picture in pictures), []) for y in range(sails.size)]
