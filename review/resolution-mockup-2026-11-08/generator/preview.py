"""Development previews: python preview.py ground|sheet|b  (writes into look/)."""

import sys
from pathlib import Path

from PIL import Image

from b_core import to_image

HERE = Path(__file__).parent
LOOK = HERE / "look"
LOOK.mkdir(exist_ok=True)


def save(im, name, scale):
    im.resize((im.width * scale, im.height * scale), Image.NEAREST).save(LOOK / name)


what = sys.argv[1]
if what == "ground":
    import b_ground
    pic, _ = b_ground.render()
    im = to_image(pic)
    save(im, "ground_b.png", 1)
    save(im.crop((0, 120, 320, 300)), "ground_b_zoom.png", 3)
elif what == "sheet":
    import b_sprites
    save(b_sprites.sheet(sys.argv[2:]), "sheet.png", 4)
elif what == "b":
    import version_b
    im = version_b.render()
    save(im, "b.png", 1)
    x, y = (int(v) for v in sys.argv[2:4]) if len(sys.argv) > 3 else (0, 0)
    save(im.crop((x, y, x + 320, y + 180)), "b_zoom.png", 3)
