"""Art for the rabbits (wildlife/rabbit_<look>.png), drawn whole for each pose."""

import forms
from canvas import blank, outline
from livestock import ACTIONS, TOP_LIGHT, moved

# A tame rabbit drawn a little larger than life, 20 px long sitting: round haunches, a short
# front, a round head with long ears, a white scut. It sits, nibbles with its head down, hops
# stretched out, and sleeps flat in a loaf with its ears laid back. Each pose places the parts
# (`RABBIT_POSES`): the haunch, the front, the head and the ears (from their roots to their
# tips), the hind foot, the front paw and how high it is off the ground.

RABBIT_SIZE = (24, 20)
RABBIT_POSES = {
    "sit": {"haunch": ((9, 13), [6.5, 5]), "front": ((14, 12), [4, 4.5]), "head": (17, 8), "ears": [((16, 6), (13, 0)), ((17, 6), (16, 0))], "foot": ((9, 17), [4, 1.5]), "paw": [(15, 14), (16, 17)]},
    "twitch": {"haunch": ((9, 13), [6.5, 5]), "front": ((14, 12), [4, 4.5]), "head": (17, 8), "ears": [((16, 6), (12, 1)), ((17, 6), (17, 0))], "foot": ((9, 17), [4, 1.5]), "paw": [(15, 14), (16, 17)]},
    "nibble": {"haunch": ((9, 13), [6.5, 5]), "front": ((14, 13), [4, 4]), "head": (18, 13), "ears": [((16, 11), (11, 7)), ((17, 11), (13, 6))], "foot": ((9, 17), [4, 1.5]), "paw": [(15, 15), (16, 17)]},
    "stretch": {"haunch": ((8, 11), [6, 4]), "front": ((15, 10), [5, 3.5]), "head": (19, 7), "ears": [((18, 5), (13, 2)), ((19, 5), (15, 1))], "foot": ((2, 13), [3, 1.5]), "paw": [(19, 12), (21, 14)]},
    "land": {"haunch": ((8, 12), [6, 4.5]), "front": ((15, 12), [4.5, 4]), "head": (19, 9), "ears": [((18, 7), (14, 2)), ((19, 7), (16, 1))], "foot": ((6, 15), [3.5, 1.5]), "paw": [(18, 15), (19, 17)]},
    "loaf": {"haunch": ((9, 15), [7, 3.5]), "front": ((14, 15), [4, 3]), "head": (18, 12), "ears": [((16, 10), (9, 9)), ((17, 9), (11, 7))], "foot": None, "paw": None},
    "loaf_low": {"haunch": ((9, 15), [7, 3.3]), "front": ((14, 15), [4, 2.8]), "head": (18, 13), "ears": [((16, 11), (9, 10)), ((17, 10), (11, 8))], "foot": None, "paw": None},
}
RABBIT_LOOKS = {
    # The grey-brown of the wild rabbit (agouti).
    "agouti": {"coat": ("mud", "sand", "sand", "sand_light"), "ear": "petal", "eye": "ink", "outline": "mud_dark"},
    # White with pink eyes.
    "white": {"coat": ("stone_light", "lime", "lime", "snow_light"), "ear": "petal", "eye": "red_light", "outline": "stone"},
    # Dutch: dark ears, head and rump, a white blaze, collar and forelegs.
    "dutch": {"coat": ("ink", "stone_dark", "stone_dark", "stone"), "ear": "petal", "eye": "ink", "white": ("stone_light", "lime", "lime"), "outline": "ink"},
}


def rabbit_frame(look, pose, lift=0, eye_shut=False):
    style = RABBIT_LOOKS[look]
    parts = moved(RABBIT_POSES[pose], 0, -lift)
    width, height = RABBIT_SIZE
    picture = blank(width, height)
    coat = style["coat"]
    ears = [forms.capsule(width, height, root, tip, 1.5, 1.1) for root, tip in parts["ears"]]
    forms.shade(picture, ears[0], (coat[0], coat[0], coat[1]), 1)
    if parts["foot"]:
        (x, y), (rx, ry) = parts["foot"]
        forms.shade(picture, forms.ellipse(width, height, x, y, rx, ry), coat[:3], 1)
    (x, y), (rx, ry) = parts["haunch"]
    body = forms.ellipse(width, height, x, y, rx, ry)
    (fx, fy), (frx, fry) = parts["front"]
    front = forms.ellipse(width, height, fx, fy, frx, fry)
    hx, hy = parts["head"]
    head = forms.ellipse(width, height, hx, hy, 3.6, 3.2) | forms.ellipse(width, height, hx + 2, hy + 1, 2.2, 2)
    whole = body | front | head
    level = forms.light_level(whole, 4, TOP_LIGHT)
    forms.shade_by_level(picture, whole, coat, level)
    if "white" in style:
        # The Dutch rabbit's white: the blaze down the face, the collar and the forelegs.
        blaze = forms.polygon(width, height, [(hx + 1, hy - 3), (hx + 2, hy - 3), (hx + 4, hy + 3), (hx, hy + 3)])
        forms.shade_by_level(picture, (front | blaze) & whole, style["white"], level)
    if parts["paw"]:
        paw = forms.capsule(width, height, *parts["paw"], 1.3, 1.1)
        forms.shade(picture, paw, style.get("white", coat)[:3], 1)
    forms.shade(picture, ears[1], (coat[1], coat[2], coat[3]), 1)
    (root_x, root_y), (tip_x, tip_y) = parts["ears"][1]
    forms.dots(picture, [(round((root_x + tip_x) / 2), round((root_y + tip_y) / 2))], style["ear"])
    # The scut, the eye and the nose.
    forms.shade(picture, forms.ellipse(width, height, x - rx + 0.5, y - 1, 1.8, 1.8), ("stone_light", "lime", "snow_light"), 1)
    ex, ey = round(hx + 1), round(hy - 1)
    if eye_shut:
        forms.dots(picture, [(ex, ey + 1), (ex + 1, ey + 1)], coat[0])
    else:
        forms.dots(picture, [(ex, ey), (ex, ey + 1)], style["eye"])
        forms.dots(picture, [(ex + 1, ey)], "cream")
    forms.dots(picture, [(round(hx + 4), round(hy + 1))], "petal")
    return outline(picture, style["outline"])


def rabbit_sheet(look):
    sit = rabbit_frame(look, "sit")
    hop = [rabbit_frame(look, "stretch", lift=2), rabbit_frame(look, "stretch", lift=4), rabbit_frame(look, "land"), sit]
    frames = {
        "idle": [sit, rabbit_frame(look, "twitch")],
        "walk": hop,
        "graze": [rabbit_frame(look, "nibble"), rabbit_frame(look, "nibble", lift=1)],
        "sleep": [rabbit_frame(look, "loaf", eye_shut=True), rabbit_frame(look, "loaf_low", eye_shut=True)],
        "run": hop,
    }
    return [frames[action] for action in ACTIONS]


def sheets():
    """Every sheet of the rabbits as (file name, cell size, rows of cells for palette.save)."""
    for look in RABBIT_LOOKS:
        yield f"rabbit_{look}", RABBIT_SIZE, rabbit_sheet(look)
