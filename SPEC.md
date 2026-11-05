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
- Tiled maps (`.tmx`) are imported directly by an **importer addon** (e.g. YATI). The `.tmx`
  file stays the source of truth; there is no manual export step.
- Build, run, test and other multi-step tasks are wrapped in **make** targets, so each one
  is a single command.
- **`make setup`** sets up the stack:
  - it installs what it can automatically: project-local addons (Tiled importer, GUT) and
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
- **Inventory and equipment.** Carried items have weight (see Energy).
- **Tools** are bought and upgraded.

### Time, seasons and weather

- Days and seasons work as is usual for the genre: crops grow day by day, and the season
  decides what grows.
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

- Wild crops can be foraged.
- The biome decides which resources are available and what the land is good for
  agriculturally (see Biomes).

### Resources: trees and minerals

- The world has **trees and minerals in different varieties** (e.g. several tree types,
  stone, ores).
- Each variety has a **harvest level**: harvesting it needs a tool of at least that level.
  This ties resources to tool upgrades (see Player: Tools).
- The biome decides which varieties occur where (see Biomes).

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
loading, real art (placeholder tiles only).

Tasks: see [TASKS.md](TASKS.md).

## Open questions

- **Reputation details:**
  - What does reputation unlock or block (prices, quests, hostility)?
  - Which NPCs in the territory are affected: everyone, or only those living closest?
- **Resources:**
  - Are trees and minerals world objects placed on tiles (with their own state, e.g. hits
    left, regrowth), or terrain types? Suggested: world objects.
  - Do they regrow or respawn? If so, how (trees from saplings, minerals per season, new
    ones in unexplored areas)?
  - Can the player plant trees?
  - Does a stronger tool only unlock varieties, or also harvest faster?
- **Target platforms:** Linux only, or desktop in general? Web?
- **Scope:** hobby, learning project or release target?

## Deliberately left out

- Land ownership and plots.
- Fully modular, tile-by-tile building construction.
- Multiplayer in the first version.
