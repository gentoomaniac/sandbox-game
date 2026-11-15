"""Tests of the tools' swing (tool_swing.py, swing.py): every tool in every frame is a whole,
rigid picture held by its handle (the watering can by its hoop), and it stays inside its cell."""

import unittest

import character
import swing
import tool_swing
from tool_swing import FRAMES, GROUND, METAL, MOTION_OF_TOOL, SOIL, WATER, WOOD, motion_frames, oriented, tool_hand_index, tool_letters

FACINGS = ("down", "up", "right")
# The tools that swing on a handle, not the watering can.
HANDLED = [tool for tool in MOTION_OF_TOOL if tool != "watering_can"]


def frames_of(tool):
    for motion, index in motion_frames():
        if motion == MOTION_OF_TOOL[tool]:
            for facing in FACINGS:
                yield motion, index, facing


class ToolPictureTest(unittest.TestCase):
    def test_the_hand_holds_the_handle_in_every_frame(self):
        for tool in HANDLED:
            for motion, index, facing in frames_of(tool):
                letters = tool_letters(tool, motion, index, facing)
                with self.subTest(tool=tool, motion=motion, index=index, facing=facing):
                    self.assertIn(letters[(0, 0)], WOOD)
                    self.assertLessEqual(set(letters.values()), set(WOOD + METAL + "e" + SOIL))

    def test_the_hand_holds_the_can_by_its_hoop(self):
        for motion, index, facing in frames_of("watering_can"):
            letters = tool_letters("watering_can", motion, index, facing)
            with self.subTest(index=index, facing=facing):
                self.assertNotIn((0, 0), letters)
                self.assertTrue(any(letters.get((dx, dy)) == "k" for dx in (-1, 0, 1) for dy in (-1, 0, 1)))
                self.assertLessEqual(set(letters.values()), set(METAL + WATER))

    def test_the_tipped_can_pours(self):
        streams = [tool_letters("watering_can", "pour", index, "right") for index in (2, 3)]
        drops = [{at for at, letter in letters.items() if letter in WATER} for letters in streams]
        self.assertTrue(all(drops))
        self.assertNotEqual(drops[0], drops[1])

    def test_a_turned_picture_keeps_every_pixel(self):
        for tool in HANDLED:
            for points in (tool_swing.UP, tool_swing.RIGHT, tool_swing.DOWN, tool_swing.LEFT):
                with self.subTest(tool=tool, points=points):
                    self.assertEqual(len(oriented(tool, points, 0)), len(tool_swing.upright(tool).letters))
            for points in (tool_swing.UP_RIGHT, tool_swing.DOWN_RIGHT, tool_swing.DOWN_LEFT, tool_swing.UP_LEFT):
                with self.subTest(tool=tool, points=points):
                    self.assertEqual(len(oriented(tool, points, 0)), len(tool_swing.diagonal(tool).letters))

    def test_a_turned_picture_is_lit_from_the_top_left(self):
        # The horizontal axe's handle: its top row lit, its bottom row dark.
        letters = oriented("axe", tool_swing.RIGHT, 1)
        self.assertEqual(letters[(3, 0)], "l")
        self.assertEqual(letters[(3, 1)], "d")

    def test_every_tool_stays_inside_its_cell(self):
        left, top = swing.FIGURE_AT
        for tool in MOTION_OF_TOOL:
            for motion, index, facing in frames_of(tool):
                frame = tool_swing.figure_frame(motion, index, facing)
                hand_x, hand_y = frame["hands"][tool_hand_index(facing)]
                for x, y in tool_letters(tool, motion, index, facing):
                    with self.subTest(tool=tool, motion=motion, index=index, facing=facing):
                        self.assertTrue(0 <= left + hand_x + x < swing.USE_CELL)
                        self.assertTrue(0 <= top + hand_y + frame["sink"] + y < swing.USE_CELL)

    def test_every_motion_has_four_or_five_frames_in_each_facing_and_their_durations(self):
        for motion in tool_swing.MOTIONS:
            count = tool_swing.frame_count(motion)
            self.assertIn(count, (4, 5))
            self.assertEqual(len(tool_swing.DURATIONS[motion]), count)
            for facing in FACINGS:
                self.assertEqual(len(FRAMES[(motion, facing)]), count)


class DigTest(unittest.TestCase):
    def test_a_foot_drives_the_blade_into_the_ground(self):
        for facing in FACINGS:
            frames = FRAMES[("dig", facing)]
            pushed = [index for index, frame in enumerate(frames) if any(tool_swing.raised_feet(frame))]
            with self.subTest(facing=facing):
                self.assertEqual(len(pushed), 1)
                frame = frames[pushed[0]]
                hand_y = frame["hands"][tool_hand_index(facing)][1] + frame["sink"]
                lowest = max(y for (_, y), letter in tool_letters("shovel", "dig", pushed[0], facing).items() if letter in METAL + "e")
                self.assertGreater(hand_y + lowest, GROUND[facing])

    def test_the_spit_of_earth_lies_on_the_blade(self):
        for facing in FACINGS:
            letters = tool_letters("shovel", "dig", tool_swing.frame_count("dig") - 1, facing)
            soil = [(x, y) for (x, y), letter in letters.items() if letter in SOIL]
            with self.subTest(facing=facing):
                self.assertTrue(soil)
                for x, y in soil:
                    below = [letters.get((x, y + dy)) for dy in range(1, 4)]
                    self.assertTrue(any(letter in METAL + "e" + SOIL for letter in below if letter))

    def test_the_foot_on_the_blade_is_forward_and_up(self):
        standing = character.Figure("right", character.POSES["idle"]).legs[1].foot
        stepping = character.Figure("right", character.POSES["idle"] | {"step": (6, 6)}).legs[1].foot

        def pixels(part):
            return [(x, y) for y, row in enumerate(part) for x, on in enumerate(row) if on]

        self.assertGreater(min(x for x, _ in pixels(stepping)), min(x for x, _ in pixels(standing)))
        self.assertLess(max(y for _, y in pixels(stepping)), max(y for _, y in pixels(standing)))


class ToolSheetTest(unittest.TestCase):
    def test_a_tool_sheet_shows_only_its_motion(self):
        rows = swing.tool_sheet("hammer", "iron", False)
        columns = [index for index, (motion, _) in enumerate(motion_frames()) if motion == "knock"]
        for row in rows:
            for column, cell in enumerate(row):
                drawn = any(colour is not None for line in cell for colour in line)
                if column not in columns:
                    self.assertFalse(drawn)
        self.assertTrue(any(colour is not None for line in rows[3][columns[2]] for colour in line))


if __name__ == "__main__":
    unittest.main()
