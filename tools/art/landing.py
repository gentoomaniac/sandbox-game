"""The landing of the fisherman's hut in assets/objects.png (task 103): the jetty, the rowing boat,
the net frame and the eel traps, and the icons of the items that place them.

The jetty is laid a piece per tile and joins its neighbours like a Knick or the dyke: a picture per
connection mask (see boundaries.SIDES), planks across the way it runs on oak piles, and two mooring
posts at its head. The boat lies on 2x1 tiles beside it or on the mud, the net frame stands on 2x1
tiles by the hut with a tarred net hung over its pole, and the eel traps lie by the door to dry.
Each picture is drawn on its own and set into its cell with `_in_cell`. Light from the top left, as
everywhere.
"""

import math

import items
from canvas import OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, TILE, blank, outline
from palette import darkest_of

# Weathered oak planks: the lit edge of a plank, its face and the joint.
PLANKS = ("bare_light", "bare", "mud_dark")
# The wet oak of beams, piles and posts, lit to dark.
OAK = ("soil_light", "soil_mid", "soil", "soil_dark")
# Willow wicker, lit to dark.
WICKER = ("sand_light", "sand", "mud", "mud_dark")
# The bits of a jetty piece's connection mask (as boundaries.SIDES): the sides it joins.
NORTH, EAST, SOUTH, WEST = 1, 2, 4, 8
# A jetty picture rises this far above its tile, for the mooring posts.
JETTY_ABOVE = 7
# The middle of a jetty piece's deck, in px of its tile; it reaches out to each side it joins.
# Under its front edge the beam and the piles show.
DECK_TOP, DECK_BOTTOM = 2, 9
DECK_LEFT, DECK_RIGHT = 3, 12


def _in_cell(picture):
    """A picture in its object cell, centred on its footprint and its bottom on the cell's."""
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    top = OBJECT_CELL_HEIGHT - len(picture)
    left = (OBJECT_CELL_WIDTH - len(picture[0])) // 2
    for y, row in enumerate(picture):
        for x, name in enumerate(row):
            if name is not None:
                canvas[top + y][left + x] = name
    return canvas


def _jetty_deck(mask):
    """The pixels of a jetty piece's deck, in px of its tile: the middle and an arm out to each
    side it joins."""
    deck = {(x, y) for x in range(DECK_LEFT, DECK_RIGHT + 1) for y in range(DECK_TOP, DECK_BOTTOM + 1)}
    arms = {
        NORTH: (DECK_LEFT, DECK_RIGHT, 0, DECK_TOP - 1),
        EAST: (DECK_RIGHT + 1, TILE - 1, DECK_TOP, DECK_BOTTOM),
        SOUTH: (DECK_LEFT, DECK_RIGHT, DECK_BOTTOM + 1, TILE - 1),
        WEST: (0, DECK_LEFT - 1, DECK_TOP, DECK_BOTTOM),
    }
    for side, (x0, x1, y0, y1) in arms.items():
        if mask & side:
            deck.update((x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1))
    return deck


def _mooring_posts(mask):
    """Where the mooring posts of a jetty head stand (the deck pixel each rises from): at the
    corners of its free end. Only a piece joined on exactly one side is a head."""
    corners = {
        EAST: ((DECK_LEFT, DECK_TOP), (DECK_LEFT, DECK_BOTTOM)),
        WEST: ((DECK_RIGHT - 1, DECK_TOP), (DECK_RIGHT - 1, DECK_BOTTOM)),
        SOUTH: ((DECK_LEFT, DECK_TOP), (DECK_RIGHT - 1, DECK_TOP)),
        NORTH: ((DECK_LEFT, DECK_BOTTOM), (DECK_RIGHT - 1, DECK_BOTTOM)),
    }
    return corners.get(mask, ())


