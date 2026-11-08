"""Writes the mockup next to this file: a_today_640x360.png, b_32px_640x360.png, compare.png,
the same pair at x3 (1920x1080), and compare_detail.png (three close-ups, A above B, at x3).
Deterministic; needs Pillow and numpy from the game's .venv:

    /home/marco/git-private/sandbox-game/.venv/bin/python make.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

import version_a
import version_b

HERE = Path(__file__).parent


def labelled(im, text):
    """The picture with a caption strip under it."""
    out = Image.new("RGBA", (im.width, im.height + 18), (29, 27, 38, 255))
    out.paste(im, (0, 0))
    ImageDraw.Draw(out).text((6, im.height + 4), text, fill=(241, 230, 194, 255))
    return out


def main():
    a = version_a.render().resize((640, 360), Image.NEAREST)
    b = version_b.render()
    a.save(HERE / "a_today_640x360.png")
    b.save(HERE / "b_32px_640x360.png")
    a.resize((1920, 1080), Image.NEAREST).save(HERE / "a_today_1920x1080.png")
    b.resize((1920, 1080), Image.NEAREST).save(HERE / "b_32px_1920x1080.png")
    left = labelled(a, "A  today: 16x16 px tiles, 320x180 art px, shown x2")
    right = labelled(b, "B  32x32 px tiles, 640x360 art px, shown x1")
    compare = Image.new("RGBA", (left.width + right.width + 8, left.height), (29, 27, 38, 255))
    compare.paste(left, (0, 0))
    compare.paste(right, (left.width + 8, 0))
    compare.save(HERE / "compare.png")
    # Close-ups, 320x180 each: the people, chicken and horse; the cat, field, mouse and cow;
    # the willow, reeds, stream and frog.
    crops = [(150, 40), (90, 170), (320, 100)]
    detail = Image.new("RGBA", (3 * 960 + 16, 2 * 540 + 8), (29, 27, 38, 255))
    for column, (x0, y0) in enumerate(crops):
        for row, im in enumerate((a, b)):
            part = im.crop((x0, y0, x0 + 320, y0 + 180)).resize((960, 540), Image.NEAREST)
            detail.paste(part, (column * (960 + 8), row * (540 + 8)))
    detail.save(HERE / "compare_detail.png")


if __name__ == "__main__":
    main()
