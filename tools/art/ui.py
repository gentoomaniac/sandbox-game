"""Art for the menus: the pixel font, the 9-slice panel frame and the button frames.

Called from generate.py, which passes the palette so it stays the only source of colours.
Written to assets/ui/:
- font.png and font.fnt: a BMFont that Godot imports as a font. Glyphs are 5 px wide, capitals
  and digits 7 px tall, with descenders reaching 2 px below the baseline;
- panel.png: a 24x24 frame, 8 px corners (StyleBoxTexture margin 8);
- slider_grabber.png and slider_grabber_highlight.png: 10x10 slider knobs (the highlight one
  is used when hovered, focused or dragged);
- button_normal.png, button_hover.png, button_pressed.png, button_focus.png: 12x12 frames,
  4 px corners (margin 4). The focus frame has no fill and is drawn over the others;
- energy_icon.png and health_icon.png: 12x12 icons for the bars next to the hotbar;
- bar_frame.png (48x8) and energy_fill.png, health_fill.png (46x6, the frame's inside): the
  bars. The game draws as much of a fill as the bar is full;
- bubble_<id>.png: the thought bubbles over the player's head, one per id of BUBBLE_ICONS.
The Theme that uses them is game/scenes/ui_theme.tres.
"""

from PIL import Image

GLYPH_COLOUR = "cream"
CELL_WIDTH = 6
CELL_HEIGHT = 10
ATLAS_COLUMNS = 16
# The font's line: capitals sit on the rows above BASELINE, descenders hang below it.
LINE_HEIGHT = 10
BASELINE = 7
SPACE_ADVANCE = 3
PANEL_SIZE = 24
BUTTON_SIZE = 12
GRABBER_SIZE = 10
BAR_WIDTH = 48
BAR_HEIGHT = 8

