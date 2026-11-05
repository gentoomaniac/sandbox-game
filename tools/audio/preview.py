"""Writes every generated sound into one WAV file to listen to, in the order of
generate.EVENTS: each variant once (a loop twice, to hear its seam), with short gaps.
It reads the files under assets/sounds/, so run `make assets` first.

    .venv/bin/python tools/audio/preview.py OUT.wav

Prints when each event starts, to find it in the file.
"""

import sys
from pathlib import Path

import numpy as np

from check import read_wav
from dsp import RATE, silence
from generate import EVENTS, SOUNDS, is_loop, wav_bytes

GAP_BETWEEN_VARIANTS = 0.35
GAP_BETWEEN_EVENTS = 1.0


def main():
    out = Path(sys.argv[1])
    parts = []
    for event, (_, variants) in EVENTS.items():
        at = sum(len(part) for part in parts) / RATE
        print(f"{int(at // 60)}:{at % 60:04.1f}  {event}")
        for number in range(1, len(variants) + 1):
            pcm, _ = read_wav(SOUNDS / f"{event}_{number}.wav")
            played = np.tile(pcm, 2) if is_loop(event) else pcm
            parts += [played, silence(GAP_BETWEEN_VARIANTS)]
        parts.append(silence(GAP_BETWEEN_EVENTS))
    out.write_bytes(wav_bytes(np.round(np.concatenate(parts) * 32767), loop=False))


if __name__ == "__main__":
    main()
