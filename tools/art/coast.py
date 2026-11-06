"""The things of the Wadden coast in assets/objects.png: the Ewer, a flat-bottomed sailing barge
lying on the mud at low tide.

The Ewer stands on a footprint of 3x1 tiles, so its picture fills the width of its cell: a long,
low hull of tarred planks with a bluff bow, lying askew on the mud (the stern settled deeper, the
bow up) and heeled towards the viewer so its deck shows, a leeboard raised on the near side, a big
rudder, the mast leaning with the hull, the brown sail furled on its boom and the stays down to bow
and stern. Light from the top left, as everywhere.
"""

from canvas import OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, blank

# The row of the Ewer's flat bottom, and its ends: the bow on the left, the stern on the right.
_KEEL = 75
_BOW, _STERN = 1, 46
# The mast stands at this x on the deck and leans this many pixels to the right per pixel up.
_MAST_FOOT = 19
_MAST_LEAN = 1 / 7
_MAST_TOP = 14


def _put(canvas, x, y, colour):
    if 0 <= x < OBJECT_CELL_WIDTH and 0 <= y < OBJECT_CELL_HEIGHT:
        canvas[y][x] = colour


def _line(canvas, x0, y0, x1, y1, colour):
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for step in range(steps + 1):
        _put(canvas, round(x0 + (x1 - x0) * step / steps), round(y0 + (y1 - y0) * step / steps), colour)


def _askew(x):
    """How much lower the hull lies at x than amidships: she has settled stern first."""
    return round((x - 24) / 11)


def _sheer(x):
    """The row of the near gunwale at x: the bow rises highest, the stern a little."""
    if x < 12:
        rise = round((12 - x) ** 1.5 / 6)
    elif x > 38:
        rise = round((x - 38) * 0.4)
    else:
        rise = 0
    return 66 - rise + _askew(x)


def _bottom(x):
    """The row of the hull's bottom at x: flat, rounding up into the bluff bow and the stern."""
    if x < 8:
        rise = round((8 - x) ** 2 / 5)
    elif x > 41:
        rise = round((x - 41) ** 2 / 4)
    else:
        rise = 0
    return _KEEL - rise + _askew(x)


def _mast_x(y):
    return _MAST_FOOT + round((_sheer(_MAST_FOOT) - 3 - y) * _MAST_LEAN)


def ewer():
    """The Ewer lying on the mud at low tide."""
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    # The wet mud pressed down around the flat bottom.
    for x in range(_BOW + 3, _STERN - 1):
        _put(canvas, x, _KEEL + 1, "mud_dark")
        if 6 < x < 42 and x % 3:
            _put(canvas, x, _KEEL + 2, "mud_dark")
    # The stays, behind everything else: from the masthead down to the bow and the stern.
    top = (_mast_x(_MAST_TOP), _MAST_TOP)
    _line(canvas, *top, _BOW + 1, _sheer(_BOW + 1) - 4, "stone_dark")
    _line(canvas, *top, _STERN - 2, _sheer(_STERN - 2) - 3, "stone_dark")
    # The deck seen over the far gunwale, as she heels towards us: weathered planks.
    for x in range(_BOW + 2, _STERN - 1):
        far = _sheer(x) - 4
        _put(canvas, x, far, "soil_dark")
        for y in range(far + 1, _sheer(x)):
            _put(canvas, x, y, "bare_light" if (y + x // 6) % 2 else "bare")
    # The hull side: tarred planks, a seam every 3 rows, the wale along the top catching the light.
    for x in range(_BOW, _STERN + 1):
        for y in range(_sheer(x), _bottom(x) + 1):
            if y == _sheer(x):
                colour = "soil" if x < 30 else "soil_dark"
            elif y == _bottom(x) or x in (_BOW, _STERN):
                colour = "ink"
            elif (y - _sheer(x)) % 3 == 0:
                colour = "ink"
            elif y == _sheer(x) + 1 and x < 24 and x % 4:
                colour = "stone_dark"
            else:
                colour = "soil_dark"
            _put(canvas, x, y, colour)
    # The stem post at the bow and the rudder hung on the stern, with its tiller over the deck.
    _line(canvas, _BOW, _sheer(_BOW) - 1, _BOW + 2, _bottom(_BOW + 2), "soil")
    for y in range(_sheer(_STERN) - 1, _KEEL):
        for x in range(_STERN - 1, _STERN + 2):
            _put(canvas, x, y, "soil_mid" if x == _STERN - 1 else "soil")
        _put(canvas, _STERN + 1, y, "soil_dark")
    _line(canvas, _STERN - 1, _sheer(_STERN) - 2, _STERN - 8, _sheer(_STERN - 8) - 3, "soil_mid")
    # The leeboard raised on the near side: a fan of planks on its pivot.
    for y in range(67, 74):
        half = 1 + (y - 67) // 2
        for x in range(14 - half, 15 + half):
            edge = x in (14 - half, 14 + half) or y == 73
            _put(canvas, x, y, "ink" if edge else ("soil_mid" if x < 14 else "soil"))
    _put(canvas, 14, 68, "stone_light")
    # The mast, leaning with the hull, lit on its left.
    for y in range(_MAST_TOP, _sheer(_MAST_FOOT) - 2):
        x = _mast_x(y)
        _put(canvas, x, y, "soil_light")
        _put(canvas, x + 1, y, "soil")
    # A pennant at the masthead.
    for dx, dy in ((2, 0), (3, 0), (4, 1), (2, 1), (3, 1)):
        _put(canvas, top[0] + dx, top[1] + dy, "red_light" if dy == 0 else "rust")
    # The brown sail furled on its boom, lashed every few pixels, from the mast towards the stern.
    boom_y = _sheer(_MAST_FOOT) - 8
    for x in range(_mast_x(boom_y) + 1, 42):
        y = boom_y + (x - _MAST_FOOT) // 9
        for k, colour in enumerate(("umber", "rust_dark", "rust_dark", "russet_deep")):
            _put(canvas, x, y + k, colour)
        if x % 5 == 0:
            _put(canvas, x, y + 1, "sand")
            _put(canvas, x, y + 2, "sand")
    # The boom's end sticking out beyond the sail.
    end_y = boom_y + (42 - _MAST_FOOT) // 9
    _line(canvas, 42, end_y + 2, 45, end_y + 2, "soil_mid")
    return canvas


def ewer_row():
    return [ewer()]