# One glyph per line: the character, an optional @row where its first pixel row sits, then
# the pixel rows (# is ink). Without @row a glyph starts at row 0 if it has 7 or more rows
# and at row 2 (the x-height) if it has fewer, and g, p, q, y always start at row 2. Glyphs
# are trimmed to their ink and advance by their width plus 1 px.
# fmt: off
GLYPHS = """
A .###. #...# #...# ##### #...# #...# #...#
B ####. #...# #...# ####. #...# #...# ####.
C .###. #...# #.... #.... #.... #...# .###.
D ####. #...# #...# #...# #...# #...# ####.
E ##### #.... #.... ####. #.... #.... #####
F ##### #.... #.... ####. #.... #.... #....
G .###. #...# #.... #.### #...# #...# .####
H #...# #...# #...# ##### #...# #...# #...#
I .###. ..#.. ..#.. ..#.. ..#.. ..#.. .###.
J ..### ...#. ...#. ...#. ...#. #..#. .##..
K #...# #..#. #.#.. ##... #.#.. #..#. #...#
L #.... #.... #.... #.... #.... #.... #####
M #...# ##.## #.#.# #.#.# #...# #...# #...#
N #...# ##..# #.#.# #..## #...# #...# #...#
O .###. #...# #...# #...# #...# #...# .###.
P ####. #...# #...# ####. #.... #.... #....
Q .###. #...# #...# #...# #.#.# #..#. .##.#
R ####. #...# #...# ####. #.#.. #..#. #...#
S .#### #.... #.... .###. ....# ....# ####.
T ##### ..#.. ..#.. ..#.. ..#.. ..#.. ..#..
U #...# #...# #...# #...# #...# #...# .###.
V #...# #...# #...# #...# #...# .#.#. ..#..
W #...# #...# #...# #.#.# #.#.# ##.## #...#
X #...# #...# .#.#. ..#.. .#.#. #...# #...#
Y #...# #...# .#.#. ..#.. ..#.. ..#.. ..#..
Z ##### ....# ...#. ..#.. .#... #.... #####
0 .###. #...# #..## #.#.# ##..# #...# .###.
1 ..#.. .##.. ..#.. ..#.. ..#.. ..#.. .###.
2 .###. #...# ....# ...#. ..#.. .#... #####
3 .###. #...# ....# ..##. ....# #...# .###.
4 ...#. ..##. .#.#. #..#. ##### ...#. ...#.
5 ##### #.... ####. ....# ....# #...# .###.
6 ..##. .#... #.... ####. #...# #...# .###.
7 ##### ....# ...#. ..#.. .#... .#... .#...
8 .###. #...# #...# .###. #...# #...# .###.
9 .###. #...# #...# .#### ....# ...#. .##..
a .###. ....# .#### #...# .####
b #.... #.... #.##. ##..# #...# #...# ####.
c .###. #...# #.... #...# .###.
d ....# ....# .##.# #..## #...# #...# .####
e .###. #...# ##### #.... .###.
f ..##. .#..# .#... ###.. .#... .#... .#...
g .#### #...# #...# #...# .#### ....# .###.
h #.... #.... #.##. ##..# #...# #...# #...#
i ..#.. ..... .##.. ..#.. ..#.. ..#.. .###.
j ...#. ..... ..##. ...#. ...#. ...#. ...#. #..#. .##..
k #.... #.... #..#. #.#.. ##... #.#.. #..#.
l .##.. ..#.. ..#.. ..#.. ..#.. ..#.. .###.
m ##.#. #.#.# #.#.# #.#.# #.#.#
n #.##. ##..# #...# #...# #...#
o .###. #...# #...# #...# .###.
p #.##. ##..# #...# #...# ####. #.... #....
q .##.# #..## #...# #...# .#### ....# ....#
r #.##. ##..# #.... #.... #....
s .#### #.... .###. ....# ####.
t .#... .#... ###.. .#... .#... .#..# ..##.
u #...# #...# #...# #..## .##.#
v #...# #...# #...# .#.#. ..#..
w #...# #...# #.#.# #.#.# .#.#.
x #...# .#.#. ..#.. .#.#. #...#
y #...# #...# #...# .#### ....# #...# .###.
z ##### ...#. ..#.. .#... #####
! #. #. #. #. #. .. #.
" @0 #.# #.# ...
# .#.#. .#.#. ##### .#.#. ##### .#.#. .#.#.
$ ..#.. .#### #.#.. .###. ..#.# ####. ..#..
% ##..# ##..# ...#. ..#.. .#... #..## #..##
& .##.. #..#. #.#.. .#... #.#.# #..#. .##.#
' @0 #. #. .#
( ...#. ..#.. .#... .#... .#... ..#.. ...#.
) .#... ..#.. ...#. ...#. ...#. ..#.. .#...
* @1 ..#.. #.#.# .###. #.#.# ..#..
+ @1 ..#.. ..#.. ##### ..#.. ..#..
, @5 .# .# #.
- @3 #####
. @5 ## ##
/ ....# ....# ...#. ..#.. .#... #.... #....
: @2 ## ## .. ## ##
; @2 ## ## .. ## .# #.
< ...#. ..#.. .#... #.... .#... ..#.. ...#.
= @2 ##### ..... #####
> #.... .#... ..#.. ...#. ..#.. .#... #....
? .###. #...# ....# ...#. ..#.. ..... ..#..
@ .###. #...# #.### #.#.# #.### #.... .###.
[ .###. .#... .#... .#... .#... .#... .###.
\\ #.... #.... .#... ..#.. ...#. ....# ....#
] .###. ...#. ...#. ...#. ...#. ...#. .###.
^ ..#.. .#.#. #...#
_ @7 #####
` #. .#
{ ..##. .#... .#... #.... .#... .#... ..##.
| # # # # # # #
} .##.. ...#. ...#. ....# ...#. ...#. .##..
~ @3 .##.# #.##.
· @3 ##
× @2 #...# .#.#. ..#.. .#.#. #...#
° @0 .#. #.# .#.
"""
# fmt: on


