"""The things of the Wadden coast in assets/objects.png: the Ewer, a flat-bottomed sailing barge
lying on the mud at low tide, drawn at 32 px per tile.

The Ewer lies on a footprint of 7x1 tiles, its picture three object cells wide (288x160, the
`cells_wide` of its type), so it is in scale with the people beside it: a long, low hull of
tarred planks with a bluff bow, lying askew on the mud (the stern settled deeper, the bow up) and
heeled towards the viewer so its deck shows, a leeboard raised on the near side, a small cabin
aft with its hatch, a big rudder with its tiller, the mast leaning with the hull, the brown sail
furled on its boom under the gaff, and the stays down to bow and stern. Light from the top left,
as everywhere; the hull is rimmed in its darkest tar.
"""

from canvas import GAME_OBJECT_CELL_HEIGHT, GAME_OBJECT_CELL_WIDTH, blank

# The Ewer's picture spans this many object cells, side by side.
CELLS_WIDE = 3
WIDTH, HEIGHT = CELLS_WIDE * GAME_OBJECT_CELL_WIDTH, GAME_OBJECT_CELL_HEIGHT
# The row of the Ewer's flat bottom, and its ends: the bow on the left, the stern on the right.
_KEEL = 154
_BOW, _STERN = 30, 254
_MIDSHIPS = (_BOW + _STERN) // 2
# The mast stands at this x on the deck and leans this many pixels to the right per pixel up.
_MAST_FOOT = 112
_MAST_LEAN = 1 / 9
_MAST_TOP = 6


def _put(canvas, x, y, colour):
    if 0 <= x < WIDTH and 0 <= y < HEIGHT:
        canvas[y][x] = colour


def _line(canvas, x0, y0, x1, y1, colour):
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for step in range(steps + 1):
        _put(canvas, round(x0 + (x1 - x0) * step / steps), round(y0 + (y1 - y0) * step / steps), colour)


def _askew(x):
    """How much lower the hull lies at x than amidships: she has settled stern first."""
    return round((x - _MIDSHIPS) / 28)


def _sheer(x):
    """The row of the near gunwale at x: the bow rises highest, the stern a little."""
    if x < _BOW + 60:
        rise = round((_BOW + 60 - x) ** 1.5 / 22)
    elif x > _STERN - 50:
        rise = round((x - _STERN + 50) * 0.22)
    else:
        rise = 0
    return 130 - rise + _askew(x)


def _bottom(x):
    """The row of the hull's bottom at x: flat, rounding up into the bluff bow and the stern."""
    if x < _BOW + 40:
        rise = round((_BOW + 40 - x) ** 2 / 50)
    elif x > _STERN - 22:
        rise = round((x - _STERN + 22) ** 2 / 26)
    else:
        rise = 0
    return _KEEL - rise + _askew(x)


def _mast_x(y):
    return _MAST_FOOT + round((_sheer(_MAST_FOOT) - 8 - y) * _MAST_LEAN)


