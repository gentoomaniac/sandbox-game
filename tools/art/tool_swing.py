"""The swing of the tools (task 227), for both art sets: the motions, their frames and the tools'
pictures in them. swing.py draws them at 32 px per tile, classic/swing.py at 16 px.

When the player uses a tool, the arms and the tool swing: four or five frames of a motion in each
facing (MOTIONS: the chop of the axe, the pickaxe and the hoe, the knock of the hammer, the dig of
the shovel and the mow of the scythe), each shown for as long as DURATIONS says. A frame (FRAMES) says where the hands are, in the 32 px figure's pixels
(character.py; the classic art halves them), which way the tool points from the hand that holds
it and which side its blade is on, whether it is behind the figure, how far the figure sinks as
the blow lands, which arms reach forward out of sight from behind, and where the feet are.

A tool is one rigid picture in each frame, a map of letters as its icon and the held tool are
(tool_grades.py): upright as in the hand (held_maps.py) or on the true diagonal (DIAGONALS, at
the size of the classic icons, whose handle is 2 px a row), turned in quarter turns and mirrored,
so nothing is drawn at an odd angle. A turned picture is lit anew from the top left (`relit`).
"""

import held_maps

# The motions and the tools that make them; the frames of each are in FRAMES.
MOTIONS = ("chop", "knock", "dig", "mow")
MOTION_OF_TOOL = {
    "axe": "chop",
    "pickaxe": "chop",
    "hoe": "chop",
    "hammer": "knock",
    "shovel": "dig",
    "scythe": "mow",
}

# Directions as steps in the picture (x to the right, y down).
UP, DOWN, LEFT, RIGHT = (0, -1), (0, 1), (-1, 0), (1, 0)
UP_RIGHT, DOWN_RIGHT, DOWN_LEFT, UP_LEFT = (1, -1), (1, 1), (-1, 1), (-1, -1)

WOOD = "lwd"
METAL = "msk"


class Tool:
    """A tool's picture as a map of letters around the pixel the hand holds, (0, 0): the left
    column of the handle there. `points` is the way from the hand to the working end, `side` the
    side its blade or bit is on (1 a quarter turn clockwise from `points`, -1 the other way, 0 for
    a head that is alike on both)."""

    def __init__(self, letters, points, side):
        self.letters = letters
        self.points = points
        self.side = side


def stamped(rows, top, handle_column, letters):
    """Adds a head map (character.py: pointing right, its handle in the columns `handle_column`
    and the next) over the handle, from row `top` down."""
    for dy, row in enumerate(rows):
        for dx, letter in enumerate(row):
            if letter != ".":
                letters[(dx - handle_column, top + dy)] = letter
    return letters


def handle(top, bottom):
    """The 2 px handle from row `top` to `bottom`, the left column lit."""
    letters = {}
    for y in range(top, bottom + 1):
        letters[(0, y)], letters[(1, y)] = "l", "d"
    return letters


def upright(tool):
    """The tool as it is held (character.py), head up, with as much handle below the hand as a
    swing shows."""
    if tool == "hoe":
        return Tool(stamped(held_maps.HOE_HEAD, -19, 0, handle(-17, 6)), UP, 1)
    if tool == "shovel":
        letters = stamped(held_maps.SPADE_GRIP, -14, 1, handle(-13, 10))
        return Tool(stamped(held_maps.SPADE_BLADE, 11, 2, letters), DOWN, 0)
    if tool == "scythe":
        # Held at the nib, the snath going on past it.
        letters = stamped(held_maps.SCYTHE_BLADE, -18, 0, handle(-16, 9))
        return Tool(stamped(held_maps.SCYTHE_NIB, 0, 0, letters), UP, 1)
    if tool == "axe":
        return Tool(stamped(held_maps.AXE_HEAD, -9, 1, handle(-4, 8)), UP, 1)
    if tool == "pickaxe":
        return Tool(stamped(held_maps.PICK_HEAD, -9, 3, handle(-7, 8)), UP, 0)
    return Tool(stamped(held_maps.HAMMER_HEAD, -7, 2, handle(-3, 3)), UP, 0)


