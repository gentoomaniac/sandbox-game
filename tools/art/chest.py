"""The chest: a box of oak planks with a lid, iron bands and a brass lock, drawn at 32 px per tile.

One picture serves inside a house (assets/interior/chest.png), outdoors (a cell of
assets/objects.png, with a ground shadow) and as the body of its item icon (items.chest_icon).
The header icon of the storage screen is in ui.py.
"""

from canvas import blank, outline_edge, rect

WIDTH = 32
HEIGHT = 22
# The rows of the lid: its top face, seen from a little above, and its front.
LID_TOP = 4
LID_BOTTOM = 9


def planks(picture, x0, y0, x1, y1, shades, seams):
    """Oak planks running across x0..x1, y0..y1, lit to dark in `shades` (three), with a dark
    seam on the rows of `seams` and a few streaks of grain."""
    lit, face, dark = shades
    rect(picture, x0, y0, x1, y1, face)
    rect(picture, x0, y0, x1, y0, lit)
    for y in seams:
        rect(picture, x0, y, x1, y, dark)
        if y + 1 <= y1:
            rect(picture, x0, y + 1, x1, y + 1, lit)
    for x, y, length in ((x0 + 5, y0 + 2, 6), (x0 + 17, y0 + 3, 5), (x0 + 9, y1 - 1, 4), (x0 + 21, y1 - 2, 6)):
        if y0 < y < y1 and y not in seams:
            rect(picture, x, y, min(x1, x + length - 1), y, dark)


def chest():
    """The chest seen from the front and a little above, 32x22 px, standing on its bottom row
    (which has no outline). Light falls from the top left."""
    picture = blank(WIDTH, HEIGHT)
    # The lid's top face, with its corners cut, lit; then its front.
    planks(picture, 1, 0, WIDTH - 2, LID_TOP - 1, ("sand_light", "sand", "soil_light"), (2,))
    picture[0][1] = picture[0][WIDTH - 2] = None
    planks(picture, 0, LID_TOP, WIDTH - 1, LID_BOTTOM, ("soil_light", "soil_mid", "soil"), (7,))
    # The iron rim along the seam between lid and box, its rivets.
    rect(picture, 0, LID_BOTTOM + 1, WIDTH - 1, LID_BOTTOM + 1, "stone_light")
    rect(picture, 0, LID_BOTTOM + 2, WIDTH - 1, LID_BOTTOM + 2, "stone")
    rect(picture, 0, LID_BOTTOM + 3, WIDTH - 1, LID_BOTTOM + 3, "stone_dark")
    # The box: planks, darker towards the ground, its foot dark.
    planks(picture, 0, LID_BOTTOM + 4, WIDTH - 1, HEIGHT - 1, ("soil_mid", "soil_mid", "soil"), (17,))
    rect(picture, 0, HEIGHT - 2, WIDTH - 1, HEIGHT - 1, "soil")
    rect(picture, WIDTH - 3, LID_TOP, WIDTH - 2, HEIGHT - 1, "soil")
    # Iron bands over the lid and down the box, lit on the left, with rivets.
    for x in (4, 24):
        rect(picture, x, 0, x + 3, HEIGHT - 1, "stone")
        rect(picture, x, 0, x, HEIGHT - 1, "stone_light")
        rect(picture, x + 3, LID_BOTTOM + 1, x + 3, HEIGHT - 1, "stone_dark")
        for y in (6, 16):
            picture[y][x + 1] = "stone_light"
            picture[y][x + 2] = "stone_dark"
    # The brass lock plate over the rim, with its keyhole, lit on its upper edge.
    rect(picture, 13, 7, 18, 15, "gold")
    rect(picture, 13, 7, 18, 7, "cream")
    rect(picture, 18, 8, 18, 15, "ochre")
    rect(picture, 13, 15, 18, 15, "ochre_dark")
    rect(picture, 15, 9, 16, 11, "soil_dark")
    picture[12][15] = picture[12][16] = "soil_dark"
    picture[13][15] = "soil_dark"
    return outline_edge(picture, "soil_dark", keep_bottom=True)
