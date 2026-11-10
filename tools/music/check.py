"""Checks every module under art/generated/music/ with an independent player (run by `make art`,
after generate.py): libmodplug (see modplug.py) must load it as 4 channels with its patterns, and
play it row by row as its piece says: every row of every section in the order, each for `speed`
ticks (see `tick_frames`), the short sections broken off after their last row, and then stop.
Where libmodplug is not installed it says so and checks nothing.
"""

import sys

import modplug
from generate import MUSIC, PATTERN_ROWS, PIECES, parse_piece

RATE = 44100


def tick_frames(tempo):
    """The samples of a tick at RATE: 2.5 / tempo seconds, cut to a whole number, as libmodplug plays
    it. At tempo 125 it is exact."""
    return RATE * 5 // (2 * tempo)


def expected_rows(piece):
    """The (order, row) of every row the piece plays, in order."""
    rows, order = [], 0
    for name in piece["order"]:
        section_rows = piece["sections"][name]["rows"]
        for start in range(0, section_rows, PATTERN_ROWS):
            rows += [(order, row) for row in range(min(PATTERN_ROWS, section_rows - start))]
            order += 1
    return rows


def problems(module, piece):
    _, positions, info = modplug.play(module, RATE, tick_frames(piece["tempo"]))
    patterns = sum(-(-piece["sections"][name]["rows"] // PATTERN_ROWS) for name in set(piece["order"]))
    found = []
    if info["channels"] != 4:
        found.append(f"{info['channels']} channels, not 4")
    if info["patterns"] != patterns:
        found.append(f"{info['patterns']} patterns, the piece has {patterns}")
    # ModPlug reports the position after each tick: the row each tick belongs to.
    played = positions[:: piece["speed"]]
    rows = expected_rows(piece)
    if played[: len(rows)] != rows:
        first = next(i for i, (a, b) in enumerate(zip(played, rows + [None] * len(played))) if a != b)
        found.append(f"row {first} played as {played[first]}, the piece has {rows[first] if first < len(rows) else 'ended'}")
    if len(positions) > (len(rows) + 2) * piece["speed"]:
        found.append(f"plays {len(positions) / piece['speed']:.0f} rows, the piece has {len(rows)}")
    return found


def main():
    if modplug.LIBRARY is None:
        print("tools/music/check.py: skipped, libmodplug is not installed (Gentoo: media-libs/libmodplug)")
        return
    failed = False
    for path in sorted(PIECES.glob("*.txt")):
        module = (MUSIC / f"{path.stem}.mod").read_bytes()
        for problem in problems(module, parse_piece(path.read_text())):
            print(f"{path.stem}.mod: {problem}")
            failed = True
    if failed:
        sys.exit("tools/music/check.py: a module does not play as its piece says")


if __name__ == "__main__":
    main()