# fmt: off
# The tools on the diagonal from the bottom left to the top right, as the classic icons draw them
# (classic/tool_icons.py), the hand's pixel as "h" (a "w" of the handle); the handle goes on below
# the map by `TAILS` more steps. The shovel's blade is at the bottom left, its grip at the top.
DIAGONALS = {
    "hoe": (
        "..........mm....",
        ".........ldmm...",
        "........wd..mm..",
        ".......wd....me.",
        "......wd......e.",
        ".....wd.........",
        "....wd..........",
        "...wd...........",
        "..hd............",
        ".wd.............",
    ),
    "axe": (
        "........e.......",
        ".......emm......",
        "......esssm.....",
        ".....esssssmk...",
        "......kksssskk..",
        ".........ld.....",
        "........wd......",
        ".......wd.......",
        "......hd........",
        ".....wd.........",
        "....wd..........",
    ),
    "pickaxe": (
        ".....em.........",
        "......mmm.......",
        "........mm......",
        ".........mm.....",
        ".........lmm....",
        "........wd.mm...",
        ".......wd...m...",
        "......wd....mm..",
        ".....hd......m..",
        "....wd........e.",
        "...wd...........",
    ),
    "hammer": (
        ".......ee.......",
        "......eesm......",
        ".......mssm.....",
        "........mssm....",
        ".........mssm...",
        "........ldmssm..",
        ".......hd..msee.",
        "......wd....ee..",
        ".....wd.........",
    ),
    "shovel": (
        "..........d.....",
        "...........d....",
        "...........ld...",
        "..........wd.d..",
        ".........wd.....",
        "........hd......",
        ".....m.wd.......",
        "....msmw........",
        "...msssm........",
        "..mssssk........",
        ".essssk.........",
        ".esssk..........",
        ".eekk...........",
    ),
    "scythe": (
        ".....mmmmmm.....",
        "...meeeeeeemm...",
        "..ee......ssk...",
        "..e.......ld....",
        ".........wd.....",
        "........wd......",
        ".......wd.......",
        "......wd........",
        ".....wd.........",
        "....wd..........",
        "...wd...........",
        "..wd............",
        ".hd.............",
    ),
}
# fmt: on
# How the diagonal pictures point and which side their blade is on (see `Tool`).
DIAGONAL_POSE = {
    "hoe": (UP_RIGHT, 1),
    "axe": (UP_RIGHT, -1),
    "pickaxe": (UP_RIGHT, 0),
    "hammer": (UP_RIGHT, 0),
    "shovel": (DOWN_LEFT, 0),
    "scythe": (UP_RIGHT, -1),
}
# Steps of handle below the diagonal map, past the hand.
TAILS = {"hoe": 4, "axe": 3, "pickaxe": 3, "hammer": 1, "shovel": 0, "scythe": 4}
# The icons' handles are short for a tool in the hand: steps of handle put in below these rows of
# the maps (the rows below move down and to the left), so a diagonal tool is as long as upright.
LONGER = {"hoe": ((5, 8),), "shovel": ((3, 4), (5, 9)), "scythe": ((4, 5),)}


def diagonal(tool):
    rows = DIAGONALS[tool]
    letters = {}
    for y, row in enumerate(rows):
        for x, letter in enumerate(row):
            if letter == "h":
                grip = (x, y)
                letter = "w"
            if letter != ".":
                letters[(x, y)] = letter
    for row, steps in reversed(LONGER.get(tool, ())):
        letters = lengthened(letters, row, steps)
        if grip[1] > row:
            grip = (grip[0] - steps, grip[1] + steps)
    # The handle on down to the left, from where it leaves the map's bottom row.
    bottom = max(y for _, y in letters)
    left = min(x for x, y in letters if y == bottom)
    for step in range(1, TAILS[tool] + 1):
        letters[(left - step, bottom + step)], letters[(left - step + 1, bottom + step)] = "w", "d"
    points, side = DIAGONAL_POSE[tool]
    return Tool({(x - grip[0], y - grip[1]): letter for (x, y), letter in letters.items()}, points, side)


def lengthened(letters, row, steps):
    """A diagonal map with `steps` more of its handle below `row`: the rows below it move down
    and to the left, and the handle's two pixels of `row` go on between."""
    result = {}
    for (x, y), letter in letters.items():
        result[(x - steps, y + steps) if y > row else (x, y)] = letter
    wood = sorted(x for (x, y), letter in letters.items() if y == row and letter in WOOD)
    pair = wood[:2]
    for step in range(1, steps + 1):
        result[(pair[0] - step, row + step)], result[(pair[0] + 1 - step, row + step)] = "w", "d"
    return result


