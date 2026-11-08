"""All version B pictures by name, and a contact sheet of them for checking."""

from PIL import Image

from b_core import to_image
import b_animals
import b_kate
import b_people
import b_plants

MAKERS = {
    "player": b_people.player,
    "villager": b_people.villager,
    "horse": b_animals.horse,
    "cow": b_animals.cow,
    "chicken": b_animals.chicken,
    "cat": b_animals.cat,
    "mouse": b_animals.mouse,
    "frog": b_animals.frog,
    "kate": b_kate.kate,
    "willow": b_plants.willow,
    "reeds": lambda: b_plants.reeds(0),
    "reeds1": lambda: b_plants.reeds(1),
    "tall_grass": lambda: b_plants.tall_grass(0),
    "wheat": lambda: b_plants.wheat(0),
    "cabbage": lambda: b_plants.cabbage(0),
}


def sheet(names=()):
    names = names or list(MAKERS)
    pics = [to_image(MAKERS[n]()) for n in names]
    width = sum(p.width for p in pics) + 6 * (len(pics) + 1)
    height = max(p.height for p in pics) + 12
    out = Image.new("RGBA", (width, height), (70, 112, 61, 255))
    x = 6
    for p in pics:
        out.alpha_composite(p, (x, height - 6 - p.height))
        x += p.width + 6
    return out
