"""Tests of generate.py and check.py (`make test` runs them): the text of a piece, what is refused,
and the bytes of the module."""

import contextlib
import io
import struct
import unittest

import numpy as np

import check
import modplug
from generate import PieceError, module_bytes, parse_piece, sections_text

BAR = "C-2:16"
PIECE = f"""
speed 5
tempo 125
order loop fill
section loop 64
lead saw:
  {BAR} {BAR} {BAR} {BAR}
chords pulse:
  A-2:64:037
bass triangle:
  A-1:32 ^:32
drums noise:
  C-1:2:EC4 .:62
section fill 16
lead saw:
  {BAR}
chords pulse:
  ^:16
bass triangle:
  A-1:16
drums noise:
  G-2:16
"""
HEADER = 20 + 31 * 30
ORDER_LENGTH = HEADER
ORDERS = HEADER + 2
PATTERNS = HEADER + 2 + 128 + 4
ROW = 4 * 4


def cell(module, pattern, row, channel):
    """(period, sample, command, parameter) of a cell."""
    start = PATTERNS + pattern * 64 * ROW + row * ROW + channel * 4
    word, low, parameter = struct.unpack_from(">HBB", module, start)
    return word & 0x0FFF, (word >> 8 & 0xF0) | low >> 4, low & 0x0F, parameter


def with_token(token):
    return PIECE.replace("A-2:64:037", f"A-2:4 {token} .:{60 - int(token.split(':')[1])}")