def ewer():
    """The Ewer lying on the mud at low tide."""
    canvas = blank(WIDTH, HEIGHT)
    # The wet mud pressed down around the flat bottom, a puddle left by the tide at the stern.
    for x in range(_BOW + 16, _STERN - 4):
        for dy in (1, 2, 3):
            if dy == 1 or (x * 7 + dy) % 5 < 3 - dy // 2:
                _put(canvas, x, _bottom(x) + dy, "mud_dark")
    for x in range(_STERN - 30, _STERN + 6):
        _put(canvas, x, _KEEL + 4, "water" if x % 3 else "water_light")
    # The stays, behind everything else: from the masthead down to the bow and the stern.
    top = (_mast_x(_MAST_TOP), _MAST_TOP)
    _line(canvas, *top, _BOW + 2, _sheer(_BOW + 2) - 8, "stone_dark")
    _line(canvas, *top, _STERN - 6, _sheer(_STERN - 6) - 6, "stone_dark")
    # The deck seen over the far gunwale, as she heels towards us: weathered planks running fore
    # and aft, the far gunwale dark over them.
    for x in range(_BOW + 4, _STERN - 2):
        far = _sheer(x) - 9
        _put(canvas, x, far, "soil_dark")
        _put(canvas, x, far + 1, "soil")
        for y in range(far + 2, _sheer(x)):
            plank = (y - far) % 3
            colour = "bare_light" if plank == 2 else "bare" if (x // 23 + y) % 5 else "mud"
            _put(canvas, x, y, colour)
    # The hatch amidships, its coaming lit along its top.
    for x in range(_MIDSHIPS - 30, _MIDSHIPS + 6):
        y0 = _sheer(x) - 10
        for y in range(y0, _sheer(x) - 3):
            _put(canvas, x, y, "soil_light" if y == y0 else "soil_mid" if y < y0 + 3 else "soil")
    # The small cabin aft, its roof lit and its door dark.
    for x in range(_STERN - 48, _STERN - 20):
        y0 = _sheer(x) - 16
        for y in range(y0, _sheer(x) - 2):
            if y == y0:
                colour = "bare_light"
            elif y < y0 + 3:
                colour = "bare"
            elif _STERN - 38 <= x < _STERN - 32 and y > y0 + 5:
                colour = "ink"
            else:
                colour = "soil_mid" if x < _STERN - 44 else "soil"
            _put(canvas, x, y, colour)
    # The hull side: tarred planks in strakes 4 rows deep, the wale along the top catching the
    # light, a little grey where the tar has worn.
    for x in range(_BOW, _STERN + 1):
        for y in range(_sheer(x), _bottom(x) + 1):
            row = y - _sheer(x)
            if row <= 1:
                colour = ("soil_light" if row == 0 else "soil") if x < _MIDSHIPS + 40 else ("soil_mid" if row == 0 else "soil_dark")
            elif y == _bottom(x) or x in (_BOW, _STERN):
                colour = "ink"
            elif row % 4 == 1:
                colour = "ink"
            elif row % 4 == 2 and x < _MIDSHIPS and (x // 3 + row) % 4:
                colour = "stone_dark"
            else:
                colour = "soil_dark"
            _put(canvas, x, y, colour)
    # The stem post at the bow, and the rudder hung on the stern with its tiller over the deck.
    _line(canvas, _BOW - 1, _sheer(_BOW) - 3, _BOW + 6, _bottom(_BOW + 6), "soil")
    _line(canvas, _BOW, _sheer(_BOW) - 3, _BOW + 7, _bottom(_BOW + 7), "soil_mid")
    for y in range(_sheer(_STERN) - 3, _KEEL + 1):
        width = 8 if y > _sheer(_STERN) + 10 else 5
        for x in range(_STERN + 1, _STERN + 1 + width):
            _put(canvas, x, y, "soil_mid" if x == _STERN + 1 else "soil")
        _put(canvas, _STERN + width, y, "soil_dark")
    for x in range(_STERN - 22, _STERN + 2):
        y = _sheer(_STERN) - 5 - (_STERN - x) // 5
        _put(canvas, x, y, "soil_mid")
        _put(canvas, x, y + 1, "soil")
    # The leeboard raised on the near side: a fan of planks on its pivot.
    pivot_x, pivot_y = _MIDSHIPS - 46, _sheer(_MIDSHIPS - 46) + 2
    for y in range(pivot_y, pivot_y + 18):
        half = 2 + (y - pivot_y) // 2
        for x in range(pivot_x - half, pivot_x + half + 1):
            edge = x in (pivot_x - half, pivot_x + half) or y == pivot_y + 17
            plank = (x - pivot_x) % 4 == 0
            _put(canvas, x, y, "ink" if edge else "soil_dark" if plank else ("soil_mid" if x < pivot_x else "soil"))
    _put(canvas, pivot_x, pivot_y + 2, "stone_light")
    _put(canvas, pivot_x + 1, pivot_y + 2, "stone")
    # The mast, leaning with the hull, lit on its left, and its top.
    for y in range(_MAST_TOP, _sheer(_MAST_FOOT) - 8):
        x = _mast_x(y)
        _put(canvas, x, y, "soil_light")
        _put(canvas, x + 1, y, "soil_mid")
        _put(canvas, x + 2, y, "soil" if y > _MAST_TOP + 30 else "soil_mid")
    # A pennant at the masthead.
    for dx, dy, colour in ((3, 0, "red_light"), (4, 0, "red_light"), (5, 0, "red_light"), (6, 1, "red_light"),
                           (7, 1, "rust"), (3, 1, "rust"), (4, 1, "rust"), (5, 1, "rust"), (8, 2, "rust")):
        _put(canvas, top[0] + dx, top[1] + dy, colour)
    # The gaff hoisted a little up the mast, and the brown sail furled on the boom under it,
    # lashed every few pixels, from the mast towards the stern.
    boom_y = _sheer(_MAST_FOOT) - 22
    _line(canvas, _mast_x(boom_y - 20) + 2, boom_y - 20, _STERN - 70, boom_y - 30, "soil_mid")
    for x in range(_mast_x(boom_y) + 3, _STERN - 46):
        y = boom_y + (x - _MAST_FOOT) // 26
        for k, colour in enumerate(("ochre_dark", "umber", "rust_dark", "rust_dark", "russet_deep", "russet_deep")):
            _put(canvas, x, y + k, colour)
        if x % 9 == 0:
            for k in range(1, 5):
                _put(canvas, x, y + k, "sand" if k < 3 else "mud")
    # The boom's end sticking out beyond the sail.
    end_y = boom_y + (_STERN - 46 - _MAST_FOOT) // 26
    _line(canvas, _STERN - 46, end_y + 5, _STERN - 36, end_y + 6, "soil_mid")
    return canvas


def ewer_row():
    return [ewer()]
