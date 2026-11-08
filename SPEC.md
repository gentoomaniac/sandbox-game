# Sandbox Game: Spec

Status: playable prototype (the milestone 1 slice and much more; the README lists what
works today). Last updated: 2026-11-06.

This file is the single source of truth for what the game is. Decisions move from
"Open questions" to "Decided" as they are made.

## Vision

A top-down farming and life sim in the tradition of Stardew Valley and Harvest Moon. It
has much more exploration than those games, and optional real-time combat for players who
want it. Building is free: structures can be placed anywhere, and they are far more
customisable than the genre usually allows. The world reacts to seasons and weather:
rivers freeze, swell or block the way.

Art direction: 16-bit-era top-down pixel art, in the direction of Zelda: A Link to the
Past. World, characters, art and names are original; nothing is taken from existing games.

**Setting:** semi-fantasy, medieval. **Magic** comes later (see Later features).

**Lighting** gives the pixel art a slightly modernised retro look: modern light effects on
top of classic pixel art (details under "Lighting and look").

## Pillars

1. **Home loop:** farming and life sim as the steady core.
2. **Exploration:** a larger world with biomes and more to discover than is usual for the
   genre.
3. **Optional combat:** fighting is the player's choice; peaceful play stays fully viable.
4. **Free building:** construct anywhere; buildings are highly customisable.

## Decided

### General

- Perspective: top-down 2D, pixel art.
- The world is built from tile maps.
- Single-player for now. Multiplayer may come later, so don't make choices that rule it
  out. In practice: game state (world, entities, reputation) is kept separate from
  rendering and input, and it changes only through explicit actions.

### Lighting and look

- **Rendering in two stages:**
  1. The world is rendered **on the art-pixel grid** (one art pixel = one render pixel) into
     an off-screen image of at most about 640×360 plus a small margin. Lighting, tint and
     glow are computed there, so light lands exactly on the pixel grid.
  2. That image is scaled to the screen **steplessly** with a sharp-bilinear filter:
     pixels stay sharp, only one row of screen pixels blends at their edges. Zoom and
     camera movement stay smooth at any value, without uneven pixels.
- **UI** is rendered separately at native resolution.
- **Tiles: 32×32** (decided 2026-11-08, after the mockup in review/resolution-mockup-2026-11-08:
  the 16×16 art was "early PC, almost C64"; small animals and legs one pixel wide did not read).
  The widest view is a native 640×360 art pixels (20×11 tiles, the area the 16 px art showed at
  zoom 1), shown at a whole multiple on the usual screens (×3 at 1080p, ×4 at 1440p). Until all
  art is redrawn at 32 px, the generators' 16 px output is doubled pixel for pixel (tasks 106 and
  on); the people are drawn at 32 px since task 113. The 16 px art of a redrawn group stays in
  the game as the classic art, a setting (see Settings). (Was: 16×16, 320×180 at zoom 1.)
- **Stepless zoom** from the widest view (640×360 art pixels, zoom 1) in to 2× (320×180); the
  game starts at the widest (the user zooms out fully anyway, 2026-11-08). Ctrl and the mouse
  wheel zoom; the wheel alone steps through the hotbar. (Was: 0.5× to 2×, starting at 0.5×.)
- **Smooth camera following:** the camera follows the player's exact position, so the
  world scrolls at sub-pixel precision; the player, drawn on the pixel grid, may wobble by up
  to half an art pixel. Chosen over a pixel-locked camera (2026-11-05).
- **Camera API** for scripted moves (cutscenes later): follow a target, move to a point,
  zoom to a value, chain moves in a sequence. The mouse wheel uses the same zoom.
- **Standard effects:**
  - **day and night tint:** the whole picture changes colour with the time of day (warm
    morning, neutral noon, orange dusk, blue night);
  - **point lights:** campfire, torches, lit windows at night, with a slight flicker.
    Dark nights make light sources valuable, which ties in with keeping creatures away;
  - **subtle glow/bloom** on bright light sources. Keep it subtle.
- **Later: normal maps** on sprites and tiles, so light gives the pixel art relief. This
  is mostly an art cost. Code should not rule it out.
- **See-through occluders:** when the character is behind something (tree, building,
  other tall object), that object becomes translucent in a soft-edged circle around the
  character, so the character stays visible. Only objects in front of the character fade;
  objects behind it stay as they are. Defaults (tunable): radius about 2 tiles around
  the character's centre, about 35 % opacity inside, soft edge.
- **Left out for now:** shadows cast by objects.

### Art pipeline

- Assets are created by Claude for now, in a **semi-fantasy/medieval pixel style**.
- They come from a **generator script** (`make assets`). The generated PNGs are
  committed. Hand-drawn PNGs may replace single files later.
- **One fixed palette** (own palette, see Style rules for its size): earthy greens and browns,
  muted blue water, warm accents for fire and light, room for magic colours. All assets
  use only palette colours.
- **Terrain transitions (autotiling)** from the first art pass, so terrains blend
  instead of meeting as hard squares.
- **Style rules** (from the art review):
  - outlines: outer outline in the darkest colour of the object's own colour ramp; ink only
    for characters and interactable pickups; no outlines on terrain; plants with loose blades
    (tall grass, fern, reeds) get a ground shadow, a dense foot in the two darkest shades
    rimmed in the ramp's darkest, and light shades above, never an outline round single blades;
    the helpers are `canvas.outline` and `canvas.outline_edge`, the ramp table `palette.DARKEST_OF`;
  - light from the top left everywhere;
  - every standing thing gets a small contact shadow;
  - houses and interiors in 3/4 view like trees and characters;
  - 2–4 px detail clusters, not single-pixel noise.
- **Palette:** "about 32" is loosened to **up to ~48 colours**, so snow/ice, a berry red and
  a cool shadow grey fit; merge near-duplicate greens. The seasonal looks (spring greens,
  autumn leaves, snow) raise the cap to **about 64** (decided 2026-11-05). The style guide's
  swaps (task 52): `meadow_dark`, `lush`, `crimson` and `frost_light` merged into their
  neighbours; `meadow_light` stays, as the Scots pine's lit needles; `lime` (lime-wash),
  `paint_teal` (doors and shutters), `heather` and `heather_dark` added. `arcane` and
  `spirit` are kept for magic only. 64 of 64 used: a new colour needs a merge first.
- **Variety:** the world must not look tiled.
  - Large-scale colour variation: terrain colour shifts slowly across the world (e.g.
    lusher, drier, yellower patches of grass), driven by low-frequency noise in world
    coordinates.
  - Many variants per terrain, including the edge shapes.
  - A **visual-only decoration layer** (flowers, clover, pebbles, small plants) scattered
    unevenly on top of terrain. It has no gameplay effect and is not a world object.
  - **Flowering meadows** (decided 2026-11-06, task 75): in spring and summer the green
    flowers with the meadow and pasture flowers of the region, in drifts and patches by a
    seeded noise, not evenly sprinkled. Each habitat has its chance and its communities of
    species that bloom one after another (`data/flowers.cfg`): dense on meadow grass and the
    floodplain, heather on the dry Geest, cuckooflower and meadowsweet on wet ground, few
    (wood anemone, red campion) in the woods, none on fields or water. A tile shows its
    species furthest into its bloom, so the species of a drift mix and the drift changes
    colour with the weeks; a species' first and last flowers are small ones. Early spring has
    few, late spring and summer are full, autumn fades and winter has none. When a tile
    blooms nothing, its ordinary decoration shows.
- **Desire paths** (decided 2026-11-06, task 77): ways walked often wear into paths with
  less grass. Every tile the player steps onto outdoors takes a step of wear (a farm animal
  half a step); a tile turns trodden (thin, flattened grass with the earth showing) and then
  a path of bare earth, and each night takes some wear off, so an unused path grows back to
  grass in about two weeks. Numbers in `data/paths.cfg`: trodden from 8 steps, a path from
  24, at most 32, 2 a night; walking the same line about eight times a day makes a path in
  four or five days. Only grass (ordinary, lush, dry) and the floodplain wear; fields,
  wetland, water, buildings (their doors too) and interiors don't. Worn tiles lose their
  flowers and tufts. A path is a look only: no change to speed or farming, and tilling it
  works as on grass (and clears the wear). Drawn as two dual-grid layers over the grass,
  with soft dithered edges, in every season's look and the frost; snow covers paths, with a
  faint trodden track over them; in a bare winter the earth lies dark. The wear is saved
  (only worn tiles, dropped once they have grown back).
- **Floodplain looks fertile:** lush, damp meadow, with a narrow muddy bank right at the
  water. It must not read as barren sand.

### Saving (first version)

- Save format: seed + world edits (terrain, objects and the wear of desire paths) + buildings with their interiors +
  player state (position, current map, home, appearance, inventory) + clock. One JSON
  file per world under `user://saves/`.
- **Autosave when the player sleeps, passes out and when the game quits.** On start, the
  game loads the save if there is one, otherwise it starts a new game (`--new-game` forces
  one).
- **Upgrades kept for ten steps** (the user, 2026-11-08): the game is in
  development, so a save of version `VERSION - 10` to `VERSION` is upgraded step by step on
  load (13 to 23 today); an older one is refused like any unreadable save (renamed `.bak`,
  a new game). When `VERSION` goes up, the oldest step, its constants, helpers and tests go,
  in a commit of its own titled `Save: drop the upgrade from version <N> (oldest read: <N+1>)`.
  To rescue an older save, find that commit with `git log --grep '^Save: drop'`, check out
  its parent (which still upgrades it), load and save the game there, then move on.
- No save menu or multiple slots yet; revisit when there is a main menu.

### Tile state (architecture)

- A tile is **state, not a fixed picture**: terrain type plus dynamic properties (for now
  only frozen).
- What a tile looks like and whether it can be walked on or built on are **derived from
  that state**.
- This applies from the prototype on, even before weather exists. The chunk and tile code
  must not need rewriting when weather arrives.
- Handcrafted Tiled maps use the same tile properties (as Tiled custom properties), so
  they react to weather like generated land.

### Tech

- Engine: **Godot 4.x**, language: **GDScript**. The exact version is pinned in the project
  (e.g. a `.godot-version` file), and `make setup` checks that the installed Godot
  matches.
- Tiled maps (`.tmx`) are read at runtime by our own small loader (`InteriorLoader`). The
  `.tmx` file stays the source of truth; there is no manual export step. (Decided
  2026-11-05: the YATI importer addon does not run on the Gentoo Godot build and was
  removed.)
- Build, run, test and other multi-step tasks are wrapped in **make** targets, so each one
  is a single command.
- **`make setup`** sets up the stack:
  - it installs what it can automatically: project-local addons (GUT) and
    Python tools in a project-local venv;
  - it does not try to install system packages, because the developer machine may run a
    less common Linux distro (e.g. Gentoo). It checks system dependencies (Godot, Python,
    git, curl; Tiled is optional, only for editing interiors) and prints which ones are
    missing, with a hint on what to install;
  - running it again is safe and only does what is still missing.
- Targets (`make help` lists them): `help` (the default), `setup`, `venv`, `run`,
  `screenshot`, `test`, `lint`, `format`, `assets`, `clean` and `export` (a placeholder: no
  export presets exist yet).
- Tools:
  - test LLM for NPC talk (decided 2026-11-06): `make llm-up`, `llm-check` and `llm-down`
    run Ollama (pinned tag) in a podman/docker container with Qwen2.5 7B Instruct (Apache-2.0;
    the 3B has the Qwen Research License and was not as good, 2026-11-07) on the CPU,
    OpenAI-compatible API on 127.0.0.1:11434/v1 (`tools/llm/llm.sh`); no test needs it;
    `make llm-eval` tries the villagers' prompts on a model (`tools/llm/`);
  - tests: **GUT**, run headless by `make test`;
  - lint and format: gdtoolkit (`gdlint` / `gdformat`).

### Player

