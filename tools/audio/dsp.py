"""Building blocks of the sound generator: noise, tones, filters and envelopes.

Every signal is a numpy float array at RATE samples per second, roughly within -1..1 (the
generator scales each event to its level afterwards). Times are in seconds, frequencies in
Hz. Functions that take `loop=True` treat the signal as circular, so a loop built from them
wraps around without a seam.
"""

import numpy as np

RATE = 44100


def samples(seconds):
    return round(seconds * RATE)


def times(duration):
    return np.arange(samples(duration)) / RATE


def silence(duration):
    return np.zeros(samples(duration))


def noise(rng, duration):
    return rng.uniform(-1, 1, samples(duration))


def grains(rng, duration, per_second):
    """Sparse random clicks: the raw stuff of crunches, crackles and patter."""
    count = samples(duration)
    hits = rng.random(count) < per_second / RATE
    return np.where(hits, rng.uniform(-1, 1, count), 0.0)


def _filter(x, response, loop):
    """Applies a frequency response (a function of Hz) through the FFT. A loop is filtered
    as a circle, which is exactly its steady state; anything else gets silence appended
    first, so the filter's ring-out doesn't wrap around onto its start (up to a power of
    two, which is fast)."""
    if loop:
        padded = x
    else:
        size = 2 ** int(np.ceil(np.log2(len(x) + samples(0.25))))
        padded = np.concatenate([x, np.zeros(size - len(x))])
    spectrum = np.fft.rfft(padded)
    frequencies = np.fft.rfftfreq(len(padded), 1 / RATE)
    return np.fft.irfft(spectrum * response(frequencies), len(padded))[: len(x)]


def _one_pole(frequencies, cutoff):
    """The response of the gentle one-pole low-pass y += a * (x - y): 6 dB per octave."""
    a = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    return a / (1 - (1 - a) * np.exp(-2j * np.pi * frequencies / RATE))


def lowpass(x, cutoff, loop=False):
    return _filter(x, lambda f: _one_pole(f, cutoff), loop)


def highpass(x, cutoff, loop=False):
    """The rest of a one-pole low-pass: x minus it."""
    return _filter(x, lambda f: 1 - _one_pole(f, cutoff), loop)


def bandpass(x, low, high, loop=False):
    """A high-pass at low, then a low-pass at high."""
    return _filter(x, lambda f: (1 - _one_pole(f, low)) * _one_pole(f, high), loop)


def resonance(x, centre, width, loop=False):
    """A peak around centre, width octaves wide (one standard deviation): a body, a
    formant or a whistle."""
    with np.errstate(divide="ignore"):
        return _filter(x, lambda f: np.exp(-0.5 * (np.log2(f / centre) / width) ** 2), loop)


def swept_band(x, centre, width, loop=False):
    """A band of x around a centre frequency that moves (an array as long as x). Made of a
    bank of fixed third-octave peaks, each faded in by how close the centre is to it."""
    out = np.zeros_like(x)
    for peak in 2 ** np.arange(np.log2(60), np.log2(14000), 1 / 3):
        closeness = np.exp(-0.5 * (np.log2(centre / peak) / width) ** 2)
        if closeness.max() > 0.01:
            out += closeness * resonance(x, peak, 1 / 6, loop)
    return out


def noise_band(rng, duration, low, high, loop=False):
    """Band-passed noise at unit RMS, so bands of different widths mix by their gains."""
    band = bandpass(noise(rng, duration), low, high, loop)
    return band / rms(band)


def burst(rng, duration, low, high, attack, rate, per_second=None):
    """A short hit of band-passed noise (unit RMS before the envelope), or of grains when
    per_second is given: a rustle, a thump, a crunch. Its end fades out, so whatever is
    left of its decay doesn't stop with a click."""
    raw = noise(rng, duration) if per_second is None else grains(rng, duration, per_second)
    band = bandpass(raw, low, high)
    return fade_out(band / rms(band) * envelope(duration, attack, rate), duration / 5)


