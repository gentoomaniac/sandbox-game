"""The market stall of the town square (issue #10) in the classic 16 px art, as tools/art/stall.py
draws it at 32 px, at half the size: a plank counter on 2x1 tiles between two oak posts, under a
striped awning of red and cream cloth, a sack of seed and two candles on the counter. A
placeholder, to be refined by a pixel artist.
"""

from canvas import TILE, blank, outline_edge, rect

OAK = ("soil_light", "soil_mid", "soil_dark")
PLANKS = ("bare_light", "bare", "mud_dark")
WIDTH, HEIGHT = 2 * TILE, 28
POSTS = (1, WIDTH - 3)
AWNING_TOP, AWNING_BOTTOM = 1, 7
COUNTER_TOP = 18
STRIPE = 4


def _awning(picture):
    """Red and cream stripes: lit along the top, shaded along the hem."""
    for x in range(WIDTH):
        is_red = x // STRIPE % 2 == 0
        lit, cloth, shade = ("red_light", "ember", "rust_dark") if is_red else ("lime", "cream", "sand_light")
        scalloped_bottom = AWNING_BOTTOM + (1 if x // (STRIPE // 2) % 2 else 0)
        for y in range(AWNING_TOP, scalloped_bottom + 1):
            picture[y][x] = lit if y == AWNING_TOP else shade if y == scalloped_bottom else cloth


def market_stall():
    """The stall, 32x28 px, standing (its bottom row on the ground)."""
    picture = blank(WIDTH, HEIGHT)
    for x in POSTS:
        rect(picture, x, AWNING_BOTTOM, x, HEIGHT - 1, OAK[1])
        rect(picture, x + 1, AWNING_BOTTOM, x + 1, HEIGHT - 1, OAK[2])
    left, right = POSTS[0] + 2, POSTS[1]
    rect(picture, left, COUNTER_TOP, right, COUNTER_TOP + 1, OAK[0])
    for x in range(left, right + 1):
        rect(picture, x, COUNTER_TOP + 2, x, HEIGHT - 1, PLANKS[2] if (x - left) % 4 == 0 else PLANKS[1])
    # A sack of seed on the left, two candles on the right, one lit.
    rect(picture, 6, COUNTER_TOP - 4, 11, COUNTER_TOP - 1, "straw")
    rect(picture, 7, COUNTER_TOP - 5, 10, COUNTER_TOP - 5, "sand")
    for x in (20, 23):
        rect(picture, x, COUNTER_TOP - 4, x + 1, COUNTER_TOP - 1, "cream")
    picture[COUNTER_TOP - 5][20] = "flame"
    _awning(picture)
    return outline_edge(picture, "soil_dark", keep_bottom=True)
