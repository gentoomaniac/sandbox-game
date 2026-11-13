# Music: can the game play generated modules? (task 169)

Measured 2026-11-10 on an Intel Core Ultra 9 185H (22 threads), Linux 6.18, Godot 4.7.2 (the
Gentoo build, `4.7.2.stable.gentoo`), headless and muted, with Godot's Dummy audio driver (it
mixes in real time, in blocks of about 93 ms, and sends nothing to a device). Nothing here plays in
the game yet.

The question: background music in the style of 1980s home-computer games, generated as small
tracker modules from text and rendered by the game on a background thread. Is that fast, cheap and
exact enough, and can Godot switch and crossfade the renders on the beat?

**Answer: yes (the beat timing on a real audio driver was measured in task 170, see "Switching on
the beat").** A GDScript renderer renders a minute of 44.1 kHz stereo in about 1 s on a worker thread
(the 8-bar loop of the test piece, 18 s, in 0.3 s) and matches an independent player. The stream is
made whole on the worker; the main thread spends under 0.2 ms per render to take it and hand it to
a two-player crossfade, which starts the new stream on the next beat with its beats on the old
ones to the frame. The frames stay as they are, also while a save is written, and the game quits
cleanly. Two things don't work: making a copy of a rendered stream on the main thread (12 to 21 ms a
minute, over the frame budget), and AudioStreamInteractive with rendered streams (it needs a script
subclass of AudioStreamWAV to know the beat, and such a stream, once played, crashes the quit).

## What was built

| Part | Where | What it does |
|---|---|---|
| Generator | `tools/music/generate.py`, run by `make art` | Plain text (`tools/music/pieces/*.txt`: speed, tempo, order, sections of four voices, tokens `NOTE:ROWS[:EFFECT]`) to a 4-channel ProTracker module (`M.K.`), `art/generated/music/<name>.mod`, packed into `assets/music/`. Deterministic. Single-cycle instruments made in code: a 32-sample sawtooth (lead), a 25 % pulse (arpeggio chords), a 64-sample triangle (bass), one-shot decaying noise (drums). |
| Effect set | the generator's docstring | 0xy arpeggio, 1xx/2xx portamento, 3xx tone portamento, 4xy vibrato, Axy volume slide, Cxx volume, ECx note cut; Fxx speed/tempo and Dxx pattern break are written by the generator only (every section starts with its speed and tempo, a section shorter than its pattern ends with D00). Anything else is refused. |
| Sections stand alone | the generator | A section sounds the same whatever played before it: no effect memory (300, 4x0), and every voice starts a section by striking a note (not with 3xx) or with `^`; before its first note it may only rest or cut. |
| Test piece | `tools/music/pieces/test_reel.txt` | Our own reel in A dorian at **106 beats a minute** (speed 6, tempo 106: a row of 141.5 ms, 16 rows a bar; the user found the first 150 too fast for the game): an 8-bar loop (18.1 s) and a 1-bar fill (2.3 s) that leads back into it. Sawtooth lead with vibrato on the long notes, arpeggio chords on the off-beats, a walking triangle bass, noise kick, snare and hats; the fill has a pulse sweep up (1xx), toms falling (2xx), a slide (3xx) and a fade (Axy). A tick at tempo 106 is no whole number of samples, so the piece also tries how ticks are cut. |
| Independent check | `tools/music/check.py` with `modplug.py`, run by `make art` | Plays each module with **libmodplug** (the system's ModPlug library, through ctypes) and checks it is 4 channels with its patterns, and plays every row of the piece in its order, each for `speed` ticks, the fill broken off after its 16 rows, and then stops. |
| Renderer | `game/audio/tracker_module.gd`, `game/audio/module_renderer.gd` | Reads the module, refusing what it can't play (another format, a cut-off file, an empty order list, finetunes, loops past a sample's end, effects outside the set or with memory, breaks past row 63). Renders parts of the order list (an order and a row count, from a defined entry state: speed 6, tempo 125, all channels silent) into a plain 16-bit mono or stereo AudioStreamWAV, at once or whole on a WorkerThreadPool thread, and tells its beat (`beat_seconds`). Arpeggios step through ProTracker's period table as ProTracker does. Samples interpolated linearly, volumes ramped over 2 ms (since task 171, see "Clean held notes" below); channels 1+4 left, 2+3 right with a quarter on the other side. Apart from AudioService. |
| Crossfade on the beat | `game/audio/music_crossfade.gd` | Two AudioStreamPlayers; see "Switching on the beat" below. |
| AudioStreamInteractive trial | `game/audio/music_stream_wav.gd` | `MusicStreamWAV extends AudioStreamWAV` and overrides `_get_bpm`, `_get_beat_count`, `_get_bar_beats`. Not used by the renderer (the crash, below). |
| Tests | `tests/test_module_renderer.gd`, `test_module_effects.gd`, `test_music_crossfade.gd`, `test_music_stream_wav.gd`, `tools/music/test_generate.py` | See the checks below. |
| Measurements | `make bench-music` (`tools/bench/music.gd`), `make music-check` (`tools/music/render.gd` + `check.py --against`) | The numbers below. |

