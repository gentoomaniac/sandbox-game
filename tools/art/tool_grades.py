"""The five grades of the tools, told apart at a glance by their metal (task 206).

Every tool's picture (its icon in both art sets, the tool in the hand) is a hand-drawn map of
letters, one per region, and a grade is the colours those letters get: `e` the cutting edge or
striking face, `m` the lit face, `s` the body, `k` the shade of the metal; `l`, `w` and `d` the
lit, plain and dark wood of the handle. Three grades add marks on top of the map, pixels only
they show: the rust's pits (`p` dark, `q` orange), the hairline crack of brittle steel (`c`) and
the keen edge's second line and glints of sharp steel (`g`).

From worst to best: rusty iron (today's tools: dull brown-grey iron, pitted with rust, on an old
dark handle), iron (plain grey), brittle steel (lighter and cold blue, with a crack), steel
(bright and clean) and sharp steel (steel with a keen white edge).
"""

GRADES = ("rusty_iron", "iron", "brittle_steel", "steel", "sharp_steel")

METALS = {
    "rusty_iron": {"e": "bare_light", "m": "bare_light", "s": "bare", "k": "mud_dark"},
    "iron": {"e": "stone_light", "m": "stone_light", "s": "stone", "k": "stone_dark"},
    "brittle_steel": {"e": "snow", "m": "snow", "s": "snow_shadow", "k": "snow_deep"},
    "steel": {"e": "lime", "m": "lime", "s": "stone_light", "k": "stone"},
    "sharp_steel": {"e": "snow_light", "m": "snow_light", "s": "snow", "k": "stone_light"},
}
# The rusty tool's handle is old wood, dull and dark; the others have a lit ash handle.
WOODS = {
    "rusty_iron": {"l": "soil_mid", "w": "soil_mid", "d": "soil"},
    "iron": {"l": "soil_light", "w": "soil_mid", "d": "soil"},
}
MARKS = {
    "rusty_iron": {"p": "rust_dark", "q": "rust"},
    "brittle_steel": {"c": "stone_dark"},
    "sharp_steel": {"g": "snow_light"},
}


def keys(grade):
    """The colour of each letter of a tool map in `grade`."""
    return WOODS.get(grade, WOODS["iron"]) | METALS[grade]


def marks(grade):
    """The colour of each mark letter `grade` shows; the other marks stay as the map has them."""
    return MARKS.get(grade, {})


# The grade's Roman numeral, I to V, in the bottom left corner of the icons (the slot draws the
# count bottom right and the can's water badge top left): tiny glyphs 4 px tall with 1 px
# strokes, in cream on an ink backing with a 1 px margin, so they read on any slot and over the
# tool. Drawn at `scale` 2 in the 32 px icons, which the UI shows at half size, and 1 in the
# classic 16 px icons.
NUMERALS = {
    "rusty_iron": ("#", "#", "#", "#"),
    "iron": ("#.#", "#.#", "#.#", "#.#"),
    "brittle_steel": ("#.#.#", "#.#.#", "#.#.#", "#.#.#"),
    "steel": ("#.#.#", "#.#.#", "#.#.#", "#..#."),
    "sharp_steel": ("#.#", "#.#", "#.#", ".#."),
}
NUMERAL_COLOUR = "cream"
NUMERAL_BACKING = "ink"


def numeral(picture, grade, scale):
    """Draws the grade's numeral on its backing, flush with the picture's bottom left corner."""
    glyph = NUMERALS[grade]
    width, height = (len(glyph[0]) + 2) * scale, (len(glyph) + 2) * scale
    left, top = 0, len(picture) - height
    for y in range(top, top + height):
        for x in range(left, left + width):
            picture[y][x] = NUMERAL_BACKING
    for gy, row in enumerate(glyph):
        for gx, cell in enumerate(row):
            if cell == "#":
                for dy in range(scale):
                    for dx in range(scale):
                        picture[top + (gy + 1) * scale + dy][left + (gx + 1) * scale + dx] = NUMERAL_COLOUR
    return picture


def stamp(picture, x, y, rows, grade, marks_at=None):
    """Draws a map of letters with its top left at (x, y) in the colours of `grade`; "." leaves a
    pixel as it is. `marks_at` is {letter: [(x, y), ...]} in the map's own pixels, drawn over it
    for the grade that shows the letter."""
    colours = keys(grade)
    for dy, row in enumerate(rows):
        for dx, letter in enumerate(row):
            if letter != ".":
                picture[y + dy][x + dx] = colours[letter]
    for letter, colour in marks(grade).items():
        for mx, my in (marks_at or {}).get(letter, ()):
            picture[y + my][x + mx] = colour
    return picture
