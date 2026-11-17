"""Tests of the windmill's sails (sails.py, windmill.py): the turning strip loops, and the sails
stay inside their frame and hang behind the body at its hub; both arts and the game agree on the
number of frames."""

import importlib.util
import re
import unittest
from pathlib import Path

import sails
import windmill


class SailsTest(unittest.TestCase):
    def test_a_quarter_turn_on_looks_like_the_first_frame(self):
        # The four sails are alike, so the frame after the strip's last is its first again.
        self.assertEqual(sails.frame(windmill.SAILS, 90, True), sails.frame(windmill.SAILS, 0, True))

    def test_the_strip_has_its_frames_side_by_side(self):
        strip = windmill.sails()
        self.assertEqual(len(strip), windmill.SAILS.size)
        self.assertEqual(len(strip[0]), windmill.SAILS.size * windmill.SAIL_FRAMES)

    def test_the_sails_stay_inside_their_frame(self):
        picture = sails.frame(windmill.SAILS, 30, True)
        size = windmill.SAILS.size
        edges = [picture[0], picture[size - 1], [row[0] for row in picture], [row[size - 1] for row in picture]]
        self.assertTrue(all(colour is None for edge in edges for colour in edge))

    def test_furled_sails_bare_most_of_the_lattice(self):
        def cloth(picture):
            return sum(colour in sails.ROLL for row in picture for colour in row)

        spread = sails.frame(windmill.SAILS, windmill.STILL_DEGREES, True)
        self.assertLess(cloth(windmill.still_sails()) * 3, cloth(spread))

    def test_the_hub_is_behind_the_roof(self):
        body, _ = windmill.windmill(False)
        x, y = windmill.SAILS_HUB
        self.assertIsNotNone(body[y][x])

    def test_both_arts_and_the_game_have_as_many_frames(self):
        here = Path(__file__).resolve().parent
        spec = importlib.util.spec_from_file_location("classic_windmill", here / "classic" / "windmill.py")
        classic = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(classic)
        sail_turn = (here.parents[1] / "game" / "scenes" / "sail_turn.gd").read_text()
        game_frames = int(re.search(r"^const FRAMES := (\d+)$", sail_turn, re.MULTILINE).group(1))
        self.assertEqual(classic.SAIL_FRAMES, windmill.SAIL_FRAMES)
        self.assertEqual(game_frames, windmill.SAIL_FRAMES)


if __name__ == "__main__":
    unittest.main()
