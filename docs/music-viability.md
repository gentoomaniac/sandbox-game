# Music: can the game play generated modules? (task 169)

Measured 2026-11-10 on an Intel Core Ultra 9 185H (22 threads), Linux 6.18, Godot 4.7.2 (the
Gentoo build, `4.7.2.stable.gentoo`), headless and muted. Nothing here plays in the game yet.

**Which piece the numbers are of:** every number below was measured with the test piece's first
version, at 150 beats a minute (speed 5, tempo 125: 100 ms a row, the 8-bar loop 12.8 s, a minute
600 rows). The piece is now at 106 beats a minute (the user found 150 too fast), so `make
bench-music` and `make music-check` print other lengths and times than these; the next report
measures again.

The question: background music in the style of 1980s home-computer games, generated as small
tracker modules from text and rendered by the game on a background thread. Is that fast, cheap and
exact enough, and can Godot switch and crossfade the renders on the beat?

**Answer: yes, with one open problem.** A GDScript renderer renders a minute of 44.1 kHz stereo in
about 1.1 s on a worker thread (an 8-bar loop in 0.2 s), costs the main thread well under 0.1 ms
per render, leaves the frame times as they are (also during a save), and matches an independent
player. AudioStreamInteractive switches the renders on the next beat or bar once the stream tells
its BPM, which takes a script subclass of AudioStreamWAV; but such a stream, once played with Main
running, crashes the game when it quits. The recommendation (at the end) avoids that subclass.

## What was built

