"""Writes every piece of tools/music/pieces/ as a 4-channel ProTracker module (run it with `make art`).

Each pieces/<name>.txt becomes art/generated/music/<name>.mod ("M.K.", 31 samples, 64-row patterns),
which `make assets` copies to assets/music/. The same text gives the same bytes every time.

A piece is plain text; a `#` at the start of a line or after a space starts a comment:

    speed 5                  ticks per row (1..31)
    tempo 125                ticks per 2.5 seconds (32..255): with 125 a tick is 20 ms
    order loop fill          the sections in the order they play; the module restarts at the first

    section loop 128         a section: its name and length in rows, whole bars of 16 rows
    lead saw:                a voice (one channel, in the order of the lines) and its instrument
      E-2:2 A-2:2 A-2:6:452  its tokens, on as many indented lines as wanted

Every section has the same voices in the same order, four of them, and each voice's tokens fill the
section's rows exactly. A token is NOTE:ROWS or NOTE:ROWS:EFFECT:
- NOTE is a note from C-1 to B-3 (`C-2`, `F#3`), played with the voice's instrument at its default
  volume; `.` plays nothing (what sounds goes on); `^` silences the channel (effect C00).
- EFFECT is three hex digits, ProTracker's effect and parameter. The effects that act while a note
  sounds (0xy, 1xx, 2xx, 3xx, 4xy, Axy) are written on every row of the token, the others on its
  first row only. A row has one effect per channel.

The effect set, and nothing else (anything other is refused, so the renderer in game/audio/ need
only know these):
- 0xy arpeggio: the note, +x and +y semitones, changing every tick.
- 1xx / 2xx portamento up / down: the period goes down / up by xx every tick but the first.
- 3xx tone portamento: slides from the sounding note to the token's note (which is not struck) by
  xx a tick.
- 4xy vibrato: speed x, depth y (both from 1).
- Axy volume slide: up by x or down by y a tick (one of them 0).
- Cxx set volume, 00 to 40 (hex).
- ECx note cut after x ticks (1..F).
- Fxx set speed (01..1F) / tempo (20..FF), and Dxx pattern break: the generator writes these, a
  piece doesn't. Each section starts with the piece's speed and tempo (on its first row, in the
  first channels free there), so it plays the same wherever it is entered; a section that ends
  inside a pattern ends with D00 there.

A section played from its start sounds the same whatever played before it. So ProTracker's effect
memory (300, 400 using the last parameter) is not allowed, and every voice starts a section with
a note it strikes or with `^`; until it strikes its first note it may only rest (`.` with no
effect) or cut, and a tone portamento can't be its first note (it would slide from what played
before).

The instruments are short waveforms made here, looped (single-cycle) or one-shot:
- saw: a sawtooth of 32 samples, the sharp lead; with 32 samples C-2 sounds about as C4.
- pulse: a 25 % pulse of 32 samples, for chords played as arpeggios.
- triangle: a triangle of 64 samples, the soft bass (an octave below the others at the same note).
- noise: 2048 samples of decaying noise, one-shot: low notes thud, high notes hiss.
Each waveform starts at zero, so a note starts without a jump.
"""

import re
import struct
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
PIECES = Path(__file__).resolve().parent / "pieces"
MUSIC = ROOT / "art" / "generated" / "music"

CHANNELS = 4
PATTERN_ROWS = 64
BAR_ROWS = 16
SAMPLE_SLOTS = 31
# ProTracker's periods from C-1 to B-3 (finetune 0).
PERIODS = [
    856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453,
    428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226,
    214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113,
]  # fmt: skip
NOTE_NAMES = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"]
HOLD = "."
CUT = "^"
# The effects that act while a note sounds, written on every row of their token.
HELD_EFFECTS = "01234A"
STATED_EFFECTS = "0xy arpeggio, 1xx/2xx portamento, 3xx tone portamento, 4xy vibrato, Axy volume slide, Cxx volume, ECx note cut"


def waveform(name):
    """An instrument's 8-bit samples (-128..127), whether they loop and its default volume (0..64)."""
    if name == "saw":
        return [(index + 16) % 32 * 8 - 128 for index in range(32)], True, 40
    if name == "pulse":
        return [0] + [96] * 8 + [-32] * 23, True, 28
    if name == "triangle":
        return [round(127 * (1 - abs((index / 16 + 1) % 4 - 2))) for index in range(64)], True, 64
    if name == "noise":
        rng = np.random.default_rng(169)
        decay = np.exp(-np.arange(2048) / 400)
        # The first two samples stay 0: ProTracker loops them after a one-shot ends.
        return [0, 0] + [int(value) for value in np.round(rng.uniform(-127, 127, 2046) * decay[2:])], False, 48
    raise ValueError(f"unknown instrument {name!r} (saw, pulse, triangle or noise)")


