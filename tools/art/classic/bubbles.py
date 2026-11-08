"""The thought bubbles over the player's head as they were drawn at 16 px per tile: the bubble
part of ui.py at commit 97e9736, unchanged (see generate.py here)."""

from PIL import Image

BUBBLE_COLOURS = {"k": "ink", "b": "water_deep"}
BUBBLE_PADDING = 2
# The pictures inside the thought bubbles (see ThoughtBubble), by id. One bubble_<id>.png is
# drawn for each, with the bubble around the picture: add a picture here to add a bubble.
BUBBLE_ICONS = {
    "zzz": """
.....bbbbb
........b.
.......b..
bbbb..b...
..b..bbbbb
.b........
bbbb......
""",
}


def rgba(palette, name):
    return (*bytes.fromhex(palette[name]), 255)


def bubble(palette, rows):
    """A thought bubble around the picture `rows` (BUBBLE_COLOURS characters; . is clear): a
    rounded outline, a cream inside and a small tail below, pointing at the head."""
    picture = rows.split()
    margin = BUBBLE_PADDING + 1
    width = len(picture[0]) + 2 * margin
    height = len(picture) + 2 * margin
    image = Image.new("RGBA", (width, height + 2), (0, 0, 0, 0))
    for y in range(height):
        for x in range(width):
            is_corner = x in (0, width - 1) and y in (0, height - 1)
            is_edge = x in (0, width - 1) or y in (0, height - 1)
            if not is_corner:
                image.putpixel((x, y), rgba(palette, "ink" if is_edge else "cream"))
    middle = width // 2
    for x in (middle - 1, middle):
        image.putpixel((x, height - 1), rgba(palette, "cream"))
        image.putpixel((x, height), rgba(palette, "cream"))
        image.putpixel((x, height + 1), rgba(palette, "ink"))
    for x in (middle - 2, middle + 1):
        image.putpixel((x, height), rgba(palette, "ink"))
    for y, line in enumerate(picture):
        for x, character in enumerate(line):
            if character != ".":
                image.putpixel((margin + x, margin + y), rgba(palette, BUBBLE_COLOURS[character]))
    return image