| Part | Where | What it does |
|---|---|---|
| Generator | `tools/music/generate.py`, run by `make art` | Plain text (`tools/music/pieces/*.txt`: speed, tempo, order, sections of four voices, tokens `NOTE:ROWS[:EFFECT]`) to a 4-channel ProTracker module (`M.K.`), `art/generated/music/<name>.mod`, packed into `assets/music/`. Deterministic. Single-cycle instruments made in code: a 32-sample sawtooth (lead), a 25 % pulse (arpeggio chords), a 64-sample triangle (bass), one-shot decaying noise (drums). |
| Effect set | the generator's docstring | 0xy arpeggio, 1xx/2xx portamento, 3xx tone portamento, 4xy vibrato, Axy volume slide, Cxx volume, ECx note cut; Fxx speed/tempo and Dxx pattern break are written by the generator only (every section starts with its speed and tempo, a section shorter than its pattern ends with D00). Anything else is refused, and so is effect memory (300, 4x0), so a section sounds the same whatever played before it. |
| Test piece | `tools/music/pieces/test_reel.txt` | Our own reel in A dorian, now at 106 beats a minute (speed 6, tempo 106: about 141.5 ms a row, 16 rows a bar; measured below at its first 150): an 8-bar loop and a 1-bar fill that leads back into it. Sawtooth lead with vibrato on the long notes, arpeggio chords on the off-beats, a walking triangle bass, noise kick, snare and hats; the fill has a pulse sweep up (1xx), toms falling (2xx), a slide (3xx) and a fade (Axy). |
| Independent check | `tools/music/check.py` with `modplug.py`, run by `make art` | Plays each module with **libmodplug** (the system's ModPlug library, through ctypes) and checks it is 4 channels with its patterns, and plays every row of the piece in its order, each for `speed` ticks of 2.5 / `tempo` s, the fill broken off after its 16 rows, and then stops. |
| Renderer | `game/audio/tracker_module.gd`, `game/audio/module_renderer.gd` | Reads the module; renders parts of the order list (an order and a row count, from a defined entry state: speed 6, tempo 125, all channels silent) into a 16-bit mono or stereo `MusicStreamWAV`, at once or on WorkerThreadPool. Amiga style: no interpolation, no volume ramps; channels 1+4 left, 2+3 right with a quarter on the other side. Apart from AudioService; nothing plays it. |
| Beat for AudioStreamInteractive | `game/audio/music_stream_wav.gd` | `MusicStreamWAV extends AudioStreamWAV` and overrides `_get_bpm`, `_get_beat_count`, `_get_bar_beats`. |
| Tests | `tests/test_module_renderer.gd`, `tests/test_music_stream_wav.gd`, `tools/music/test_generate.py` | See the checks below. |
| Measurements | `make bench-music` (`tools/bench/music.gd`), `make music-check` (`tools/music/render.gd` + `check.py --against`) | The numbers below. |

No other player is installed here: no `openmpt123`/libopenmpt, MilkyTracker, xmp or mikmod, and this
ffmpeg is built without libopenmpt and libmodplug. libmodplug (`/usr/lib64/libmodplug.so`) is, and
it is independent of our code, so it is the check. libopenmpt descends from the same ModPlug code
and plays MOD files the same way in what matters here. Whether OpenMPT or MilkyTracker open the file
was not tried on this machine: the file is a plain `M.K.` module, which both read.

**Export:** Godot doesn't import `.mod` files, so they are read as bytes
(`FileAccess.get_file_as_bytes`). There is no `export_presets.cfg` yet; the preset, once made, needs
`*.mod` in "Filters to export non-resource files" (`include_filter`), or the exported game has no
music (also in tools/README.md).

## Render times

`make bench-music`, best of 3 runs on the main thread, the test piece (two runs of the bench,
both shown):

| Rendered | Rate | Channels | Time | Faster than real time | Stream |
|---|---|---|---|---|---|
| 8-bar loop, 12.8 s | 22.05 kHz | mono | 64 / 69 ms | 190-200x | 0.54 MB |
| 8-bar loop, 12.8 s | 22.05 kHz | stereo | 106 / 113 ms | 115-120x | 1.08 MB |
| 8-bar loop, 12.8 s | 44.1 kHz | mono | 132 / 136 ms | 95x | 1.08 MB |
| 8-bar loop, 12.8 s | 44.1 kHz | stereo | 205 / 241 ms | 55-60x | 2.15 MB |
| 1 minute (600 rows) | 22.05 kHz | mono | 307 / 332 ms | 180-195x | 2.52 MB |
| 1 minute | 22.05 kHz | stereo | 498 / 549 ms | 110-120x | 5.05 MB |
| 1 minute | 44.1 kHz | mono | 599 / 658 ms | 90-100x | 5.05 MB |
| 1 minute | 44.1 kHz | stereo | 1083 / 1079 ms | 55x | 10.09 MB |

Reading the module: 0.25 ms. In the game (Main running on the bench save) a minute at 44.1 kHz
stereo took 1.0 to 1.2 s on a worker thread. The time goes into the inner loop over the samples
(four channels, one add each per output sample; stereo two), then the conversion to 16 bit.

For comparison, native code: libmodplug (C++, linear interpolation, through ctypes) plays the same
module about 5,000 to 12,000 times faster than real time: a minute in roughly 5 to 12 ms. A native
renderer would be about 100 times faster than the GDScript one.

## Memory

The stream is 16-bit PCM: **2.5 MB a minute** at 22.05 kHz mono, 5 MB at 44.1 kHz mono or 22.05
kHz stereo, **10 MB a minute at 44.1 kHz stereo**. While rendering, the float mix buffer (4 bytes a
sample) and the 16-bit data exist together: about 3 times the stream at the peak, briefly. The
music is short loops, so what is kept is small: the 8-bar loop at 44.1 kHz stereo is 2.2 MB, its
fill 0.3 MB.

## The main thread and the frame budget

Task 158's budget is 8 ms of spread-out work a frame, so that a frame stays under 33 ms. From
`make bench-music` (Main on the bench save, standing; 300 frames each; renders of a minute at
44.1 kHz stereo one after the other on a worker; a timed save started in the middle of them):

| Scenario | Mean frame | Longest | Over 16.7 ms | Over 33 ms |
|---|---|---|---|---|
| Standing, no render (runs 1, 2) | 7.01 / 7.02 ms | 14.5 / 20.2 ms | 0 / 1 | 0 / 0 |
| Rendering on a worker | 6.92 / 6.89 ms | 17.7 / 9.7 ms | 1 / 0 | 0 / 0 |
| Rendering, and a timed save | 6.90 / 6.94 ms | 14.2 / 24.6 ms | 0 / 1 | 0 / 0 |

The rendering changes nothing measurable: the odd frame over 16.7 ms happens standing without music
as well (`make bench` shows such frames too). A third run, while the machine was busy with other
work, had spikes up to 370 ms in all three scenarios and a render took 4.3 s; it is left out.

What the main thread spends per finished render (the longest of the runs): **take it from the
worker 0.01 ms, set it as a clip of an AudioStreamInteractive 0.01 ms, set it on a player and play
0.05 ms.** Nothing is copied: the stream is made on the worker. Copying the data into another
AudioStreamWAV (`stream.data = other.data`) is a real copy: **12 to 21 ms** for a minute at 44.1
kHz stereo, over the 8 ms budget, so any such copy belongs on the worker too.

## Viability checks

- **The loop is seamless** (GUT, `test_the_loop_wraps_into_its_own_start_without_a_seam`): the loop
  rendered twice in a row is, in its second half, the loop rendered once, sample for sample. So a
  stream of the loop that wraps from its last sample to its first plays exactly what the music
  would; there is no click at the wrap beyond what the music itself has. This holds because every
  voice strikes a note or is cut on the loop's first row and nothing depends on effect memory (the
  generator enforces the latter).
- **Fill, then the loop on the bar** (GUT, `test_the_fill_breaks_after_a_bar_and_the_loop_resumes_on_the_bar`):
  playing the order list from the start (loop, fill, and round again) gives the loop, then the fill
  sample for sample as rendered alone, exactly one bar long (its D00 breaks after row 16), then the
  loop again from its start, sample for sample. Rows are a whole number of samples at both rates
  (each tick is cut to a whole number of samples, as libmodplug does), so bars land on exact
  samples.
