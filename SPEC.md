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
- **Tiles: 16×16.** Default view about 320×180 art pixels (20×11 tiles).
- **Stepless zoom** from 0.5× (about 640×360 art pixels) to about 2×. The mouse wheel
  zooms.
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
    for characters and interactable pickups; no outlines on terrain;
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
- **Floodplain looks fertile:** lush, damp meadow, with a narrow muddy bank right at the
  water. It must not read as barren sand.

### Saving (first version)

- Save format: seed + world edits (terrain and objects) + buildings with their interiors +
  player state (position, current map, home, appearance, inventory) + clock. One JSON
  file per world under `user://saves/`.
- **Autosave when the player sleeps, passes out and when the game quits.** On start, the
  game loads the save if there is one, otherwise it starts a new game (`--new-game` forces
  one).
- No save menu or multiple slots yet; revisit when there is a main menu.

### Tile state (architecture)

- A tile is **state, not a fixed picture**: terrain type plus dynamic properties such as
  water level, frozen, snow depth.
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
    - **Weight:** up to 20 kg costs nothing extra; above that, +10 % cost per 10 kg more.
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
  - The **hotbar** (10 slots, shown at the bottom of the screen) and the **backpack** (20
    slots) are separate (changed 2026-11-05): what is on the hotbar takes no backpack
    space, so the player carries 30 slots. Screens show the backpack (two rows of ten,
    as wide as the hotbar) with the hotbar as its own row below, set off by a small gap.
    Shift+click from a chest sends a stack to the backpack first, then the hotbar. Picked-up items join a matching stack first, then take the first
    free slot, hotbar before backpack. Backpack upgrades later add rows to the backpack.
  - The selected hotbar slot is what the player holds: keys 1–0 pick a slot. The use
    action (left click or Space) acts with the held item.
  - Items of the same kind stack, up to 99 per slot; tools don't stack.
  - Every item has a weight; the total carried weight raises how much energy actions use
    (see Energy).
  - An inventory screen shows all slots; items can be moved between slots.
- **Character screen** (decided 2026-11-05): Tab opens one screen with the character and
  their equipment on one side and the inventory on the other.
  - Equipment slots: head, body, legs, feet, back, main hand, off hand. Clothes, armour
    and later weapons, shields and backpacks are items with a slot; worn items show on the
    character (each slot is a sprite layer).
  - Items move between inventory slots and fitting equipment slots by clicking (pick up,
    put down, swap); an item only goes into a slot it fits, and fitting slots light up
    while an item is picked up. Right-click equips or unequips at once.
  - Worn items count toward the carried weight.
  - Hair and body are the character's look, not equipment.
  - New game: tunic and trousers worn; a straw hat, a knitted cap and a spare shirt in the
    inventory. The straw hat has a low crown and a wide brim drooping at its ends (task 52,
    it read as a pith helmet); the knitted cap is a red wool stocking cap, as the guide's
    period dress has it.
- **Movement keys:** arrow keys and WASD (decided 2026-11-05). All keys can be changed in
  the settings (see Menus and settings).
- **Scale between character and world:** character figure 27–28 px tall in its 16×32
  frame; mature trees about 2–2.5× the character (60–66 px); a small house about 3.4× (5×3
  footprint, ~96 px tall, door at least as tall as the character). Numbers in
  `docs/archive/art-review-2026-11-05.md`.
- **Character sprite: 16×32 pixels** (one tile wide, two tall), built from **layers**
  (body, clothes, head/hair, held tool or weapon, later gear), so equipment can be shown
  by swapping or adding a layer instead of redrawing the character.
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
  flower. Butterflies are silent.
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
  - **Display:** fullscreen or windowed.
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
- Commands: `help`; `tp <x> <y>` (teleport to a world tile; outside only); `give <item>
  [count]` (into the inventory); `god` (toggle invincibility:
  health doesn't drop); `nodrain` (toggle: actions cost no energy); `noweight` (toggle:
  carried weight doesn't raise costs). Later commands: `spawn`, `weather`, `snow`, `crop`
  (see `help`), and `skip <n>m|h|d` (let minutes, hours or days pass, at most a year; the
  nights in between pass as when sleeping, so crops grow).
- Tab completes command names and every argument with a fixed set of values: item ids,
  animal kinds, weather conditions, snow values. Each command lists its argument kinds in
  one table in the console code; numbers are not completed.
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
    built: the trunk is slightly crooked, grey-brown and furrowed below and reddish-orange
    in the crown, with three or four flat, ragged clumps on short branches in its top half;
    snow lies on the clumps, frost pales them.
- **Vegetation density follows the year** (decided 2026-11-05):
  - Ground cover (grass tufts, flowers, small plants, fallen leaves; the visual decoration
    layer) has a density per kind that follows a smooth yearly curve: grass tufts sparse
    in early spring, fullest in summer, thinning in autumn, a few dry stalks poking
    through the snow in winter; flowers bloom in spring and summer, fallen leaves in
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
    rain); lily pads drift and bob a little. It is all done by shaders, with no nodes or
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
  ochre or copper, bushes yellow and ochre, red rare (no tree has it yet), and yellower
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
  snow have soft edges and no seams. The season looks have stacked layers for lush and dry
  grass too, like the terrain. Snow and frost lie over the season's look. Decorations,
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
- Vegetation varieties planned so far: oak, spruce (needle tree), pine, dead tree, and
  bushes (e.g. berry bush, plain shrub).
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
    spruce 4, pine 7 (level 2), dead tree 3, stone 3, boulder 6 (level 2), stump 2, dead stump 2.
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
    logs (e.g. oak 3, spruce 3, pine 4, dead tree 2) and chops out the stump for 1 log.
    Living trees sometimes leave a seed of their species on the ground (acorn, spruce cone,
    pine cone; about 25 %).
  - **Trunk placement** (decided 2026-11-05): a trunk always lies horizontally (there is no
    vertical art). With the player left or right of the tree it lies on the far side of the
    stump; with the player above or below it lies to the right of the stump, or to the left if
    the right has no room. With no room for 2×1 a 1×1 trunk lies on any free tile beside the
    stump (never the player's), and with none there is no trunk. The numbers are in
    world_object_types.gd: trunk hit points (oak 4, spruce 3, pine 5, dead tree 2), rot after 14
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
  water) and at wetland edges, thick in patches and thin elsewhere, all year, with no dormancy:
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
  water or wetland within 5 tiles, in clusters, never where an object stands. The shovel's
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
  - bees: at flowers by day in spring and summer;
  - butterflies: over meadows and flowers by day in spring and summer.
