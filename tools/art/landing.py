"""The landing of the fisherman's hut in assets/objects.png (task 103), drawn at 32 px per tile: the
jetty, the rowing boat, the net frame and the eel traps, and the bodies of the icons of the items
that place them, which are their pictures.

The jetty is laid a piece per tile and joins its neighbours like a Knick or the dyke: a picture per
connection mask (see boundaries.SIDES), planks across the way it runs on oak piles, and two mooring
posts at its head. The boat lies on 2x1 tiles beside it or on the mud, the net frame stands on 2x1
tiles by the hut with a tarred net hung over its pole, and the eel traps lie by the door to dry.
Each picture is drawn on its own and set into its cell with `_in_cell`. Light from the top left, as
everywhere; each is rimmed in the darkest shade of its own colours.
"""

import math

import items
from canvas import GAME_OBJECT_CELL_HEIGHT, GAME_OBJECT_CELL_WIDTH, GAME_TILE, blank, rect

TILE = GAME_TILE
# Weathered oak planks: the lit edge of a plank, its face, and the joint; grain in the face.
PLANKS = ("bare_light", "bare", "mud_dark")
# The wet oak of beams, piles and posts, lit to dark.
OAK = ("soil_light", "soil_mid", "soil", "soil_dark")
# Willow wicker, lit to dark.
WICKER = ("sand_light", "sand", "mud", "mud_dark")
# The bits of a jetty piece's connection mask (as boundaries.SIDES): the sides it joins.
NORTH, EAST, SOUTH, WEST = 1, 2, 4, 8
# A jetty picture rises this far above its tile, for the mooring posts.
JETTY_ABOVE = 14
# The middle of a jetty piece's deck, in px of its tile; it reaches out to each side it joins.
# Under its front edge the beam and the piles show.
DECK_TOP, DECK_BOTTOM = 4, 19
DECK_LEFT, DECK_RIGHT = 6, 25
# A plank is this wide across the way the jetty runs.
PLANK = 4


def _in_cell(picture):
    """A picture in its object cell, centred on its footprint and its bottom on the cell's."""
    canvas = blank(GAME_OBJECT_CELL_WIDTH, GAME_OBJECT_CELL_HEIGHT)
    top = GAME_OBJECT_CELL_HEIGHT - len(picture)
    left = (GAME_OBJECT_CELL_WIDTH - len(picture[0])) // 2
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
        EAST: ((DECK_LEFT, DECK_TOP + 2), (DECK_LEFT, DECK_BOTTOM)),
        WEST: ((DECK_RIGHT - 3, DECK_TOP + 2), (DECK_RIGHT - 3, DECK_BOTTOM)),
        SOUTH: ((DECK_LEFT, DECK_TOP + 2), (DECK_RIGHT - 3, DECK_TOP + 2)),
        NORTH: ((DECK_LEFT, DECK_BOTTOM), (DECK_RIGHT - 3, DECK_BOTTOM)),
    }
    return corners.get(mask, ())