def turned(points):
    """A direction a quarter turn clockwise."""
    return (-points[1], points[0])


def oriented(tool, points, side):
    """The tool's picture pointing along `points`, its blade on `side` (see `Tool`): its upright
    or its diagonal picture, turned and mirrored to point so, and lit anew if it was."""
    picture = diagonal(tool) if points[0] and points[1] else upright(tool)
    for flip in (False, True):
        way = (-picture.points[0], picture.points[1]) if flip else picture.points
        blade = -picture.side if flip else picture.side
        for quarters in range(4):
            if way == points and (blade == side or not blade or not side):
                if not flip and not quarters:
                    return picture.letters
                return relit(moved(picture.letters, flip, quarters))
            way = turned(way)
    raise ValueError(f"the {tool} cannot point {points}")


def moved(letters, flip, quarters):
    """The map mirrored (if `flip`) and then turned clockwise by `quarters`, about the hand."""
    result = {}
    for (x, y), letter in letters.items():
        if flip:
            x = -x
        for _ in range(quarters):
            x, y = -y, x
        result[(x, y)] = letter
    return result


def relit(letters):
    """A turned picture lit anew from the top left: wood lit where other than wood is above or
    left of it and shaded where it is below or right; metal lit where nothing is above or left of
    it and shaded where nothing is below or right. Edges stay."""
    result = {}
    for (x, y), letter in letters.items():
        before, after = ((x - 1, y), (x, y - 1)), ((x + 1, y), (x, y + 1))
        if letter in WOOD:
            lit = any(letters.get(p, ".") not in WOOD for p in before)
            shaded = any(letters.get(p, ".") not in WOOD for p in after)
            letter = "w" if lit == shaded else "l" if lit else "d"
        elif letter in METAL:
            letter = "m" if any(p not in letters for p in before) else "k" if any(p not in letters for p in after) else "s"
        result[(x, y)] = letter
    return result


def tool_hand_index(facing):
    """Which of `Figure.arms` holds the tool: the near one from the side, the left of the picture
    from the front, the right from behind (as when it is held, character.py)."""
    return 0 if facing == "down" else 1


def frame(hands, points, side, behind=False, sink=0, hidden=(), slide=0, lean=0, lift=(0, 0), step=None, load=False):
    """A frame of a motion: where the hands are (`hands`, in the order of `Figure.arms`, the
    tool's hand at the tool's hand pixel), which way the tool points and its blade's side,
    whether it is behind the figure, how far the figure sinks, and which arms reach forward out
    of sight (`hidden`, from behind). `slide` is how far the hand holds the tool up its handle
    from where it is held standing (the spade's hands go up the shaft), `lean` how many rows of a
    spade's shaft go up for each pixel it leans aside (to the right if more than 0, see `leant`),
    `lift` how far each foot is raised (from the front or behind) and `step` how far the near foot
    is put forward and up (from the side, onto the spade's blade), and `load` puts a spit of earth
    on the blade."""
    return {
        "hands": hands,
        "points": points,
        "side": side,
        "behind": behind,
        "sink": sink,
        "hidden": hidden,
        "slide": slide,
        "lean": lean,
        "lift": lift,
        "step": step,
        "load": load,
    }