No other player is installed here: no `openmpt123`/libopenmpt, MilkyTracker, xmp or mikmod, and this
ffmpeg is built without libopenmpt and libmodplug. libmodplug (`/usr/lib64/libmodplug.so`) is, and
it is independent of our code, so it is the check. libopenmpt descends from the same ModPlug code.
Whether OpenMPT or MilkyTracker open the file was not tried on this machine: it is a plain `M.K.`
module, which both read.

**Timing convention:** a tick lasts `mix rate x 2.5 / tempo` samples cut to a whole number, as
libmodplug plays it (checked: at tempo 106 libmodplug's rows start every 6 x 1040 samples at 44.1
kHz, not 6 x 1040.09). The renderer and `check.py` both count so. At tempo 106 the ticks are
0.009 % short of the exact 2.5 / 106 s, so the piece runs at 106.01 beats a minute.

**Export:** Godot doesn't import `.mod` files, so they are read as bytes
(`FileAccess.get_file_as_bytes`). The presets of `export_presets.cfg` list
`assets/music/*.mod` in "Filters to export non-resource files" (`include_filter`), or the exported
game would have no music (also in tools/README.md).

## Render times

`make bench-music`, best of 3 renders on the main thread, two runs of the bench:

| Rendered | Rate | Channels | Time | Faster than real time | Stream |
|---|---|---|---|---|---|
| 8-bar loop, 18.1 s | 22.05 kHz | mono | 87 / 91 ms | 200-210x | 0.76 MB |
| 8-bar loop, 18.1 s | 22.05 kHz | stereo | 144 / 145 ms | 125x | 1.52 MB |
| 8-bar loop, 18.1 s | 44.1 kHz | mono | 170 / 170 ms | 105x | 1.52 MB |
| 8-bar loop, 18.1 s | 44.1 kHz | stereo | 289 / 278 ms | 63-65x | 3.05 MB |
| 1 minute (424 rows) | 22.05 kHz | mono | 296 / 292 ms | 205x | 2.52 MB |
| 1 minute | 22.05 kHz | stereo | 479 / 467 ms | 125x | 5.05 MB |
| 1 minute | 44.1 kHz | mono | 575 / 612 ms | 100x | 5.05 MB |
| 1 minute | 44.1 kHz | stereo | 955 / 938 ms | 63x | 10.09 MB |

Reading the module: 0.4 ms. In the game (Main running on the bench save) a minute at 44.1 kHz stereo
took 0.96 to 1.1 s on a worker thread. The time goes into the inner loop over the samples (four
channels, one add each per output sample; stereo two), then the conversion to 16 bit.

For comparison, native code: libmodplug (C++, linear interpolation, through ctypes) plays the
module roughly 5,000 to 12,000 times faster than real time, a minute in about 5 to 12 ms (measured
at the first tempo, 150 beats a minute): about 100 times faster than the GDScript renderer.