def jetty(mask):
    """One piece of a plank jetty on oak piles, joined to the pieces on the sides of `mask`. The
    planks lie across the way it runs, 4 px wide, each lit on its first pixel, with a dark joint,
    grain and a nail at each end, and a dark free edge. Under the front edge of the deck the beam
    shows, and the piles stand in the water or the mud below it, green with weed at the foot. At
    a head, two mooring posts stand at the free end, a rope round one."""
    picture = blank(TILE, TILE + JETTY_ABOVE)
    deck = _jetty_deck(mask)
    runs_across = bool(mask & (EAST | WEST)) or not mask & (NORTH | SOUTH)

    def put(x, y, colour):
        picture[y + JETTY_ABOVE][x] = colour

    for x in range(TILE):
        front = max((y for dx, y in deck if dx == x), default=TILE - 1)
        if front >= TILE - 1:
            continue
        for row, colour in enumerate((OAK[1], OAK[2], OAK[2], OAK[3])):
            put(x, front + 1 + row, colour)
        pile = x - DECK_LEFT if DECK_LEFT <= x <= DECK_RIGHT else x % 16
        width = DECK_RIGHT - DECK_LEFT
        if pile not in (0, 1, 2, width - 2, width - 1, width):
            continue
        shade = OAK[0] if pile in (0, width - 2) else OAK[1] if pile in (1, width - 1) else OAK[3]
        for y in range(front + 5, TILE - 3):
            put(x, y, shade)
        put(x, TILE - 3, "green_dark")
        put(x, TILE - 2, "green_deep")
        put(x, TILE - 1, "ink")
    for x, y in deck:
        along = x if runs_across else y
        across = y if runs_across else x
        colour = (PLANKS[0], PLANKS[1], PLANKS[1], PLANKS[2])[along % PLANK]
        # Grain along the plank, and a nail where it lies on the beams.
        if colour == PLANKS[1] and (across * 7 + along // PLANK * 5) % 11 == 0:
            colour = "mud"
        if along % PLANK == 1 and across in (DECK_TOP + 1, DECK_BOTTOM - 1, DECK_LEFT + 1, DECK_RIGHT - 1):
            colour = "stone_dark"
        is_free_edge = any(
            (x + dx, y + dy) not in deck and 0 <= x + dx < TILE and 0 <= y + dy < TILE
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
        )
        put(x, y, "soil_dark" if is_free_edge else colour)
    for number, (x, y) in enumerate(_mooring_posts(mask)):
        top = y - 12
        for row in range(top, y + 1):
            put(x, row, OAK[0])
            put(x + 1, row, OAK[1])
            put(x + 2, row, OAK[2])
            put(x + 3, row, OAK[3])
        for dx, colour in enumerate(("soil_light", "sand", "soil_light", "soil_mid")):
            put(x + dx, top, colour)
        if number == 0:
            for dx in range(4):
                put(x + dx, top + 5, "sand_light" if dx < 2 else "sand")
                put(x + dx, top + 6, "sand" if dx < 2 else "mud")
            put(x + 3, top + 7, "sand")
            put(x + 3, top + 8, "mud")
    return picture


def jetty_row():
    """The atlas row of the jetty: one picture per connection mask."""
    return [_in_cell(jetty(mask)) for mask in range(16)]


def rowing_boat():
    """A flat-bottomed rowing boat on 2x1 tiles, seen from above at a slant: the bow on the left,
    narrowing and rising a little, a square stern. Inside, the far side's planking in shade over
    weathered floor boards with ribs, two thwarts and a pair of oars; outside, the tarred side
    in strakes under a lit wale, and a contact shadow."""
    width, height = 2 * TILE, 36
    picture = blank(width, height)
    middle = 14
    for x in range(2, width - 2):
        half = 10 if x >= 20 else max(2, round(10 * math.sqrt((x - 2) / 18)))
        rise = max(0, 12 - x) // 2
        far, near = middle - half - rise, middle + half - rise
        picture[far][x] = "ink"
        for y in range(far + 1, near):
            if y - far <= 4:
                colour = "soil" if y - far <= 2 else "soil_mid"
            elif x % 10 in (0, 1):
                colour = "soil_mid"
            elif (y - far) % 4 == 0:
                colour = PLANKS[2]
            else:
                colour = PLANKS[0] if (y - far) % 4 == 1 else PLANKS[1]
            picture[y][x] = colour
        lit = x < 40
        picture[near][x] = "soil_light" if lit else "soil_mid"
        picture[near + 1][x] = "soil_mid" if lit else "soil"
        for row in range(near + 2, near + 9):
            picture[row][x] = "stone_dark" if (row - near) % 3 == 2 and lit else "soil_dark"
        picture[near + 9][x] = "ink"
        picture[near + 10][x] = "shadow"
        picture[near + 11][x] = "shadow" if x % 2 else None
    for y in range(middle - 10, middle + 20):
        picture[y][width - 2] = "ink"
        picture[y][width - 3] = "soil" if y <= middle + 10 else "soil_dark"
        picture[y][width - 4] = "soil_mid" if y <= middle + 10 else "soil_dark"
    for y in range(middle - 6, middle + 2):
        picture[y][1] = "ink"
        picture[y][2] = "soil"
    # Two thwarts across, lit along their left.
    for x in (22, 42):
        for y in range(middle - 7, middle + 10):
            picture[y][x] = "soil_light"
            picture[y][x + 1] = "soil_mid"
            picture[y][x + 2] = "soil"
    # The oars, along the boat from the stern, blades towards the bow.
    for x in range(14, 56):
        blade = x < 22
        picture[middle][x] = "sand_light" if not blade else "sand"
        picture[middle + 1][x] = "sand" if not blade else "sand"
        if blade:
            picture[middle - 1][x] = "sand_light"
        picture[middle + 4][x - 4] = "sand" if not blade else "mud"
        picture[middle + 5][x - 4] = "mud"
    return picture


def rowing_boat_row():
    return [_in_cell(rowing_boat())]


def net_frame():
    """A net frame on 2x1 tiles: two forked oak posts with a pole across, and a brown tarred net
    hung over it in a curtain that sags between them, its diamond meshes open so the ground
    shows through, a fold over the pole and pale cork floats along the hem."""
    width, height = 2 * TILE, 60
    picture = blank(width, height)
    pole = 12
    posts = (6, 54)
    for x in posts:
        for y in range(pole - 4, height - 2):
            picture[y][x] = OAK[0]
            picture[y][x + 1] = OAK[1]
            picture[y][x + 2] = OAK[2]
            picture[y][x + 3] = OAK[3]
        for y in (pole - 6, pole - 5):
            picture[y][x - 1] = picture[y][x] = OAK[1]
            picture[y][x + 3] = picture[y][x + 4] = OAK[3]
        for dx in range(-3, 7):
            for y in (height - 2, height - 1):
                picture[y][x + dx] = "shadow"
    for x in range(1, width - 1):
        picture[pole][x] = OAK[0]
        picture[pole + 1][x] = OAK[1]
        picture[pole + 2][x] = OAK[3]
    for x in range(posts[0] - 2, posts[1] + 6):
        if x % 3:
            picture[pole - 1][x] = "umber"
            picture[pole - 2][x] = "soil" if x % 3 == 1 else None
        sag = round(6 * math.sin(math.pi * (x - posts[0] + 2) / (posts[1] - posts[0] + 8)))
        hem = height - 14 + sag
        for y in range(pole + 3, hem):
            if (x + y) % 6 == 0:
                picture[y][x] = "umber"
            elif (x - y) % 6 == 0:
                picture[y][x] = "soil"
        picture[hem][x] = "soil_dark"
        picture[hem + 1][x] = "soil_dark" if x % 2 else None
        if x % 7 in (1, 2):
            for dy in (0, 1):
                picture[hem + dy][x] = "sand_light" if x % 7 == 1 else "sand"
            picture[hem + 2][x] = "mud"
    return picture


def net_frame_row():
    return [_in_cell(net_frame())]


def _trap(picture, left, bottom, length, radius):
    """One wicker eel trap lying on its side, its wide mouth on the left: a cone of willow rods,
    lit along the top and shaded underneath, the rods showing as fine lines, bound by dark hoops
    every 6 px, rimmed in the darkest wicker, with the dark round mouth and a tied tail."""
    middle = bottom - radius
    for i in range(length + 1):
        half = round(radius * (1 - 0.55 * i / length))
        for y in range(middle - half, middle + half + 1):
            if y in (middle - half, middle + half) or i == length:
                colour = WICKER[3]
            elif i % 6 in (4, 5):
                colour = WICKER[2] if i % 6 == 4 else WICKER[3]
            elif y < middle - half / 3:
                colour = "straw" if y == middle - half + 1 else WICKER[0]
            elif y < middle + half / 2:
                colour = WICKER[1] if (y + i // 2) % 3 else WICKER[0]
            else:
                colour = WICKER[2]
            picture[y][left + i] = colour
    mouth_rows = range(middle - radius + 1, middle + radius)
    for y in mouth_rows:
        picture[y][left] = WICKER[3]
        if abs(y - middle) < radius - 1:
            picture[y][left + 1] = "soil_dark"
            if abs(y - middle) < radius - 3:
                picture[y][left + 2] = "ink"
    picture[middle][left + length + 1] = WICKER[3]
    picture[middle][left + length + 2] = WICKER[2]
    picture[middle + 1][left + length + 2] = WICKER[3]


def eel_traps():
    """Eel traps on one tile: two wicker cones lying one on the other, put by the door to dry."""
    picture = blank(TILE, 30)
    _trap(picture, 2, 27, 23, 8)
    _trap(picture, 8, 15, 17, 6)
    for x in range(3, 29):
        for y in (28, 29):
            if picture[y][x] is None and (y == 28 or x % 2):
                picture[y][x] = "shadow"
    return picture


def eel_traps_row():
    return [_in_cell(eel_traps())]


def icons():
    """The bodies of the icons of the landing's items, by item id: their pictures."""
    return {
        "jetty": items.icon_of(jetty(EAST | WEST)),
        "rowing_boat": items.icon_of(rowing_boat()),
        "net_frame": items.icon_of(net_frame()),
        "eel_traps": items.icon_of(eel_traps()),
    }