def jetty(mask):
    """One piece of a plank jetty on oak piles, joined to the pieces on the sides of `mask`. The
    planks lie across the way it runs, 2 px wide, each lit on its first pixel, with dark joints and
    a dark free edge. Under the front edge of the deck the beam shows, and the piles stand in the
    water or the mud below it, green with weed at the foot. At a head, two mooring posts stand at
    the free end, a rope round one."""
    picture = blank(TILE, TILE + JETTY_ABOVE)
    deck = _jetty_deck(mask)
    runs_across = bool(mask & (EAST | WEST)) or not mask & (NORTH | SOUTH)

    def put(x, y, colour):
        picture[y + JETTY_ABOVE][x] = colour

    for x in range(TILE):
        front = max((y for dx, y in deck if dx == x), default=TILE - 1)
        if front >= TILE - 1:
            continue
        put(x, front + 1, OAK[2])
        put(x, front + 2, OAK[3])
        pile = x - DECK_LEFT if DECK_LEFT <= x <= DECK_RIGHT else x % 8
        if pile not in (0, 1, DECK_RIGHT - DECK_LEFT - 1, DECK_RIGHT - DECK_LEFT):
            continue
        for y in range(front + 3, TILE - 2):
            put(x, y, OAK[1] if pile % 2 == 0 else OAK[3])
        put(x, TILE - 2, "green_dark")
        put(x, TILE - 1, "ink")
    for x, y in deck:
        along = x if runs_across else y
        colour = (PLANKS[0], PLANKS[1], PLANKS[2])[along % 3]
        is_free_edge = any(
            (x + dx, y + dy) not in deck and 0 <= x + dx < TILE and 0 <= y + dy < TILE
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
        )
        put(x, y, "soil_dark" if is_free_edge else colour)
    for number, (x, y) in enumerate(_mooring_posts(mask)):
        top = y - 6
        put(x, top, OAK[1])
        put(x + 1, top, OAK[2])
        for row in range(top + 1, y + 1):
            put(x, row, OAK[0])
            put(x + 1, row, OAK[2])
        if number == 0:
            put(x, top + 3, "sand_light")
            put(x + 1, top + 3, "sand")
            put(x + 1, top + 4, "sand")
    return picture


def jetty_row():
    """The atlas row of the jetty: one picture per connection mask."""
    return [_in_cell(jetty(mask)) for mask in range(16)]


def rowing_boat():
    """A flat-bottomed rowing boat on 2x1 tiles, seen from above at a slant: the bow on the left,
    narrowing and rising a little, a square stern. Inside, the far side's planking in shade over
    weathered floor boards with ribs, two thwarts and a pair of oars; outside, the tarred side
    under a lit wale, and a contact shadow."""
    width, height = 2 * TILE, 18
    picture = blank(width, height)
    middle = 7
    for x in range(1, width - 1):
        half = 5 if x >= 10 else max(1, round(5 * math.sqrt((x - 1) / 9)))
        rise = max(0, 6 - x) // 2
        far, near = middle - half - rise, middle + half - rise
        picture[far][x] = "ink"
        for y in range(far + 1, near):
            if y - far <= 2:
                colour = "soil" if y - far == 1 else "soil_mid"
            elif x % 5 == 0:
                colour = "soil_mid"
            else:
                colour = PLANKS[0] if y == far + 3 else PLANKS[1]
            picture[y][x] = colour
        picture[near][x] = "soil_light" if x < 20 else "soil_mid"
        picture[near + 1][x] = "stone_dark" if x < 20 else "soil_dark"
        picture[near + 2][x] = "soil_dark"
        picture[near + 3][x] = "soil_dark"
        picture[near + 4][x] = "ink"
        picture[near + 5][x] = "shadow"
    for y in range(middle - 5, middle + 10):
        picture[y][width - 1] = "ink"
        picture[y][width - 2] = "soil" if y <= middle + 5 else "soil_dark"
    for y in range(middle - 3, middle + 1):
        picture[y][0] = "ink"
    # Two thwarts across, lit along their left.
    for x in (11, 21):
        for y in range(middle - 3, middle + 5):
            picture[y][x] = "soil_light"
            picture[y][x + 1] = "soil"
    # The oars, along the boat from the stern, blades towards the bow.
    for x in range(7, 28):
        blade = x < 11
        picture[middle][x] = "sand" if blade else "sand_light"
        picture[middle + 2][x - 2] = "mud" if blade else "sand"
    return picture


def rowing_boat_row():
    return [_in_cell(rowing_boat())]