class PieceTest(unittest.TestCase):
    def test_writes_the_header_order_and_samples(self):
        module = module_bytes("test", parse_piece(PIECE))
        self.assertEqual(module[:4], b"test")
        self.assertEqual(module[PATTERNS - 4 : PATTERNS], b"M.K.")
        self.assertEqual(module[ORDER_LENGTH], 2)
        self.assertEqual(list(module[ORDERS : ORDERS + 3]), [0, 1, 0])
        name, words, _, volume, loop_start, loop_words = struct.unpack_from(">22sHBBHH", module, 20)
        self.assertEqual((name.rstrip(b"\0"), words, volume, loop_start, loop_words), (b"saw", 16, 40, 0, 16))
        noise = struct.unpack_from(">22sHBBHH", module, 20 + 3 * 30)
        self.assertEqual((noise[1], noise[4], noise[5]), (1024, 0, 1), "the noise is one-shot")
        self.assertEqual(len(module), PATTERNS + 2 * 64 * ROW + 32 + 32 + 64 + 2048)

    def test_writes_notes_held_effects_and_cuts(self):
        module = module_bytes("test", parse_piece(PIECE))
        self.assertEqual(cell(module, 0, 0, 1), (254, 2, 0x0, 0x37))
        self.assertEqual(cell(module, 0, 5, 1), (0, 0, 0x0, 0x37), "an arpeggio is held on every row")
        self.assertEqual(cell(module, 0, 32, 2), (0, 0, 0xC, 0), "^ is C00")
        self.assertEqual(cell(module, 0, 1, 3), (0, 0, 0, 0), "a note cut is on the first row only")
        self.assertEqual(cell(module, 0, 16, 0), (428, 1, 0, 0))

    def test_every_section_starts_with_speed_and_tempo_and_a_short_one_breaks(self):
        module = module_bytes("test", parse_piece(PIECE))
        self.assertEqual(cell(module, 0, 0, 0)[2:], (0xF, 5))
        self.assertEqual(cell(module, 0, 0, 1)[2:], (0x0, 0x37), "a channel with an effect keeps it")
        self.assertEqual(cell(module, 0, 0, 2)[2:], (0xF, 125))
        self.assertEqual(cell(module, 0, 0, 3)[2:], (0xE, 0xC4))
        self.assertEqual(cell(module, 1, 0, 0)[2:], (0xF, 5))
        self.assertEqual(cell(module, 1, 0, 2)[2:], (0xF, 125))
        self.assertEqual(cell(module, 1, 15, 0)[2:], (0xD, 0))
        self.assertEqual(cell(module, 1, 16, 0), (0, 0, 0, 0))

    def test_refuses_a_first_row_without_room_for_speed_and_tempo(self):
        crowded = PIECE.replace(f"lead saw:\n  {BAR} {BAR}", f"lead saw:\n  C-2:16:C20 {BAR}", 1)
        with self.assertRaisesRegex(PieceError, "needs 2 channels without an effect"):
            module_bytes("test", parse_piece(crowded))

    def test_is_the_same_every_time(self):
        self.assertEqual(module_bytes("test", parse_piece(PIECE)), module_bytes("test", parse_piece(PIECE)))

    def test_refuses_effects_outside_the_set_and_effect_memory(self):
        for effect in ["B00", "900", "500", "E10", "F06", "D00", "300", "440", "404", "A11", "C41", "EC0"]:
            with self.subTest(effect=effect), self.assertRaisesRegex(PieceError, "not in the effect set"):
                parse_piece(with_token(f"A-2:4:{effect}"))
        for effect in ["037", "101", "201", "308", "452", "A02", "C40", "EC3"]:
            with self.subTest(effect=effect):
                parse_piece(with_token(f"A-2:4:{effect}"))

    def test_refuses_a_slide_to_no_note(self):
        with self.assertRaisesRegex(PieceError, "not in the effect set"):
            parse_piece(with_token(".:4:308"))

    def test_refuses_what_does_not_fill_the_rows_or_names_no_note(self):
        cases = {
            "C-2:15": "15 rows of tokens",
            "H-2:16": "no note",
            "C-4:16": "no note",
            "C-2:0": "not NOTE:ROWS",
            "^:16:C20": "takes no other",
        }
        for token, message in cases.items():
            with self.subTest(token=token), self.assertRaisesRegex(PieceError, message):
                parse_piece(PIECE.replace(f"lead saw:\n  {BAR}\n", f"lead saw:\n  {token}\n"))

    def test_refuses_a_voice_whose_start_depends_on_what_played_before(self):
        cases = {
            ".:2 C-2:14": "starts with `.`",
            "C-2:16:308": "first note slides",
            "^:2 .:2:A04 C-2:12": "effect before its first note",
        }
        for tokens, message in cases.items():
            with self.subTest(tokens=tokens), self.assertRaisesRegex(PieceError, message):
                parse_piece(PIECE.replace(f"lead saw:\n  {BAR}\n", f"lead saw:\n  {tokens}\n"))
        parse_piece(PIECE.replace(f"lead saw:\n  {BAR}\n", "lead saw:\n  ^:2 .:2 C-2:4 .:4:A02 E-2:4:308\n"))

    def test_refuses_other_voices_or_sections(self):
        with self.assertRaisesRegex(PieceError, "every section has the same"):
            parse_piece(PIECE.replace("bass triangle:\n  A-1:16", "bass saw:\n  A-1:16"))
        with self.assertRaisesRegex(PieceError, "whole bars"):
            parse_piece(PIECE.replace("section fill 16", "section fill 8"))
        with self.assertRaisesRegex(PieceError, "must name sections"):
            parse_piece(PIECE.replace("order loop fill", "order loop bridge"))
        with self.assertRaisesRegex(PieceError, "unknown instrument"):
            parse_piece(PIECE.replace("drums noise:", "drums kazoo:"))


