# Sandbox Game: Design

Status: playable prototype (the milestone 1 slice and much more; the [handbook](../handbook/README.md)
lists what works today). Last updated: 2026-11-08.

This folder is the single source of truth for what the game is. It was one file (`SPEC.md`)
until 2026-11-08 and is now a tree: one folder per category, one file per topic. Decisions
move from "Open questions" to the category pages as they are made. Pages that are only
ideas or plans say so at the top: **Planned, not decided**, or **Ideas, not decided**.

A category folder can hold draft images (mock-ups, sketches) next to the text that uses
them, linked from that text. Finished game screenshots live in
[docs/screenshots](../docs/screenshots) instead.

## Vision

A top-down farming and life sim in the tradition of Stardew Valley and Harvest Moon. It
has much more exploration than those games, and optional real-time combat for players who
want it. Building is free: structures can be placed anywhere, and they are far more
customisable than the genre usually allows. The world reacts to seasons and weather:
rivers freeze, swell or block the way.

Art direction: 16-bit-era top-down pixel art, in the direction of Zelda: A Link to the
Past. World, characters, art and names are original; nothing is taken from existing games.

**Setting:** semi-fantasy, medieval. **Magic** comes later (see [Later features](#later-features)).

**Lighting** gives the pixel art a slightly modernised retro look: modern light effects on
top of classic pixel art (details in [Lighting and look](presentation/look.md)).

## Pillars

1. **Home loop:** farming and life sim as the steady core.
2. **Exploration:** a larger world with biomes and more to discover than is usual for the
   genre.
3. **Optional combat:** fighting is the player's choice; peaceful play stays fully viable.
4. **Free building:** construct anywhere; buildings are highly customisable.

## Contents

- [World](world/README.md): The generated land, its coast, the year and the weather, and the wild animals.
    - [generation.md](world/generation.md): Shape, biomes, interiors, the worked land (fields, Knicks, ditches), which trees grow where.
    - [coast.md](world/coast.md): The North Sea coast: sea dyke, salt marsh, tidal mud, Warften, Ewer.
    - [seasons-and-weather.md](world/seasons-and-weather.md): Calendar, seasons, vegetation through the year, weather, day length, floods.
    - [wildlife.md](world/wildlife.md): Ambient wildlife: birds, deer, frogs and the rest, and how they come and go.
- [Player](player/README.md): The figure the player controls: energy, sleep, inventory, tools and fighting.
    - [energy-and-sleep.md](player/energy-and-sleep.md): The energy bar, tiredness, passing out, beds, sleep.
    - [inventory-and-character.md](player/inventory-and-character.md): Mouse targeting, inventory and equipment, the character screen, movement keys, sprite, tools.
    - [combat.md](player/combat.md): Real-time action combat (little decided yet).
- [Farming and resources](farming/README.md): What grows, what is gathered and what is kept.
    - [crops.md](farming/crops.md): Crops, tilling, watering, foraging.
    - [resources.md](farming/resources.md): Trees and minerals, felling and mining, harvesting, scythe, reeds, clay, regrowth.
    - [livestock.md](farming/livestock.md): Cows, sheep, hens, dogs, cats and horses; riding.
- [Crafting](crafting/README.md): Making things from what was gathered, and the skills that grow with it.
    - [crafting.md](crafting/crafting.md): The crafting menu, recipes, the chest.
    - [professions.md](crafting/professions.md): Skills, stations, the kiln, the recipe list.
    - [ideas.md](crafting/ideas.md): Ideas for more crafts and professions. Not decided.
- [Building and land](building/README.md)
    - [first-buildings.md](building/first-buildings.md): The first buildings, their looks and shapes, the landing.
- [Villagers](villagers/README.md): The people of Wehlsbüll, what they say, and what they think of the player.
    - [villagers.md](villagers/villagers.md): Who the villagers are, the village, sheets, behaviour, what is saved.
    - [dialogue.md](villagers/dialogue.md): Talking: the chat, the language model, the prompt, memory.
    - [gossip.md](villagers/gossip.md): What villagers see, remember and pass on. Decided, not built.
    - [reputation.md](villagers/reputation.md): Reputation, and how it spreads.
    - [relationships.md](villagers/relationships.md): Friendship levels and what moves them. Planned, not decided.
    - [ideas.md](villagers/ideas.md): Ideas for NPCs, behaviour and LLM dialogue. Not decided.
- [Economy](economy/README.md): Money, trade and shops. Planned, not decided.
    - [README.md](economy/README.md): Currency, barter, shops, the player's stall, how money is saved.
- [Presentation](presentation/README.md): How the game looks, sounds and is operated.
    - [look.md](presentation/look.md): Rendering, tile size, zoom, camera, lighting.
    - [art-pipeline.md](presentation/art-pipeline.md): How the art is made, the palette, style rules, variety.
    - [sound.md](presentation/sound.md): Generated sounds and the ambience.
    - [menus-and-hud.md](presentation/menus-and-hud.md): Pause menu, settings, tooltips, UI look, coordinates display.
    - [console.md](presentation/console.md): The debug console and its commands.
- [Tech](tech/README.md): How the game is built: engine, saving, the tile model and world edits.
    - [build-and-tools.md](tech/build-and-tools.md): Engine, make targets, tools.
    - [saving.md](tech/saving.md): Save format, autosave, save upgrades.
    - [tile-state.md](tech/tile-state.md): A tile is state, not a picture.
    - [world-objects-and-edits.md](tech/world-objects-and-edits.md): World objects, and how edits and buildings are stored.

## General

- Perspective: top-down 2D, pixel art.
- The world is built from tile maps.
- Single-player for now. Multiplayer may come later, so don't make choices that rule it
  out. In practice: game state (world, entities, reputation) is kept separate from
  rendering and input, and it changes only through explicit actions.

## Later features

- **Magic.** Planned for later; design to be done. The lighting setup (point lights,
  glow) should make magic effects cheap to add.

## Milestones

### 1. Prototype (vertical slice)

Goal: prove the world, building and Tiled pipeline with the smallest playable thing.

- A generated, chunked world from a seed, using the tile-state model (see [Tile state](tech/tile-state.md)).
- Building placement that checks tile state (at least: blocked tiles).
- A player who can walk around, starting at the camp site.
- A day counter. Sleeping in the sleeping bag advances to the next day.
- One preset building that can be placed, with one interior map.
- One crop that can be planted and grows over days.
- The make targets from [Tech](tech/build-and-tools.md), including `make setup`.

Not in the prototype (as planned): combat, reputation, biomes beyond one, weather, energy,
saving and loading, final hand-made art (generated art only, see [Art pipeline](presentation/art-pipeline.md)). The slice
is done, and weather, energy, saving and loading and sound have been added since.

Tasks: see [TASKS.md](../TASKS.md).

### 2. A first season without the console

Decided 2026-11-14 (the user, from the
[game design review](../review/game-design-review-2026-11-11/README.md)): a new player can
farm, replant, meet the village, make something useful and work towards something, with no
console commands.

- **The village:** Wehlsbüll stands in the world near the start with its eight hand-written
  villagers in their homes, not one farm alone.
- **Seeds:** a villager's seed chest trades seeds by barter (no money yet), and some seeds are
  found wild. Recovering from a lost harvest never needs friendship or a language model.
- **Light:** the lantern and candles can be made.
- **Information:** seeds and crops say in plain words what they need and how they are doing;
  a hint names what the next click or E will do.
- **Goals:** villagers ask for small things now and then; no quest chain.

Tasks 231 to 236 in [TASKS.md](../TASKS.md).

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
