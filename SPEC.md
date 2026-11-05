# Sandbox Game: Spec

Status: early concept. Last updated: 2026-11-05.

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
  autumn leaves, snow) raise the cap to **about 64** (decided 2026-11-05).
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
- **Autosave when the player sleeps and when the game quits.** On start, the game loads
  the save if there is one, otherwise it starts a new game (`--new-game` forces one).
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
    less common Linux distro (e.g. Gentoo). It checks system dependencies (Godot, Tiled,
    Python, …) and prints which ones are missing, with a hint on what to install;
  - running it again is safe and only does what is still missing.
- Planned targets: `setup`, `run`, `test`, `lint`, `export`.
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
    - **Passing out** at 0: wake up in the home bed at 06:00 next morning. That day:
      half walking speed, energy only up to 50 %, health 25. Speed effects don't stack;
      the slowest wins. The debuff lasts until the next midnight, so after passing out between
      00:00 and 06:00 it is less than a full day; sleeping does not end it early.
    - **Sleeping** fills energy and health per bed (sleeping bag 100 %, ground 50 %), and
      **eating** food (berries, turnips) restores a little energy. Both are values in the
      data file (`data/energy.cfg`).
    - The energy drain setting: Low ×0.5, Normal ×1, High ×1.5.
- **Home is the last bed the player slept in**, like a spawn point. Passing out wakes the
  player there.
- **Starting shelter:** the game starts at a small camp site with a fireplace and a
  sleeping bag, so there is always a bed.
- **The player can sleep without a bed** (on the ground, anywhere), with a real penalty:
  - energy fills to only 50 %;
  - it does not set home;
  - in dangerous areas, creatures can attack the sleeping player;
  - there is no next-day debuff. That stays unique to passing out, so the two feel
    different.
- **Sleep has a fixed duration per bed.** The player can't choose how long to sleep.
  Going to bed later simply means waking up later the next day.
- **Later: sleeping quality depends on the bed.**
  - Each bed type has its own sleep duration, e.g. sleeping bag 8 h, luxurious bed 6 h.
  - The sleeping bag is the baseline: it fills the energy bar to 100 %.
  - Better beds may fill the bar a little above 100 %. Better beds should feel like a
    bonus, not like escaping a penalty.
  - Other bed bonuses come later.
- **Tile targeting with the mouse:** the tile highlight follows the mouse cursor.
  - Within reach (the 3×3 tiles around the player for hand tools; later tools may reach
    further), the highlight shows normally, and the action (left click or Space) works on
    that tile.
  - Out of reach, the highlight turns translucent red and the action does nothing.
  - When the mouse hasn't moved for a few seconds, the highlight fades out. Then the
    keyboard action (Space) works on the tile the player faces, as before, and the
    highlight shows that tile again once the player moves.
- **Inventory and equipment** (decided 2026-11-05):
  - 20 slots at the start; the first 10 are the **hotbar**, shown at the bottom of the
    screen. Backpack upgrades later add rows of 10.
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
  - New game: tunic and trousers worn; a straw hat and a spare shirt in the inventory.
- **Movement keys:** arrow keys and WASD (decided 2026-11-05). All keys can be changed in
  the settings (see Menus and settings).
- **Scale between character and world:** character figure 27–28 px tall in its 16×32
  frame; mature trees about 2–2.5× the character (60–66 px); a small house about 3.4× (5×3
  footprint, ~96 px tall, door at least as tall as the character). Numbers in
  `docs/art-review-2026-11-05.md`.
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
  - Settings are saved in `user://settings.cfg`, separate from the save game.
  - Gamepads later.
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
  - **Foliage and grass blend:** spring to summer, summer to autumn and autumn to winter
    change over several days around each boundary, tile by tile and tree by tree (each
    has its own threshold), not on one morning. Autumn colours come in gradually; trees
    drop their leaves one by one in late autumn and leaf out one by one in spring. Winter
    without snow is bare and brown-grey, not white.
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
  Spring is a lighter, fresher green; autumn has colourful foliage (orange, red, yellow)
  and yellower grass; winter is snow-covered (snow on the ground, snow on evergreens,
  bare deciduous trees). The look changes when the season changes. This is the visual
  season only: frozen rivers, deep snow and other weather effects on tiles stay with the
  weather system. The season's look is only the base: the blend, snow and frost above
  decide per tile and per plant which look shows.
