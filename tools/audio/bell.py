"""The bronze bell of the bell frame: one strike with a long decay (see design/presentation/sound.md).

A cast bell does not ring one note but a family of partials that are not whole multiples of each
other: the hum an octave below the strike note, the strike note (the prime), the minor third on
top of it that gives a church bell its sombre colour, the fifth, the octave (the nominal) and a
few more above. The low ones sing for many seconds, the high ones die away quickly, so the
sound turns from a bright clang into a dark hum. Every partial of a real bell is two nearly
equal pitches (the bell is never quite round), which beat slowly: the shimmer.
"""

import numpy as np

from dsp import burst, envelope, fade_out, highpass, lowpass, place, ring, silence, times

BELL_LENGTH = 11.0
# A village bell's strike note, about G4, a little different for each variant.
PRIME = 392.0
# Each partial: its pitch over the prime, its loudness and how fast it dies away (1/s).
PARTIALS = (
    (0.5, 0.55, 0.3),  # the hum
    (1.0, 1.0, 0.4),  # the prime
    (1.2, 0.7, 0.5),  # the minor third
    (1.5, 0.45, 0.6),  # the fifth
    (2.0, 0.6, 0.75),  # the nominal
    (2.5, 0.25, 1.1),
    (3.0, 0.22, 1.5),
    (4.1, 0.14, 2.2),
    (5.2, 0.08, 3.2),
)
# How far apart, at most, the two pitches of a partial are (Hz): the slow beating.
BEAT = 1.6


def _bell(rng, base_prime, length):
    """The strike of a bell with this strike note (Hz), `length` seconds long."""
    t = times(length)
    prime = base_prime * rng.uniform(0.97, 1.03)
    out = silence(length)
    for ratio, loudness, rate in PARTIALS:
        pitch = prime * ratio * rng.uniform(0.995, 1.005)
        for detune in (-1, 1):
            phase = rng.uniform(0, 2 * np.pi)
            wave = np.sin(2 * np.pi * (pitch + detune * rng.uniform(0.2, BEAT) / 2) * t + phase)
            # The strike takes a few milliseconds to build up the partial.
            out += loudness / 2 * wave * envelope(length, 0.004, rate * rng.uniform(0.9, 1.1))
    # The clapper: a bright knock, and the metallic ring of the bell's lip just after it.
    clapper = burst(rng, 0.03, 1200, 5000, 0.0008, 90)
    place(out, clapper, 0.0, 0.35)
    place(out, ring(prime * 2.76, 30, 0.4), 0.0, 0.1)
    return fade_out(highpass(out, 60), 1.5)


def bell_strike(rng):
    """One strike of the clapper: a short dry tick of the clapper on the bronze, then the
    partials of the bell ringing out, each a little off the textbook by the casting."""
    return _bell(rng, PRIME, BELL_LENGTH)


# The big bell of the church, about A3: its hum is the low A2 that carries across the marsh.
ALARM_PRIME = 220.0
ALARM_LENGTH = 10.0
# The marsh throws the stroke back from the dykes and farms: (delay in s, gain) of the echoes.
ALARM_ECHOES = ((0.42, 0.22), (0.95, 0.12))


def church_alarm_stroke(rng):
    """One stroke of the church bell tolled as an alarm, heard from far off over the marsh: the
    big bell's strike with its brightness gone (the air takes the high partials and the clapper's
    knock first), the hum and the strike note left to cut through a storm, and two faint
    echoes. The game tolls it again and again (three strokes in the warning, steadily once the
    sea runs)."""
    near = _bell(rng, ALARM_PRIME, ALARM_LENGTH)
    # Two passes of the one-pole filter: a steeper slope, as the air and the marsh dull a far-off
    # bell far more than a single gentle roll-off would.
    far = lowpass(lowpass(near, 1800), 2600)
    out = far.copy()
    for delay, gain in ALARM_ECHOES:
        place(out, lowpass(far, 900), delay, gain)
    return fade_out(highpass(out, 60), 1.5)
