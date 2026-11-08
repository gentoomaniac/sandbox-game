# Tools: the art and sound generators

Every picture and every sound of the game is made by the Python code here. There are no
hand-drawn files to edit: change the code, run `make assets`, and look at the result. The
output is deterministic, so a change that should not alter a picture leaves it byte for byte
the same (`git status` after `make assets` shows what moved).

```sh
make assets    # all art (the classic art first), all sounds, then the palette and sound checks
make classic-assets  # just the classic art under assets/classic/
make venv      # just the Python environment (make assets does this itself)
```

`make assets` needs Python 3 and nothing else (no Godot). The pinned packages are in
[requirements.txt](requirements.txt). After new art, `make run`, `make test` and
`make screenshot` import it themselves.

## Tests: tools/run_tests.py

`make test` runs it. It spreads tests/test_*.gd over `TEST_JOBS` headless Godot processes
(default 8; `TEST_JOBS=1` is one process), each with its own `user://` (`build/user-data-<i>`)
and log (`build/test-<i>.log`), and kills them after `TEST_TIMEOUT` seconds (default 600, the
whole run), counting that as a failure. The files are balanced by their duration in the last
run (`build/test-times`, from GUT's junit output), by file size until a file has a time.
`build/test.log` is the shard logs joined plus a summary (Passing Tests, Failing Tests,
`[Failed] file: test`, time); the exit status is non-zero if any shard or check fails.

## Art: tools/art/

`generate.py` is the entry point: it assembles the object atlas and `main()` writes every
file under `assets/`, one small `write_...` function per family. The drawing is in the modules
by topic. Where is a thing drawn?

| Module | What it draws |
|---|---|
| `contrast_sheet.py` | `make contrast-sheet` (after `make assets`): the tall grass, fern and reeds (or the atlas rows named in `KINDS="willow shrub"`) over the grass, lush grass, dry grass and floodplain of every look (each season, frost, snow, and night) into `build/contrast_sheet.png`, to check contrast by eye. |
| `generate.py` | The object atlas (`object_atlas()`, with the numbered table of its rows), the writers, `main()`, and `DOUBLED` with `scale_up_16_px_art()`: the files still drawn at 16 px per tile, scaled up to the game's 32 px tile pixel for pixel (see [docs/art-style.md](../docs/art-style.md), "Resolution"). |
| `canvas.py` | The shared basics: `TILE` (the 16 px the art is drawn at), `GAME_TILE` (the game's 32 px tile), the size of an object cell, `blank`, `filled`, `copy`, a clipped `rect`, and the two outline helpers: `outline` (a ring outside the drawing) and `outline_edge` (recolours the drawing's border). |
| `palette.py` | The palette, `DARKEST_OF` (the colour that outlines each ramp), `to_image`, `save` (one PNG under `assets/`) and the palette check. |
| `terrain.py` | The ground: water, floodplain, wetland, grass, soil, and their decorations. |
| `flowers.py` | The meadow flowers of the region: the flower row of the decoration atlas. |
| `trees.py` | Oak, spruce, pine, dead tree, bushes, ferns, stones, boulders and stumps, and the shared tree parts (crowns of shaded blobs, trunks, bare twigs). |
| `beech.py`, `birch.py`, `alder.py` | The beech, the birch and the alder, in leaf and bare. |
| `willow.py` | The pollard willow, in leaf and bare. |
| `camp.py` | The fireplace and the bedroll. |
| `character.py` | The player's layers at 32 px per tile (body, breeches and stockings, clogs, shirt and waistcoat, jacket, hair, hats, hoe), all drawn on one `Figure` (where the head, arms and legs are in a frame), their passing out, sitting on a horse and the sleeping "z". |
| `villagers.py` | The villagers' layers on the same figure: the women's dress (bodice, skirt, apron, shawl, coif, headscarf), other skins, hair colours and cloth, the felt hat, the tricorne and the white stocking cap. |
| `forms.py` | Rounded shapes as masks (ellipse, capsule, polygon, rounded box) and their shading by the light from the top left, for the figures of character.py and villagers.py and the farm animals of livestock.py. |
| `portraits.py` | The 32x32 chat portrait of every layer that shows in a bust: the top of its frame facing the viewer. |
| `interior.py` | The room tiles and the furniture inside the buildings, the hearth too. |
| `buildings.py` | The shack, Kate, longhouse, hall house and barn, plain and with lit windows. |
| `church.py` | The church and its bell frame (as buildings.py), and the graves of the churchyard (a row of the object atlas). |
| `seasons.py` | The other looks (spring, autumn, bare, frost, snow, dusting, leaf-out steps) made from the summer art by colour remaps and overlays. Also adds its colours to the palette. |
| `crops.py`, `crop_icons.py` | Crop sheets (growth stages and the dead one), seed bag and produce icons, wet soil. |
| `items.py`, `tool_icons.py`, `chest.py` | Item icons, the slot frames and the tools; the chest, which is drawn once for every use. |
| `boundaries.py` | The lines across the land, drawn as solids tile by tile with a picture per connection mask: the Knick, the wattle fence, the fieldstone wall and the dyke. |
| `coast.py` | The things of the Wadden coast: the Ewer lying on the mud. |
| `landing.py` | The fisherman's landing: the jetty (a picture per connection mask), the rowing boat, the net frame and the eel traps, and their icons. |
| `crafts.py` | The professions' art: the stations (workbench, kiln, bake oven) and the carved chest, each drawn once for the atlas, the interior and its icon, and the icons of what is made at them. |
| `trunks.py`, `meadow.py`, `reeds.py` | Felled trunks, tall grass and clay hint, reeds. |
| `fire.py` | The animation frames of the campfire and the hearth. |
| `animals.py` | One sheet per animal of the ambient wildlife. |
| `birds.py` | The sheets of the big birds of the marsh: the white stork and the greylag goose. |
| `livestock.py` | One sheet per farm animal and look (cows, sheep, hens, tame rabbits, dogs, cats, horses), drawn at 32 px per tile with forms.py: the four-legged ones share `quadruped_frame` (body and head as shaded polygons, legs through their joints set for each step, the face and marks by hand), the hen and the rabbit are drawn whole per pose. A horse also has a saddled sheet and the ridden horse's sheets (side, front and back, walking and trotting). It keeps `to_picture` for the 16 px birds until task 116. |
| `ui.py` | The pixel font, the panel frame and the button frames. |

`generate.py` imports all the others and none of them imports it; most import `canvas.py`, and
Of the art modules, `palette.py` imports only `seasons` (for its colours) and `canvas`.

Pictures are lists of rows of **palette colour names** (`None` is transparent), never RGB
values. The colours are `BASE_COLOURS` in `palette.py` plus `COLOURS` in `seasons.py`, merged
into `PALETTE` (a name in both fails), and the palette is limited to `MAX_PALETTE_COLOURS`
(when it is full, merge two similar colours to add one). A picture with a colour that is not
in it fails with "unknown colour X in <the file being written>". After writing,
`check_palette()` fails if any PNG under `assets/` has a colour outside the palette.

### The classic art: tools/art/classic/

The game can show the art of a group redrawn at 32 px per tile as it was before, the 16 px art
doubled (Settings → Display, F7; see `ArtSet` in game/scenes/art_set.gd). That classic art is
generated like the rest: tools/art/classic/ holds the old generators of the groups that went
native, copied from git history as they were, and its `generate.py` writes their files under
assets/classic/, with the same names as the new files under assets/, and doubles the world's
ones by its own `DOUBLED`. The old modules import their siblings there first and the shared
`canvas.py` and `palette.py` of tools/art/ after them; a later change to those two that an old
module trips over (a colour renamed) is made in the old module too. So far: the people (task
113), from commit 97e9736: `character.py`, `villagers.py` and `portraits.py` unchanged, and
`bubbles.py`, the thought bubble part of `ui.py`; the farm animals (task 114), from commit
2793065: `livestock.py` and `animals.py` (whose tame rabbit it draws from) unchanged. The cow's
and the horse's cells grew at 32 px, so `set_in_grown_cells` puts their classic cells in the
new ones (bottom centre), as the classic files must have the new cell sizes.

When a group goes native (docs/art-style.md, "Resolution"), before its redraw changes them:

1. Copy each module the group's old drawing is in from the commit before the redraw:
   `git show <commit>:tools/art/<module>.py > tools/art/classic/<module>.py`. Take a whole
   module, or just the group's part of a shared one (as `bubbles.py`), and change nothing but
   what it needs to run beside the others (an import, a path). If a module of that name is
   already there (two groups drawn in one module), add the group's part to it.
2. Add the group's old `write_...` lines to `main` in tools/art/classic/generate.py, writing to
   `f"{CLASSIC}/<path>"`, and its doubled globs to `DOUBLED` there.
3. `make assets`, and compare a few classic files with those of the commit
   (`git show <commit>:assets/<path>`): they are the same picture, byte for byte while nothing
   shared changed.

### Adding things

- **A colour:** a name and a hex value in `BASE_COLOURS` in `palette.py` (or in
  `seasons.COLOURS`, if only a season look needs it). Mind the limit above.
- **A sprite for something that already has a type** (an item, a furniture piece): draw it in
  the module of its topic and add it to `ICONS` (items) or to `furniture()` (interior.py; new
  pieces go at the end, the tile ids of the interior tileset are counted in that order). Item
  icons are named after the item id in `game/state/item_types.gd`; the 8x8 version for the
  ground is made for you.
- **A world object** (a tree, a rock, a plant): draw its variants in the module of its topic
  (`trees.py` for most), add a row to `object_atlas()` and to the numbered table above it
  (the table says the order; new rows go at the end), and give its type an
  `atlas_row` in `game/state/world_object_types.gd`. `generate.py` writes
  `assets/objects_rows.txt` from the rows it draws, and `tests/test_object_atlas.gd` compares
  it with every type's `atlas_row` and number of looks. A tree that leaves a trunk also has the
  two rows of `trunks.rows(<tree>)` (its bark in `trunks.SPECIES`), and its `trunk` names the
  first of them.
  `seasons.py` needs a winter look per kind: add one entry to `_WINTER_LOOKS` (a kind
  without one stops the build with its name), and look at the picture under snow.
- **A building:** its picture in `buildings.py` or `church.py` (`PICTURES`), its section in
  `data/buildings.cfg`, and its interior ([maps/README.md](../maps/README.md)).
- **A crop:** a section in `data/crops.cfg` and a sheet in `crops.py`; no game code.
- **A new kind of file** (a new family of PNGs): a `write_...` function in `generate.py` that
  calls `save` or `save_picture`, and a line in `main()`. If the world draws it and it is drawn
  at 16 px per tile, add it to `DOUBLED`.

### Seeds: why the art stays the same between runs

Variants (the three oaks, the stones) come from a seed, and a picture must come out the same
every time. So:

- Use `random.Random(seed)` with an integer seed that is written in the code, and nothing
  else for randomness. Never `hash()` of a string (Python changes it from run to run) and
  never the global `random` or the clock.
- **Draw order matters.** A random generator is a sequence: if you draw something new before
  another call to the same generator, everything after it changes. Add new random calls at
  the end of a function, or give the new part its own generator.
- A seed also picks the structure of a variant: `seed % 3` or `seed % 2` decides, say, how
  many branches or tiers a tree has. Choose the seeds of a new object so the variants differ
  (they are 101, 102, 103 for the oaks, 121 to 123 for the spruces).

## Sound: tools/audio/

`generate.py` is the entry point. `EVENTS` lists every sound event with its peak level in dBFS
and the functions that make its variants; it writes `assets/sounds/<event>_<n>.wav`. The
sounds themselves are in `footsteps.py`, `work.py`, `ui.py`, `weather.py` and `animals.py`,
built from the filters, noise, tones and envelopes of `dsp.py`. A variant is a function that
takes a random generator and returns samples.

| Command | What it does |
|---|---|
| `make assets` | Generates the sounds, then runs `check.py` on them. |
| `.venv/bin/python tools/audio/check.py --table` | Checks every file (format, clipping, DC offset, clicks, loop seams) and prints length, peak and level of each. |
| `.venv/bin/python tools/audio/preview.py out.wav` | Joins all sounds into one WAV to listen to, and prints when each starts. |

Each variant gets its own generator, seeded from the event name and the variant number, so
changing one sound leaves all the others the same. A loop (an event name ending in `_loop`)
is built as a circle, and its functions take `loop=True`.

**Adding a sound:** write the function in the module of its kind, add the event to `EVENTS`,
add the event to `SoundRules.EVENTS` (`game/state/sound_rules.gd`) and a section to
`data/sounds.cfg`, then make the game play it (for work and steps, `SoundEvents` decides which
event a happening makes; `GameSounds` and `AudioService` play it). To use a recording instead
of a generated sound, point the event's `files` in `data/sounds.cfg` at the recording.

## A local LLM for testing NPC talk: tools/llm/

`llm.sh` runs [Ollama](https://ollama.com) in a container (podman if present, else docker;
`CONTAINER=docker` forces one) with Qwen2.5 7B Instruct, on the NVIDIA GPU when the host
exposes it to containers (see below), else on the CPU. It serves an
OpenAI-compatible API at `http://127.0.0.1:11434/v1` (this machine only). The game never
needs it: `make test` does not touch it, unless `SANDBOX_LLM_URL=http://127.0.0.1:11434/v1`
is set, which runs the two tests that ask a real model. It is the game's default endpoint
(Settings → Language model), so villagers talk through it as soon as it is up (README,
"Talking NPCs with a language model").

```sh
make llm-up       # start the container, pull the model if missing; safe to repeat
make llm-check    # one chat request as a 1750s North Frisian villager, with the time taken
make llm-down     # remove the container; the model stays in its volume
make llm-down PURGE=1   # also delete the volume (the model)
make llm-pull LLM_MODEL=qwen2.5:3b-instruct   # fetch another model next to the first
make llm-models   # the models it has, with their sizes
make llm-check LLM_MODEL=qwen2.5:3b-instruct  # ask that one
make llm-eval LLM_MODEL=qwen2.5:3b-instruct   # the villagers' prompts on it, see below
make llm-rm LLM_MODEL=qwen2.5:3b-instruct     # delete it again
tools/llm/llm.sh status | logs
```

**Other models.** All pulled models sit side by side in the volume; the server loads the one
a request names. The game uses the model set under Settings → Language model → Model, so
after `make llm-pull` set it there (or `model="..."` under `[language_model]` in
`settings.cfg`). Sizes are Ollama's Q4 downloads; a model needs about that much free memory
plus 1-2 GB while it answers (RAM on the CPU, VRAM on the GPU):

| Tag | Size | Licence | Notes |
|---|---|---|---|
| `qwen2.5:1.5b-instruct` | 1.0 GB | Apache-2.0 | Fast, plainer lines |
| `qwen2.5:3b-instruct` | 1.9 GB | Qwen Research (non-commercial) | Twice as fast as the 7B; its lines drift into nonsense more often; testing only |
| `qwen2.5:7b-instruct` | 4.7 GB | Apache-2.0 | The default: stays in character, follows the chat and the language better; needs about 6 GB free |
| `llama3.2:3b` | 2.0 GB | Llama 3.2 Community | |
| `gemma2:2b` | 1.6 GB | Gemma Terms of Use | |

Which ones fit on the GPU (8 GB of VRAM here) is for later, with the GPU set up as below.

- **Model:** `qwen2.5:7b-instruct` (override with `LLM_MODEL=<ollama tag>`), 7.6B parameters,
  Q4_K_M, 4.7 GB, Apache-2.0. It is the default because, with the refined prompts, the 3B
  (`qwen2.5:3b-instruct`, 1.9 GB) was not about as good (see "Trying the prompts"). The 3B has
  the **Qwen Research License** (non-commercial), not Apache-2.0: the 3B size is the exception
  in the Qwen2.5 family. Fine for testing here; never ship it with the game.
  `qwen2.5:1.5b-instruct` is Apache-2.0 too.
- **Coming from the 3B:** settings.cfg keeps only what was changed, so unless the 3B was
  picked in Settings, the game now asks for the 7B. If only the 3B is pulled, the test LLM
  answers "model not found" and villagers say scripted lines until `make llm-up` (which pulls
  the default) or `make llm-pull LLM_MODEL=qwen2.5:7b-instruct` has run; or pick the 3B in
  Settings.
- **Where things live:** the container is `sandbox-game-llm`, the models are in the
  volume `sandbox-game-llm-models`, the image is the pinned `docker.io/ollama/ollama` tag in
  `llm.sh` (5.5 GB, from the container tool's image storage).
- **Remove everything:** `make llm-down PURGE=1`, then `podman rmi docker.io/ollama/ollama:<tag>`
  (or `docker rmi`).
- On 22 CPU cores the 7B answers a short line in two to four seconds (the 3B in one to two);
  speed is not a goal.
- **GPU:** `llm.sh up` passes the GPU in (`--device nvidia.com/gpu=all`, CDI) when a CDI spec
  for `nvidia.com/gpu` is in `/etc/cdi` or `/var/run/cdi`. `LLM_GPU=1` insists on the GPU,
  `LLM_GPU=0` keeps the CPU; a container started with the other setting is recreated.
  `make llm-check` ends with `ollama ps`, whose PROCESSOR column says `GPU` or `CPU`. One-time
  host setup (root; Gentoo, the RTX 4070 here):

  ```sh
  sudo emerge app-containers/nvidia-container-toolkit
  sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml   # again after each driver update
  nvidia-ctk cdi list   # should list nvidia.com/gpu=0 and nvidia.com/gpu=all
  ```

  With 8 GB of VRAM, the default `qwen2.5:7b-instruct` (4.7 GB) should fit on the GPU (not tried
  yet).

### Trying the prompts: `make llm-eval`

`make llm-eval LLM_MODEL=<tag>` (the test LLM must be up with that model; `LLM_RUNS=n` replies
per scenario, 3 by default) checks the villagers' prompts on a model. Godot builds the requests
with `NpcPrompt` itself (`tools/llm/dump_requests.gd`: 25 fixed scenarios, a greeting, rain at
dusk, switches of language (German after English, also in a longer chat, Danish after English,
English after German, a short "Moin" after German and "Hej" after Danish), Danish, Swedish
(which the game does not know), a phone, a car, a rude line, a fact from earlier in a long chat,
a villager with a memory, a memory summary, and keeping to the sheets: family (also in German),
the husband's name again after a long chat, another villager, the pastor, the Deichgraf (in
German), a sister or brother the villager doesn't have (also in German); Antje, Momme, Ocke and
Kerrin), so the tool never drifts from the game; `tools/llm/eval_prompts.py` sends each one `n` times at the configured
temperature and writes `build/llm-eval/<model>.md`: every reply, with crude checks (too long,
too many sentences, cut off, assistant phrases, label echo, copying the example or the player's
line, the wrong language by stop words and telling letters, a memory not in the first person,
none of the names a scenario expects (Hinrich or Boy for Antje's family, Martens for the pastor,
Momsen for the Deichgraf), a name of the region the request never mentions, that is made up).
The report gives the average prompt tokens too.
The checks only find what is plainly wrong; read the replies. `LLM_API_KEY` set in the
environment is sent as the bearer key, so that `tools/llm/eval_prompts.py --endpoint <url>
--model <name>` can try a hosted model, and `--requests <file>` sends the requests of an earlier
dump (to try old words again). The requests have the cut-down sheets a local model gets;
`--full-sheets` sends the full ones a hosted model gets (report `<model>-full.md`). To try them
on Gemini with your AI Studio key:

```
LLM_API_KEY=AIza... .venv/bin/python tools/llm/eval_prompts.py --full-sheets --runs 2 \
  --endpoint https://generativelanguage.googleapis.com/v1beta/openai --model gemini-3.1-flash-lite
```

On HTTP 429 (the free tier's limit) it stops and writes what it has; `--only <id> ...` runs a few
scenarios. `tools/llm/eval_prompts.py --compare <tag> <tag>` puts the
replies of two earlier runs side by side in `build/llm-eval/compare.md`. It takes about 2
minutes for the 3B and 4 for the 7B with 5 replies each. When the prompt words in
`data/npc_talk.cfg` change, run it on both and read the reports.
