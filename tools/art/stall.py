"""The market stall of the town square (issue #10) in assets/objects.png, drawn at 32 px per tile:
a plank counter on 2x1 tiles between two oak posts, under a striped awning of red and cream
cloth with a scalloped hem, a sack of seed and two candles on the counter. A placeholder, to be
refined by a pixel artist. Light from the top left, as everywhere.

The picture is set into its cell, on a ground shadow, by `generate.standing_outdoors`.
"""

from canvas import GAME_TILE, blank, outline_edge, rect

TILE = GAME_TILE
# The wet oak of the posts, lit to dark, and the planks of the counter.
OAK = ("soil_light", "soil_mid", "soil", "soil_dark")
PLANKS = ("bare_light", "bare", "mud_dark")
WIDTH, HEIGHT = 2 * TILE, 56
POSTS = (3, WIDTH - 7)
AWNING_TOP, AWNING_BOTTOM = 2, 14
COUNTER_TOP = 36
# The cloth of the awning is striped this many px to a stripe.
STRIPE = 8


def _awning(picture):
    """Red and cream stripes: lit along the top, shaded along the hem."""
    for x in range(WIDTH):
        is_red = x // STRIPE % 2 == 0
        lit, cloth, shade = ("red_light", "ember", "rust_dark") if is_red else ("lime", "cream", "sand_light")
        scalloped_bottom = AWNING_BOTTOM + (2 if x // (STRIPE // 2) % 2 else 0)
        for y in range(AWNING_TOP, scalloped_bottom + 1):
            picture[y][x] = lit if y == AWNING_TOP else shade if y >= scalloped_bottom - 1 else cloth


def _posts(picture):
    for x in POSTS:
        for dx, colour in enumerate(OAK):
            rect(picture, x + dx, AWNING_BOTTOM, x + dx, HEIGHT - 1, colour)


def _counter(picture):
    left, right = POSTS[0] + 4, POSTS[1] - 1
    rect(picture, left, COUNTER_TOP, right, COUNTER_TOP + 2, OAK[0])
    rect(picture, left, COUNTER_TOP + 3, right, COUNTER_TOP + 3, OAK[3])
    for x in range(left, right + 1):
        for y in range(COUNTER_TOP + 4, HEIGHT - 1):
            along = x - left
            picture[y][x] = PLANKS[2] if along % 8 == 0 else PLANKS[0] if along % 8 == 1 else PLANKS[1]
    rect(picture, left, HEIGHT - 1, right, HEIGHT - 1, OAK[3])


def _wares(picture):
    # A sack of seed with its mouth rolled over, on the left.
    rect(picture, 12, COUNTER_TOP - 9, 23, COUNTER_TOP - 1, "straw")
    rect(picture, 12, COUNTER_TOP - 9, 14, COUNTER_TOP - 1, "sand_light")
    rect(picture, 12, COUNTER_TOP - 1, 23, COUNTER_TOP - 1, "sand")
    rect(picture, 14, COUNTER_TOP - 12, 21, COUNTER_TOP - 10, "sand")
    rect(picture, 14, COUNTER_TOP - 6, 21, COUNTER_TOP - 5, "mud")
    # Two candles, one lit, on the right.
    for left in (40, 46):
        rect(picture, left, COUNTER_TOP - 8, left + 2, COUNTER_TOP - 1, "cream")
        rect(picture, left + 2, COUNTER_TOP - 8, left + 2, COUNTER_TOP - 1, "sand_light")
    rect(picture, 41, COUNTER_TOP - 11, 41, COUNTER_TOP - 9, "gold")
    picture[COUNTER_TOP - 12][41] = "flame"


def market_stall():
    """The stall, 64x58 px, standing (its bottom row on the ground)."""
    picture = blank(WIDTH, HEIGHT)
    _posts(picture)
    _counter(picture)
    _wares(picture)
    _awning(picture)
    return outline_edge(picture, "soil_dark", keep_bottom=True)
