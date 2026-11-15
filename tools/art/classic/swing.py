"""The swing of the tools in the classic art (assets/classic/character/use/<name>.png, task 227),
drawn at 16 px per tile: the motions and frames of tool_swing.py at half the size.

The sheets have the layout of the 32 px ones (swing.py there): a row per facing, a column per
frame of each motion, cells of USE_CELL with the figure's 16x32 frame at FIGURE_AT. The hands and
feet of a frame are the 32 px figure's halved; the figure's arms are lines from the shoulder to
the hand (`character.posed_arms`), only the near one from the side. A tool is its 32 px picture in
the frame at half the size (`halved`): a pixel where two of the four it covers are wood or metal,
so the 2 px handles become the classic 1 px shafts, its metal lit anew from the top left; the
earth on the spade where a block has only earth.
"""

import character
import tool_grades
from canvas import blank
from character import CHARACTER_HEIGHT, CHARACTER_WIDTH, outlined, pixels_of
from tool_swing import GROUND, METAL, MOTION_OF_TOOL, SOIL, WOOD, figure_frame, motion_frames, raised_feet, relit, tool_hand_index, tool_letters

USE_CELL = 48
FIGURE_AT = (16, 8)
# The colours of what is not the tool in a tool's picture: earth on the spade.
EXTRAS = {"o": "soil_mid", "O": "soil_light"}


def halved(point):
    return (point[0] // 2, point[1] // 2)


def pose_of(motion_frame):
    """The classic pose of a frame: the idle stance, the hands and feet at half their 32 px
    places."""
    hands = tuple(None if at is None else halved(at) for at in motion_frame["hands"])
    lift = tuple(raised // 2 for raised in motion_frame["lift"])
    step = motion_frame["step"] and halved(motion_frame["step"])
    return character.POSES["idle"] | {"sink": motion_frame["sink"], "hands": hands, "hidden": motion_frame["hidden"], "lift": lift, "step": step}


def halved_letters(letters):
    """A tool's 32 px picture at half the size, around the same hand: wood where two of a block's
    four pixels are wood (one dark shaft), else metal where two are metal (the edge if one of them
    is), the metal lit anew; earth where a block has some and nothing else."""
    blocks = {}
    for (x, y), letter in letters.items():
        blocks.setdefault(halved((x, y)), []).append(letter)
    result = {}
    for block, found in blocks.items():
        metal = [letter for letter in found if letter in METAL + "e"]
        wood = [letter for letter in found if letter in WOOD]
        if len(metal) >= 2:
            result[block] = "e" if "e" in metal else "s"
        elif len(wood) >= 2:
            result[block] = "d"
        else:
            if all(letter in SOIL for letter in found):
                result[block] = max(found, key=found.count)
    lit = relit({block: letter for block, letter in result.items()})
    return {block: (letter if letter in WOOD + SOIL else lit[block]) for block, letter in result.items()}


def placed(canvas):
    """The 16x32 figure frame in its place in a use cell."""
    cell = blank(USE_CELL)
    left, top = FIGURE_AT
    for y, row in enumerate(canvas):
        for x, colour in enumerate(row):
            if colour is not None:
                cell[top + y][left + x] = colour
    return cell


def layer_sheet(draw, variant_colours):
    """One layer of the figure in every frame of every motion, with its outline."""
    rows = []
    for facing in character.PLAYER_FACINGS:
        drawn = "right" if facing == "left" else facing
        row = []
        for motion, index in motion_frames():
            pose = pose_of(figure_frame(motion, index, facing))
            body = pixels_of(placed(character.draw_body(drawn, pose)))
            canvas = placed(draw(drawn, pose, **variant_colours))
            canvas = outlined(canvas, set() if draw is character.draw_body else body)
            row.append(character.mirrored(canvas) if facing == "left" else canvas)
        rows.append(row)
    return rows


def tool_frame(tool, grade, motion, index, facing, behind):
    """The tool's layer in one frame, in front of the figure or behind it (empty if the tool is
    not there in that frame); in front, the arms that are not hidden hold it."""
    motion_frame = figure_frame(motion, index, facing)
    cell = blank(USE_CELL)
    if motion_frame["behind"] != behind:
        return cell
    colours = tool_grades.keys(grade) | EXTRAS
    left, top = FIGURE_AT
    pose = pose_of(motion_frame)
    hand_x, hand_y = pose["hands"][tool_hand_index(facing)]
    hand_y += pose["sink"]
    ground = GROUND[facing] // 2
    for (x, y), letter in halved_letters(tool_letters(tool, motion, index, facing)).items():
        if tool == "shovel" and letter not in SOIL and hand_y + y > ground:
            continue
        cell[top + hand_y + y][left + hand_x + x] = colours[letter]
    if not behind:
        for arm in character.posed_arms(facing, pose):
            if not arm.hidden:
                for x, y in character.arm_pixels(arm):
                    if 0 <= x < CHARACTER_WIDTH and 0 <= y < CHARACTER_HEIGHT:
                        cell[top + y][left + x] = None
        # A foot put up on the spade's blade is in front of it, its clog a pixel wider.
        for (x0, x1, _top, bottom), raised in zip(character.leg_boxes(facing, pose), raised_feet(motion_frame)):
            if raised:
                for y in range(bottom - 3, bottom + 1):
                    for x in range(x0 - 1, x1 + 3):
                        cell[top + y][left + x] = None
    return cell


def tool_sheet(tool, grade, behind):
    """A tool's layer in its motion's frames (the other columns empty), outlined."""
    rows = []
    for facing in character.PLAYER_FACINGS:
        drawn = "right" if facing == "left" else facing
        row = []
        for motion, index in motion_frames():
            if motion != MOTION_OF_TOOL[tool]:
                row.append(blank(USE_CELL))
                continue
            pose = pose_of(figure_frame(motion, index, facing))
            body = pixels_of(placed(character.draw_body(drawn, pose)))
            canvas = outlined(tool_frame(tool, grade, motion, index, drawn, behind), body)
            row.append(character.mirrored(canvas) if facing == "left" else canvas)
        rows.append(row)
    return rows


def tool_sheets():
    """The sheets of the tools that swing, by file name (held_<grade>_<tool>, and _behind), as
    the arguments of `tool_sheet`."""
    sheets = {}
    for grade in tool_grades.GRADES:
        for tool in MOTION_OF_TOOL:
            sheets[f"held_{grade}_{tool}"] = (tool, grade, False)
            sheets[f"held_{grade}_{tool}_behind"] = (tool, grade, True)
    return sheets