BOTH = (0, 1)
# The frames of each motion in each facing drawn ("left" is "right" mirrored).
FRAMES = {
    # The chop: the tool brought up before the chest, lifted back over the head, swung forward and
    # down onto the work as the figure sinks into the blow, and held there as it straightens.
    # From the front it goes out to the side and comes down before the body; from behind it goes
    # up beside the head and forward out of sight but for its head.
    ("chop", "right"): (
        frame(((20, 35), (23, 35)), UP_RIGHT, 1),
        frame(((13, 17), (10, 17)), UP_LEFT, 1),
        frame(((21, 25), (23, 24)), UP_RIGHT, 1),
        frame(((22, 37), (25, 37)), RIGHT, 1, sink=1),
        frame(((21, 35), (24, 35)), RIGHT, 1),
    ),
    ("chop", "down"): (
        frame(((6, 32), None), UP, -1),
        frame(((3, 20), None), UP_LEFT, -1),
        frame(((5, 28), None), LEFT, -1),
        frame(((13, 40), (17, 38)), DOWN, -1, sink=1),
        frame(((13, 38), (17, 36)), DOWN, -1),
    ),
    ("chop", "up"): (
        frame((None, (26, 31)), UP, 1, behind=True),
        frame((None, (28, 20)), UP_RIGHT, 1, behind=True),
        frame((None, (26, 28)), RIGHT, 1, behind=True),
        frame(((13, 34), (21, 34)), UP_RIGHT, 1, behind=True, sink=1, hidden=BOTH),
        frame(((13, 32), (21, 32)), UP_RIGHT, 1, behind=True, hidden=BOTH),
    ),
    # The knock of the hammer, with one hand at the height of the chest: brought up, cocked back
    # beside the head, struck forward level with the chest, and bounced back off the work.
    ("knock", "right"): (
        frame((None, (22, 36)), UP_RIGHT, 0),
        frame((None, (17, 23)), UP_LEFT, 0),
        frame((None, (21, 24)), UP_RIGHT, 0),
        frame((None, (25, 31)), RIGHT, 0),
        frame((None, (24, 30)), UP_RIGHT, 0),
    ),
    ("knock", "down"): (
        frame(((5, 35), None), UP_LEFT, 0),
        frame(((4, 23), None), UP_LEFT, 0),
        frame(((7, 26), None), UP, 0),
        frame(((11, 32), None), RIGHT, 0),
        frame(((9, 29), None), UP_RIGHT, 0),
    ),
    ("knock", "up"): (
        frame((None, (26, 31)), UP, 0, behind=True),
        frame((None, (28, 23)), UP_RIGHT, 0, behind=True),
        frame((None, (25, 26)), UP, 0, behind=True),
        frame((None, (21, 31)), UP, 0, behind=True, hidden=(1,)),
        frame((None, (23, 29)), UP, 0, behind=True),
    ),
    # The dig: the spade set upright on the ground before the feet, the hands high on its shaft;
    # the foot drives the blade in as the figure leans on it; the shaft pulled back levers the
    # blade in the ground; and the spit of earth comes up on the blade.
    ("dig", "right"): (
        frame(((25, 26), (25, 32)), DOWN, 0, slide=8),
        frame(((25, 31), (25, 36)), DOWN, 0, sink=1, slide=9, step=(6, 6)),
        frame(((16, 32), (20, 40)), DOWN, 0, slide=6, lean=-3),
        frame(((16, 40), (26, 40)), RIGHT, 0, slide=-6, load=True),
    ),
    ("dig", "down"): (
        frame(((11, 36), (12, 30)), DOWN, 0, slide=9),
        frame(((11, 39), (12, 34)), DOWN, 0, sink=1, slide=9, lift=(5, 0)),
        frame(((15, 41), (18, 34)), DOWN, 0, slide=7, lean=3),
        frame(((10, 40), (24, 40)), LEFT, 0, slide=-4, load=True),
    ),
    ("dig", "up"): (
        frame(((20, 30), (22, 35)), DOWN, 0, behind=True, hidden=BOTH, slide=8),
        frame(((20, 33), (22, 38)), DOWN, 0, behind=True, sink=1, hidden=BOTH, slide=9, lift=(0, 5)),
        frame(((15, 31), (18, 39)), DOWN, 0, behind=True, hidden=BOTH, slide=6, lean=-3),
        frame(((8, 40), (23, 40)), RIGHT, 0, behind=True, hidden=(0,), slide=-4, load=True),
    ),
    # The mow: the scythe drawn back and up, swept from behind along the ground to before the
    # figure, and lifted off it as the stroke runs out.
    ("mow", "right"): (
        frame(((16, 34), (13, 37)), DOWN_LEFT, -1),
        frame(((17, 37), (14, 40)), DOWN_LEFT, -1),
        frame(((23, 36), (24, 41)), DOWN, -1),
        frame(((20, 37), (23, 40)), DOWN_RIGHT, -1),
        frame(((22, 34), (25, 37)), DOWN_RIGHT, -1),
    ),
    ("mow", "down"): (
        frame(((8, 37), (11, 33)), DOWN_LEFT, -1),
        frame(((9, 40), (12, 36)), DOWN_LEFT, -1),
        frame(((15, 42), (18, 36)), DOWN, -1),
        frame(((21, 40), (20, 35)), DOWN_RIGHT, -1),
        frame(((22, 37), (21, 32)), DOWN_RIGHT, -1),
    ),
    ("mow", "up"): (
        frame(((20, 32), (23, 37)), DOWN_RIGHT, 1, behind=True, hidden=BOTH),
        frame(((19, 35), (22, 40)), DOWN_RIGHT, 1, behind=True, hidden=BOTH),
        frame(((13, 36), (16, 42)), DOWN, 1, behind=True, hidden=BOTH),
        frame(((11, 36), (10, 40)), DOWN_LEFT, 1, behind=True, hidden=BOTH),
        frame(((10, 33), (9, 37)), DOWN_LEFT, 1, behind=True, hidden=BOTH),
    ),
}
# Where a tool points otherwise than its motion's frame says, by (tool, facing drawn, frame): the
# pick and the hoe strike the ground before the feet.
POINTS = {
    ("pickaxe", "right", 3): DOWN_RIGHT,
    ("pickaxe", "right", 4): DOWN_RIGHT,
    ("hoe", "right", 3): DOWN_RIGHT,
    ("hoe", "right", 4): DOWN_RIGHT,
}
# How long each frame of a motion shows, in milliseconds, for the game to play them at: the blow
# and the push hold longest, the fast middle of a swing shortest.
DURATIONS = {
    "chop": (100, 160, 70, 180, 120),
    "knock": (90, 140, 60, 160, 110),
    "dig": (130, 220, 150, 200),
    "mow": (130, 90, 70, 90, 150),
}
# The row of the ground before the feet, in the figure's rows, by facing drawn: a spade's blade
# thrust into it is cut off below. From the front it is below the feet in the picture, from behind
# above them.
GROUND = {"right": 61, "down": 66, "up": 58}


