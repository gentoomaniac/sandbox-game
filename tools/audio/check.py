"""Checks every sound under assets/sounds/ (run by `make assets`, after generate.py).

Each file must be 16-bit mono at the generator's rate, keep its peak below -1 dBFS (no
clipping) and carry no DC offset. A one-shot sound must start and end at silence, so it
doesn't click. A loop must carry its loop in a "smpl" chunk and wrap around without a seam:
the wave bends no more from its last sample into its first than it usually does between
samples, and its level just before the seam matches the level just after it.

With --table it also prints the length, peak and RMS level of every file.
"""

import struct
import sys

import numpy as np

from dsp import RATE, samples
from generate import SOUNDS, is_loop

MAX_PEAK_DB = -1.0
MAX_DC = 0.001
# A one-shot's first and last samples, in 16-bit steps.
MAX_EDGE = 2
# A loop's seam may be as sharp as this percentile of the file's sample-to-sample bends.
SEAM_PERCENTILE = 99
# Both sides of a loop's seam are compared over this long, and may differ by this much.
SEAM_WINDOW = 0.05
MAX_SEAM_LEVEL_DB = 3.0


def read_wav(path):
    """The samples (-1..1) of a 16-bit mono WAV file, and its loop (start, end) or None."""
    raw = path.read_bytes()
    assert raw[:4] == b"RIFF" and raw[8:12] == b"WAVE", "not a WAV file"
    position, chunks = 12, {}
    while position < len(raw):
        name, size = struct.unpack_from("<4sI", raw, position)
        chunks[name] = raw[position + 8 : position + 8 + size]
        position += 8 + size + size % 2
    _, channels, rate, _, _, bits = struct.unpack_from("<HHIIHH", chunks[b"fmt "])
    assert (channels, rate, bits) == (1, RATE, 16), f"{channels} channels, {rate} Hz, {bits} bit"
    pcm = np.frombuffer(chunks[b"data"], "<i2").astype(float) / 32767
    loop = None
    if b"smpl" in chunks:
        loop = struct.unpack_from("<2I", chunks[b"smpl"], 36 + 8)
    return pcm, loop


def decibels(value):
    return 20 * np.log10(max(value, 1e-9))


def problems(event, pcm, loop):
    found = []
    peak = np.abs(pcm).max()
    if decibels(peak) > MAX_PEAK_DB:
        found.append(f"peak {decibels(peak):.1f} dBFS")
    if abs(pcm.mean()) > MAX_DC:
        found.append(f"DC offset {pcm.mean():.4f}")
    if not is_loop(event):
        if loop:
            found.append("a loop chunk on a one-shot sound")
        edges = np.abs(pcm[[0, -1]]) * 32767
        if edges.max() > MAX_EDGE:
            found.append(f"starts or ends off silence ({edges[0]:.0f}, {edges[1]:.0f})")
        return found
    if loop != (0, len(pcm) - 1):
        found.append(f"loop {loop} instead of the whole file")
    # A click is a kink in the wave: a big second difference. Played as a loop, the
    # samples on both sides of the seam must be no kinkier than the file usually is.
    kinks = np.abs(np.roll(pcm, -1) - 2 * pcm + np.roll(pcm, 1))
    usual = np.percentile(kinks, SEAM_PERCENTILE)
    if max(kinks[0], kinks[-1]) > usual:
        found.append(f"seam kinks by {max(kinks[0], kinks[-1]):.4f}, usually up to {usual:.4f}")
    window = samples(SEAM_WINDOW)
    before = np.sqrt(np.mean(pcm[-window:] ** 2))
    after = np.sqrt(np.mean(pcm[:window] ** 2))
    if abs(decibels(before) - decibels(after)) > MAX_SEAM_LEVEL_DB:
        levels = f"level {decibels(before):.1f} dB before the seam, {decibels(after):.1f} after it"
        found.append(levels)
    return found


def main():
    table = "--table" in sys.argv
    paths = sorted(SOUNDS.glob("*.wav"))
    failed = 0
    if table:
        print(f"{'file':28} {'length':>7} {'peak':>6} {'RMS':>6}")
    for path in paths:
        event = path.stem.rsplit("_", 1)[0]
        pcm, loop = read_wav(path)
        if table:
            peak = decibels(np.abs(pcm).max())
            rms = decibels(np.sqrt(np.mean(pcm**2)))
            line = f"{path.name:28} {len(pcm) / RATE:6.2f}s {peak:6.1f} {rms:6.1f}"
            print(line + ("  loop" if loop else ""))
        for problem in problems(event, pcm, loop):
            print(f"{path.name}: {problem}")
            failed += 1
    if failed:
        sys.exit(f"Sound check failed: {failed} problems in {len(paths)} files.")
    print(f"Sound check passed: {len(paths)} files in {SOUNDS.relative_to(SOUNDS.parents[1])}/.")


if __name__ == "__main__":
    main()