- **Energy bar:** actions use up energy.
  - Carrying weight increases how much energy actions use.
  - **At zero energy the player passes out** and wakes up in their bed. They lose no items
    or money, but they get a **debuff for the next day**: very slow walking, low health,
    very little energy. The real loss is the time: crops and other chores may go
    untended.
  - A game setting scales how fast energy drains.
  - Details (decided 2026-11-05):
    - **Energy and health bars**, 100 points each, next to the hotbar. A bar at 20 % or
      less pulses to show it is low. Health matters once combat exists; for now only the
      pass-out debuff and sleep change it.
    - **Costs per action** live in a hand-editable data file (`data/energy.cfg`). First
      values: tool use (till, hit, water) 2, planting and picking 0.5; walking is free.
    - **Weight:** up to 40 kg costs nothing extra (changed 2026-11-06, was 20 kg); above
      that, +10 % cost per 10 kg more. Tools weigh nothing (task 72).
    - **Low energy slows walking:** at 10 % or less to 75 % speed, below 5 % to 50 %.
    - **Passing out** at 0 (changed 2026-11-05): the player sleeps until the next 06:30,
      but at least 10 hours (collapsing at 22:00 wakes at 08:00, at 15:00 at 06:30), and
      wakes in the home bed. That day: half walking speed, energy only up to 50 %, health
      25. Speed effects don't stack; the slowest wins. The debuff lasts until the next
      midnight; sleeping does not end it early.
    - **Staying up too late** (decided 2026-11-05): a player still awake at 01:00 passes
      out as well, with the same flow and debuff (the 10-hour minimum wakes them at 11:00);
      the message says they stayed up too late instead of running out of energy. Only time
      the player lives through counts: a console `skip` over 01:00 does not make them pass
      out (like it costs no energy), and sleeping over it of course doesn't either.
    - **How passing out looks** (decided 2026-11-05): the player stops, can't be
      controlled, sinks to the knees, tips over and lies asleep with rising "z"s (about
      1.5 s, the world keeps running), then the screen fades to black. A short message fades
      in: what happened, how long they slept, where they wake ("at home" or "at the camp")
      and what the debuff does, e.g. "You collapsed from exhaustion. You slept 10 hours and
      wake at the camp, still worn out: slow, weak and with half your energy until
      midnight." After a key or click it fades into the bed in the morning. The asleep
      frames are reused for sleeping on the ground later. The collapse is drawn from the
      side: a player facing up or down falls to the right. The held tool is not drawn while
      down. The clock stands still while the screen is black.
    - **Signs of tiredness** (decided 2026-11-05):
      - **Sweat:** while energy is at 20 % or less, every action (tool hit, till, water,
        mow, dig, plant, pick) throws one sweat drop off the head; at 10 % or less two or
        three, in a slightly bigger arc.
      - **Thought bubble** (changed 2026-11-05): a small "zzz…" bubble pops up above the
        player for about 2 s at 00:00 and again at 00:30 while they are awake, as the
        warning before passing out at 01:00. It is only the late-hour warning; low energy
        shows by sweat alone.
        The bubble is a general system: an icon in a bubble over the player, to be used
        later for other states (cold, hungry, a question mark, ...).
    - **Sleeping** fills energy and health per bed (sleeping bag 100 %, ground 50 %), and
      **eating** food (berries, turnips) restores a little energy. Both are values in the
      data file (`data/energy.cfg`).
    - The energy drain setting: Low ×0.5, Normal ×1, High ×1.5.
- **Home is the last bed the player slept in**, like a spawn point. Passing out wakes the
  player there.
- **Waking in the bed** (decided 2026-11-06, after a player woke behind a bed and was stuck):
  after sleeping and after passing out the player wakes lying in the middle of the bed, head
  on the pillow and the body under the blanket (the asleep frame of the collapse, turned to
  the bed; the bedroll at the camp has its own cover, `ObjectCover`). The beds of the houses
  are drawn in layers: frame and pillow under the player, the blanket over them while they
  lie there. Beds block walking (the bedroll does not). **Getting out** (decided 2026-11-06, after
  players walked into the cupboard bed): the first move puts the player on the free tile beside
  the bed in the direction they pressed; if that is a wall or taken, on a free tile at the front
  of the bed (opposite its head, facing into the room), else at its sides, never behind it.
  Then they walk on. A player standing where they do not fit (an old save, or one made in
  bed) walks through objects, not walls, until they are free, so nobody is stuck.
  Nothing of this is saved: a game saved in bed loads with the player standing on it.
- **Starting shelter:** the game starts at a small camp site with a fireplace and a
  bedroll, so there is always a bed. The bedroll (task 52, replacing a modern sleeping bag)
  is a straw sack with a rolled grey wool blanket; its type id stays `sleeping_bag`, so
  saves and `data/energy.cfg` are unchanged. It has snow and frost looks.
- **The player can sleep without a bed** (on the ground, anywhere), with a real penalty:
  - energy fills to only 50 %;
  - it does not set home;
  - in dangerous areas, creatures can attack the sleeping player;
  - there is no next-day debuff. That stays unique to passing out, so the two feel
    different.
- **Sleep lasts until the next morning** (changed 2026-11-05, replaces the fixed duration
  per bed): sleeping always wakes the player at the next 06:30, whenever they lie down
  (after midnight that is the same morning). The screen fades to black and back, showing
  the new day briefly (its date on the black), with no key press. Beds differ only in what
  they restore.
- **Later: sleeping quality depends on the bed.**
  - The sleeping bag is the baseline: it fills the energy bar to 100 %.
  - Better beds may fill the bar a little above 100 %. Better beds should feel like a
    bonus, not like escaping a penalty.
  - Other bed bonuses come later.
  - Left out for now: less energy when going to bed very late (a 05:00 nap still refills
    fully).
- **Tile targeting with the mouse:** the tile highlight follows the mouse cursor.
  - Within reach (the 3×3 tiles around the player for hand tools; later tools may reach
    further), the highlight shows normally, and the action (left click or Space) works on
    that tile.
  - Out of reach, the highlight turns translucent red and the action does nothing.
  - When the mouse hasn't moved for a few seconds, the highlight fades out. Then the
    keyboard action (Space) works on the tile the player faces, as before, and the
    highlight shows that tile again once the player moves.
- **Inventory and equipment** (decided 2026-11-05):
  - The **hotbar** (8 slots, shown at the bottom of the screen; 10 until task 72) and the
    **backpack** (20 slots) are separate (changed 2026-11-05): what is on the hotbar takes no
    backpack space, so the player carries 28 slots. Screens show the backpack (4 rows of 5);
    the hotbar is only the HUD's (changed 2026-11-06, task 88): while the character or chest
    screen is open it stays lit, above the screens' dimmed backdrop, and is the quick bar
    there (its slots take the clicks; the screens draw no copy of it). A version 10 save moves
    what lay in the two dropped hotbar slots into the backpack (onto a stack of the same item
    first), or onto the ground at the player's feet when the backpack is full.
    Shift+click from a chest sends a stack to the backpack first, then the hotbar. Picked-up
    items join a matching stack first, then take the first free slot, hotbar before backpack. Backpack upgrades later add rows to the backpack.
  - The selected hotbar slot is what the player holds: keys 1–8 pick a slot. The use
    action (left click or Space) acts with the held item.
  - Items of the same kind stack, up to 99 per slot; tools don't stack.
  - Every item has a weight; the total carried weight raises how much energy actions use
    (see Energy).
  - An inventory screen shows all slots; items can be moved between slots. Putting the picked
    stack on a different item swaps and the other item is picked up in turn (task 88); the same
    item stacks. Shift+click on the character screen sends a stack from the backpack to the
    hotbar and back (onto stacks of the same item first, then the first free slot, as far as
    there is room); in a chest screen it sends it to the other side.
  - **Dropping** (task 88): a left click outside the screen's panel with a backpack or hotbar
    stack picked, or the rebindable `drop_item` action (T) for the held stack, puts the stack on
    the ground in front of the player as piles like any drop (not inside a house). Such piles
    are not pulled back until the player has walked out of reach of them; then they are
    collected as usual.
- **Character screen** (decided 2026-11-05): Tab opens one screen with the character and
  their equipment on one side and the inventory on the other.
  - Equipment slots: head, body, legs, feet, coat, back, main hand, off hand (coat added in
    task 53, for a jacket over the body item). Clothes, armour
    and later weapons, shields and backpacks are items with a slot; worn items show on the
    character (each slot is a sprite layer).
  - Items move between inventory slots and fitting equipment slots by clicking (pick up,
    put down, swap); an item only goes into a slot it fits, and fitting slots light up
    while an item is picked up. Right-click equips or unequips at once.
  - Worn items count toward the carried weight.
  - Hair and body are the character's look, not equipment.
  - New game (period clothes since task 53, North Sea coast 1700–1800): a red waistcoat
    over a linen shirt, brown knee breeches with white stockings and wooden clogs worn; a
    straw hat, a knitted cap, a spare linen shirt and a short blue jacket in the inventory.
    The clothes are light (0.3 to 0.6 kg) and the tools weigh nothing, so a new game carries
    2.9 kg, far under the 40 kg that cost no extra energy. Three hair styles: short, shoulder length, and long tied back
    with a ribbon. Old saves (version 8) get the tunic and trousers renamed to the waistcoat
    and breeches and clogs on their bare feet. The straw hat has a low crown and a wide brim drooping at its ends (task 52,
    it read as a pith helmet); the knitted cap is a red wool stocking cap, as the guide's
    period dress has it.
- **Movement keys:** arrow keys and WASD (decided 2026-11-05). All keys can be changed in
  the settings (see Menus and settings).
- **Scale between character and world:** the character figure is 61 px tall (hat to soles)
  in its 32×64 frame (task 113; 27–28 px in 16×32 before). Mature trees are about 2–2.5× the
  character, a small house about 3.4× (5×3 footprint, door at least as tall as the
  character); numbers in `docs/archive/art-review-2026-11-05.md`, in pixels of the 16 px art.
- **Character sprite: 32×64 pixels** (one tile wide, two tall; 16×32 before task 113), built
  from **layers** (body, clothes, head/hair, held tool or weapon, later gear), so equipment
  can be shown by swapping or adding a layer instead of redrawing the character. Every layer
  is drawn on the same figure, so they line up; the faces have eyes with a glint, brows, a
  nose shadow, cheeks and a mouth. The player and the villagers stand on a small contact
  shadow, as the animals do.
- **Tools** are bought and upgraded (decided 2026-11-05):
  - The player starts with a hoe, axe, pickaxe, watering can, scythe, shovel and a bag of
    turnip seeds, all tools at level 1.
  - Upgrades later come from a smith in a settlement, in tiers (level 2 copper, level 3
    iron, as palette swaps of the same icon).
  - The tool decides the action: hoe tills, seeds plant, axe fells, pickaxe mines, the
    watering can wets tilled soil, the scythe mows tall grass, the shovel digs for clay,
    an empty hand harvests crops, clears dead ones and picks bushes.

### Sound

Decided 2026-11-05. Everything makes sound; no background music for now.

- **All sounds are generated** by a script (`tools/audio/`, run by `make assets`), like
  the art: deterministic, in the repo, retro in style, with a few variants per sound
  and a little pitch variation when played. **`data/sounds.cfg`** maps every sound event
  to its files, volume and pitch range, so any sound can later be replaced by a recording
  without touching code. The loops carry their loop points in the WAV file (a "smpl"
  chunk), which Godot's importer reads, so they loop without any setting in the game.
- **World sounds come from where they happen** (positional), on an Effects or Ambience
  bus. Inside a house the weather and the world outside are muffled.
- **Footsteps** follow the walk animation and the ground: grass, soil, sand or floodplain,
  wetland (squelch), ice, snow (crunch), wooden floor.
- **Work:** axe chop, a tree's crack and thud when it falls, pickaxe on stone, stone
  breaking, scythe swish, shovel dig, hoe, watering, planting, picking a bush, a soft pop
  when an item on the ground is collected, placing a building, and a short "denied" sound
  (e.g. needs a better tool).
- **UI:** clicks for menus, the inventory and the hotbar.
- **Weather (ambience):** rain and wind as loops that follow their strength and fade like
  the weather visuals, wind gusts, and thunder after a flash, delayed as if far away.
- **Animals:** birds sometimes chirp where they are; frogs croak near rivers and ponds in
  spring and summer, mostly in the evening and at night and when it is warm, louder the
  closer the player is; deer snort now and then and their hooves sound when they bound
  away; rabbits rustle when they flee; squirrels chatter; bees buzz softly at their
  flower. Butterflies are silent. Where frogs are about (task 80) a quiet chorus of them
  swells on spring and summer evenings, fuller with more frogs, as warm as the croaks need
  it. Storks clatter their bills (a dry, hollow rattle) about once a minute or so while one
  is in view; geese honk now and then and when they take off, a skein flying over more
  often. Both are rare and quieter than the farm animals.
- **How the ambience is made** (decided 2026-11-05, numbers in `data/ambience.cfg`): once
  a second the weather sets the loops: rain at its strength, wind from calm (silent) to
  full speed, and in wind a gust now and then plays `wind_gust` and swells the wind loop
  for a couple of seconds. Each lightning flash is followed by one thunder 1 to 9 seconds
  later, plain (not positional) on the Ambience bus. Birds chirp at a chance per second by
  season (winter few), part of the day (none at night) and rain (none in heavy rain), from
  a bird in view or else a tree near the player. Frogs look at some random tiles within 12
  of the player and croak at the nearest water or wetland among them, by season (none in
  winter, few in autumn), part of the day (mostly night), warmth (none below 4 °C, full
  from 16 °C) and distance. Deer, rabbits and squirrels make their sound now and then, and
  when they start to run. The nearest two bees within 4 tiles buzz quietly as loops that
  follow them (changed 2026-11-05: they were too loud and heard from too far). The world's
  effects are muffled in a house like the weather; birds and frogs fall silent there.