INSTRUMENTS = ["saw", "pulse", "triangle", "noise"]


class PieceError(ValueError):
    pass


def note_index(name):
    match = re.fullmatch(r"([A-G][-#])([1-3])", name)
    if not match or match.group(1) not in NOTE_NAMES:
        raise PieceError(f"{name!r} is no note from C-1 to B-3")
    return NOTE_NAMES.index(match.group(1)) + 12 * (int(match.group(2)) - 1)


def checked_effect(text, has_note):
    """The effect of a token as (command, parameter), refused unless it is in the stated set."""
    if not re.fullmatch(r"[0-9A-F]{3}", text):
        raise PieceError(f"effect {text!r} is not three hex digits")
    command, parameter = int(text[0], 16), int(text[1:], 16)
    x, y = parameter >> 4, parameter & 15
    allowed = {
        0x0: parameter > 0,
        0x1: parameter > 0,
        0x2: parameter > 0,
        0x3: parameter > 0 and has_note,
        0x4: x > 0 and y > 0,
        0xA: (x == 0) != (y == 0),
        0xC: parameter <= 64,
        0xE: x == 0xC and y > 0,
    }
    if not allowed.get(command, False):
        raise PieceError(f"effect {text} is not in the effect set ({STATED_EFFECTS}; no effect memory)")
    return command, parameter


def parse_piece(text):
    """The piece as {"speed", "tempo", "order", "sections"}; a section is {"rows", "voices"}, a voice
    (name, instrument, tokens) and a token (note: index, HOLD or CUT; rows; effect or None)."""
    piece = {"speed": 6, "tempo": 125, "order": [], "sections": {}}
    voice = None
    for number, line in enumerate(text.splitlines(), start=1):
        content = re.sub(r"(^|\s)#.*", "", line).rstrip()
        if not content:
            continue
        try:
            words = content.split()
            if content[0].isspace():
                if voice is None:
                    raise PieceError("tokens outside a voice")
                voice[2].extend(parse_token(word) for word in words)
            elif words[0] == "speed" and len(words) == 2 and 1 <= int(words[1]) <= 31:
                piece["speed"] = int(words[1])
            elif words[0] == "tempo" and len(words) == 2 and 32 <= int(words[1]) <= 255:
                piece["tempo"] = int(words[1])
            elif words[0] == "order":
                piece["order"] = words[1:]
            elif words[0] == "section" and len(words) == 3:
                section = {"rows": int(words[2]), "voices": []}
                piece["sections"][words[1]] = section
                voice = None
            elif len(words) == 2 and words[1].endswith(":") and piece["sections"]:
                instrument = words[1][:-1]
                if instrument not in INSTRUMENTS:
                    raise PieceError(f"unknown instrument {instrument!r} ({', '.join(INSTRUMENTS)})")
                voice = (words[0], instrument, [])
                section["voices"].append(voice)
            else:
                raise PieceError(f"cannot read {content.strip()!r}")
        except ValueError as error:
            raise PieceError(f"line {number}: {error}") from error
    check_piece(piece)
    return piece


def parse_token(word):
    parts = word.split(":")
    if len(parts) not in (2, 3) or not parts[1].isdigit() or int(parts[1]) < 1:
        raise PieceError(f"token {word!r} is not NOTE:ROWS or NOTE:ROWS:EFFECT")
    note = parts[0] if parts[0] in (HOLD, CUT) else note_index(parts[0])
    if note == CUT and len(parts) == 3:
        raise PieceError(f"token {word!r}: a cut (^) is the effect C00 and takes no other")
    effect = checked_effect(parts[2], note not in (HOLD, CUT)) if len(parts) == 3 else None
    return note, int(parts[1]), effect


def check_piece(piece):
    if not piece["order"] or any(name not in piece["sections"] for name in piece["order"]):
        raise PieceError(f"the order {piece['order']} must name sections ({', '.join(piece['sections'])})")
    voices = None
    for name, section in piece["sections"].items():
        if section["rows"] < BAR_ROWS or section["rows"] % BAR_ROWS:
            raise PieceError(f"section {name}: {section['rows']} rows are no whole bars of {BAR_ROWS}")
        signature = [(voice, instrument) for voice, instrument, _ in section["voices"]]
        if len(signature) != CHANNELS or signature != (voices or signature):
            raise PieceError(f"section {name}: voices {signature}, but every section has the same {CHANNELS}")
        voices = signature
        for voice, _, tokens in section["voices"]:
            rows = sum(token[1] for token in tokens)
            if rows != section["rows"]:
                raise PieceError(f"section {name}, voice {voice}: {rows} rows of tokens, the section has {section['rows']}")
            check_entry(f"section {name}, voice {voice}", tokens)


