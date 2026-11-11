"""The sound of a fire on a hearth: the fire-crackle loop (see design/presentation/sound.md).

The loop is built as a circle (see generate.py), so it places its parts with loop=True. Only
the random generator it is given decides anything, so every run writes the same file.
"""

from dsp import burst, place, silence

CRACKLE_LENGTH = 8.0
# Ticks and snaps keep clear of the seam, so a loud one never stands right beside it (a jump in
# level there would be heard as the loop's join); the quiet embers cross it and wrap around.
APART_FROM_SEAM = (0.1, CRACKLE_LENGTH - 0.15)


def fire_crackle_loop(rng):
    """Only crackling, no bed of noise under it: ticks of all sizes scattered over the loop,
    sometimes two in a quick run, and now and then the snap of a log: all short, bright and
    dry, nothing low or ringing that would sound like a thump."""
    out = silence(CRACKLE_LENGTH)

    # The fine crackle of the embers, so no stretch of the loop (nor its seam) falls silent.
    for _ in range(round(500 * CRACKLE_LENGTH)):
        pitch = rng.uniform(2500, 7000)
        fleck = burst(rng, 0.004, pitch * 0.6, pitch * 1.6, 0.0003, 900)
        place(out, fleck, rng.uniform(0, CRACKLE_LENGTH), rng.uniform(0.02, 0.06), loop=True)

    for _ in range(round(14 * CRACKLE_LENGTH)):
        # Mostly small ticks; their loudness falls off steeply, like real crackle.
        gain = rng.uniform(0.08, 1.0) ** 2.5 * 0.7
        pitch = rng.uniform(1800, 5200)
        tick = burst(rng, 0.012, pitch * 0.6, pitch * 1.6, 0.0005, 450)
        start = rng.uniform(*APART_FROM_SEAM)
        place(out, tick, start, gain, loop=True)
        if rng.random() < 0.25:
            place(out, tick, start + rng.uniform(0.01, 0.05), gain * 0.5, loop=True)

    for _ in range(round(0.9 * CRACKLE_LENGTH)):
        place(out, _pop(rng), rng.uniform(*APART_FROM_SEAM), rng.uniform(0.5, 1.0), loop=True)
    return out


def _pop(rng):
    """A bigger snap: a very short broadband crack, bright and dry, with a smaller one after."""
    crack = burst(rng, 0.02, 1500, 8000, 0.0004, 220)
    after = burst(rng, 0.008, 2500, 9000, 0.0003, 500)
    out = crack.copy()
    place(out, after, rng.uniform(0.004, 0.015), 0.5)
    return out