class SectionsTest(unittest.TestCase):
    def test_tells_the_piece_and_where_each_section_is(self):
        self.assertEqual(
            sections_text("piece_a", parse_piece(PIECE)),
            "; Written by tools/music/generate.py from pieces/piece_a.txt; read by game/audio/music_piece.gd.\n"
            "[piece]\nspeed=5\ntempo=125\nbeat_rows=4\nbar_beats=4\n"
            '\n[loop]\norder=0\nrows=64\nexits=["fill"]\n'
            '\n[fill]\norder=1\nrows=16\nexits=["loop"]\n',
        )

    def test_the_meter_and_exits_are_the_pieces(self):
        piece = parse_piece(
            PIECE.replace("order loop fill", "beat 8\nbar 2\norder loop fill").replace(
                "section loop 64", "section loop 64 exits loop fill"
            )
        )
        self.assertEqual((piece["beat_rows"], piece["bar_beats"]), (8, 2))
        text = sections_text("x", piece)
        self.assertIn("beat_rows=8\nbar_beats=2", text)
        self.assertIn('[loop]\norder=0\nrows=64\nexits=["loop", "fill"]', text)

    def test_a_section_is_whole_bars_of_the_pieces_meter(self):
        with self.assertRaisesRegex(PieceError, "no whole bars of 12"):
            parse_piece(PIECE.replace("order loop fill", "beat 6\nbar 2\norder loop fill"))

    def test_a_later_section_comes_after_the_patterns_of_the_earlier_ones(self):
        piece = parse_piece(PIECE.replace("order loop fill", "order fill loop"))
        self.assertIn("[fill]\norder=0", sections_text("x", piece))
        self.assertIn("[loop]\norder=1", sections_text("x", piece))

    def test_refuses_exits_that_are_no_sections_of_the_order(self):
        with self.assertRaisesRegex(PieceError, "exits"):
            parse_piece(PIECE.replace("section fill 16", "section fill 16 exits bridge"))
        with self.assertRaisesRegex(PieceError, "called piece"):
            parse_piece(PIECE.replace("section fill 16", "section piece 16").replace("order loop fill", "order loop piece"))


@unittest.skipIf(modplug.LIBRARY is None, "libmodplug is not installed")
class CheckTest(unittest.TestCase):
    def test_finds_nothing_wrong_with_a_module_as_its_piece_says(self):
        piece = parse_piece(PIECE)
        self.assertEqual(check.problems(module_bytes("test", piece), piece), [])

    def test_finds_rows_played_at_another_speed(self):
        piece = parse_piece(PIECE)
        module = module_bytes("test", piece)
        piece["speed"] = 6
        self.assertTrue(check.problems(module, piece))

    def test_counts_ticks_cut_to_whole_samples_as_libmodplug_plays_them(self):
        # 44100 * 2.5 / 127 is 868.1 samples: libmodplug plays 868.
        piece = parse_piece(PIECE.replace("tempo 125", "tempo 127"))
        self.assertEqual(check.tick_frames(127), 868)
        self.assertEqual(check.problems(module_bytes("test", piece), piece), [])

    def test_a_render_like_libmodplugs_passes_and_silence_does_not(self):
        piece = parse_piece(PIECE)
        module = module_bytes("test", piece)
        rows = len(check.expected_rows(piece))
        length = rows * piece["speed"] * check.tick_frames(piece["tempo"])
        reference = modplug.play(module, check.RATE, 882)[0][:length]
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(check.render_problems(module, piece, reference), [])
            found = check.render_problems(module, piece, np.zeros(length))
        self.assertTrue(any("loudness" in problem for problem in found), found)
        self.assertTrue(any("unlike" in problem for problem in found), found)

    def test_a_render_too_short_to_compare_is_said_so(self):
        piece = parse_piece(PIECE)
        module = module_bytes("test", piece)
        with contextlib.redirect_stdout(io.StringIO()):
            found = check.render_problems(module, piece, np.zeros(1000))
        self.assertTrue(any("too short to compare" in problem for problem in found), found)

    def test_finds_a_section_played_longer_than_it_is(self):
        piece = parse_piece(PIECE)
        piece["sections"]["fill"]["rows"] = 64
        self.assertTrue(check.problems(module_bytes("test", piece), parse_piece(PIECE)))



if __name__ == "__main__":
    unittest.main()