- **AudioStreamInteractive on the beat** (GUT, `tests/test_music_stream_wav.gd`, mixed offline with
  `AudioStreamPlayback.mix_audio`): with two `MusicStreamWAV` clips at 150 BPM, a switch asked for
  at 0.1 s and set to "next beat" starts its crossfade at 0.4 s and ends it at 0.8 s (a beat's
  fade); set to "next bar" it starts at 1.6 s. A plain AudioStreamWAV has no BPM (its `get_bpm` is 0)
  and switches at once, whatever the transition says (AudioStreamPlaylist takes its BPM from its
  streams too; not tried). So a script subclass overriding `_get_bpm`, `_get_beat_count` and
  `_get_bar_beats` is needed, and enough; no engine change.
- **The crash:** a played script subclass of AudioStreamWAV (`MusicStreamWAV`, and as well an empty
  `extends AudioStreamWAV`), played by an AudioStreamPlayer directly or inside an
  AudioStreamInteractive, makes Godot abort when it quits while Main is in the tree (SIGSEGV in
  `pthread_mutex_lock` during shutdown; exit status 134). The same scene with a plain
  AudioStreamWAV quits cleanly, and so does a scene without Main, or one where the player was
  stopped and its stream cleared some frames before the quit (but not in the benchmark, where it
  crashed even then). Reproduced with a headless script that adds Main and a player, plays a
  rendered MusicStreamWAV and quits 40 frames later. The cause is not found; it looks like an engine
  problem with script-backed streams at shutdown. That is why `make bench-music` plays a plain copy.
- **The render matches an independent player** (`make music-check`, the order list once through,
  mono 44.1 kHz, against libmodplug's play):

  | Measure | Result | Tolerance |
  |---|---|---|
  | Length | 635,040 samples = 144 rows x 100 ms exactly; libmodplug's rows run at the same times (`check.py`) | exact |
  | Offset between the two | 1 sample | at most 2 |
  | Loudness tick by tick (20 ms), correlation | 0.917 | at least 0.9 |
  | Spectrum row by row (100 ms), cosine similarity | min 0.968, median 0.996 | at least 0.95 in every row |
  | Strongest frequency row by row | the same (within 50 cents) in 100 % of the 144 rows | 95 % |

  The differences are what libmodplug adds and the renderer leaves out: interpolation between
  samples and volume ramps at note starts. With the arpeggio switched off in the renderer the check
  fails (correlation 0.79, a row at similarity 0.945), so it does see a missing effect.

## Recommendation

**Render at runtime in GDScript, on a WorkerThreadPool thread, into plain AudioStreamWAVs; switch
and crossfade with two AudioStreamPlayers that the director times on the beat; render transitions
that must be sample-exact (fill into loop) into one stream.**

- **Speed is no problem.** The music is short loops: an 8-bar loop at 44.1 kHz stereo renders in
  about 0.2 s, a fill in 0.03 s, on a worker, while the frames stay as they are. Even a whole
  minute takes 1.1 s. A native renderer would be 100 times faster, but nothing here needs that.
- **The main thread pays almost nothing** (0.06 ms per render to take and play it), as long as no
  copy of the data is made on it (a copy of a minute costs 12 to 21 ms).
- **Memory:** 2.2 MB per 8-bar loop at 44.1 kHz stereo; 22.05 kHz mono would quarter it, if memory
  ever matters (the renderer plays samples without interpolation, as the Amiga did, so the lower
  rate keeps the style).
- **Exact:** it matches libmodplug, loops seamlessly, and lands the fill and the loop on the bar,
  sample for sample, because the renderer can play parts one after the other (`[fill, loop]`) into
  one stream.
- **Switching:** AudioStreamInteractive would do beat-synced crossfades by itself, but only with the
  script subclass, which crashes the quit (above). Until that is understood, keep the subclass out
  of anything that plays: the director (task 171) knows the BPM and the playback position
  (`get_playback_position()` plus `AudioServer.get_time_since_last_mix()`), so it can start a
  crossfade between two players at the next beat within a mix buffer (about 10 ms at a 400 ms
  beat), and hard cuts that need to be exact are rendered into one stream. If the crash is found to
  be avoidable (for example by freeing the music player in a set order before quitting), switching
  to AudioStreamInteractive with `MusicStreamWAV` is a small change.
- **Not a native GDExtension around libopenmpt:** it would be about 100 times faster, but it needs a
  C++ build per platform and a third-party library in the export, for speed the game doesn't need.
- **Build-time renders** (OGG files made by `make art`, which Godot imports with BPM and loop
  settings, so AudioStreamInteractive works with no subclass) remain the fallback: no runtime cost
  at all, about 1 MB a minute on disk, but every variation has to be rendered ahead, and the
  modules become a build step only.

Numbers to watch when task 170 builds it: render time on the slowest machine the game should run
on (GDScript is about 55x real time at 44.1 kHz stereo here, so a machine 10 times slower still
renders a loop in 2 s), and whether the crash on quit also happens in the editor and in an exported
game.