**Since linear interpolation** (task 171, 2026-11-10, one run of `make bench-music`): the renders
take about a third longer: the 8-bar loop at 44.1 kHz stereo 379 ms (48x real time), mono 272 ms;
a minute at 44.1 kHz stereo 1.28 s (47x), 22.05 kHz mono 472 ms (127x); in the game on a worker a
minute took 1.31 to 1.32 s. The frames stayed as they were (rendering: mean 6.89 ms, longest 7.1
ms; with a save, longest 10.7 ms; none over 16.7 ms). **With volume ramps** (the same day, the
machine busy with other work, load 8.6): the loop at 44.1 kHz stereo 442 ms (41x), a minute 1.48 s
(40x), 22.05 kHz mono 548 ms (110x); the frames again as they were (mean 6.90 ms, longest 7.0 ms).
A stream that loops renders its parts twice: the test reel's loop at 44.1 kHz stereo took 416 ms
once and 796 ms looping (best of 3, load 6.5).

## Memory

The stream is 16-bit PCM: **2.5 MB a minute** at 22.05 kHz mono, 5 MB at 44.1 kHz mono or 22.05
kHz stereo, **10 MB a minute at 44.1 kHz stereo**. While rendering, the float mix buffer (4 bytes a
sample) and the 16-bit data exist together: about 3 times the stream at the peak, briefly, on the
worker. The music is short loops, so what is kept is small: the 8-bar loop at 44.1 kHz stereo is
3.05 MB, its fill 0.4 MB.

## The main thread and the frame budget

Task 158's budget is 8 ms of spread-out work a frame, so that a frame stays under 33 ms. From
`make bench-music` (Main on the bench save, standing; 300 frames each; renders of a minute at
44.1 kHz stereo one after the other on a worker, each handed to the crossfade; in the third a timed
save started at frame 10, which was written, ending in frame 37 and 31 of the two runs):

| Scenario | Mean frame | Longest | Over 16.7 ms | Over 33 ms |
|---|---|---|---|---|
| Standing, no render (runs 1, 2) | 7.01 / 7.02 ms | 18.8 / 23.8 ms | 1 / 1 | 0 / 0 |
| Rendering on a worker, crossfading | 6.90 / 6.90 ms | 8.0 / 9.9 ms | 0 / 0 | 0 / 0 |
| The same and a timed save | 6.90 / 6.91 ms | 9.7 / 17.3 ms | 0 / 1 | 0 / 0 |

On these runs the rendering changed nothing measurable; the odd frame over 16.7 ms happens standing
without music as well (`make bench` shows such frames too). An earlier run while the machine was
busy with other work had spikes up to 370 ms in all scenarios, music or not; it is left out. That is
two runs of 300 frames each on one machine, not a guarantee for slower ones.

What the main thread spends per finished render, the longest of the runs: **taking the stream from
the worker 0.03 ms, handing it to the crossfade 0.14 ms; the crossfade's own work in a frame
(starting the new stream on the beat, setting the volumes) at most 0.18 ms, 0.4 ms in a later run.** No data is copied on
the main thread: the worker makes the AudioStreamWAV whole. A copy would not fit: assigning a
minute's data to another AudioStreamWAV (`stream.data = other.data`) took **12 to 21 ms** in the
first version of the bench.

## Viability checks

- **The loop is seamless** (GUT, `test_the_loop_wraps_into_its_own_start_without_a_seam` and
  `tests/test_module_loops.gd`): a stream that loops (`render(parts, true)`) is the parts rendered
  twice in a row, keeping the second time through. So it starts as the parts sound after their
  own end, the notes left sounding there fading out into it (a ramp's length, 2 ms), and a stream
  that wraps from its last sample to its first plays exactly what the music would, also where a
  part's start depends on what played before (a cut note raised again, a sample named without a
  note, a tone portamento without a note): the tests render three times through and compare. With
  the generator's sections, which start every voice with a struck note or a cut and use no effect
  memory, the looping stream is from 2 ms on the loop rendered once.
- **Fill, then the loop on the bar** (GUT, `test_the_fill_breaks_after_a_bar_and_the_loop_resumes_on_the_bar`):
  playing the order list from the start (loop, fill, and round again) gives, sample for sample, the
  loop, the fill and the loop rendered as parts one after the other: the fill exactly one bar long
  (its D00 breaks after row 16), then the loop again from its start. Ticks are whole numbers of samples (the convention
  above), so bars land on exact samples.
