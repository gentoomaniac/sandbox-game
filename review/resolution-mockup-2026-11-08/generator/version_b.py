"""Version B, "32x32": the scene drawn natively at 32 px per tile (640x360), every piece in
view redrawn at twice the resolution in the same palette and style."""

import b_animals
import b_ground
import b_kate
import b_people
import b_plants
from b_core import flip, stamp, to_image
from scene import CREATURES, THINGS

T = 32

CREATURE_PICTURES = {
    "player": b_people.player,
    "villager": b_people.villager,
    "horse": b_animals.horse,
    "cow": b_animals.cow,
    "chicken": b_animals.chicken,
    "cat": b_animals.cat,
    "mouse": b_animals.mouse,
    "frog": b_animals.frog,
}


def sprites():
    """(bottom y, picture, left x, top y) of everything standing, drawn bottom-sorted."""
    out = []
    for kind, tx, ty, extra in THINGS:
        bottom = (ty + 1) * T
        if kind == "kate":
            pic = b_kate.kate()
            out.append((bottom, pic, tx * T, bottom - pic.shape[0]))
            continue
        if kind == "willow":
            pic = b_plants.willow()
        elif kind == "reeds":
            pic = b_plants.reeds(extra)
        elif kind == "tall_grass":
            pic = b_plants.tall_grass(extra)
        elif kind == "wheat":
            pic = b_plants.wheat(tx)
        elif kind == "cabbage":
            pic = b_plants.cabbage(tx + ty)
        h, w = pic.shape
        out.append((bottom - 1, pic, tx * T + T // 2 - w // 2, bottom - h))
    for kind, fx, fy, facing in CREATURES:
        pic = CREATURE_PICTURES[kind]()
        if facing == "left":
            pic = flip(pic)
        h, w = pic.shape
        x, y = round(fx * T), round(fy * T)
        out.append((y, pic, x - w // 2, y - h))
    return out


def render():
    pic, _ = b_ground.render()
    for _, sprite, x, y in sorted(sprites(), key=lambda s: s[0]):
        stamp(pic, sprite, x, y)
    return to_image(pic[:360, :640])