- **How the looks are drawn** (decided 2026-11-05): there are six looks (spring, summer,
  autumn, bare = winter without snow, frost, snow), each a recolour of the summer art made by
  the generator. The base terrain is summer; a look is drawn over it as a dual-grid overlay
  layer of its own (the same edge shapes as the terrain layers), so patches of autumn, bare
  ground, frost and snow have soft edges and no seams. Snow and frost lie over the season's
  look. Decorations, objects and houses pick their art by look instead. Snow cover comes from
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
    (regrow), tomatoes (regrow), strawberries (regrow) and pumpkin.
  - **Crops need light, water and warmth to grow**, with the needs per crop in the
    config: a temperature range (minimum, best, maximum), the sunlight they need per
    day, the soil moisture they need, and how much wind they stand. Each night a crop
    grows by how well the day met its needs (good days count fully, poor days partly,
    bad days not at all) and moves to the next stage after enough growth.
  - **Crops can die:** days without enough sun or water, frost below the crop's
    minimum, or wind above its tolerance (beans and tomatoes are fragile, wheat bends)
    damage the crop; enough damage and it dies and shows its dead stage, which the empty
    hand clears. Damage heals slowly on good days.
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
    spruce 4, pine 7 (level 2), dead tree 3, stone 3, boulder 6 (level 2), stump 2.
    Damage heals overnight.
- **Harvesting, reworked** (decided 2026-11-05; replaces drops straight into the inventory,
  stumps regrowing into trees and the generic sapling):
  - **Final resources lie on the ground** where they come off, as items you collect by
    walking over them (a small pull towards the player in the last half tile). Final
    resources are logs (the item `wood` becomes `logs`), stone, clay, hay, all crop
    produce, and also what is picked by hand (berries, fibre) and seeds. They stay on the
    ground (saved) until collected; with a full inventory they stay where they are.
  - **Intermediate leftovers are objects** that are hit again with the right tool.
  - **Trees:** felling leaves a stump on the tree's tile and a fallen trunk (2×1, lying
    away from the player; 1×1 if there is no room). The axe cuts the trunk into most of the
    logs (e.g. oak 3, spruce 3, pine 4, dead tree 2) and chops out the stump for 1 log.
    Living trees sometimes leave a seed of their species on the ground (acorn, spruce cone,
    pine cone; about 25 %).
  - **Stumps don't regrow into trees.** A stump left alone rots away over about two weeks;
    when it is gone it has a chance (about 30 %) to leave a sapling of its tree's species
    in its place.
  - **Seeds per species:** a tree seed is planted on grass anywhere, becomes a sapling of
    its species and then that tree. The generic sapling item goes away.
  - **Stone:** a mined stone breaks into stone items scattered around its tile; a boulder
    (level 2) into more of them.
  - **Hit feedback:** every hit shakes the object, the finishing one too. A tree with
    foliage drops a few leaves (needles for spruce and pine, all year), a snowy tree a
    puff of snow, a bare tree nothing. Stone and boulders throw a few one-pixel splinters
    that arc out and fade. Effects are pixel particles on the art grid.
  - A berry bush gives berries and bears again after a few days; picking it doesn't
    remove it. Shrubs and fern bushes give fibre.
  - Collected items go onto existing stacks first, then into free slots, and into the held
    slot only when nothing else is free, so an empty hand stays empty while harvesting.
- **Scythe and tall grass:** tall grass grows in meadows, in over spring, tallest in summer,
  gone in winter (a vegetation curve). The scythe mows 4 tiles per swing: the 2 straight
  ahead and the tiles left and right of the nearer one. Mown grass gives hay on the ground
  and grows back after some days.
- **Shovel and clay:** some spots near rivers, lakes and wetland hold clay, hinted only
  slightly on the ground (a few reddish-grey pixels; easy to miss). Digging such a spot
  with the shovel sometimes gives clay; a dug spot is spent for some days. Digging
  anywhere else gives nothing.
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

Not in the prototype: combat, reputation, biomes beyond one, weather, energy, saving and
loading, final hand-made art (generated art only, see Art pipeline).

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
