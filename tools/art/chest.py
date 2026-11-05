"""The chest: a wooden box with a lid, iron bands and a gold lock.

One picture serves everywhere (rows of palette colour names, None = clear): inside a house
(assets/interior/chest.png), outdoors (a cell of assets/objects.png, with a ground shadow), as
the item icon (assets/items/chest.png) and, in the item's half size, on the ground. The header
icon of the storage screen is in ui.py.
"""

WIDTH = 16
HEIGHT = 11


def _rect(picture, x0, y0, x1, y1, colour):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            picture[y][x] = colour


def chest(is_standing=True):
    """The chest seen from the front and a little above, 16x11 px with its outline. It stands
    on its bottom row, which then has no outline; without `is_standing` it is outlined all
    round. Light falls from the top left."""
    picture = [[None] * WIDTH for _ in range(HEIGHT)]
    # The lid's top face, with its corners cut, then its front.
    _rect(picture, 1, 0, 14, 1, "soil_light")
    _rect(picture, 2, 0, 13, 0, "sand")
    _rect(picture, 0, 2, 15, 4, "soil_mid")
    # The iron rim along the seam between lid and box.
    _rect(picture, 0, 5, 15, 5, "stone_light")
    _rect(picture, 0, 6, 15, 6, "stone")
    # The box.
    _rect(picture, 0, 7, 15, 10, "soil_mid")
    _rect(picture, 0, 10, 15, 10, "soil")
    # Plank edges and grain marks on the wood.
    _rect(picture, 8, 2, 8, 4, "soil")
    _rect(picture, 8, 7, 8, 10, "soil")
    for x, y in ((5, 3), (12, 4), (4, 8), (12, 9)):
        picture[y][x] = "soil"
    # Iron bands, running over the lid and down the box, lit on the left, with rivets.
    for x in (2, 12):
        _rect(picture, x, 0, x + 1, 10, "stone")
        _rect(picture, x, 0, x, 10, "stone_light")
        _rect(picture, x + 1, 7, x + 1, 10, "stone_dark")
        picture[3][x + 1] = "stone_dark"
        picture[8][x + 1] = "stone_dark"
    # The lock plate over the rim, with its keyhole.
    _rect(picture, 6, 4, 9, 8, "gold")
    _rect(picture, 6, 4, 9, 4, "cream")
    _rect(picture, 6, 8, 9, 8, "straw")
    _rect(picture, 7, 5, 8, 6, "soil_dark")
    return _outline(picture, is_standing)


def icon():
    """The item icon: the chest outlined all round, in the middle of 16x16 px."""
    picture = [[None] * WIDTH for _ in range(WIDTH)]
    top = (WIDTH - HEIGHT) // 2
    for y, row in enumerate(chest(is_standing=False)):
        picture[top + y] = row
    return picture


def _outline(picture, keeps_bottom):
    """Gives the border of the picture the darkest brown, but for the bottom row if
    `keeps_bottom`: a picture standing on the ground."""
    height, width = len(picture), len(picture[0])
    border = []
    for y in range(height - 1 if keeps_bottom else height):
        for x in range(width):
            if picture[y][x] is None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < width and 0 <= ny < height) or picture[ny][nx] is None:
                    border.append((x, y))
                    break
    for x, y in border:
        picture[y][x] = "soil_dark"
    return picture