def parse_glyphs():
    """Returns {character: (first pixel row, [row string, ...])}."""
    glyphs = {" ": (0, [])}
    for line in GLYPHS.strip().splitlines():
        character, *rows = line.split(" ")
        if rows[0].startswith("@"):
            top = int(rows.pop(0)[1:])
        elif character in "gpqy":
            top = 2
        else:
            top = 0 if len(rows) >= 7 else 2
        glyphs[character] = (top, rows)
    return glyphs


def font_files(palette):
    """Returns the font atlas image and the .fnt text that describes it."""
    glyphs = parse_glyphs()
    order = sorted(glyphs, key=ord)
    rows = -(-len(order) // ATLAS_COLUMNS)
    image = Image.new("RGBA", (ATLAS_COLUMNS * CELL_WIDTH, rows * CELL_HEIGHT), (0, 0, 0, 0))
    ink = (*bytes.fromhex(palette[GLYPH_COLOUR]), 255)
    lines = []
    for index, character in enumerate(order):
        top, picture = glyphs[character]
        left = min((row.find("#") for row in picture if "#" in row), default=0)
        right = max((row.rfind("#") for row in picture), default=-1)
        width = right - left + 1
        assert width < CELL_WIDTH and top + len(picture) < CELL_HEIGHT, character
        cell_x = index % ATLAS_COLUMNS * CELL_WIDTH
        cell_y = index // ATLAS_COLUMNS * CELL_HEIGHT
        for y, row in enumerate(picture):
            for x in range(left, min(right + 1, len(row))):
                if row[x] == "#":
                    image.putpixel((cell_x + x - left, cell_y + y), ink)
        advance = width + 1 if picture else SPACE_ADVANCE
        lines.append(
            f"char id={ord(character)} x={cell_x} y={cell_y} width={width} "
            f"height={len(picture)} xoffset=0 yoffset={top} xadvance={advance} page=0 chnl=15"
        )
    header = [
        f'info face="Pixel" size={LINE_HEIGHT - 1} bold=0 italic=0 charset="" unicode=1 '
        "stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0",
        f"common lineHeight={LINE_HEIGHT} base={BASELINE} scaleW={image.width} "
        f"scaleH={image.height} pages=1 packed=0",
        'page id=0 file="font.png"',
        f"chars count={len(lines)}",
    ]
    return image, "\n".join(header + lines) + "\n"


# Icon pictures: one character per pixel, outlined in ink as pickups are.
ICON_COLOURS = {
    "k": "ink",
    "c": "cream",
    "g": "gold",
    "f": "flame",
    "p": "petal",
    "e": "ember",
    "l": "soil_light",
    "m": "soil_mid",
    "s": "soil",
    "i": "stone",
    "j": "stone_light",
    "d": "stone_dark",
}
ICON_ROWS = {
    "energy_icon": """
.....kkkkk..
....kcgggk..
...kcggfk...
..kcggfk....
..kcgggkkk..
...kkgggfk..
.....kgfk...
....kgfk....
...kgfk.....
...kfk......
....kk......
............
""",
    "health_icon": """
............
..kkkk.kkkk.
.kppppkeeeek
kppppeeeeeek
kpppeeeeeeek
keeeeeeeeeek
keeeeeeeeeek
.keeeeeeeek.
..keeeeeek..
...keeeek...
....keek....
.....kk.....
""",
    # Headers of the two sides of the storage screen: what you carry, and the chest.
    "backpack_icon": """
....kkkk....
...kllllk...
..kkmmmmkk..
.kmmmmmmmmk.
.kmllllllmk.
.kmmssssmmk.
.kmmmggmmmk.
.kmmmmmmmmk.
.kmllllllmk.
.ksmssssmsk.
..kssssssk..
...kkkkkk...
""",
    "chest_icon": """
............
..kkkkkkkk..
.kllllllllk.
kmmimmmmimmk
kmmimmmmimmk
kjjjjggjjjjk
kiiiiggiiiik
kmmdmggmdmmk
kmmdmmmmdmmk
kssssssssssk
.kkkkkkkkkk.
............
""",
}

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


def icon(palette, rows):
    """An image from rows of ICON_COLOURS characters; . is clear."""
    lines = rows.split()
    image = Image.new("RGBA", (len(lines[0]), len(lines)), (0, 0, 0, 0))
    for y, line in enumerate(lines):
        for x, character in enumerate(line):
            if character != ".":
                image.putpixel((x, y), rgba(palette, ICON_COLOURS[character]))
    return image


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


def bar_frame(palette):
    """An ink border with its corner pixels cut, round a dark inside."""
    image = Image.new("RGBA", (BAR_WIDTH, BAR_HEIGHT), rgba(palette, "soil_dark"))
    last_x, last_y = BAR_WIDTH - 1, BAR_HEIGHT - 1
    for x in range(BAR_WIDTH):
        for y in range(BAR_HEIGHT):
            if x in (0, last_x) and y in (0, last_y):
                image.putpixel((x, y), (0, 0, 0, 0))
            elif x in (0, last_x) or y in (0, last_y):
                image.putpixel((x, y), rgba(palette, "ink"))
    return image


def bar_fill(palette, light, mid, shade):
    """The inside of a bar: a light top row and a shaded bottom, as lit from above."""
    width, height = BAR_WIDTH - 2, BAR_HEIGHT - 2
    image = Image.new("RGBA", (width, height))
    for y in range(height):
        colour = light if y == 0 else shade if y >= height - 2 else mid
        for x in range(width):
            image.putpixel((x, y), rgba(palette, colour))
    return image


def frame(palette, size, fill, lit, shaded, border="ink", studs=None, inner=None):
    """A square frame: a 1 px border with its corner pixels cut, a 1 px bevel (`lit` on the
    top and left, `shaded` on the bottom and right), an optional second ring `inner`, then
    the fill (None for no fill). `studs` is one pixel placed 4 px in from each corner."""
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    def put(x, y, name):
        if name is not None:
            image.putpixel((x, y), (*bytes.fromhex(palette[name]), 255))

    last = size - 1
    for y in range(size):
        for x in range(size):
            ring = min(x, y, last - x, last - y)
            if ring == 0:
                if x not in (0, last) or y not in (0, last):
                    put(x, y, border)
            elif ring == 1:
                put(x, y, lit if x == 1 or y == 1 else shaded)
            elif ring == 2 and inner is not None:
                put(x, y, inner)
            else:
                put(x, y, fill)
    if studs is not None:
        for x in (4, last - 4):
            for y in (4, last - 4):
                put(x, y, studs)
    return image


def ui_images(palette):
    """Returns {file name: image} of the frames, icons and bars."""
    icons = {f"{name}.png": icon(palette, rows) for name, rows in ICON_ROWS.items()}
    bubbles = {f"bubble_{name}.png": bubble(palette, rows) for name, rows in BUBBLE_ICONS.items()}
    return icons | bubbles | {
        "bar_frame.png": bar_frame(palette),
        "energy_fill.png": bar_fill(palette, "cream", "gold", "flame"),
        "health_fill.png": bar_fill(palette, "petal", "ember", "soil"),
        "panel.png": frame(
            palette, PANEL_SIZE, "soil_dark", "soil_light", "soil", inner="soil_mid", studs="gold"
        ),
        "button_normal.png": frame(palette, BUTTON_SIZE, "soil", "soil_light", "soil_dark"),
        "button_hover.png": frame(palette, BUTTON_SIZE, "soil_mid", "sand_light", "soil"),
        "button_pressed.png": frame(palette, BUTTON_SIZE, "soil_dark", "soil", "soil_mid"),
        "slider_grabber.png": frame(palette, GRABBER_SIZE, "sand", "sand_light", "soil_mid"),
        "slider_grabber_highlight.png": frame(palette, GRABBER_SIZE, "gold", "cream", "sand"),
        "button_focus.png": frame(palette, BUTTON_SIZE, None, "gold", "gold", border="gold"),
    }


def write_ui_assets(folder, palette):
    folder.mkdir(exist_ok=True)
    atlas, descriptor = font_files(palette)
    atlas.save(folder / "font.png")
    (folder / "font.fnt").write_text(descriptor)
    for name, image in ui_images(palette).items():
        image.save(folder / name)
