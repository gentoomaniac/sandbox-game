"""The swing of the tools at 32 px per tile (assets/character/use/<name>.png, task 227; the
motions, frames and tool pictures are in tool_swing.py).

One sheet per layer, in the layout of the standing sheets (character.py): a row per facing
(down, up, left, right; left is the mirror image of right) and a column per frame, the four or
five of each motion one after the other (tool_swing.MOTIONS, `motion_frames`). The cells are
larger than the figure's (USE_CELL), with the figure's 32x64 frame at FIGURE_AT, so that a tool
swung up, back or forward stays in its cell.

Every layer of the figure is drawn in each frame with the frame's arms (`Figure` with the pose's
`hands`); the legs stand as when idle but where the frame lifts a foot or steps onto the spade. A
tool's sheet (`held_<grade>_<tool>.png`) is drawn in its motion's columns only, the others empty,
so that the game shows every layer at the same frame. A tool is in front of the figure
(`held_...`) or behind it (`held_..._behind.png`, which the game draws under the body); in front
of it, the near arms still cover its handle where the hands hold it, and a foot on the spade's
blade covers the blade.
"""

import character
import forms
import tool_grades
from canvas import blank
from character import CHARACTER_HEIGHT, CHARACTER_WIDTH, Figure, hand, mask, outlined, pixels_of, sleeve
from tool_swing import GROUND, MOTION_OF_TOOL, SOIL, figure_frame, motion_frames, raised_feet, tool_hand_index, tool_letters

USE_CELL = 96
# Where the figure's 32x64 frame is in a cell: room above it for a tool raised over the head, and
# on both sides and below for one swung back, forward or down at the ground before the feet.
FIGURE_AT = (32, 16)
# The colours of what is not the tool in a tool's picture: earth on the spade.
EXTRAS = {"o": "soil_mid", "O": "soil_light"}


def pose_of(motion_frame):
    """The pose `Figure` takes in a frame: the idle stance, the hands and feet where the frame
    has them."""
    centred = tuple(None if at is None else (at[0] + 0.5, at[1] + 0.5) for at in motion_frame["hands"])
    return character.POSES["idle"] | {key: motion_frame[key] for key in ("sink", "hidden", "lift", "step")} | {"hands": centred}


def placed(canvas):
    """The 32x64 figure frame in its place in a use cell."""
    cell = blank(USE_CELL)
    left, top = FIGURE_AT
    for y, row in enumerate(canvas):
        for x, colour in enumerate(row):
            if colour is not None:
                cell[top + y][left + x] = colour
    return cell


def cleared(cell, part):
    """Clears the pixels of a 32x64 mask, in its place in a use cell."""
    left, top = FIGURE_AT
    for y in range(CHARACTER_HEIGHT):
        for x in range(CHARACTER_WIDTH):
            if part[y][x]:
                cell[top + y][left + x] = None
    return cell


# The layers with sleeves: a far arm raised past the head is behind it, so their far sleeve is
# left out there (the body draws the head over its own arm).
SLEEVED = (character.draw_shirt, character.draw_waistcoat, character.draw_jacket)


def head_and_neck(figure):
    radius = 7.3 if figure.is_side else 7.6
    head = mask(forms.ellipse, figure.head[0], figure.head[1], radius, 7.8)
    neck = mask(forms.box, 14, 22 + figure.top, 17, character.SHOULDERS + figure.top)
    return [[a or b for a, b in zip(row, neck_row)] for row, neck_row in zip(head, neck)]


def layer_frame(draw, variant_colours, facing, pose):
    """One layer in one frame, placed in its cell; the far sleeves behind the head."""
    canvas = placed(character.worn(draw, facing, pose, variant_colours))
    if draw in SLEEVED:
        figure = Figure(facing, pose)
        head = head_and_neck(figure)
        for arm in figure.arms:
            if arm.far and arm.posed:
                part = sleeve(arm)
                cleared(canvas, [[a and b for a, b in zip(row, head_row)] for row, head_row in zip(part, head)])
    return canvas


def layer_sheet(draw, variant_colours):
    """One layer of the figure in every frame of every motion, with its outline."""
    rows = []
    for facing in character.PLAYER_FACINGS:
        drawn = "right" if facing == "left" else facing
        row = []
        for motion, index in motion_frames():
            pose = pose_of(figure_frame(motion, index, facing))
            body = pixels_of(placed(character.draw_body(drawn, pose)))
            canvas = layer_frame(draw, variant_colours, drawn, pose)
            canvas = outlined(canvas, set() if draw is character.draw_body else body)
            row.append(character.mirrored(canvas) if facing == "left" else canvas)
        rows.append(row)
    return rows


def tool_frame(tool, grade, motion, index, facing, behind):
    """The tool's layer in one frame, in front of the figure or behind it (empty if the tool is
    not there in that frame). A spade's blade is cut off where it goes into the ground."""
    motion_frame = figure_frame(motion, index, facing)
    cell = blank(USE_CELL)
    if motion_frame["behind"] != behind:
        return cell
    colours = tool_grades.keys(grade) | EXTRAS
    left, top = FIGURE_AT
    hand_x, hand_y = motion_frame["hands"][tool_hand_index(facing)]
    hand_y += motion_frame["sink"]
    for (x, y), letter in tool_letters(tool, motion, index, facing).items():
        if tool == "shovel" and letter not in SOIL and hand_y + y > GROUND[facing]:
            continue
        cell[top + hand_y + y][left + hand_x + x] = colours[letter]
    if not behind:
        # The near hands hold the handle: their sleeves and hands are in front of it; so is a
        # foot put up on the spade's blade.
        figure = Figure(facing, pose_of(motion_frame))
        for arm in figure.arms:
            if not arm.far:
                cleared(cell, sleeve(arm))
                cleared(cell, hand(arm))
        for leg, raised in zip(figure.legs, raised_feet(motion_frame)):
            if raised:
                cleared(cell, leg.shin)
                cleared(cell, leg.foot)
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
