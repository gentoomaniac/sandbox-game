"""The mockup scene, shared by both versions: a 20x11-tile stretch of farm and village edge
(the view is 20x11.25 tiles; a 12th row of ground fills its last quarter tile).

Ground letters: g grass, l lush grass, d dry grass, p path, t trodden grass, s tilled soil,
w water. Things stand on tiles and are drawn bottom-sorted.
"""

GROUND = [
    # 0         1
    # 01234567890123456789
    "ggggggggggggglllwwlg",  # 0
    "ggggggggggggllllwwlg",  # 1
    "gggggggggggglllwwllg",  # 2
    "ggggggggggggggllwwlg",  # 3
    "gggggggggggggglwwggg",  # 4
    "ggtggggggggggggwwggg",  # 5
    "tppppppppppppttwwgdd",  # 6
    "gggggggggggggggwwddd",  # 7
    "gssssssssggggggwwgdd",  # 8
    "gssssssssgggdddwwgdd",  # 9
    "gssssssssggdddwwggdd",  # 10
    "gggggggggggddwwgggdd",  # 11, only its top quarter is in view
]
W, H = 20, 12

# (kind, tile x, tile y, extra). Positions are the tile the thing stands on; buildings give
# their footprint's bottom-left tile.
THINGS = [
    ("kate", 0, 5, None),
    ("willow", 13, 3, None),
    ("reeds", 14, 0, 0), ("reeds", 18, 1, 1), ("reeds", 14, 2, 2), ("reeds", 18, 3, 0),
    ("reeds", 14, 4, 1), ("reeds", 14, 7, 2), ("reeds", 17, 8, 0), ("reeds", 13, 10, 1),
    ("reeds", 17, 5, 2),
    ("tall_grass", 12, 9, 0), ("tall_grass", 13, 8, 1), ("tall_grass", 18, 7, 2),
    ("tall_grass", 19, 9, 0), ("tall_grass", 11, 10, 2), ("tall_grass", 18, 10, 1),
    ("tall_grass", 12, 0, 2), ("tall_grass", 19, 4, 1),
]
for x in range(1, 9):
    THINGS.append(("wheat", x, 8, None))
    THINGS.append(("cabbage", x, 9, None))
    THINGS.append(("cabbage", x, 10, None))

# Creatures: (kind, x, y in tile units with fractions, facing). Feet at that point.
CREATURES = [
    ("player", 8.5, 6.75, "down"),
    ("villager", 6.4, 6.8, "right"),
    ("horse", 9.6, 3.8, "left"),
    ("cow", 11.0, 8.9, "right"),
    ("chicken", 5.6, 5.4, "right"),
    ("cat", 3.8, 7.3, "right"),
    ("mouse", 9.6, 8.6, "left"),
    ("frog", 12.6, 7.6, "right"),
]