def check_entry(where, tokens):
    """Refuses a voice whose start depends on what played before its section (see the docstring)."""
    if tokens[0][0] == HOLD:
        raise PieceError(f"{where} starts with `.`: it must strike a note or cut (^)")
    for note, _, effect in tokens:
        if note not in (HOLD, CUT):
            if effect and effect[0] == 0x3:
                raise PieceError(f"{where}: its first note slides (3xx) from what played before")
            return
        if note == HOLD and effect:
            raise PieceError(f"{where}: an effect before its first note acts on what played before")


def section_rows(piece, section):
    """The section's rows: per row, per channel a cell [period or 0, sample number or 0, command, parameter]."""
    rows = [[[0, 0, 0, 0] for _ in range(CHANNELS)] for _ in range(section["rows"])]
    for channel, (_, instrument, tokens) in enumerate(section["voices"]):
        row = 0
        for note, length, effect in tokens:
            cell = rows[row][channel]
            if note == CUT:
                cell[2:] = [0xC, 0]
            elif note != HOLD:
                cell[:2] = [PERIODS[note], INSTRUMENTS.index(instrument) + 1]
            if effect:
                held_rows = length if f"{effect[0]:X}" in HELD_EFFECTS else 1
                for held in range(row, row + held_rows):
                    rows[held][channel][2:] = list(effect)
            row += length
    put_in_free_channel(rows[0], [(0xF, piece["speed"]), (0xF, piece["tempo"])], "the first row")
    if section["rows"] % PATTERN_ROWS:
        put_in_free_channel(rows[-1], [(0xD, 0)], "the last row")
    return rows


def put_in_free_channel(row, effects, where):
    """Writes the effects into the channels of a row that have none."""
    free = [cell for cell in row if cell[2:] == [0, 0]]
    if len(free) < len(effects):
        raise PieceError(f"{where} of a section needs {len(effects)} channels without an effect, it has {len(free)}")
    for cell, effect in zip(free, effects):
        cell[2:] = list(effect)


def module_bytes(title, piece):
    """The piece as a ProTracker module: header, sample headers, order list, "M.K.", patterns, samples."""
    patterns, pattern_of_section = [], {}
    for name in dict.fromkeys(piece["order"]):
        rows = section_rows(piece, piece["sections"][name])
        pattern_of_section[name] = list(range(len(patterns), len(patterns) + -(-len(rows) // PATTERN_ROWS)))
        for start in range(0, len(rows), PATTERN_ROWS):
            pattern = rows[start : start + PATTERN_ROWS]
            patterns.append(pattern + [[[0, 0, 0, 0]] * CHANNELS] * (PATTERN_ROWS - len(pattern)))
    order = [pattern for name in piece["order"] for pattern in pattern_of_section[name]]
    if len(order) > 128:
        raise PieceError(f"the order is {len(order)} patterns long, a module holds 128")

    data = title.encode("ascii")[:20].ljust(20, b"\0")
    waveforms = [waveform(name) for name in INSTRUMENTS]
    for name, (samples, loops, volume) in zip(INSTRUMENTS, waveforms):
        words = len(samples) // 2
        loop_start, loop_words = (0, words) if loops else (0, 1)
        data += struct.pack(">22sHBBHH", name.encode(), words, 0, volume, loop_start, loop_words)
    data += struct.pack(">22sHBBHH", b"", 0, 0, 0, 0, 1) * (SAMPLE_SLOTS - len(INSTRUMENTS))
    data += struct.pack(">BB", len(order), 0) + bytes(order).ljust(128, b"\0") + b"M.K."
    for pattern in patterns:
        for row in pattern:
            for period, sample, command, parameter in row:
                data += struct.pack(">HBB", (sample & 0xF0) << 8 | period, (sample & 0x0F) << 4 | command, parameter)
    for samples, _, _ in waveforms:
        data += np.array(samples, dtype=np.int8).tobytes()
    return data


def main():
    MUSIC.mkdir(parents=True, exist_ok=True)
    for path in sorted(PIECES.glob("*.txt")):
        try:
            piece = parse_piece(path.read_text())
        except PieceError as error:
            sys.exit(f"{path.relative_to(ROOT)}: {error}")
        (MUSIC / f"{path.stem}.mod").write_bytes(module_bytes(path.stem.replace("_", " "), piece))


if __name__ == "__main__":
    main()