def raised_feet(motion_frame):
    """Whether each foot is put up in a frame (the far or left one first): a spade's blade is
    behind it."""
    return (motion_frame["lift"][0] > 0, motion_frame["lift"][1] > 0 or motion_frame["step"] is not None)


def frame_count(motion):
    """How many frames a motion has (as many in each facing)."""
    return len(FRAMES[(motion, "right")])


def motion_frames():
    """Every (motion, frame index) in the order of the sheets' columns."""
    return [(motion, index) for motion in MOTIONS for index in range(frame_count(motion))]


def figure_frame(motion, index, facing):
    """A frame in a facing of the sheets ("left" is drawn as "right" and mirrored)."""
    return FRAMES[(motion, "right" if facing == "left" else facing)][index]


def tool_letters(tool, motion, index, facing):
    """The tool's picture in a frame (in a facing drawn), around the hand that holds it."""
    motion_frame = figure_frame(motion, index, facing)
    points = POINTS.get((tool, facing, index), motion_frame["points"])
    letters = oriented(tool, points, motion_frame["side"])
    slide = motion_frame["slide"]
    if slide:
        letters = {(x + points[0] * slide, y + points[1] * slide): letter for (x, y), letter in letters.items()}
    if motion_frame["lean"]:
        letters = leant(letters, motion_frame["lean"])
    if motion_frame["load"]:
        letters = loaded(letters)
    return letters


def leant(letters, lean):
    """A spade pointing down with its shaft leant over above the blade, which stays upright in
    the ground: a pixel aside for each `lean` rows up (to the right if `lean` is more than 0),
    still held at the hand."""
    blade = min(y for (x, y), letter in letters.items() if letter in METAL + "e")

    def aside(y):
        return 0 if y >= blade else (blade - y + abs(lean) - 1) // abs(lean) * (1 if lean > 0 else -1)

    return {(x + aside(y) - aside(0), y): letter for (x, y), letter in letters.items()}


# The letters of what is not the tool: earth on the spade.
SOIL = "oO"


def loaded(letters):
    """A spit of earth heaped on the blade of a spade held flat: a mound over its middle columns,
    lit on top."""
    metal = [(x, y) for (x, y), letter in letters.items() if letter in METAL + "e"]
    columns = sorted({x for x, _ in metal})
    inner = columns[2:-1]
    result = dict(letters)
    for number, x in enumerate(inner):
        top = min(y for mx, y in metal if mx == x)
        height = 1 + min(number, len(inner) - 1 - number, 2)
        for dy in range(1, height + 1):
            result[(x, top - dy)] = "O" if dy == height else "o"
    return result