def net_frame():
    """A net frame on 2x1 tiles: two forked oak posts with a pole across, and a brown tarred net
    hung over it in a curtain that sags between them, its diamond meshes open so the ground
    shows through, a fold over the pole and pale cork floats along the hem."""
    width, height = 2 * TILE, 30
    picture = blank(width, height)
    pole = 6
    posts = (3, 27)
    for x in posts:
        for y in range(pole - 2, height - 1):
            picture[y][x] = OAK[1]
            picture[y][x + 1] = OAK[3]
        picture[pole - 3][x - 1] = OAK[1]
        picture[pole - 3][x + 2] = OAK[3]
        for dx in (-1, 0, 1, 2):
            picture[height - 1][x + dx] = "shadow"
    for x in range(1, width - 1):
        picture[pole][x] = OAK[0]
        picture[pole + 1][x] = OAK[3]
    for x in range(posts[0] - 1, posts[1] + 3):
        if x % 3:
            picture[pole - 1][x] = "umber"
        sag = round(3 * math.sin(math.pi * (x - posts[0] + 1) / (posts[1] - posts[0] + 4)))
        hem = height - 7 + sag
        for y in range(pole + 2, hem):
            if (x + y) % 4 == 0:
                picture[y][x] = "umber"
            elif (x - y) % 4 == 0:
                picture[y][x] = "soil"
        picture[hem][x] = "soil_dark"
        if x % 4 == 1:
            picture[hem][x] = "sand_light"
            picture[hem + 1][x] = "sand"
    return picture


def net_frame_row():
    return [_in_cell(net_frame())]


def _trap(picture, left, bottom, length, radius):
    """One wicker eel trap lying on its side, its wide mouth on the left: a cone of willow rods,
    lit along the top and shaded underneath, bound by dark hoops every 3 px, outlined, with the
    dark round mouth and a tied tail."""
    middle = bottom - radius
    for i in range(length + 1):
        half = round(radius * (1 - 0.55 * i / length))
        for y in range(middle - half, middle + half + 1):
            if y in (middle - half, middle + half) or i == length:
                colour = WICKER[3]
            elif i % 3 == 2:
                colour = WICKER[2]
            elif y < middle - half / 3:
                colour = "straw" if y == middle - half + 1 else WICKER[0]
            elif y < middle + half / 2:
                colour = WICKER[1]
            else:
                colour = WICKER[2]
            picture[y][left + i] = colour
    for y in range(middle - radius + 1, middle + radius):
        picture[y][left] = WICKER[3]
        if abs(y - middle) < radius - 1:
            picture[y][left + 1] = "soil_dark"
    picture[middle][left + length + 1] = WICKER[3]


def eel_traps():
    """Eel traps on one tile: two wicker cones lying one on the other, put by the door to dry."""
    picture = blank(TILE, 15)
    _trap(picture, 1, 13, 11, 4)
    _trap(picture, 4, 7, 8, 3)
    for x in range(2, 14):
        if picture[14][x] is None:
            picture[14][x] = "shadow"
    return picture


def eel_traps_row():
    return [_in_cell(eel_traps())]


def _icon(picture):
    """An item icon of a picture: halved if it is wider than an icon, its bottom rows if it is
    taller, without its contact shadow, in the middle of 16x16 px and outlined."""
    if len(picture[0]) > TILE:
        size = len(picture[0])
        square = blank(size)
        top = (size - len(picture)) // 2
        for y, row in enumerate(picture):
            square[top + y] = list(row)
        picture = items.small(square)
    picture = [row for row in picture if any(name not in (None, "shadow") for name in row)][-(TILE - 2) :]
    icon = blank()
    top = (TILE - len(picture)) // 2
    left = (TILE - len(picture[0])) // 2
    for y, row in enumerate(picture):
        for x, name in enumerate(row):
            if name not in (None, "shadow"):
                icon[top + y][left + x] = name
    return outline(icon, darkest_of)


def icons():
    """The icons of the landing's items, by item id."""
    return {
        "jetty": _icon(jetty(EAST | WEST)),
        "rowing_boat": _icon(rowing_boat()),
        "net_frame": _icon(net_frame()),
        "eel_traps": _icon(eel_traps()),
    }