- **The effects one by one** (GUT, `tests/test_module_effects.gd`): each effect's periods and volumes
  tick by tick, an arpeggio after a slide (from 852 it plays E-1 678 and G#1 538, as ProTracker,
  not 716 and 568 as a ratio would), speed, tempo, a tempo whose tick is no whole number of samples,
  a pattern break to a row of the next pattern, each channel's stereo side, and malformed files.
- **The render matches an independent player** (`make music-check`, the order list once through,
  mono 44.1 kHz, against libmodplug's play):

  | Measure | Result | Tolerance |
  |---|---|---|
  | Length | 898,560 samples = 144 rows x 6 ticks x 1040; libmodplug's rows run at the same times (`check.py`) | exact |
  | Offset between the two | 1 sample; 0 with interpolation | at most 2 |
  | Loudness tick by tick (23.6 ms), correlation | 0.936; 0.968 with interpolation; 0.975 with volume ramps | at least 0.9 |
  | Spectrum row by row (141.5 ms), cosine similarity | min 0.977, median 0.996; with interpolation min 0.982, median 1.000 | at least 0.95 in every row; rows silent in both count as alike |
  | Strongest frequency row by row | the same (within 50 cents) in 100 % of the 144 rows | 95 % |

  The differences were what libmodplug adds and the renderer left out until task 171: interpolation
  between samples and volume ramps; what is left is how libmodplug's ramps differ. With the arpeggio switched off in the renderer the check
  fails (loudness correlation 0.815), so it does see a missing effect.

## Switching on the beat

**Two players (`MusicCrossfade`), what the recommendation uses.** Each frame it reads how far the
playing player has been mixed. On the first frame past the next beat it starts the new stream on the
other player from as far into it as the old one is past the beat, holding the audio thread
(`AudioServer.lock()`) between reading and starting, so that no mix falls in between; then it fades
the new one in and the old one out over the fade, counting the new stream's play on across its
loop's wraps (so a fade may be longer than the loop, and a stalled frame or a loop shorter than a
mix block doesn't hold it back). A crossfade asked for during a fade waits
until the fade is over (the newest request only), so no gain jumps. A player's position runs 128
frames ahead of
what it has mixed (Godot's resampling reads the stream ahead in blocks of 128); without taking that
off, the new beats fell 127 to 128 frames early. Measured:

- **Beat grids** (GUT, `tests/test_music_crossfade.gd`, the bus captured with AudioEffectCapture,
  two click tracks of the same beat): the new stream's clicks fall on the old stream's beats within
  one frame (the start position is given in seconds and may round to the frame beside), also when
  the beat is a loop's wrap. Five runs in a row passed. This holds for streams at the mix rate
  (44.1 kHz here); at another rate the read-ahead is 128 frames of the stream but not at a fixed
  phase, so the grids may be up to 128 of its frames apart (up to 5.8 ms at 22.05 kHz; not
  measured).
- **Fades in a row and long fades** (GUT): a crossfade asked for halfway through a fade waits for it
  and then runs, each player's gain never moving by more than a mix block's share of the fade from
  one frame to the next, and it ends on the last stream asked for with the other player stopped.
  A fade's progress is how far the new stream has played: the positions to the sample, its loop's
  whole wraps from the time between the mixes (`MusicCrossfade.played_seconds`, tested on its own
  with no wrap, one, several in a loop shorter than a mix block, and a stalled frame). In real time
  a 2 s fade into a 1.6 s loop ends, and takes no less than its length less a block and a frame.
- **Known limit**: the time between mixes is when they happened, not how much they mixed. If the
  audio thread itself is held up (say 400 ms) and then mixes one block, that looks like 400 ms of
  play, and a fade into a short loop may end early by about that much. Godot exposes no count of
  mixed frames, so this is left to task 170 (noted in TASKS.md).
- **Lateness** (`lateness`): how long after the beat the new stream was scheduled, up to a frame and
  a mix block; the new stream's first moments are skipped. With the Dummy driver's 93 ms blocks it
  was 58 to 75 ms (three crossfades in `make bench-music`). **On a real driver** (task 170,
  `make music-latency`, PulseAudio here, 60 fps, output latency 46 ms, 20 crossfades asked for at
  different points of a beat, silent: Master muted, a capture effect on the probe's bus before the
  mute): scheduled **2 to 20 ms after the beat** (median 8.5), a frame and a block. The fade is
  heard later, as its gain rises from the next frame on and the audio thread, which mixes ahead of
  the speakers by the driver's buffer, applies it a block later: with a fade of a millisecond the new
  level was in the mix **97 to 190 ms after the beat** (median 143), in the mix's own time. The old
  beat is as late on its way to the speakers, so this is only how long after the beat the fade
  starts rising: at 190 ms into a 4 s fade the new stream is at 5 % (-26 dB). Its beats lay a median
  **3.3 ms** after the old ones (one run of 20 15.8 ms before them), against a frame on the Dummy
  driver. Two things the probe found: Godot's bus skips the effects of a bus that mixes silence, so
  a capture hears only the non-silent frames (the probe's streams are never silent).
  **Decision: no earlier start from a predicted position.** The
  scheduling is within a frame and a block, and what is late is the start of a fade that lasts
  seconds; the beats of the two pieces don't coincide in any case (the pieces' tempos differ), and
  what is heard is the new piece's fade in, not its first beat.
- **Quit**: `make bench-music` quits cleanly with streams played by the crossfade (exit status 0,
  all four runs).

**AudioStreamInteractive** (GUT, `tests/test_music_stream_wav.gd`, mixed offline with
`AudioStreamPlayback.mix_audio`): with two `MusicStreamWAV` clips at 150 BPM, a switch asked for at
0.1 s and set to "next beat" starts its crossfade at 0.4 s and ends it at 0.8 s; set to "next bar" it
starts at 1.6 s. A plain AudioStreamWAV has no BPM (0) and switches at once. So the script subclass
is needed, and it works, but **the crash**: a played script subclass of AudioStreamWAV
(`MusicStreamWAV`, and as well an empty `extends AudioStreamWAV`), played by an AudioStreamPlayer
directly or inside an AudioStreamInteractive, makes Godot abort when it quits while Main is in the
tree (SIGSEGV in `pthread_mutex_lock` during shutdown; exit status 134). The same scene with a plain
AudioStreamWAV quits cleanly, and so does a scene without Main. Reproduced with a headless script
that adds Main and a player, plays a rendered MusicStreamWAV and quits 40 frames later. The cause
was not found.

## Clean held notes (task 171)

The user heard the first ambient sketches of task 171 as notes that "struggle to keep the pitch,
like a voice breaking". Measured on each voice alone (the other channels' notes taken out of the
module), rendered by the game and by libmodplug: the pitch every 5 ms over three periods, in cents
off the note, on rows that hold a note; and how much of a held row's sound lies off the note's
harmonics.

| | Game, nearest sample | Game, interpolated | libmodplug |
|---|---|---|---|
| Saw lead, holds without vibrato: pitch off, rms / max | 1.8 / 5.3 cents | 0.1 / 0.3 cents | 0.2 / 0.6 cents |
| Saw lead, held row off its harmonics | -21 dB | -31 dB | -31 dB |
| A steady 32-sample saw at C-2 (computed) off its harmonics | -22 dB | -47 dB | |
| Saw lead, holds with the sketches' vibrato (423, 424): pitch off, rms / p95 / max | 21 / 46 / 57 cents | 21 / 46 / 55 cents | 22 / 47 / 55 cents |

Two causes. **The renderer**: it took the nearest sample at the mix rate, so a looped wave of 32
samples was no longer exactly periodic (its steps moved by up to a frame, in a pattern that beats
against the note): a rough tone a few cents unsteady, which libmodplug, interpolating, doesn't have.
The renderer now interpolates linearly. **The music**: vibrato of depth 3 and 4 at speed 2 swings
the pitch about half a semitone each way once or twice a second: not a vibrato but a drifting
note, the same in libmodplug. The sketches now strike each note clean and hold it plain: the user
chose that after hearing it beside a light vibrato late in the longer notes (481: 10 cents at 4 to
4.5 a second; 5 / 10 / 14 cents rms / p95 / max).
Tone portamento slurs (3FF) were dropped as well: each played a tick of the old note at the start
of the new one.

## Clicks between notes (task 171)

The user then heard "slight cracking in between note switches". The renderer cut the old note and
started the new one from its first sample, and set a new volume at once: a jump from wherever the
wave was. Measured per voice alone at each row that strikes, cuts or sets a volume: the steepest
step from one sample to the next there, against the steepest the voice makes elsewhere (over 1x
is a step steeper than the wave itself: a click).

| Voice (sketch) | Before: steepest / median, share over 1x | With ramps | libmodplug |
|---|---|---|---|
| Triangle bass (Harbour, 36 notes) | 82x / 32x, 97 % | 1.9x / 1.0x, 47 % | 1.9x / 1.0x, 50 % |
| Triangle drone (Tide) | 36x / 5.7x, 2 of 3 | 0.4x / 0.3x, none | 0.7x / 0.5x, none |
| Pulse (Tide, 96 notes) | 5.5x / 1.0x, 50 % | 0.7x / 0.06x, none | 0.6x / 0.08x, none |
| Saw lead (Harbour) | 1.8x / 0.7x, 28 % | 0.8x / 0.03x, none | 0.05x / 0.02x, none |

Now a channel's gain moves to a new volume over 2 ms, a struck note starts from silence, and the
note before fades out beside it over the same 2 ms: libmodplug's figures. What is left over 1x on
the bass is the 2 ms fade itself, about as steep as the low triangle's own slope.

## Recommendation

**Render at runtime in GDScript, on a WorkerThreadPool thread, into plain AudioStreamWAVs made whole
there; switch with two players crossfaded on the beat (`MusicCrossfade`); render transitions that
must be sample-exact (fill into loop) into one stream.** Confirmed in task 170 by the measurement of how late
the crossfade begins on a real audio driver.

- **Speed is no problem.** An 8-bar loop at 44.1 kHz stereo renders in about 0.3 s, a fill in 0.04
  s, on a worker, and the frames stayed as they were. A native renderer would be 100 times faster,
  but nothing here needs that.
- **The main thread pays almost nothing**: at most 0.2 ms per render, and under 0.5 ms in a frame of the
  crossfade, as the stream is made whole on the worker. A copy of the data on the main thread (12
  to 21 ms a minute) must not happen.
- **Memory:** 3 MB per 8-bar loop at 44.1 kHz stereo; 22.05 kHz mono would quarter it, if memory
  ever matters, but the crossfade lines beats up exactly only for streams at the mix rate.
- **Exact:** it matches libmodplug, loops seamlessly, and lands the fill and the loop on the bar,
  sample for sample, because the renderer plays parts one after the other (`[fill, loop]`) into one
  stream. Between pieces, the two players line the beats up to a frame.
- **Lateness on a real driver** (task 170, see "Switching on the beat"): scheduled within 2 to 20 ms
  of the beat, the fade heard rising 97 to 190 ms after it; no predicted start is needed.
- **Not AudioStreamInteractive** while a played script-subclassed stream crashes the quit; if that is
  found to be avoidable, switching to it with `MusicStreamWAV` is a small change.
- **Not a native GDExtension around libopenmpt:** about 100 times faster, but it needs a C++ build
  per platform and a third-party library in the export, for speed the game doesn't need.
- **Build-time renders** (OGG files made by `make art`, which Godot imports with BPM and loop
  settings, so AudioStreamInteractive works with no subclass) remain the fallback: no runtime cost
  at all, about 1 MB a minute on disk, but every variation has to be rendered ahead.

Numbers to watch when task 170 builds it: render time on the slowest machine the game should run
on (GDScript is about 63x real time at 44.1 kHz stereo here, so a machine 10 times slower still
renders a loop in 3 s), and the crossfade's lateness on the real driver (measured: 2 to 20 ms).