- **The world decides how many:** time of day (birds and insects by day, deer at dawn and
  dusk, fewer animals at night), season (no insects in winter; fewer birds; rabbits and
  squirrels still about), weather (animals hide in heavy rain, storms and dense fog), and
  the land (each kind has its terrain).
- **Size relative to the character (27–28 px tall):** deer about 20 px tall with the head
  up, body about 18 px long; rabbit about 8×7 px; squirrel about 7×7 px; birds about
  5×4 px; butterfly 3–4 px; bee 2–3 px. Each has a few animation frames, palette only,
  in the art style of the world.
- **How:** animals appear only near the player, out of sight or at the edge of the view,
  and vanish when far away. Behaviour is a simple per-animal state machine (idle, move,
  flee). The rules for how many and where are plain, testable logic; the animals
  themselves are view nodes.
- No animals inside buildings.

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
  validated like the other data files. Crafting works anywhere for now (a workbench may
  come later); the hammer is a later recipe. When the result would not fit in the inventory
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
  other side. Opening makes a creaky squeak, closing a soft wooden thump.
- **Picking a chest up:** hitting it with the axe (three hits outdoors) takes it down and
  gives the chest item back; its contents spill onto the ground as piles around it. Inside
  a house there is no ground to spill on: one swing of the axe puts the chest item and its
  contents into the inventory, if they all fit (otherwise nothing happens and the player is
  told).
- A chest and its contents are saved with the world (outdoors) or the building's inside.

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
  - **Kate:** a small cottage, 5×3, door on the middle tile. It replaces the old small
    house (old saves map to it).
  - **Longhouse:** a larger farmhouse with the big gable door of the Lower Saxon hall house;
    7×3, door on the middle tile.
  - **Barn:** a work and storage building, no hearth or bed; 6×3, door on the third tile
    from the left, no windows. Costs 30 logs, 15 stone, 5 clay, 25 reeds. The longhouse
    costs 60 logs, 30 stone, 30 clay, 50 reeds.
  - **Insides** (decided 2026-11-05): each is a Tiled map, `maps/interiors/<id>.tmx`, a little
    larger than the footprint: shack 6×6 (straw sleeping mat, crate, stool), Kate 9×8 (hearth,
    bed, table, stools, chest), longhouse 15×8 (living end with hearth, box bed, table and
    bench; a stall partition divides it from the animal end with stalls, hay and sacks), barn
    13×8 (four hay stalls, crates, barrels, sacks). Sleep fills: mat 80, bed and box bed 100.
    The barn has no bed, so it can't be slept in.
  - The look (from the user's reference photos, 2026-11-05): the roof is the hero, a huge,
    thick reed thatch, weathered grey-brown with moss, hipped at both ends with heavy rounded
    eaves, and eyebrow dormers (the thatch swells in a wave over a half-round window). The
    Kate has lime-washed walls (`lime`), a teal door and shutters (`paint_teal`), white
    window frames, a turf ridge and a small white chimney. The longhouse has buff brick on a fieldstone base, crossed sticks
    on its ridge, two brick chimneys, white windows in dark green frames, climbing roses, and
    the big arched green barn door of the hall house as its door (the middle tile), the
    thatch sweeping up over it. The barn is half-timbered (dark oak beams, red brick) with big
    plank doors and no windows; the shack is plank-built with a roof of weathered boards.
    Every building has a summer look, a snow look and lit windows (spring and autumn show
    the summer picture until the game asks for more looks).
    Windows have small panes (task 52): 2×2 px panes in 1 px white glazing bars, 3×3 panes
    in a house window, 2×3 in the shack's, and the dormers' half-round windows divided
    the same way; a lit pane glows in one colour. The window inside is the same, with
    wooden bars and daylight.
- **Buildings cost materials:** logs, stone, clay and reeds (reeds for the thatch), taken
  from the inventory when the building is placed. The ghost shows the costs against what
  the player carries and refuses the spot while something is missing. No refunds or
  demolishing yet. First numbers (tune in play): shack 20 logs, 5 stone (plank roof, no clay or reeds);
  Kate 30 logs, 15 stone, 15 clay, 25 reeds; longhouse about twice the Kate; barn like the
  Kate with less clay.
- **The hammer builds:** holding the hammer is build mode (the ghost follows the cursor,
  use places the building); Q and E (rebindable) pick the building, and B selects the
  hammer. Escape or a right click dismisses build mode until something else is held or B is
  pressed again. With the hammer in hand E picks buildings and does not put the player to
  bed. The `nocost` console cheat waives the costs (`god` and `noweight` don't). The player
  starts with a hammer (later it is crafted); `give hammer` works too.
  A new game starts at the camp: the materials for a first house have to be gathered.
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