### Menus and settings

Decided 2026-11-05.

- **Escape opens the pause menu** (in build mode it first leaves build mode). The game
  pauses while it is open: Resume, Settings, Save and quit. A title screen comes later.
- **Settings:**
  - **Controls:** every game action with its keys. Click a binding, then press a key or
    mouse button to change it. Each action has up to two bindings. A key already used by
    another action moves to the new one, and the menu says so. "Reset to defaults" restores
    all keys.
  - **Display:** fullscreen or windowed, and the art: new (drawn at 32 px per tile) or classic
    (the 16 px art doubled, for the groups redrawn since; the rest is the same in both). F7
    switches the art on the fly (task 117, the user's wish of 2026-11-08).
  - **Game:** UI scale (a slider from 0.5× to 2×, the UI only, not the world), the
    energy drain (Low, Normal, High) and the day length variation (0–100 %).
  - **Audio:** Master, Effects and Ambience volume sliders, and "Sound in background"
    (off: the game is silent while its window is not focused).
  - Settings are saved in `user://settings.cfg`, separate from the save game.
  - Gamepads later.
- **Tooltips** (decided 2026-11-05): hovering a slot in the hotbar, the inventory or the
  equipment shows a small framed panel by the cursor: the item's name, kind and weight
  (each and stack), a one-line description, and what matters for its kind, from the data
  files: food the energy it gives back (and health once food restores any), tools their type and level, seeds what
  they grow and where they are planted, equipment its slot (stats once there are any).
  Settings show a short explanation on hover too.
- **UI look:** a pixel font and a framed panel (9-slice) in palette colours, in one shared
  Godot Theme that all UI uses.

### Coordinates display

Decided 2026-11-05. The player's tile coordinates in the top right corner (inside a
house: the room's, marked "House"). Off by default; F3 (rebindable, "Show coordinates")
toggles it. Not saved.

### Console

Decided 2026-11-05. A text console for testing and cheats.

- `/` opens it (a rebindable action like all keys); Escape or Enter on an empty line closes
  it. While it is open the game keeps running, but the player doesn't walk or act.
- Commands: `help`; `tp <x> <y>` (teleport to a world tile; from inside a house the player steps out there); `give <item>
  [count]` (into the inventory); `god` (toggle invincibility:
  health doesn't drop); `nodrain` (toggle: actions cost no energy); `noweight` (toggle:
  carried weight doesn't raise costs); `noclip` (toggle: nothing blocks the player, who stays
  on the map's tiles; turned off where they don't fit, they are put on the nearest free
  ground); `freeze` (toggle: the game clock stands still, so the day, crops and weather
  wait, while the player and the animals still move; `skip`, sleep and passing out still move
  it on). Later commands: `spawn` (villagers: `npc`; farm
  animals: `cow`, `sheep`, `chicken`, `rabbit`, `dog`, `cat`, `horse`; wild ones: `bird`,
  `wild_rabbit`, `squirrel`, `deer`, `bee`, `butterfly`, `flock`, `stork`, `roof_stork`,
  `geese`, `flying_geese`, `mouse`, `frog`), `weather`, `snow`, `crop`
  (see `help`), `reset` (puts the player in the bed they wake in, inside or out), and
  `skip <n>m|h|d` (let minutes, hours or days pass, at most a year; the
  nights in between pass as when sleeping, so crops grow).
- Tab completes command names and every argument with a fixed set of values: item ids,
  animal kinds, weather conditions, snow values. Each command lists its argument kinds in
  one table in the console code; numbers are not completed. `help <command>` and a missing
  or unknown name (`spawn`, `spawn unicorn`) list the animal kinds, weather conditions and
  snow values from that same table.
- Cheat toggles last for the session; they are not saved. A line in the HUD shows which
  are on.
- A history with up/down; output and errors in the console log. The input line keeps the
  focus while the console is open: clicks elsewhere don't take it, and it stays ready
  after Enter.
- Always available for now. Whether release builds lock it is decided later.

### Time, seasons and weather

- Days and seasons work as is usual for the genre: crops grow day by day, and the season
  decides what grows.
- **Seasons fade into each other; snow and frost come from the weather** (decided
  2026-11-05; replaces the hard switch of the art at a season's first day):
  - **Snow cover is weather-driven:** snow on the ground builds up while it snows and
    melts above 0 °C (faster in sunshine). It is derived from the weather history (no
    save needed). The ground, objects and roofs show snow only where there is snow
    cover, so the first frosty days of winter are not white yet.
  - **Patches:** each tile has a fixed threshold; snow shows on a tile while the cover is
    above it. So snow arrives as a dusting in patches, and in a thaw it melts away in
    patches over 2–3 days. By the start of spring it is gone.
  - **Frost:** below 0 °C without snow, grass and plants get a frosty look (pale,
    rimed), stronger the colder it is, fading as it warms by day.
  - **Foliage and grass blend** (changed 2026-11-06): every change of look takes 2 to 3
    days from the first day of its season to the full look, tile by tile and tree by tree
    (each has its own threshold), not on one morning and not over weeks. In spring the
    trees and bushes leaf out in visible steps within those days: bare, buds, small leaves,
    full leaves. Autumn colours and leaf fall come in the same way. Winter without snow is
    bare and brown-grey, not white. As built (task 51): each change starts the day before
    its season, so on the first day about a sixth has changed, half on the second, five in
    six on the third, and all is done on the fourth. Leaf fall is the change to the bare
    look at the start of winter (day 91). Each tree or bush leafs out over most of those
    days and shows each step for about a day; conifers, ferns and grass have no steps.
  - **Pines look like pines** (decided 2026-11-06): a Scots pine with a tall bare reddish
    trunk and a few flat dark blue-green needle clumps high up, so they don't read as
    young leafy trees; evergreen like the spruce, which stays as the second conifer. As
    built (redrawn in task 56, which found the first one bonsai-like and its orange trunk too
    loud): about 75 px tall, the trunk slightly crooked, grey-brown and furrowed below with a
    few dead branch stubs, a warm brown with a little red in its shade up in the crown; the
    crown is a loose, flat-topped umbrella of needle clumps on thin dark branches spreading from
    the top third. Snow lies on the clumps, frost pales them.
  - **Trees of the region** (task 56, 2026-11-06): the woods are broadleaved, as docs/art-style.md
    asks. Each species has its own silhouette and bark and every look: the **beech** a tall,
    smooth grey bole under a broad round dome, copper in autumn, a fan of fine grey twigs in
    winter; the **birch** a slender white trunk with black marks and a dark foot under a narrow,
    open crown with hanging strands, yellow in autumn, white limbs and fine brown twigs in
    winter; the **alder** a straight dark stem through a narrow, lumpy cone of dark leaves,
    which stays green late and goes dull green-brown, and in winter carries black cones and
    catkins; the **oak** stays as it was. All four leaf out in steps. Pine and spruce are the
    rare ones (below). Pollard willows by the ditches and hazel and hawthorn in the Knicks are
    those of task 54. No new colours: the birch's bark is `lime`, `stone_light` and `stone`.
- **Vegetation density follows the year** (decided 2026-11-05):
  - Ground cover (grass tufts, flowers, small plants, fallen leaves; the visual decoration
    layer) has a density per kind that follows a smooth yearly curve: grass tufts sparse
    in early spring, fullest in summer, thinning in autumn, a few dry stalks poking
    through the snow in winter; flowers bloom in spring and summer (each species on a
    curve of its own, see "Flowering meadows"), fallen leaves in
    autumn.
  - Each spot has a fixed random threshold (from the seed and position), and a plant shows
    while the current density is above it. So plants come and go one by one over days,
    not all on one morning.
  - Seasonal plants among the world objects (fern bushes and similar soft plants) die back
    in late autumn and regrow in spring the same way: while dormant they are not drawn,
    don't block and can't be harvested. Woody plants (trees, berry bushes, shrubs) stay
    all year and only change their look.
  - Fruit follows the season too: berry bushes carry berries from early summer to late
    autumn (each bush starting and ending on its own day, by the same threshold rule).
    Outside that window a bush shows without berries and can't be picked; picking within
    the window works as before (bears again after a few days).
  - Harvesting a seasonal plant still removes it as before; regrowth follows the existing
    rules.
- **Weather state** (decided 2026-11-05):
  - Four values: **humidity** (0–100 %), **wind speed** (m/s, with a direction),
    **temperature** (°C) and **sunlight** (0–100 %, cloud cover dims it).
  - Weather is a deterministic function of the world seed, the region and the game time
    (smooth noise over hours and days around a per-season baseline, plus a daily cycle:
    cool nights, warm afternoons, morning fog). Nothing needs saving, and any past or
    future moment can be asked for, e.g. "has it rained for three days?" for floods
    later.
  - Regions: the world is split into weather regions (for now one region for the whole
    world, since biomes don't exist yet; the API already takes a position).
  - **Conditions** are derived from the values: rain (high humidity, above freezing),
    snow (high humidity, at or below freezing), fog (very high humidity, little wind,
    mostly mornings), strong wind and storms, thunderstorms with lightning (warm, humid,
    windy). Each has an intensity 0–1.
  - **Seasons set the baselines:** spring mild and showery; summer warm and mostly dry
    with occasional thunderstorms; autumn cooler, windy, foggy and rainy; winter cold
    with snow.
  - **Ambient motion** (decided 2026-11-05, view only): plants sway with the wind (tree
    crowns, bushes, tall grass, reeds, crops, ground tufts; gentle on calm days, hard with
    gusts in a storm, each plant with its own phase, in whole art pixels with the stems
    fixed); water shimmers and ripples, choppier in wind; the campfire and hearth burn
    (decided 2026-11-05, task 48): their flames are a short loop of drawn frames (tongues
    that rise, split, lick sideways and fall back, tips that break off and go out), played
    at about 9 frames a second, each fire starting its loop at a frame picked by its place
    so neighbours don't burn in step; the logs and stones stay still and only the flame
    moves. Outdoors the flames lean and stretch downwind, more in a strong wind, and
    sparks drift with it; rain splatters small splashes on the ground (more in heavy
    rain); lily pads drift and bob a little; the tide comes and goes on the mud (task 61). It is
    all done by shaders, with no nodes or
    scripts per plant or fire: a pixel's sideways shift grows with its
    height above the plant's foot (the trunk or stem stays put), plants lean downwind and
    gust fronts sweep across the world with the wind; only the wind across the screen
    leans them. At a light air (about 2 m/s) only the tips of the bendiest plants flick a
    pixel now and then; in a storm tree tops swing up to 3 pixels. Water ripples only
    change plain water pixels, so banks, foam and lily pads keep their shape. Splashes are
    drawn under the objects and the player. The hearth's fire burns indoors too, but
    there is no wind inside, so it does not lean. Dead trees (bare snags), pebbles, fallen
    leaves, toadstools and puddles stay still; so does a tree while it is see-through or
    falling (it is a sprite then).
  - **Effects for now are visual only:** rain and snow particles (slanted by the wind),
    fog drifting over the world, wind streaks and blowing leaves, lightning flashes, and
    overcast skies dimming daylight. Nothing in the game reacts yet (crops, floods,
    frozen rivers, energy and the like come later); the state is ready for it. No
    effects inside buildings. Rain, snow, streaks, leaves and fog are anchored to the
    world, not the screen: they stay in place when the player walks.
- **Day length follows the year** (decided 2026-11-05, made milder the same day for
  gameplay): the game is set in the Nordics, but moderately. Sunrise and sunset move
  smoothly over the year (a curve, no steps between seasons): longest day in mid-summer
  about 16 hours (about 05:00–21:00), shortest in mid-winter about 8 hours (about
  08:15–16:15), 12 hours in mid-spring and mid-autumn. Solar noon moves with summer
  time (about 13:00 in summer, 12:15 in winter). Dawn and dusk tints follow sunrise and
  sunset. A setting (Settings → Game, "Day length variation", 0–100 %, default 100 %)
  scales the swing: 0 % gives 12-hour days all year.
- **A moderate climate that blends across seasons and follows the sun** (decided
  2026-11-05, made milder the same day): the season baselines are points on a smooth
  yearly curve, not plateaus, so late autumn already leans towards winter. Temperatures
  stay moderate for gameplay, roughly: spring 5–15 °C, summer 15–25 °C, autumn 15 down
  to 3 °C, winter −10 to 0 °C. **Below 0 °C happens only in winter**, so snow and frost
  only fall in winter; random variation brings warmer or cooler spells within those
  limits. Temperature rises while the sun is up and falls at night, by how strong the
  sunlight is (clouds warm less by day and cool less at night). Sunlight is 0 at night.
  Plant growth can later depend on these values.
- **Calendar** (decided 2026-11-05): four seasons of 30 days (Spring, Summer, Autumn,
  Winter), so a year has 120 days. The game starts on the 1st day of Spring, Year 1. The
  HUD shows "10th day of Spring Year 2 · 06:00".
- **The world looks like its season** (decided 2026-11-05): the current art is summer.
  Spring is a lighter, fresher green; autumn is North Sea autumn (task 52): oaks brown,
  ochre or copper, beeches copper, birches yellow, alders a dull green-brown (task 56), bushes
  yellow and ochre, red rare (no tree has it yet), and yellower
  grass; winter is snow-covered (snow on the ground, snow on evergreens, bare deciduous
  trees). The look changes when the season changes. This is the visual
  season only: frozen rivers, deep snow and other weather effects on tiles stay with the
  weather system. The season's look is only the base: the blend, snow and frost above
  decide per tile and per plant which look shows.
- **How the looks are drawn** (decided 2026-11-05): there are seven looks of the ground
  (spring, summer, autumn, bare = winter without snow, frost, snow and its thin fringe,
  dusting), each a recolour of the summer art made by the generator, and for objects two
  more, the steps of the leaf-out (buds and young leaves, drawn over the bare tree). The
  base terrain is summer; a look is drawn over it as a dual-grid overlay layer of its own
  (the same edge shapes as the terrain layers), so patches of autumn, bare ground, frost and
  snow have soft edges and no seams. The season looks and the frost have stacked layers for
  lush and dry grass and the desire paths too, like the terrain. Snow and frost lie over the season's look. Decorations,
  objects and houses pick their art by look instead. Snow cover comes from
  `data/seasons.cfg` ([snow]: snowfall adds, warmth and sun melt, counted hour by hour from
  the start of autumn; none from the first day of the year), the blend windows too; the view
  updates once a game hour, a few milliseconds per frame.
- **Weather and seasons change the map:**
  - frost freezes rivers so they can be crossed;
  - heavy, deep snow makes some areas unreachable;
  - several days of heavy rain make rivers swell.
- **Weather is per biome:** e.g. snow in the mountains while it rains in the lowlands.
  Weather is simulated per region, not as one global value.
- **Floods only reach floodplains.** The generator marks floodplains along rivers. Water
  from swelling rivers spreads only there.
- **Floodplains are farmland with a risk:**
  - their soil is especially fertile;
  - a flood washes away and destroys crops on them;
  - a flood leaves some debris items behind, for immersion.

### Farming and foraging

- **Crops** (decided 2026-11-05, extended the same day): classic crops beside the
  turnip, all defined in a hand-editable data file (`data/crops.cfg`).
  - **One picture sheet per crop** (`assets/crops/<crop>.png`): 4 growth stages and a
    dead stage, side by side. A new crop is a new section in the config plus its sheet;
    no code. The built-in crops' sheets come from the art generator.
  - First set: turnip, potato, carrot, cabbage, onion, wheat, peas (regrow), beans
    (regrow), flax, strawberries (regrow) and pumpkin.
  - **Flax replaced tomatoes** (task 52; tomatoes weren't a farm crop here before the 19th
    century): a cool-weather fibre crop with sky-blue flowers, pulled up whole (no regrow).
    It yields a new `flax` item (flax stalks), not `fibre`: flax is a material of its own
    (retted and scutched it becomes linen fibre, a later crafting step), and every crop's
    produce is its own item built from `data/crops.cfg`, while `fibre` comes from bushes.
    Flax isn't food. Save version 7 turns tomatoes and tomato plants into flax and flax
    seeds wherever they are. Strawberries are the small wild kind, and the pumpkin is
    drawn as a small green garden squash (its id stays `pumpkin`).
  - **Seed sacks tell their crop at a glance** (task 52): each sack is tied with a string
    of the crop's colour, has the crop painted large on its front and a few of its seeds
    spilled in front.
  - **Crops need light, water and warmth to grow**, with the needs per crop in the
    config: a temperature range (minimum, best, maximum), the sunlight they need per
    day, the soil moisture they need, and how much wind they stand. Each night a crop
    grows by how well the day met its needs (good days count fully, poor days partly,
    bad days not at all) and moves to the next stage after enough growth.
  - **Crops can die:** days without enough sun or water, frost below the crop's
    minimum, or wind above its tolerance (beans and flax are fragile, wheat bends)
    damage the crop; enough damage and it dies and shows its dead stage, which the empty
    hand clears. Damage heals slowly on good days.
  - **Ripe crops must be harvested in time** (decided 2026-11-05): a ripe crop waits as
    many days as it took to ripen (since planting, or since it regrew), times its
    `ripe_wait_factor` in the config (1 for all crops for now). One day more and it
    withers: it dies, shows its dead stage and gives nothing. The player harvests by hand.
  - **Soil moisture** belongs to each tilled tile: rain wets it, the watering can fills
    it, and warmth, sun and wind dry it out over the day. Watered soil looks darker.
  - The calendar no longer gates planting: the weather does. Seeds plant on tilled soil
    any time; a crop planted in the wrong season simply won't thrive.
  - Each crop has its own seeds (a seed bag item, seed potatoes for potatoes) and its
    produce item; produce can be eaten (food values in `data/energy.cfg`).
  - Until a shop exists, seeds come from the console (`give`), and a harvest still gives
    one seed back.
- Wild crops can be foraged.
- The biome decides which resources are available and what the land is good for
  agriculturally (see Biomes).

### Resources: trees and minerals

- The world has **trees and minerals in different varieties** (e.g. several tree types,
  stone, ores).
- Vegetation varieties so far: beech, oak, birch, alder, pollard willow, spruce (needle
  tree), Scots pine, dead tree, and bushes (e.g. berry bush, plain shrub).
- Each variety has a **harvest level**: harvesting it needs a tool of at least that level.
  This ties resources to tool upgrades (see Player: Tools).
- The biome decides which varieties occur where (see Biomes).
- **Stronger tools unlock new varieties and harvest the older ones faster** (fewer hits).
  Together this is a progression loop: better tools → new resources → better tools.
- **Felling and mining** (decided 2026-11-05):
  - Every tree and mineral has hit points; each hit with a tool takes off the tool's
    power, which grows with its level. So a better tool needs fewer hits.
  - A tool below the object's harvest level does nothing, with a short message
    (e.g. "Needs a better pickaxe.").
  - First numbers (2026-11-05, tune in play): tool power = level. Hit points: oak 5,
    spruce 4, pine 7 (level 2), dead tree 3, stone 3, boulder 6 (level 2), stump 2, dead stump 2;
    beech 5, alder 4, birch 3 (soft wood) (task 56).
    Damage heals overnight.
- **Harvesting, reworked** (decided 2026-11-05; replaces drops straight into the inventory,
  stumps regrowing into trees and the generic sapling):
  - **Final resources lie on the ground** where they come off, as items you collect by
    walking over them (pulled in from 1.25 tiles, widened 2026-11-05, once a dropped
    pile has hopped out, about 1.4 s). Final
    resources are logs (the item `wood` becomes `logs`), stone, clay, hay, all crop
    produce, and also what is picked by hand (berries, fibre) and seeds. They stay on the
    ground (saved) until collected; with a full inventory they stay where they are.
  - **Intermediate leftovers are objects** that are hit again with the right tool.
  - **Trees:** felling leaves a stump on the tree's tile and a fallen trunk (2×1, lying
    away from the player; 1×1 if there is no room). The axe cuts the trunk into most of the
    logs (e.g. oak 3, beech 3, spruce 3, pine 4, birch 2, alder 2, dead tree 2) and chops out
    the stump for 1 log. Living trees sometimes leave a seed of their species on the ground
    (acorn, beechnut, birch catkin, alder cone, spruce cone, pine cone, and the willow a
    willow cutting, a rod stuck in the ground as willows are really grown; about 25 %). Every
    tree whose stump can grow a sapling has one, as a sapling picked by hand gives it back.
  - **Trunk placement** (decided 2026-11-05): a trunk always lies horizontally (there is no
    vertical art). With the player left or right of the tree it lies on the far side of the
    stump; with the player above or below it lies to the right of the stump, or to the left if
    the right has no room. With no room for 2×1 a 1×1 trunk lies on any free tile beside the
    stump (never the player's), and with none there is no trunk. The numbers are in
    world_object_types.gd: trunk hit points (oak 4, beech 4, spruce 3, alder 3, pine 5, birch 2,
    dead tree 2), rot after 14
    days, sapling chance 30 %, seed chance 25 %.
  - **Stumps don't regrow into trees.** A stump left alone rots away over about two weeks;
    when it is gone it has a chance (about 30 %) to leave a sapling of its tree's species
    in its place.
  - **The dead tree leaves a dead stump** (decided 2026-11-05): grey, weathered wood with a
    broken, splintered top and a dark rotten heart (2 looks, a snow look too), not the fresh
    brown stump of a living tree. Same numbers (2 hp, axe, 1 log, rots away after 14 days),
    but it never leaves a sapling, and it throws splinters when hit. Stumps of dead trees
    felled before this change stay brown: nothing in an old save tells them from an oak's.
  - **Seeds per species:** a tree seed is planted on grass anywhere, becomes a sapling of
    its species and then that tree. The generic sapling item goes away.
  - **Stone:** a mined stone breaks into stone items scattered around its tile; a boulder
    (level 2) into more of them.
  - **Harvest animations** (decided 2026-11-05; view only, the state changes at once):
    a felled tree topples away from the player onto the side where its trunk will lie
    (about 0.6 s, speeding up, leaves or snow burst on impact) before the trunk shows;
    everything a harvest drops starts at its source and hops in a small arc, with a little
    bounce, to where it lands: logs out of a cut trunk and a stump, stones out of a broken
    stone, hay and reeds out of mown stands, clay out of a dug spot, and the same for crops
    and bushes picked by hand. The tree rotates on the art grid.
  - **Hit feedback:** every hit shakes the object, the finishing one too. A tree with
    foliage drops a few leaves (needles for spruce and pine, all year), a snowy tree a
    puff of snow, a bare tree nothing. Stone and boulders throw a few small splinters
    that arc out and fade. Effects are pixel particles on the art grid, in colours that
    stand out from what they fall from, and leaves fall past the canopy onto the ground.
  - A berry bush gives berries and bears again after a few days; picking it doesn't
    remove it. Shrubs and fern bushes give fibre.
  - Collected items go onto existing stacks first, then into free slots, and into the held
    slot only when nothing else is free, so an empty hand stays empty while harvesting.
- **Scythe and tall grass:** tall grass grows in meadows, in over spring, tallest in summer,
  gone in winter (a vegetation curve). The scythe mows 4 tiles per swing: the 2 straight
  ahead and the tiles left and right of the nearer one (the nearer one is the targeted
  tile, "ahead" the way the player faces). Mowing nothing does nothing and costs nothing.
  Tall grass doesn't block walking, a hand can't pick it, and the hoe, planting and
  building clear it (no hay). Each mown tuft gives 2 hay on the ground and looks mown
  (stubble) for 4 days, then grows back. First numbers (2026-11-05, tune in play).
- **Reeds:** dense stands on the banks of the river (the floodplain within 2 tiles of the
  water), at wetland edges and beside the marsh ditches, thick in patches and thin elsewhere,
  all year, with no dormancy:
  green in spring and summer, golden in autumn and winter, snow-capped under snow. They don't
  block walking, the hoe doesn't clear them and a hand can't pick them. The scythe cuts them
  (the same 4-tile swing as tall grass): each stand gives 2 reeds on the ground and is left as
  low stubble. Cut reeds grow back only in their growing season: their needs (temperature,
  sunlight, and the growth a stand needs to stand again) are a `[reeds]` section of
  `data/crops.cfg`, no crop (no seeds, no sheet). Each night a cut stand gathers growth from
  the day's temperature and sun by the same score as a crop's, with no soil moisture (reeds
  stand in water), and stands again once it has enough. It gathers nothing on days too cold or
  too dark, so a stand cut in autumn stays cut through winter. First numbers (2026-11-05, tune
  in play): 4 growth, minimum 5 degrees, best 20, maximum 32, sun 2 to 6 hours: some five to
  eight good days.
- **Shovel and clay:** some spots near rivers, lakes and wetland hold clay, hinted only
  slightly on the ground (a few reddish-grey pixels; easy to miss). Digging such a spot
  with the shovel sometimes gives clay; a dug spot is spent for some days. Digging
  anywhere else gives nothing. First numbers (2026-11-05, tune in play): 40 % chance of 2 clay
  (a roll of the spot and the day), a dug spot is spent for 5 nights, spots lie on grass with
  water (the river or a ditch) or wetland within 5 tiles, in clusters, never where an object stands. The shovel's
  targeting highlight shows on any free grass tile, so spots can't be told from the cursor.
- **Regrowth:**
  - a felled tree leaves a stump that rots away and may leave a sapling (see above);
  - minerals respawn slowly, mainly in areas the player hasn't visited for a while;
  - the player can plant trees (from seeds or saplings).

### World objects (architecture)

- Trees, rocks and ores, crops, the camp site, beds and similar things are **world
  objects placed on tiles**, not terrain types.
- A world object keeps its own state (e.g. growth stage, hits left, time until regrowth).
  Tile state stays lean and only describes the ground.
- Whether a tile can be walked on, built on or planted on also depends on the objects on
  it.
- An object can cover several tiles (its **footprint**, e.g. a boulder on 2x1, a sleeping
  bag on 1x2). It is stored at its top left tile only; the tiles it covers are derived.

### World edits (architecture)

- The generated world is a pure function of seed and position. Everything the player
  changes is kept as **edits** at world level, outside the chunks: per world position,
  "this object stands here" or "the generated object here was removed" (later also
  changed terrain, e.g. grass turned to soil).
- When a chunk is generated, the edits for its area are applied on top. Changes survive
  chunk unloading, and object state (e.g. crop growth) is kept.
- Buildings are stored at world level as well.
- **Save format later:** seed + edits + buildings + player and clock state. Edits are also
  the natural unit to synchronise in multiplayer.

### Ambient wildlife

Decided 2026-11-05. Small animals that make the world feel alive. For now they are
atmosphere only: no player impact, not hunted, not saved.

- **Who and where:**
  - birds: hop and peck on open ground, fly off when the player comes close; small flocks
    cross the sky now and then (a shadow on the ground);
  - rabbits: grassland and forest edges, hop about, flee in zigzags from the player;
  - squirrels: forests, dart between trees, sit up, scurry off;
  - deer: rare, in forests and at forest edges, mostly at dawn and dusk; graze, look up,
    bound away when the player comes near;
  - bees: only at flowers in bloom, by day in spring and summer: one for every few tiles
    of flowers around the view (up to the cap), none where nothing blooms; they hop from
    flower to flower within a few tiles and fly off when none is left near (task 75);
  - butterflies: over meadows and flowers by day in spring and summer;
  - white storks (task 60): in spring and summer, by day only. They hunt on wetland, the
    floodplain and grass with open water within a few tiles (the wet meadows of the marsh),
    walking slowly with the head down and stabbing into the grass, and fly off with slow
    wingbeats and glides when the player comes near. Others fly in and stand on the ridge of a
    house near the view (one per roof; where they stand is read from the top of the house's
    picture as it is shown, snow and all) and take no notice of the player, leaving if the
    house is gone; storks clatter their bills now and then. No
    nest yet;
  - greylag geese (task 60): flocks of 6 to 12 (fewer where a narrow shore has no room for them
    all) graze the marsh and the floodplain (grass within 7 tiles of water) in autumn and winter,
    fewer in spring, by day. They raise their heads together when the player comes near and take
    off together when nearer, closing up into a V. Skeins of 7 to 13 fly over high up now and
    then, mostly at dawn and dusk. A flock counts as one animal.
  - mice (task 80): within 2 tiles of farmland (tilled soil, a crop, a Knick, a fieldstone
    wall or a building, with its hay), all year, mostly at dusk and at night and a few by day;
    they sniff and scurry, and dash off into cover (gone) when the player comes near;
  - frogs (task 80): on grass, the floodplain and wetland within 2 tiles of water, from spring
    to early autumn (fewer in autumn, none in winter), most at dusk, out in the rain; they sit
    puffing their throats, hop now and then and hop off from the player. A hunting stork that
    sees a frog within 3 tiles walks up to it, strikes and swallows it, and the frog is gone.
    The lookup (`WildlifeView.nearest_animal`) is the same a cat uses for mice (task 82).
  - the birds of the coast (task 99), the North Frisian Wadden Sea's commonest:
    oystercatchers in pairs and small groups (2 to 5) on the tidal mud and the salt marsh all
    year, a few at night, probing the mud, raising their heads when the player comes near and
    flying off low when nearer; tight flocks of 12 to 24 dunlin on the mud in the spring and
    autumn migration (fewer in winter, hardly any in summer), probing quickly and taking off
    together in a swinging wheel; herring gulls on the mud, the salt marsh and the sea all
    year, walking, pecking and calling on the ground and swimming on the water, flying off
    with long glides; and common terns over the sea and the tideways from late spring to the
    end of summer, by day, flying along over the water, hovering, plunging in with a splash
    and coming up now and then with a fish; they take no notice of the player. The tide counts:
    while it stands high over the mud (above `flooded_tide`) nothing stands there, the waders
    on it fly off and the dunlin find no mud until it falls, the gulls swim on it and the terns
    may dive into it. A flock of waders counts as one animal.
- **The world decides how many:** time of day (birds and insects by day, deer at dawn and
  dusk, fewer animals at night), season (no insects in winter; fewer birds; rabbits and
  squirrels still about), weather (animals hide in heavy rain, storms and dense fog), and
  the land (each kind has its terrain).
- **Size relative to the character (27–28 px tall):** deer about 20 px tall with the head
  up, body about 18 px long; rabbit about 8×7 px; squirrel about 7×7 px; birds about
  5×4 px; butterfly 3–4 px; bee 2–3 px; mouse and frog about 8×5 px (larger than life, to be
  seen); a dunlin about 7×6 px, an oystercatcher about 10×7 px with its bill, a tern 12 px long,
  a gull about 13×11 px. Each has a few animation frames, palette only, in the art style of the world.
- **How:** animals appear only near the player, out of sight or at the edge of the view,
  and vanish when far away. Behaviour is a simple per-animal state machine (idle, move,
  flee). The rules for how many and where are plain, testable logic; the animals
  themselves are view nodes.
- No animals inside buildings.

### Livestock

Decided 2026-11-06 (task 73). Farm animals of the region, for now put in the world with the
console (`spawn cow 3`, near the player). Unlike the wildlife they are state and saved.

- **Who:** cows (red-brown Angler, black pied and red pied marsh cattle), sheep (white marsh
  sheep, the grey Heidschnucke with a black face and legs, white with a black face), chickens
  (brown and white hens, a rooster) and tame rabbits (agouti, white, Dutch). Each animal draws
  its look and a slight tint from a seed, so no two look quite alike; how often each look
  comes up and the tints are in `data/livestock.cfg`.
- **Dogs, cats and horses** (decided 2026-11-06, task 79): dogs (a farm collie, a spitz, a
  pointer-like hunting dog), cats (tabby, black, ginger) and horses (a heavy marsh horse of the
  Oldenburg kind in bay, black and grey, and a dun pony). Dogs and cats sniff about (their
  graze), horses graze; all three run about now and then; cats walk longest and so roam
  widest; they climb nothing yet.
- **Cats hunt mice** (decided 2026-11-06, task 82): a cat that is up and about and sees a mouse
  within 3.5 tiles when it picks what to do next crouches facing it (1.5 s), creeps up on it
  slowly and pounces from 1.2 tiles, leaping onto where the mouse was. About half the pounces
  catch it (the mouse is gone, if it is still under the cat where it lands); for the others the
  mouse sees the cat coming and dashes off into cover as it leaps, as from the player. The
  mouse takes no notice of the cat until then. A cat gives up a mouse that is gone (run from
  the player) or that it hasn't come near in 12 s, and after a hunt it rests for a minute. An
  asleep cat hunts nothing; mice are out mostly at dusk and at night and cats sleep from two
  hours after sunset, so they hunt mostly at dusk and before dawn. The mice are wildlife and the
  cats livestock: the view finds the mouse and draws the catch, Livestock moves the cat, and
  nothing of a hunt is saved (a game saved mid-hunt loads with the cat looking about). The
  numbers are in `data/livestock.cfg` (`[hunting]`).
- **The bone:** an item (from the console for now). The use key at a dog in front of the
  player gives it the bone, which is used up; the dog follows the player for 3 game hours,
  day and night, then wanders again. It waits within 2 tiles of the player, walks after them
  beyond that and runs beyond 4, until it is 1 tile from them. It never blocks the player; one
  more than 15 tiles behind, or stuck for 2 seconds, is put beside the player. The numbers are
  in `data/livestock.cfg`.
- **Size:** a cow about 22 px long and 15 px to its back, a sheep about 14 px long, a hen
  about 9x10 px, a rabbit as the wild one, a dog about 17 px long, a cat about 12 px, a horse
  about 32 px (two tiles) long, its back free of the neck and head for a saddle and a rider.
- **Riding** (decided 2026-11-06, task 81): the saddle is an item (from the console for now).
  The use key with the saddle at a horse in front of the player puts it on the horse, where it
  stays; the use key with an empty hand takes it off again into the inventory (the empty
  hand's slot always has room). E at a saddled horse in front gets on it (after a villager to
  talk to, before chests, stations and beds), E again gets off. The horse walks at the
  player's walking speed and, once they have ridden on for 0.6 s, trots at twice it; riding
  costs no energy, and tiredness doesn't slow the horse (`data/livestock.cfg`). What collides
  is the rider's body, as on foot, and it also keeps off the tiles of buildings, so a horse is
  never ridden through a door (one that stood in a doorway is ridden out of it). On horseback
  the use key does nothing but say "Get off the horse first.", the hammer builds nothing, a
  door ahead and the crafting key say the same, nothing on the ground is picked up, and E only
  gets off; only the inventory (with the hotbar and dropping) and eating work as on foot (the
  user, 2026-11-07). A ridden horse does nothing of its own. Getting off puts the player on free
  ground within two tiles of the horse, its side first (above or below it, not at its head or
  tail), never in water, a wall or a building; with no room they stay on. Passing out (after
  sliding off if there is room), a teleport or waking in the home bed leave the horse where it
  is. Saved: the saddle on the horse (save version 22); riding is not saved, a game saved on
  horseback loads with the player standing beside the horse.
- **Riding, drawn:** the rider sits on the horse in all four directions, the horse standing,
  walking or trotting under them (seen from the side, from the front with its head in front
  of the rider, and from behind), the rider rising with the trot; the hands hold the reins, so
  no held item shows. A saddled horse shows its saddle. The camera follows the rider as the
  player, and what hides the player hides the rider and the horse too.
- **Behaviour:** an awake animal stands idle (and now and then turns round), walks or grazes;
  chickens peck for seeds and worms. Grazing doesn't change the grass. It walks only onto
  walkable ground under its feet and its nose, so it keeps out of water and away from
  anything solid. Rabbits hop and run from a player who comes close. At night every animal
  sleeps where it stands (lying down, or tucked in): from a while after sunset (hens go to
  roost before it) until about sunrise, each animal up to half an hour later than its
  species. They stand still while the player is in a house, like the rest of the world.
- **Sound:** now and then a moo, a baa, a cluck, a bark, a whinny or a snort, quiet and rare
  (a cat's meow rarer still); none while asleep.
- **Saved:** species, look, tint and position (save version 13), until when a dog follows the
  player (save version 16) and whether a horse wears a saddle (save version 22); what an animal
  is doing is not.
- Animals don't avoid each other or the player yet. No hoofbeats are heard while riding yet.
- **Later:** milk, wool and eggs, pens, feeding, owning and breeding.

### NPCs (villagers)

Decided 2026-11-06 (task 84, QUESTIONS.md 22): the first step towards the people of
[docs/ideas/NPC.md](docs/ideas/NPC.md). For now villagers are put in the world with the
console (`spawn npc [count]`, or `spawn npc <id>` or just `spawn <id>`, near the player); they
are state and saved.
Task 86 (2026-11-06) added who they are, words from a language model and memory.

- **Who:** each villager draws a sex, a name and a look from a seed. Names are period North
  Frisian and Low German first names by sex (Hinrich, Jens, Boy, Momme, Ocke, Tete; Antje,
  Elke, Inken, Kerrin, Wiebke) and surnames (Jensen, Petersen, Lorenzen, Nissen, Carstensen;
  the hand-written families are the Boysens, Ketels, Hansens and Paulsens). The look is layers
  like the player's: a skin, a hair style and colour (short, long or tied for men; a bun or
  plaits for women), and period clothes (men: shirt or
  waistcoat, knee breeches, sometimes a jacket, a red or white stocking cap, a straw or felt
  hat or a tricorne; women: a laced bodice over the chemise, a long skirt, often a white, blue
  or striped apron or a shawl, a white coif or a headscarf), all in existing palette colours.
  The lists are in `data/npcs.cfg`.
- **The village (task 96):** all villagers live in Wehlsbüll, a made-up marsh parish two hours
  north of Husum in 1750, and share its sheet, `data/village.cfg` (`VillageSheet`): one topic a
  section (the village, places, who is who, money and prices, this year's news and worries, the
  church year, what people know of the world), each with a full text and a cut-down one (empty
  leaves the topic out of the cut-down). Made-up people there who are not villagers (Pastor
  Johann Martens, the Deichgraf Peter Momsen, the Deichvogt Brar Feddersen, the innkeeper Tete
  Jacobsen, the sexton Claus Thomsen) have names; the offices and the history are real (the
  Danish king holds all Schleswig since 1721, the floods of 1634 and 1717).
- **Who they are:** every villager has a sheet, told to the language model: age, trade,
  personality, background (the essentials of family and story; the dead are told only here),
  home, speech (the manner of talking, written so that it holds in any language: no English words
  to say, the user's "Aye." in a German talk), sample lines in their voice (they show the manner,
  not the language), people (family and close friends, each a villager by id with the kind and
  what they think of them), likes, wants (this year), day (where they are when), habits, avoids
  (what they don't know or won't talk about) and secrets (only hinted at). Eight are written by
  hand in `data/villagers.cfg` with a fixed look, spawned by id and once each: `antje` (Antje
  Boysen, a farmer's wife: the user's prompt example), her husband `hinrich` and their son `boy`;
  `momme` (Momme Ketels, a fisherman) and his daughter `inken`, Boy's sweetheart; `ocke` (Ocke
  Hansen, the miller) and his wife `gesche`, Antje's friend; and `kerrin` (Kerrin Paulsen, the
  late Deichvogt's widow), Gesche's aunt. Everyone a sheet names as kin or close friend is a
  villager of the file, and `VillagerRules` checks that the sheets agree: each names the other
  back with a matching kind (husband and wife, father or mother and son or daughter, aunt or uncle
  and niece or nephew, brother or sister, sweetheart, friend) of the right sex, a parent is 15 or
  more years older than the child, and a married couple has the same home. The others draw their
  sheet from tables in `data/npcs.cfg` along with their name, once (it is saved): an age of 18 to
  70, a trade with its day and a family by sex (the spouse a first name of the other sex with the
  villager's surname), a personality, a worry, a home on the edges of the parish (newcomers and
  outlying farms), a speech with its sample lines, likes, wants, a habit, what they avoid and a
  secret; no people, and no surname of the village sheet, so they are kin to none of its
  families.
- **Where:** each keeps near its anchor: the yard in front of the door of the nearest
  building or the nearest fireplace within 16 tiles of where it came, else that spot. It
  never walks further than 6 tiles from it (one outside the circle only walks back in).
- **Behaviour:** by day it stands about and strolls (at a third of the player's speed) only
  where its body fits on walkable tiles, and stops short of the player rather than walk into
  them; the player walks through villagers, so they never shut the player in. At night (from
  half an hour after sunset to sunrise) it stands still. Like the animals it stands still
  while the player is in a house.
- **Talking:** E speaks to the villager on the targeted tile, or the nearest one in reach in
  front of the player, before any chest, station or bed; that villager's name shows over
  their head. The chat pauses the game and is laid out like a messenger: the villager's
  portrait on the left, the player's on the right (32x32 head-and-shoulders portraits laid
  together from the same layers, each the top of the layer's frame facing the viewer, drawn at
  2x), names under them, and between them the lines as
  bubbles: the villager's on the left with their name above the first of a run, the player's
  on the right, each with the game time small in its bottom corner, at most 70% of the window
  wide with the text wrapped, closer together within one speaker's run than between speakers
  (palette colours only), the window scrolling to the newest line (and back with the wheel or
  Page Up/Down), and a one-line input. Enter sends; while the answer is awaited the villager
  has a "..." bubble; Escape leaves (and doesn't open the
  pause menu). The villager turns to the player and stands a while.
- **Answers:** one function, `NpcDialogue.reply`, awaited by the chat. With a language model
  set in Settings (a provider, an OpenAI-compatible chat endpoint by default, the test LLM's
  `http://127.0.0.1:11434/v1`, or Claude, whose endpoint and model, `claude-opus-5-5`, it starts
  with, or Gemini through its OpenAI-compatible endpoint, with `gemini-2.5-flash-lite`; each
  provider keeps its own endpoint, model, key and most tokens an answer may take (empty: the
  game's own), so a key goes only to its own provider; a model, picked from the endpoint's list of models or typed; an optional key; an
  emptied endpoint is none) it asks the model; without one, when nothing answers, on an error
  or after 30 s it says a scripted line of `data/npc_talk.cfg` ("Aye.", "Is that so?"). The answer is trimmed to the
  spoken line: no quotes or name in front, its first line, at most two sentences. Only the
  words come from the model; nothing else in the game changes by what it says.
- **The prompt** (`data/npc_talk.cfg`, the user's working example of 2026-11-06 in shape;
  temperature 0.5 since task 96 (was 0.7), at most 60 tokens): a system line (dialogue for one
  villager of Wehlsbüll on the North Frisian coast in 1750, one or two short sentences of small
  talk that answer what was said, in the language of the neighbour's latest line (English if that
  is English), never break character or act as an assistant, keep to the sheets and to what was
  said earlier, never make up relatives, friends, names or places beyond them but say one doesn't
  know, speak in one's own manner (the sample lines show the manner, not the language), puzzled by
  what did not exist in 1750, sharp to the rude) followed by the village's sheet and the
  villager's: in full for a hosted model (a provider that needs a key, `needs_key` of
  `GameSettings.LANGUAGE_MODEL_PROVIDERS`: Gemini, Claude), cut down for a local one (the
  villager's essentials, family and friends by name and kind, speech and one sample line; the
  village line and who is who), so that a 3B or 7B stays fast; the example
  exchange ("Villager: Hark Nissen, a blacksmith. / His neighbour says: "Fine weather for the hay
  today." / Hark's reply:" and his answer; not a villager of the game, so that the models do not
  copy a villager's words into the others), the lines the villager keeps as turns of the same
  shape, and last what the player says, with the villager's age, look in words from the layers
  and memories, the moment (the date as the clock shows it and early, mid or late in the
  season; the time and part of the day by the sun: dawn, morning, noon, afternoon, dusk, night; the
  weather as it is: thunder, storm, snow, rain or fog by strength, else the sky by its clouds, the
  temperature, frost below 0 °C, the wind by strength and where it blows from; the building or fire
  within 8 tiles), that the player is a newcomer whose name they don't know, and, right before the
  answer, the language the villager answers in (so a switch of language is followed, the user's
  word of 2026-11-07; task 95): the game detects it (`NpcLanguage`: English, German or Danish by
  the common words and telling letters of `[language]` in the data file; "Antje answers in
  German." and "Antje's reply in German:"). A line too short to tell has the language of the
  player's latest earlier line that can be told; with none, or in a language it does not know
  (Swedish has a word list of its own so that it is not taken for Danish), the prompt only asks
  for "the language the neighbour just spoke in". Derived from the chat, so nothing is saved.
- **The wait:** belongs to the villager: while one answers, the player can leave and talk to
  another (who shows no typing); the answer lands in the chat of the one asked.
- **Chat history and memory (task 91):** a villager keeps the last N lines of the chat (the
  setting "Lines a villager keeps", 2 to 200, default 24, one for all providers); all go to the
  model as earlier turns, so a reopened chat goes on. Lines that drop out (after an exchange,
  when the setting is lowered, applied once the menu is closed, and on load) are made one dated memory ("On the 12th day of
  Spring, year 1 (mid spring): ..."): summed up by the model with a small prompt of its own (one sentence of at most 25 words, in
  the villager's first person),
  else the start of what the player said. One summary is asked for at a time; what drops
  meanwhile is summed up next. A villager keeps 10 memories; beyond that the oldest two merge
  into one (its last 400 characters). Later prompts tell the memories and the kept lines.
  Typing `/clear` in the chat forgets the villager's chat, memories and lines waiting for a
  memory, with a line saying so (not sent, not kept); other text with a "/" is said as it is.
- **Settings:** the endpoint (default the test LLM's), the model (default
  `qwen2.5:7b-instruct`, the test LLM's) and the key are in the settings file
  (`[language_model]`); the key is plain text there, as the Settings page says, never in the
  save; it is sent as `Authorization: Bearer <key>`, and the client follows no redirect, so
  the key goes only to that endpoint. Claude's own API needs an adapter of its own (later).
- **Saved:** name, sex, look, who they are (id, age, trade, personality, background, habits;
  save version 19; the rest of the sheet, version 23), the chat's kept lines (version 17), the
  memories, the lines that dropped out and wait for their memory (version 21), so none is lost
  when the game is saved while a summary is asked for, and how many of the oldest kept lines a
  version 20 memory already holds (they drop out without a second summary); what a villager is
  doing, and an answer still owed, are not. The file wins for a villager written by hand (decided
  2026-11-07, as the user will edit the sheets): a loaded one takes their sheet from
  `data/villagers.cfg` as it is now, and the saved sheet only stands in when their id has left
  the file. A version 18 villager is given a background from the tables, the same for the same
  name. A version 22 made-up villager is made up anew from the tables by their name (the old
  tables had "Says Aye"), with another surname if theirs is now a family of the village sheet.
- **Later:** homes, schedules, intentions, suggestions from the model, NPC to NPC talk (see
  the ideas doc).

### Combat

- **Real-time action combat.**
- Specific fights take place in handcrafted areas (Tiled).
- Mobs also spawn in certain procedurally generated areas.

### Crafting

Decided 2026-11-05.

- **C opens the crafting menu** (rebindable). It lists every recipe with its cost against
  what the player carries, like the build panel; a recipe that can't be afforded is greyed
  with the missing materials marked. Clicking an affordable one takes the materials and puts
  the item in the inventory. Recipes are in `data/recipes.cfg` (result, count, materials),
  validated like the other data files. C shows the recipes made by hand (the chest, the
  stations, flour); the others are made at a station (see Professions); the hammer is a later
  recipe. When the result would not fit in the inventory
  (once the materials are taken) crafting is refused and the menu says so; nothing is
  dropped. The game does not pause while the menu is open (as with the character screen),
  but the player neither walks nor acts. C or Escape closes it.
- **First recipe: the chest**, 5 logs. A chest holds 15 slots (5×3).
- **Placing a chest:** held like seeds; while it is held a ghost of the chest follows the
  targeted tile, and using it places the chest there. The same rules as for buildings, just
  on one tile: not on blocked or unsafe tiles, not in the way of a door (the tile in front
  of it), not on the player. The ghost is green where it fits and red where it doesn't.
  Chests can be placed outdoors and inside houses (the first furniture the player places in
  an interior): inside, on free floor, not on walls, furniture, the exit or the tile inside
  it.
- **Opening a chest:** E on a chest within reach opens the storage screen (a chest on the
  targeted tile wins over sleeping; with a bed in reach and no chest targeted the player
  sleeps, without a bed the nearest chest in reach opens; with the hammer held outdoors E
  still picks the next building).
  The player's inventory is on the left, the chest's 5×3 slots on the right, with a small
  backpack icon above the one and a chest icon above the other (equipment is not shown).
  Items move by clicking as on the character screen (pick up, then click a slot; decided by
  the implementation 2026-11-05 instead of dragging); Shift+click sends a whole stack to the
  other side. The hotbar is the HUD's, lit and clickable while the screen is open (task 88). Opening makes a creaky squeak, closing a soft wooden thump.
- **Picking a chest up:** hitting it with the axe (three hits outdoors) takes it down and
  gives the chest item back; its contents spill onto the ground as piles around it. Inside
  a house there is no ground to spill on: one swing of the axe puts the chest item and its
  contents into the inventory, if they all fit (otherwise nothing happens and the player is
  told).
- A chest and its contents are saved with the world (outdoors) or the building's inside.

### Professions

Task 74, decided by the user 2026-11-06: the first three crafts of
[docs/ideas/crafting-and-professions.md](docs/ideas/crafting-and-professions.md), the
woodworker, the cook and the mason, and a UI for them.

- **Skills grow both ways.** Each craft has a skill (woodworking, cooking, masonry; in
  `data/skills.cfg`), 0 to 100 points, shown as numbers. Crafting a recipe practises its
  skill: 2 points while the skill is at or below the recipe's level, falling evenly to
  nothing 40 points above it (no gain from trivial recipes). Points count in tenths. A
  recipe may need a level (`level` in `data/recipes.cfg`): below it the recipe is locked, and
  the menu shows it greyed with the level it needs. Recipes without a skill (by hand) teach
  nothing.
- **The total cap** (decided by the implementation, as the user's suggestion): all skills
  together have at most 200 points, so one can reach 100 with two at 50, or three can stand
  around 66. At 200 a skill only grows by taking the points from a skill the player marked
  **Fade** on the skills tab (from the first marked, in the order of the file, that has points
  left); with none marked the craft still works but teaches nothing, and the menu says to let
  a skill fade. A mark does nothing below the cap: nothing ever fades on its own. The console's
  `skill <skill> <points>` sets points (and ignores the total cap).
- **Stations are placed objects** (`data/stations.cfg`): the workbench (6 logs), the kiln
  (6 clay, 8 stone) and the bake oven (12 bricks, 2 clay, 4 stone) are made by hand and placed
  like a chest; the house hearth and the camp's fire are the hearth station, which everyone
  has. The kiln stands only outdoors (`outdoors_only`), the others also in a house; a stool
  only in a house. The axe takes down the workbench, the stool and the chests, the pickaxe
  the kiln and the oven (inside a house one swing, into the inventory). The house's own
  furniture can't be taken down; the stools of the maps can (a free stool, accepted).
- **E on a station** opens the crafting menu of its recipes, titled with its name, with the
  player's points in the skills they practise; E or Escape closes it. A note after a craft
  says what it taught. The tooltip of a recipe says what a craft teaches, or what it needs.
- **The kiln fires over time.** A recipe with `hours` puts its materials into the station,
  which holds that one work (the recipe and the game minute it is done, in the station's
  saved state) until it is taken out; the bricks take 12 game hours, so a firing started in
  the evening is done in the morning. Nothing runs while the player is away: the clock is
  compared with that minute. Opening the station's menu when the work is done takes the
  result into the inventory (or says there is no room, and it stays). While it fires, the
  menu says what and for how long, and the slow recipes are greyed. A kiln broken down gives
  back its unfired load, or the bricks once done. No new save field: the work is in the
  object's `state`, which is saved already.
- **The skills tab** is a second tab of the character screen (Tab opens the character, K the
  skills; the key of the shown tab closes it): a row per skill with a bar, the points and the
  Fade button, the total against 200, and the rule of the cap in a sentence.
- **Recipes** (levels in brackets):
  - Woodworking at the workbench: planks, 2 from a log (0); stool from 3 planks (10); a grave
    marker from 2 planks and 2 stone, only outdoors (15); clogs from a log (25); a carved
    chest, painted the Frisian way, 8 planks, 20 slots (45); the master's piece, a joined oak
    cupboard, 12 planks and 2 logs, 25 slots, only in a house (70).
  - Cooking at the hearth: roast turnip (0); pottage, 2 from cabbage, carrot and onion (10);
    pea soup, 2 from 4 peas and an onion (20). At the bake oven: bread from 2 flour (30), a
    berry tart from a flour and 6 berries (50), a feast cake from 2 flour, 4 strawberries and
    4 berries (70). Flour is ground by hand from 3 wheat (a hand
    quern, not drawn): the simplest chain, as there was no flour. Cooked food restores more
    energy than its ingredients raw (roast turnip 12, pottage 15, pea soup 16, bread 30,
    tart 35, feast cake 60; in `data/energy.cfg`).
  - Masonry: raw bricks from clay at the workbench, 2 from 2 (0), 3 from 2 (25); bricks in the
    kiln, 6 raw bricks and 2 logs make 6 (0), 12 and 3 logs make 12 (50), a master's firing of
    18 and 3 logs makes 18 (70). Bricks build the bake oven, so bread needs the mason.
  - Each craft has a master recipe at 70, which teaches up to 109, so every skill can reach
    100 (a test keeps it so).
- **Saved:** the skills and the fade marks with the player (save version 14; older saves
  start with none).
- Not yet: quality, tool wear, recipe books, more professions, a look for a kiln that fires,
  more uses of bricks (houses, paths).

### Building and land

- **No land ownership.** The player can build anywhere, except on blocked tiles.
- **Placement rules:**
  - **wetland and floodplain tiles are off limits**: no building can be placed anywhere
    that can flood;
  - while placing, blocked tiles are marked, and the player gets a message that the land
    doesn't look safe to build on.
- **Defence:** creatures can threaten what the player builds. Combat stays optional,
  because there are other ways to stay safe:
  - fight the creatures;
  - hire guards;
  - build defences;
  - build in a less dangerous area. This means the world needs regions with different
    danger levels.
- **Buildings are presets with customisation:**
  - each building type is a preset (e.g. house, barn, workshop);
  - options per building: style, doors, and similar visual or functional variants;
  - expansions attach only at **defined attachment points** on a building. That keeps
    interiors predictable to generate and render.
- **First buildings** (decided 2026-11-05), in the style of the Danish and North German
  countryside, each with its own inside:
  - **Shack:** a small wooden hut, the cheapest shelter. Footprint 3×2, door on the middle
    tile.
  - **Fisherman's hut** (*Fischerkate*, task 103, 2026-11-08, from the art review of that
    day): the shack's kin at a landing, the Ketels' home: 4×2, door on the second tile, tarred
    boards under a reed thatch with a turf ridge, one small window. Costs 25 logs, 5 stone,
    15 reeds. Its landing is made of world objects, not part of the building (see **The
    landing** below).
  - **Kate:** a small cottage, 5×3, door on the middle tile. It replaces the old small
    house (old saves map to it).
  - **Longhouse:** a larger farmhouse with the big gable door of the Lower Saxon hall house;
    7×3, door on the middle tile.
  - **Hall house** (task 59, 2026-11-06, from docs/art-style.md): the Low German hall house
    (*Niederdeutsches Hallenhaus*, Niedersachsenhaus) of Holstein, the biggest and dearest
    building: 7×5, its gable end to the front with the door (the Grote Door) on the middle
    tile. Costs 100 logs, 40 stone, 50 clay, 80 reeds. A Haubarg (the giant of the marsh
    under a pyramid of thatch) comes later.
  - **Barn:** a work and storage building, no hearth or bed; 6×3, door on the third tile
    from the left, no windows. Costs 30 logs, 15 stone, 5 clay, 25 reeds. The longhouse
    costs 60 logs, 30 stone, 30 clay, 50 reeds.
  - **Church and bell frame** (task 102, 2026-11-08, from review/art-review-2026-11-08): the
    parish church of a marsh village, 6×4, door in the porch on the third tile. A nave of
    grey-brown tuff ashlar with the lower chancel to the east, steep roofs of red pantiles
    (village churches here were tiled, not thatched), small round-arched windows of leaded
    glass in brick arches, a low lime-washed porch on the south side with its gable to the
    front, iron crosses on the west gable and the porch. Costs 70 logs, 35 stone, 45 clay
    (the pantiles are fired clay). The small marsh parishes had no tower: the **bell frame**
    (*Glockenstapel*), 2×2, is an open oak frame on a brick base under a pyramid of oak
    shingles, the bronze bell in it; 25 logs, 5 stone, 10 clay. It has no inside: its
    `interior_map` is empty, none of its tiles can be walked on and nobody goes in. The
    **churchyard**: the fieldstone wall of the fields, and **grave markers** made at the
    workbench (woodworking 15: 2 planks, 2 stone) and placed outdoors only, which stand as an
    oak cross, a sandstone headstone or a fieldstone slab by their tile; the pickaxe takes
    them up. The world generator places no church yet: there is no village in the world to
    put it in (the Warften on the salt marsh are empty); `--churchyard=<x>,<y>` puts one in
    view for screenshots.
  - **Insides** (decided 2026-11-05): each is a Tiled map, `maps/interiors/<id>.tmx`, a little
    larger than the footprint: shack 6×6 (straw sleeping mat, crate, stool), fisherman's hut
    7×6 (the shack's room a tile wider: sleeping mat, stool, barrel, sacks), Kate 9×8 (hearth,
    bed, table, stools, chest), longhouse 15×8 (living end with hearth, box bed, table and
    bench; a stall partition divides it from the animal end with stalls, hay and sacks), barn
    13×8 (four hay stalls, crates, barrels, sacks), church 12×9 (a nave with six pews either
    side of the aisle and a table for the altar under two windows), hall house 15×13: the Diele, a long
    threshing floor of clay from the door up the middle, rows of oak posts with rails (the
    stall partitions) on both sides and hay, barrels, a crate and sacks in the stalls; at its
    far end the Flett in brick across the whole width, with the open hearth on the back wall
    straight behind the door (a cooking station like every hearth), a box bed in each corner,
    the wall bench, a chest, table, bench and stool, a plate rack and three windows. The room
    is taller than the screen at zoom 1, so the camera follows the player through it as
    outside. Sleep fills: mat 80, bed and box bed 100.
    The barn and the church have no bed, so they can't be slept in.
  - **Furnished in the period** (task 57, 2026-11-06, from docs/art-style.md): the rooms look
    like 18th-century North Frisian and Danish farmhouses. Floors: red brick in a herringbone
    in the living rooms (the Kate, the longhouse's living end), beaten clay in the work rooms
    (the byre, the barn, the shack); clay is a terrain of its own (`CLAY_FLOOR`) and sounds
    like soil underfoot, while clogs clack on brick as on wood. The hearth is an open hearth
    of buff brick under a lime-washed smoke hood on an oak mantel, with an iron pot, Dutch
    tiles (blue-and-white Delft) on the wall under the hood and soot behind the fire; the
    hood stands on the back wall above the hearth's footprint, and its fire burns as before
    (same shader, light and sound). Plate racks with Delft and pewter plates hang on the back
    wall of the Kate and the longhouse's living end (wall pieces, like the window); the Kate
    has a spindle-backed bench against the back wall. The Kate's bed is boxed in like a Durk
    under a canopy with red curtains, the longhouse's box bed a panelled cupboard (an
    Alkoven) open onto the bed, reaching up the wall to just under the window; both under a
    checked indigo blanket. All furniture blocks walking as before; footprints, beds, doors
    and every free floor tile stay reachable (tested). A save from before (version 11) takes
    today's floors and the wall pieces its rooms lack; the furniture on the floor stays as
    the player left it. The jamb stove (*Bilegger*) of the best room is left for later.
  - The look (from the user's reference photos, 2026-11-05): the roof is the hero, a huge,
    thick reed thatch, weathered grey-brown with moss, hipped at both ends with heavy rounded
    eaves, and eyebrow dormers (the thatch swells in a wave over a half-round window). The
    roof is steep planes, not a dome (task 55): a lit left hip, the front slope and a shaded
    right hip with a straight ridge; the reed lies in courses about 4 px high with wavy
    edges, lit along their top in broken runs, with reed ends of mixed length hanging below,
    and moss and weathering in patches. Under snow the planes show but no stripes. The Kate has lime-washed walls (`lime`), a
    teal door and shutters (`paint_teal`), white window frames, crossed sticks on its ridge
    (a turf ridge is an option in buildings.py) and a small white chimney. The longhouse has buff brick on a fieldstone base, crossed sticks
    on its ridge, two brick chimneys, white windows in dark green frames, climbing roses, and
    the big arched green barn door of the hall house as its door (the middle tile), the
    thatch sweeping up over it. The barn is half-timbered (dark oak beams, red brick) with big
    plank doors and no windows. The shack (task 58) is a fisherman's or herdsman's hut, not a
    frontier cabin: upright boards tarred near-black with battens over the joints (the tar's
    blue-grey sheen on their edge), on a sill beam and a low fieldstone base, a ledged door
    and a shutter in ox-blood red, a white window; a turf roof on birch bark, grass in
    clumps with dry patches and a few flowers, a ragged crest and a thick lip of turf at the
    eaves with blades hanging over the pale bark edge. Under snow the turf is lumpy snow with
    the lip and the bark showing under it.
    The hall house (task 59) shows its gable: oak framing with red brick, laid in herringbone
    between the gable's posts and in slanting courses beside them, the top of the gable
    boarded in oak with the owl hole (*Uhlenloch*) under a little hip, the green Grote Door
    under a flat white arch and a carved door beam, small stable windows in green frames to
    either side and short braces in the corner bays. Its half-hipped thatch runs back up the
    picture: seen from the gable, the eaves run along the sides, so the courses run up the
    picture on its two planes (the left lit, the right in shade), with rolled eaves along
    both sides, the reed cut along the rakes, a roll of reed as the ridge (lying along the
    roof, narrowing as it runs back and ending short of its back) and moss low on the shaded
    plane. White bargeboards lie along the rakes and cross over the hip in a pair
    of carved horse heads (*Pferdeköpfe*); under snow the boards and the heads stay clear.
    Every building has lit windows and a look per season of the grass on its tile (task 58,
    SeasonalArt.HOUSE_LOOKS): the grass on a roof (the shack's turf, a turf ridge) is fresh
    in spring, yellow-brown in autumn and brown-grey in winter, its dark base and the moss
    on a thatch green all year; under snow the roof is snowed over. Frost and the dusting
    leave a roof in its season's look; the build ghost shows the summer or the snow look.
    Windows have small panes (task 52): 2×2 px panes in 1 px white glazing bars, 3×3 panes
    in a house window, 2×3 in the shack's, and the dormers' half-round windows divided
    the same way; a lit pane glows in one colour. The window inside is the same, with
    wooden bars and daylight.
- **The landing** (task 103, 2026-11-08): what stands by the fisherman's hut, placed with
  items like a chest: a **jetty**, laid a piece (1×1) at a time and joined to its neighbours
  like a Knick, on water, the sea, mud or the salt marsh at the edge; it is walked on over
  the water (the `deck` of WorldObjectTypes) and has mooring posts at its head. A flat
  **rowing boat** (2×1) lies on water or mud, only to look at, like the Ewer. A **net frame**
  (2×1, a tarred net hung on a pole between forked posts) and **eel traps** (1×1, wicker)
  stand on the land. The jetty piece (3 planks, 1 log, woodworking 20) and the boat (10
  planks, 4 fibre, woodworking 35) are made at the workbench, the net frame (2 logs, 8 fibre)
  and the eel traps (4 reeds, 1 fibre) by hand. The axe takes the jetty, the boat and the
  frame down for their items; the traps are picked up by hand, but not the jetty the
  player stands on ("Step off it first.", for the axe and the hammer alike), and a player
  who stands where they don't fit can always step onto a deck, so nobody is left in the
  water. A deck is walkable for everyone: animals, villagers and a ridden horse can go out
  on a jetty too, and getting off a horse there puts the player on the jetty, never in the
  water (getting off looks for a tile they can stand on). No fishing yet.
- **Buildings cost materials:** logs, stone, clay and reeds (reeds for the thatch), taken
  from the inventory when the building is placed. The ghost shows the costs against what
  the player carries and refuses the spot while something is missing. No refunds on
  placing. First numbers (tune in play): shack 20 logs, 5 stone (turf roof, no clay or
  reeds); fisherman's hut 25 logs, 5 stone, 15 reeds; Kate 30 logs, 15 stone, 15 clay, 25
  reeds; longhouse about twice the Kate; barn like the Kate with less clay; the hall house
  the most of every material (100 logs, 40 stone, 50 clay, 80 reeds). A new game starts at
  the camp: the materials for a first house have to be gathered.
- **The hammer builds:** holding the hammer is build mode (the ghost follows the cursor,
  use places the building); Q and E (rebindable) pick the building, and B selects the
  hammer. Escape or a right click dismisses build mode until something else is held or B is
  pressed again. With the hammer in hand E picks buildings and does not put the player to
  bed. The `nocost` console cheat waives the costs (`god` and `noweight` don't). The player
  starts with a hammer (later it is crafted); `give hammer` works too.
- **The hammer takes down:** X (rebindable, `take_down_mode`) switches the hammer between
  building and taking down; the panel says "Taking down", the tile under the mouse has a red
  frame and the building or placed thing there is tinted red, with the message saying what it
  gives. Holding Use for a second (`BuildMode.TAKE_DOWN_SECONDS`, with a progress bar) takes
  it down, with the axe's chop. A building gives half of each material, rounded down, dropped
  in front of its door (`GameState.take_down_building`; `nocost` gives nothing). It stays while
  the player is inside, or while anything they put in it is left: a thing they placed, or
  what a chest or station holds; the message says so. The furniture the house came with goes
  with it. A home bed in it falls back to the camp's sleeping bag, and a stork on its roof flies
  off. A placed thing (what an item places: chest, workbench, kiln, oven, stool, carved chest,
  cupboard) outdoors goes whole, with what it holds, into the inventory, or onto the ground
  where it stood when that is full. Crafted items are not broken down into materials.
- **`data/buildings.cfg`** defines the buildings (required keys, the game refuses to start
  if one is missing): name, footprint, door tile, picture and lit picture (the season and
  snow looks are found by name), the interior map, window lights, costs, and documented
  places for future attributes (beds, storage, warmth, comfort) that have no effect yet.

### Reputation

- Building too close to NPCs costs reputation with them.
- Reputation changes spread through relationships, **one hop only**:
  - the affected NPC loses reputation with the player;
  - the NPC's direct friends also lose reputation;
  - the NPC's direct enemies gain reputation;
  - the change stops there. This keeps it predictable and explainable to the player.
- **"Too close" means inside a settlement's territory.** The world generator marks
  territory, and building inside it affects that settlement's NPCs. This is a first
  version, to be refined if it feels odd in play.
- Relationships can be between individual NPCs and between groups.
- Ideas for NPCs, their behaviour and LLM dialogue (nothing decided):
  [docs/ideas/NPC.md](docs/ideas/NPC.md).

### World

- **Mixed generation, procedural first.** The world is procedurally generated for now.
  Handcrafted locations come later.
- Handcrafted locations are made in an existing tile-map editor (**Tiled**) and placed into
  the generated world.
- **Shape:** a bounded world, generated from a seed and streamed in chunks.
  - The maximum size is a limit defined in code, which can be raised later. Nothing should
    assume a fixed size.
- **Biomes**, each with its own:
  - mobs;
  - available resources;
  - suitability for agriculture.
- **Danger:** regions have different danger levels (see Defence).
- **Interiors:** each building interior is a separate map. Entering through the door
  switches to it.
- **The worked land** (task 54, 2026-11-06): the generator lays fields over the natural land, so
  it reads as Schleswig-Holstein around 1700–1800. Numbers in `data/landscape.cfg`, first
  values, tune in play.
  - **Fields:** rows of fields between straight east-west boundaries (13 tiles apart, up to 4
    more), each row cut by north-south ones (18 apart, up to 6 more); 80 % of the stretches of
    boundary are there, so some fields run together. Every stretch has **one gap** (a gate, a
    crossing) away from its ends, and nothing that blocks the way stands on a gap or beside it,
    so no field is ever shut in: every boundary blocks, so without gaps the player could be.
  - **The Geest** (dry grass beyond the marsh, outside the forests): a boundary is a **Knick**
    (80 %), a **fieldstone wall** (10 %) or a **wattle fence** (10 %). There are no hedges in the
    forests, the marsh, on wetland or the floodplain.
  - **The marsh** (the low land within 36 tiles of the floodplain's edge) and wetland anywhere:
    a boundary is a **ditch**, water terrain, which is how the marsh is drained and fenced. Beside
    the ditches stand **pollard willows** (10 % of the tiles) and reeds (30 %). Ditches block
    walking like the river (no jumping); their gap is the crossing. The willow (redrawn in task
    56, as the first read as a sheaf of grain on a boulder in winter) is a gnarled grey-brown
    trunk about a tile high with a knobbly brown head, and a dense crown of 30 to 38 thin rods
    of mixed lengths: silver-green leaves along them in summer, muted yellow-olive with a few
    straw tips in winter, a little snow on the head.
  - **Dykes** run on the land side of the floodplain's edge, in stretches picked by a slow noise.
  - **Walking:** Knicks, walls, fences and ditches block it; dykes don't (they are walked on,
    sheep grazed on them). Willows block like the other trees.
  - **Tools:** the axe cuts a Knick down to the ground for 1 log and 2 fibre (its wood was the
    reason it was planted and cut back every few years), and a wattle fence for 2 fibre; the
    pickaxe takes a wall apart for 3 stone. Nothing removes a dyke or fills a ditch (yet): they
    are the land's, not the player's. A willow is felled like the other trees (2 logs, its stump
    may grow a willow sapling again; it drops a willow cutting like a seed).
  - **Building and tilling:** all of them block building and tilling on their tile (a dyke too:
    nothing is built into it). Building next to them is fine. The door's front tile must still
    be walkable, so a door can't open onto a Knick or a ditch.
  - **Clay** is also found near ditches, which makes up for the clay the dykes cover by the
    river.
  - **Old worlds:** the worked land comes from the seed, so saves of version 9 and before show it
    where nothing was edited. Save version 10 lets it give way where the player has made a home,
    as if they had cleared it: 3 tiles around every building and around everything the player put
    down or changed (camp, chests, crops), over the tilled fields (their bounding box and 2 tiles
    more), under the items on the ground and where the player stands, the new objects are removed
    (as edits) and a ditch is grass. A 1-tile ring was too thin: on the user's farm ditches ran
    through the yard. So nothing new stands in or by a house, across the yard, the camp or the
    fields, or shuts the player in; further out an old world gets the new land.
- **The coast** (task 61, 2026-11-06): the North Sea lies in the west, the Wadden coast of North
  Frisia. Numbers in `data/landscape.cfg` ([coast], [tideways], [warften], [ewers]), first
  values, tune in play.
  - **Where:** a coast line runs north to south about 260 tiles west of the centre, wandering 40
    either way, so the farm and the camp lie far inland. The river runs out through it into the
    sea, widening.
  - **The sea dyke** stands on the first tiles of the land all along the coast (the floodplain
    too), without gaps but for the river: the dykes of the river (task 54) sit between the land
    and the marsh, this one between the land and the salt marsh, as real sea dykes do. The marsh
    with its ditches reaches 36 tiles inland from it as from the river.
  - **The foreshore**, west of the line, which nothing grows on: a band of **salt marsh** (about
    12 tiles, give or take 5), then the **tidal mud** (out to about 140 tiles, give or take a
    third), then the open **sea**. **Tideways** wind through the mud, one per 36 rows, from a tile
    wide at the salt marsh (or a little way out) to 7 wide towards the sea; they keep 3 tiles
    clear of the river, so no mud is cut off from the land. The water beyond the coast line is
    the sea's (`SEA`): water to walk and draw, without lily pads, frogs or reeds.
  - **Walking:** the salt marsh and the mud are walked on at any tide; the tideways and the sea
    are not. Nothing is built on the foreshore but the Warft; nothing is tilled there.
  - **The tide** is a look only: high water every 12 hours 25 minutes, a little later each day.
    The water rises over the mud by a relief of its own, filling the ripple troughs and hollows
    first, then pools that join, until the flats are under; a light line marks its edge. So the
    player can never be cut off by the water. Ice on the mud in winter: not done.
  - **Looks:** the mud keeps its look in every season and weather (the tide washes it). The salt
    marsh is grey-green turf with silvery sea purslane and green glasswort, fresher in spring,
    red-purple in autumn (the glasswort red), brown-grey in winter, rimed or white under frost
    and snow. Thrift flowers on it in late spring, sea lavender in late summer (task 75's flower
    habitat `salt_marsh`). Storks and geese come to it.
  - **A Warft** stands out on the salt marsh in one of every 150 rows of the coast (chance 0.7),
    never where the river runs out: an oval mound about 11 by 8 tiles with a pond (Fething) on
    top, in a ring of salt marsh. It is dry grass that can be walked and built on (not tilled), a
    spot for a later task to build on; nobody lives there yet.
  - **An Ewer** lies on the mud in one of every 70 rows (chance 0.6), 22 to 60 tiles out: a
    world object on 3x1 tiles, to look at; it blocks the way and no tool takes it. At the object
    atlas's scale it is smaller than a real Ewer.
  - **Old worlds:** save version 18 lets the coast give way where the player has made a home
    within its reach (the foreshore and the marsh inland of the dyke), as version 10 did for the
    worked land: the ground there is grass and the generated objects are taken off. A home away
    from the coast is left as it was.
- **Which trees grow where** (task 56, 2026-11-06): the forests stand where they stood, only the
  species of each tree changed, so old saves keep the shape of their land and need no upgrade.
  The woods are broadleaved: on wet ground (the marsh, and the Geest by wetland) alder 4, oak 1
  and birch 1 by weight, on the dry Geest beech 4, oak 3 and birch 2. Pine and spruce were not
  common before the heath plantations of the late 18th century, so they stand only in clumps on
  the Geest, where the composition noise is high (with a mixed rim), two in three of them Scots
  pine. Over three seeds the trees are about 28 % beech, 24 % oak, 19 % birch, 16 % alder, 7 %
  pine and spruce and 4 % willow (before: about half oak, half conifers). Numbers in
  `WorldGenerator`, first values, tune in play.

## Later features

- **Magic.** Planned for later; design to be done. The lighting setup (point lights,
  glow) should make magic effects cheap to add.

## Milestones

### 1. Prototype (vertical slice)

Goal: prove the world, building and Tiled pipeline with the smallest playable thing.

- A generated, chunked world from a seed, using the tile-state model (see Tile state).
- Building placement that checks tile state (at least: blocked tiles).
- A player who can walk around, starting at the camp site.
- A day counter. Sleeping in the sleeping bag advances to the next day.
- One preset building that can be placed, with one interior map.
- One crop that can be planted and grows over days.
- The make targets from Tech, including `make setup`.

Not in the prototype (as planned): combat, reputation, biomes beyond one, weather, energy,
saving and loading, final hand-made art (generated art only, see Art pipeline). The slice
is done, and weather, energy, saving and loading and sound have been added since.

Tasks: see [TASKS.md](TASKS.md).

## Open questions

- **Reputation details:**
  - What does reputation unlock or block (prices, quests, hostility)?
  - Which NPCs in the territory are affected: everyone, or only those living closest?
- **Target platforms:** Linux only, or desktop in general? Web?
- **Scope:** hobby, learning project or release target?

## Deliberately left out

- Land ownership and plots.
- Fully modular, tile-by-tile building construction.
- Multiplayer in the first version.
