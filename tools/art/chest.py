"""The chest: a wooden box with a lid, iron bands and a gold lock.

One picture serves everywhere (rows of palette colour names, None = clear): inside a house
(assets/interior/chest.png), outdoors (a cell of assets/objects.png, with a ground shadow), as
the item icon (assets/items/chest.png) and, in the item's half size, on the ground. The header
icon of the storage screen is in ui.py.
"""

from canvas import blank, outline_edge, rect

WIDTH = 16
HEIGHT = 11


def chest(is_standing=True):
    """The chest seen from the front and a little above, 16x11 px with its outline. It stands
    on its bottom row, which then has no outline; without `is_standing` it is outlined all
    round. Light falls from the top left."""
    picture = blank(WIDTH, HEIGHT)
    # The lid's top face, with its corners cut, then its front.
    rect(picture, 1, 0, 14, 1, "soil_light")
    rect(picture, 2, 0, 13, 0, "sand")
    rect(picture, 0, 2, 15, 4, "soil_mid")
    # The iron rim along the seam between lid and box.
    rect(picture, 0, 5, 15, 5, "stone_light")
    rect(picture, 0, 6, 15, 6, "stone")
    # The box.
    rect(picture, 0, 7, 15, 10, "soil_mid")
    rect(picture, 0, 10, 15, 10, "soil")
    # Plank edges and grain marks on the wood.
    rect(picture, 8, 2, 8, 4, "soil")
    rect(picture, 8, 7, 8, 10, "soil")
    for x, y in ((5, 3), (12, 4), (4, 8), (12, 9)):
        picture[y][x] = "soil"
    # Iron bands, running over the lid and down the box, lit on the left, with rivets.
    for x in (2, 12):
        rect(picture, x, 0, x + 1, 10, "stone")
        rect(picture, x, 0, x, 10, "stone_light")
        rect(picture, x + 1, 7, x + 1, 10, "stone_dark")
        picture[3][x + 1] = "stone_dark"
        picture[8][x + 1] = "stone_dark"
    # The lock plate over the rim, with its keyhole.
    rect(picture, 6, 4, 9, 8, "gold")
    rect(picture, 6, 4, 9, 4, "cream")
    rect(picture, 6, 8, 9, 8, "straw")
    rect(picture, 7, 5, 8, 6, "soil_dark")
    return outline_edge(picture, "soil_dark", keep_bottom=is_standing)


def icon():
    """The item icon: the chest outlined all round, in the middle of 16x16 px."""
    picture = blank(WIDTH)
    top = (WIDTH - HEIGHT) // 2
    for y, row in enumerate(chest(is_standing=False)):
        picture[top + y] = row
    return picture