def envelope(duration, attack, rate, hold=0.0):
    """Rises linearly over attack, holds, then decays exponentially at rate (1/s)."""
    t = times(duration)
    rise = np.clip(t / attack, 0, 1) if attack > 0 else 1.0
    return rise * np.exp(-rate * np.maximum(t - attack - hold, 0))


def swell(duration, peak):
    """Rises smoothly to 1 at time peak and falls back to 0 at the end: whooshes, gusts."""
    t = times(duration)
    up = np.sin(0.5 * np.pi * np.clip(t / peak, 0, 1)) ** 2
    down = np.cos(0.5 * np.pi * np.clip((t - peak) / (duration - peak), 0, 1)) ** 2
    return np.where(t < peak, up, down)


def fade_out(x, duration):
    """Fades the last duration seconds out (a raised cosine), so a part that is cut off
    ends at zero instead of with a click."""
    count = min(len(x), samples(duration))
    x = x.copy()
    x[len(x) - count :] *= np.cos(0.5 * np.pi * np.linspace(0, 1, count)) ** 2
    return x


def drift(rng, duration, points_per_second, loop=False):
    """A slow random curve between 0 and 1, smoothly through random points. A loop's
    curve ends where it starts."""
    count = samples(duration)
    points = max(2, round(duration * points_per_second))
    values = rng.random(points + 1)
    if loop:
        values[-1] = values[0]
    position = np.arange(count) * points / count
    index = position.astype(int)
    blend = (1 - np.cos(np.pi * (position - index))) / 2
    return values[index] * (1 - blend) + values[index + 1] * blend


def sweep(start, end, duration, curve=1.0, harmonics=(1.0,)):
    """A tone gliding from start to end Hz (curve > 1 lingers at the start, < 1 at the
    end). harmonics are the weights of the partials; partials near Nyquist are left out."""
    count = samples(duration)
    progress = (np.arange(count) / count) ** curve
    frequency = start + (end - start) * progress
    return tone(frequency, harmonics)


def tone(frequency, harmonics=(1.0,)):
    """A tone following a frequency curve (one value per sample), starting at phase 0."""
    phase = 2 * np.pi * np.cumsum(frequency) / RATE
    out = np.zeros(len(frequency))
    for number, weight in enumerate(harmonics, start=1):
        if weight and number * frequency.max() < 0.45 * RATE:
            out += weight * np.sin(number * phase)
    return out


def constant(frequency, duration):
    return np.full(samples(duration), float(frequency))


TRIANGLE = (1.0, 0.0, -1 / 9, 0.0, 1 / 25, 0.0, -1 / 49)
# A square with only its first four odd partials: hollow and dull, never buzzy.
SOFT_SQUARE = (1.0, 0.0, 1 / 3, 0.0, 1 / 5, 0.0, 1 / 7)
SAW = tuple(1 / number for number in range(1, 60))


def ring(frequency, rate, duration):
    """A struck resonance: a sine from phase 0 that dies away at rate (1/s), its end faded."""
    t = times(duration)
    return fade_out(np.sin(2 * np.pi * frequency * t) * np.exp(-rate * t), duration / 5)


def knock(base, duration):
    """A knock on wood: three wooden modes over base Hz, the higher ones shorter."""
    return (
        0.8 * ring(base, 25, duration)
        + 0.45 * ring(base * 2.3, 40, duration)
        + 0.2 * ring(base * 3.9, 80, duration)
    )


def bubble(frequency, duration=0.03):
    """A water bubble or drop: a short sine whose pitch rises as it dies away."""
    rise = sweep(frequency, frequency * 1.7, duration, 0.5)
    return rise * envelope(duration, 0.001, 5 / duration)


def place(out, sound, at, gain=1.0, loop=False):
    """Adds sound into out from time at on. In a loop it wraps around the end; otherwise
    whatever doesn't fit is dropped."""
    start = samples(at)
    if loop:
        np.add.at(out, (start + np.arange(len(sound))) % len(out), gain * sound)
    else:
        end = min(len(out), start + len(sound))
        out[start:end] += gain * sound[: end - start]


def rms(x):
    return float(np.sqrt(np.mean(x**2)))


def normalized(x):
    return x / np.abs(x).max()
