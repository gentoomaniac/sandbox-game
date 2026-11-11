# Architecture

How the code is organised, and where to look first. For what the game is meant to be, read
the [design](../design/README.md); for how to build and run it, the README.

## Three layers

```
data/*.cfg            numbers and content you can edit by hand
game/state/           the game as plain classes: no nodes, no input, no drawing
game/world/           world generation, chunk planning, the interior map loader (also no nodes)
game/scenes/          everything you see and hear: nodes, views, menus, shaders, sound playback
```

The rule that holds the project together: **scenes read the state and send it actions;
the state never knows about scenes.** That is why almost everything in `game/state/` and
`game/world/` is tested headless with GUT, and why `game/scenes/` is checked by eye with
`make screenshot`.

Names are not always where you would guess: the `World` class (tiles, chunks, objects,
buildings) is in `game/state/world.gd`. `game/world/` holds the code that builds a world
and plans which chunks to load (`WorldGenerator`, `FieldLayout`, `ChunkStreaming`, `CampSite`,
`InteriorLoader`, `PositionHash`). `WorldGenerator` makes the natural land (river, wetland,
forests) and lays the worked land of `data/landscape.cfg` over it: the fields of a `FieldLayout`
with Knicks, walls and fences on the Geest, ditches in the marsh, and dykes. In the west it makes
the coast (task 61, same file): a coast line x = f(y) like the river's centre line, the sea dyke on
the first land, and beyond it the foreshore (salt marsh, tidal mud with tideways, the sea), with a
Warft and an Ewer here and there.

## The main objects

- **Main** (`game/scenes/main.gd`, `main.tscn`) is the one scene. It owns the `GameState`,
  turns real time into game minutes, sends input to the state and creates the views and
  screens. Its `_ready` runs in steps: load the game, make the views, connect the state and
  the views, apply the start options. The windows (`CharacterScreen`,
  `CraftingScreen`, `StorageScreen`, `ChatScreen` and `PauseMenu`) extend `Modal`, which builds
  the backdrop and panel, opens, closes, takes Escape and keeps one window open at a time; Main
  asks `Modal.is_any_open()`, and a window's key does nothing while another is open (see
  [ui.md](ui.md)). The console is a strip, not a window, and keeps its own code. The debug flags
  are parsed by `StartupOptions`; `DebugRunner` does the ones that wait for the world to be drawn
  (see below).
- **GameState** (`game/state/game_state.gd`) is one game: the world, the clock, the sun, the
  weather, the snow cover and the player. It is the entry point for actions (`walk`, `use_at`,
  `sleep_in`, `pass_door`, `pass_out`, `go_to_home_bed`, `teleport_to`), and what gets saved (`to_dict`, see `SaveFile`). It owns
  the clock and gives it to the World; `current_map` follows from the building the player is in.
- **Simulation** (`game/state/simulation.gd`) is the one owner of game time, and the rule is:
  whatever moves the clock goes through it, and whatever changes with time is a
  `SimulationSystem` it runs, in a fixed order, after each span. `advance(minutes)` is played
  time (Main's frames), cut at every full hour so a long span passes as the same hours one after
  the other; `skip(minutes)` is time the player does not live through (the console's `skip`,
  sleeping, passing out): the first 3 minutes are played through minute by minute for what the
  frames move (`walked_minute`) and the rest is made up for in one go (`skipped`); `skip_over_frames`
  is the same spread over frames, for the sleep and passing out under their black screen (the
  villagers in steps of 8 ms, `Npcs.catch_up_over_frames`, and the soil moisture, which a save
  would else catch up in one go, `SoilMoisture.catch_up_all_over_frames`, and the fallow soil whose
  days are up in the skip's nights: `NightUpkeep` counts the nights and, told by `skip_begins` that
  a skip's rest is about to be made up for, sees to the soil at its end,
  `World.settle_fallow_soil_over_frames`), each within `Simulation.frame_budget_usec` a frame.
  Main holds the world still meanwhile, the chunk
  residency's streaming (no chunk loads or drops by `update`; `require` still loads what an
  action needs) and the views too (wildlife), until the player has woken, and a quit waits
  for that: so the world ends as after `skip` and a save is of a whole morning. The systems:
  `FarmingUpkeep` (every hour: the crops live through the hour, a 24th of a day's growth in the
  weather of its day; the end of the day counts for them), `NightUpkeep` (at midnight: reeds,
  saplings, stumps, bushes, clay spots, desire paths, fallow soil) and
  `ActorsUpkeep` (the farm animals and
  villagers, in loaded chunks only: short skips are walked, long ones put each on a tile it could
  have walked to, `ReachableTiles`, with dice from the world seed and the time). Three kinds of
  time-dependent state, and what each needs: (1) a pure function of the clock (weather, sun,
  tide, snow cover, station work by `total_minutes`, which plants are dormant): nothing, it
  follows by itself, so such state must stay a function of the clock; (2) state that must catch
  up (crops, tilled soil moisture, animals, villagers): a system; the soil is not stepped tile
  by tile but kept as of the hour each tile was last looked at and caught up when asked
  (`SoilMoisture`), so a month costs about its crops; (3) what only shows (wildlife, weather
  fade, clouds): the views re-show from the state, and after a skip `Simulation.skipped` has
  `WildlifeView.settle` and `WeatherView.snap` do it at once. Played time (`advance`) never moves
  animals by itself: they walk by the frame in real seconds (`Livestock.update`,
  `Npcs.update`), outdoors only. A new system (a villager schedule, a gossip meeting) is a
  `SimulationSystem` added in `GameState._start_simulation`, with the hook it needs.
  The game's speed is `GameClock.GAME_MINUTES_PER_REAL_SECOND`. Tests compare skips of an
  hour, a day and a month with the same time played in steps (`tests/test_time_skip.gd`).
- **ToolUse** (`game/state/tool_use.gd`) is what the use action does: the `Use` outcomes, what
  each tool does on a tile, and the energy it costs. GameState makes one per call
  and forwards `use_at`, `use_tile`, `use_facing_tile` and `can_use_held_item` to it (kept in a
  field, the two would hold each other and never be freed). To change what a hoe
  does, open this file. `use_tile` checks its own conditions: a tile beyond `Targeting.REACH` or
  not on the player's map is refused (`OUT_OF_REACH`, nothing changed, no energy), and on
  horseback the use is `RIDING`; so the UI, the debug scenes and tests all get the same answer.
- **ActionOutcome** (`game/state/action_outcome.gd`) is what one finished action of the player
  did: who, the kind (till, plant, harvest, break, place, build, craft, eat, pick up ...), the
  tile on its map, the object type and the items with counts. GameState tells it once through
  `action_done`, after the action worked (`ToolUse`, `Builder`, `Crafting`, `eat_held`,
  `drop_from_inventory`, `collect_ground_items`, `take_down_building`): never for a refusal and
  never for loading a game. Whoever reacts (the sounds, later the deed log of the gossip)
  listens to it; there is no global event bus. Low-level setters (`World.set_terrain`, console
  and debug commands) tell nothing.
- **GameMap** is a place the player can walk: either **World** or **Interior** (the inside of
  one building). The player is on one map at a time; the world stands still while they are
  inside. Both tell their views the same way: `objects_changed(pos)` and `tile_changed(pos)`
  (one per tile an object covers), so `WorldView` and `InteriorView` redraw from the map's own
  signals and Main redraws nothing for particular tool results.
- **World** holds the loaded chunks of tiles (`Tile`, `Chunk`), the objects on them
  (`WorldObject`: trees, crops, furniture), buildings and, in `ground_items` (`GroundItems`),
  the items lying on the ground. Line objects (Knicks, walls, fences, dykes) are one object per
  tile whose type `connects`; `World.connections` says which neighbours a tile joins, and the
  view draws the picture of that connection mask. The wear of desire paths is World's too
  (`wear_tile`, `wear_stage`, `regrow_paths`; numbers in `data/paths.cfg`, `PathRules`):
  `GameState.walk` and `Livestock` wear each tile entered, and a tile that turns trodden or
  a path emits `tile_changed`, so the view redraws the cells around it as for a tilling. The
  view draws worn tiles on the `TRODDEN` and `PATH` layers of `TerrainTileset`. Tilled soil that
  nobody tends grows over (`World.fallow`, `FallowSoil`; numbers in `data/crops.cfg`): no night
  visits every tilled tile, the nights that count are numbered and the tiles filed by the night
  they were last tended at, so a night (`World.settle_fallow_soil`) sees only to those whose days
  are up: weedy (a `tile_changed`; `DecorationView` draws the soil's weeds), or grass again (the
  terrain edit is grass). Working a tile (`set_terrain`, `set_moisture`, `add_object`, `take_off`)
  tends it. What changes with time is run by
  the Simulation's systems (`NightUpkeep` at midnight, `FarmingUpkeep` every hour) on the world.
  Every change goes through World, and it emits signals that the views follow.
- **WorldView** (`game/scenes/world_view.gd`) draws a `World` into a SubViewport at one art
  pixel per screen pixel; `CameraController` shows that viewport on the window, so the world
  scrolls smoothly. `InteriorView` draws an `Interior` in its place while the player is inside.
  Which chunks are loaded is not its business: a `ChunkResidency` (`game/world/chunk_residency.gd`,
  made by Main, no nodes) follows the player's tile, plans with `ChunkStreaming`, generates the
  nearest missing chunk and drops the far ones, and tells by `chunk_loaded` and `chunk_unloaded`.
  WorldView draws what is loaded (a chunk a few rows of cells at a time within a per-frame time
  budget, so no frame holds a whole chunk's drawing; Main lets the residency load the next one
  when the view has drawn the last) and erases what is dropped; it also draws
  terrain, objects, falling trees and the see-through effect; it owns two small views,
  `BuildingViews` (building sprites, window lights, snowy roofs) and `DecorationView` (flowers,
  pebbles, clay hints; the wildlife asks it where flowers bloom). The meadow flowers are sown per tile when a chunk is drawn, by `FlowerRules`
  (`data/flowers.cfg`) from two noises and the tile's habitat, and bloom by the curves of
  `Vegetation`; nothing about them is saved. What a tile looks like is one int, its tile code: layer, season look and weather look
  packed together (`TerrainTileset.tile_code`, read with `layer_of`, `season_of`, `weather_of`;
  the bit fields are documented there).
- **Tide** (`game/state/tide.gd`) says how high the water stands at a moment of the clock; it is a
  look only. Main gives it to `AmbientMotion.show_tide` every frame, and `mud.gdshader` on the
  mud layer floods the mud by it, with the water's ripples of `water_surface.gdshaderinc` (which
  `water.gdshader` shares).
- **Livestock** (`game/state/livestock.gd`) holds the farm animals (`FarmAnimal`) and moves
  them: GameState owns it and Main calls its `update` every frame while the player is
  outside. The numbers are `data/livestock.cfg` (`LivestockRules`). The WildlifeView draws
  them: one `FarmAnimalView` (an `Animal` like the wild ones, but its state comes from the
  FarmAnimal) for each animal near the view. A horse is saddled by `ToolUse` (`SADDLE`,
  `UNSADDLE`) and ridden through `GameState.mount` and `dismount`: `PlayerState.horse` is the
  horse ridden (not saved), which `PlayerState.move` takes along and `Livestock.update` leaves
  alone (`FarmAnimal.is_ridden`); `PlayerView` draws the rider's riding sheets on the ridden
  horse's sheets while the horse's own view hides. A dog given a bone (`ToolUse`, `GIVE_BONE`)
  follows the player until a game minute it keeps (`follow_until_minute`). Wildlife is view only and
  not saved; livestock is state and saved, and shares the wildlife's drawing, sheets and
  sounds. A group of birds is one `Animal` with a sprite per bird: `Flock` (sparrows or a
  skein of geese crossing in a V) and `GroundFlock` (geese grazing, oystercatchers and dunlin
  probing the mud, then taking off together; their numbers per kind are its `FLOCKS`). The birds
  of the coast read the tide through `WildlifeView.is_water`: above `flooded_tide` the mud is
  water, so nothing stands on it (`can_stand`), a `Gull` swims there and a `Tern` dives.
  Storks on roofs (`Stork`) stand on the top edge of the house's picture as it is shown
  (`WorldView.building_picture`, so snow is counted), just in front of where the house sorts
  (`BuildingViews.sort_position`); flying birds cast `GroundShadows`. A stork finds its frogs
  (`Frog`) with `WildlifeView.nearest_animal`, asked when it picks what to do next, not every
  frame. A cat's hunt is Livestock's alone, so it needs no view and no camera: the mice are
  ambient wildlife (nodes of the `WildlifeView`, near the camera, not saved), and each `Mouse`
  reports itself to Livestock as a `Prey` (`add_prey`; its position in tiles, `is_about`, kept up
  to date by `Mouse.sync_prey`, after the mouse has moved). When a cat picks what to do next Livestock looks for the nearest
  `Prey` in sight, and `start_hunt` has it crouch, creep and pounce by the `[hunting]` numbers of
  `data/livestock.cfg`, rolling the catch with Livestock's dice. Its outcome is left in
  `Prey.fate` (caught, or scared off from a point) for the mouse to show, and the cat's
  `FarmAnimalView` only plays the crouch, creep and pounce frames of its activity. A mouse that
  goes (run off, or its view freed) is no longer about, which ends the hunt of any cat after it:
  the cat rests and idles where it stands. With no wildlife view there are no mice, so nothing
  hunts and nothing is left half done; a cat far from the camera hunts a mouse in sight all the
  same. Skipped time (the walked minutes of a skip and `catch_up`) looks for no mouse and gives up
  a hunt in progress with no outcome for the mouse. Nothing of a hunt is saved.
  The farm yard (task 122): each animal has a `hunger` and a `thirst` (saved) that `Livestock` raises
  with game time (`YardRules`, the `[needs]` section of the same data file; the console's `noneeds`
  cheat stops it) and no other code reads yet. When a need reaches `seek_at` and the animal next
  picks what to do, `Livestock._start_trip_to_need` looks for the nearest tile it can walk to
  with fresh water (`Tile.is_fresh_water`) or an `ObjectStock` of the right `stock_kind` beside it
  (the trough: water, the hay rack: feed; the stock is `stock` in the object's state), walks there
  and takes its `drink_units` or `eat_units`; `catch_up` counts the meals of a skip. The player
  fills a stock in `ToolUse` (the can's water is `PlayerState.can_water`, filled at a draw well or at
  fresh water). `Coop` is the chicken coop: at bedtime a hen walks to one with a free roost and goes
  in (`FarmAnimal.is_housed`, derived from where she stands, so not saved), lays an egg in a nest (a
  hay pile of `Building.inside`, `eggs` in its state) and the empty hand takes them (`Use.COLLECT`).
  Petting (task 173): the empty hand at an animal is `Use.PET` (last of what the hand does on a
  tile), `Livestock.pet` changes the animal's `friendship` (saved with its petting days) and tells
  `petted`; the daily loss is worked out by `account_friendship` from the days, with the needs
  (`account_clock`). Nothing reads the friendship yet but the console's `friendship`.
- **Npcs** (`game/state/npcs.gd`) holds the villagers (`Npc`: name, sex, look as an
  `Appearance`, who they are (their whole sheet: age, trade, personality, background, home,
  speech, sample lines, people, likes, wants, day, habits, avoids, secrets), position, anchor,
  chat history and memories) and moves them like the livestock: GameState owns it, Main calls
  its `update` every frame while the player is outside, and the numbers, names, clothes and
  background tables are `data/npcs.cfg` (`NpcRules`); the villagers written by hand, spawned by
  id, are `data/villagers.cfg` (`VillagerRules`, which also checks that their family and
  friends name each other back; a loaded one takes their sheet from it, so edits to the file
  reach saved games); the village they all share is `data/village.cfg`
  (`VillageSheet`). Each is drawn by an `NpcView` among the world
  view's entities, with the player's sheets and frames. E speaks to the villager
  `Interaction.npc_to_chat` names, before any chest, station or bed; `ChatScreen` shows the
  chat as bubbles between both portraits (`Appearance.portrait_layers`) and pauses the game
  while it is open.
- **What villagers say** comes from one place, `NpcDialogue.reply` (`game/scenes/`, a node, as
  it talks to the network); `NpcDialogue.say` commits the player's line and the answer to the
  villager's chat, so no window has to survive it, and the wait is the villager's
  (`Npc.is_answering`). With a language model set in Settings the chat of the
  provider (`ModelChat`: `OpenAiChat`, one POST to an OpenAI-compatible `/chat/completions`, or
  `ClaudeChat`, one POST to Anthropic's `/messages` with the system lines on top; both run while
  the game is paused, with a time-out and no redirects, so a key goes nowhere else, and both
  list the endpoint's models for Settings; tests put `FakeChat` in their place), else, or when that fails, it says a scripted line. The
  request is built by `NpcPrompt` (`game/state/`): pure functions of the villager, the chat,
  the moment (`NpcMoment`: clock, sun, weather and place, taken from GameState) and the words
  of `data/npc_talk.cfg` (`NpcTalkRules`), so they are tested without a model. Its system line
  carries the village's sheet and the villager's, in full or cut down: `NpcDialogue` asks for the
  full ones when the provider needs a key (a hosted model). `NpcLanguage`
  tells the language of the player's line (English, German, Danish; word lists and letters from
  the same file, the chat's earlier lines for a line too short) for the prompt to name. The villager keeps the
  last lines of the chat (a setting); `NpcDialogue.compact` sums the lines that drop out up in a
  memory line, the dropped lines waiting in `Npc.uncompacted_lines` (saved) until it is made.
  Only the reply and memory text come from the model; it changes nothing else.
- **Crafting** (`game/state/crafting.gd`) is what the crafting menu does: it checks a recipe of
  `RecipeRules` (materials, the skill level it needs), crafts it and practises its skill on the
  player's **Skills** (`skills.gd`: points per skill, the total cap and the skills that fade,
  rules from `SkillRules`). A recipe is made by hand or at a station (`StationRules`: which
  object types are which station); a slow one (with `hours`, the kiln) is held by its station
  as **StationWork** in the object's `state` until it is done on the game clock. `craft` checks
  its own conditions: a recipe made at a station needs one of that kind on the player's map in
  their reach (`NO_STATION`, or `WRONG_STATION` for another kind), whatever the menu showed.
  `Interaction` says which chest or station E opens; `CraftingScreen` shows the recipes of one place.
- **Units:** the state works in tiles (positions, speeds, reach); the views turn tiles into
  world pixels with `TerrainTileset.TILE_SIZE` (32: a tile is 32×32 art pixels, task 106).
  `ViewMath` holds the numbers of the two-stage rendering: zoom 0.5 is the widest view,
  1280×720 art pixels (40×22 tiles) in a stage-one viewport of that size plus a margin, zoom 1
  shows 640×360 and zoom 2, the closest, 320×180; the zoom keys and Ctrl and the wheel move it
  (`CameraController`). While the art is the 16 px art doubled (see docs/art-style.md,
  "Resolution"), a number measured on a picture is written as its 16 px number times
  `TerrainTileset.ART_16_SCALE`; once its group is drawn at 32 px (the people, task 113; the
  farm animals, task 114; the wild animals, their shadows, the hit particles, the fire and the
  weather, task 116; the ground, task 107; the buildings, task 110; the plants and the trees'
  `sprite_height`, task 108; the items on the ground and their hop, task 115; the walls, fences,
  the dyke, the camp and the placed objects, task 111), as the number measured on the 32 px
  picture; and the shaders of
  the art work on its pixels through `art_scale` (`art_scale.gdshaderinc`), which
  `AmbientMotion` sets for the ground's and the plants' shaders by the art set (1, or 2 in the
  classic art; the plants' sway profiles are in the world's pixels and halved for the classic
  art) and to 2 for the crops, still 16 px art. The object atlas has cells of 3×5 tiles at 32
  px, every row drawn at 32 px; a type whose picture is wider (the Ewer, in scale with the
  people) spans `cells_wide` cells of its row, one tile of the TileSet. `WildlifeRules.TILE_SIZE`
  is the same tile size for the state, which can't see the
  scenes (a test keeps the two equal).
- **Item icons in the UI:** the icons are 32 px pictures and the classic ones 16 px; a slot
  (`SlotView`), a recipe row and the icon that follows the mouse (`ItemIcon`) draw them into
  16 UI pixels whatever their size, through `sharp_pixels.gdshader` (sharp bilinear, as the
  world's screen), so each art pixel stays a square at 1.5 window pixels.
- **Art sets:** the 16 px art of a group drawn anew at 32 px stays in the game as the classic
  art, generated into `assets/classic/` by tools/art/classic/ under the new art's names.
  `ArtSet` (`game/scenes/art_set.gd`) picks the picture of the chosen set: every load of a group
  that has classic art goes through `ArtSet.path`, which gives the classic picture where there is
  one. The setting is `GameSettings.is_classic_art` (Settings → Display, F7); on a switch Main
  calls `ArtSet.show`, and the views that keep their pictures (`NpcView`, `CharacterPreview`,
  `ChatScreen`, every `Animal` with the flocks' birds, `WorldView` the ground, the objects, the
  fires' flames and the buildings, `ObjectCover` the bedroll's cover, `InteriorView` its
  room, which it shows anew, `BuildMenu` the pictures of its cells, and `SlotView`, `ItemIcon`
  and `GroundItemView` the item icons
  and the items on the ground: the group `ArtSet.VIEWS`, `show_art_set()`) load them anew, while
  the others load theirs as they show them (`PlayerView` its layers and the ridden horse,
  `BuildMode` the ghost). The classic buildings are as big as the new ones, so a building's
  window lights and its place stay the same in both sets. The open chat pauses Main, so it
  passes F7 on itself (`ChatScreen.art_set_switch_pressed`). The terrain and the object
  tilesets follow: both sets have the same tiles, so `TerrainTileset.show_art_set` and
  `ObjectTileset.show_art_set` only swap the atlases' pictures and no map is redrawn;
  `WorldView` also shows the chosen set when it is given a world, since it is made before Main
  reads the setting. The numbers measured on the art are
  the new art's in both sets, but for the rider's seat on the classic horses
  (`PlayerView.CLASSIC_SEAT`, `CLASSIC_PONY_SEAT`).
- Other views each draw one piece of state: `PlayerView`, `WeatherView`, `WildlifeView`,
  `BuildMode` (the ghost, and the red marking and hold of taking down; `Builder` holds the
  mode, the chosen building and style and what each target gives,
  `GameState.take_down_building` the rules for buildings), `BuildMenu` (the row of buildings
  above the hotbar, the chosen one's styles and the preview; its cells take the clicks on
  them, so they never reach the land, and it shows build mode's messages while it is up),
  `GroundItemView`, and the HUDs and screens (`HotbarHud`, `CharacterScreen`,
  `CraftingScreen`, `PauseMenu`, `ConsoleView` and so on). The hotbar is on a layer above the
  character and chest screens and is their quick bar: they take it in their constructor and
  listen to its slot views, and it passes clicks on to the game when none of them is open.
  A stack let go outside a screen reaches the world as `drop_requested`, which Main hands to
  `GameState.drop_from_inventory`.

## Data files and how to add content

Gameplay numbers live in `data/*.cfg` (ConfigFile syntax, with the meaning of every key in
the comment at the top of each file). The path from a file to the game is usually the same (`vegetation.cfg` is read by
`Vegetation`, which has no `_rules` file; file names are plural, the classes singular):

```
data/<topic>.cfg  ->  game/state/<topic>_rules.gd  ->  a Types class or the state that uses it
```

- A `*Rules` class reads its file with `DataFile.read_sections(path)`, checks it (`problems()`,
  `is_valid()`) and serves the values. `Main._ready` refuses to start, and reports what is
  wrong, if any of them is invalid.
- `BuildingTypes`, `WorldObjectTypes` and `ItemTypes` are the tables of kinds, built from the
  rules and from definitions in code. Look there for what a kind of object or item is. Their
  entries are read-only all the way down (`ReadOnly`): a caller that changes what it gets back
  fails loudly. A test that needs an item of its own swaps in a small catalog of its own for
  `ItemTypes.TYPES` and restores it, it never adds to the shared one.
- `CatalogCheck` checks every item and object with its references at start (fields in range,
  wearables stack 1, what an item places or plants, what an object drops, leaves or seeds exists,
  ids of crops and trunks don't collide); `Main._ready` refuses to start and reports `item <id>:
  ...` or `object <id>: ...` for each mistake (as errors in the log: the game quits before it
  opens a window). `AssetCheck` does the same for the pictures: every item and object has its
  icons, sprites, sheet and atlas cells in both art sets (a line names the art set). Run `make
  test` after adding an entry: its test runs the same check.

Typical jobs:

| Job | Where |
|---|---|
| New crop | A section in `data/crops.cfg` and a picture sheet; no code. |
| New building | A section in `data/buildings.cfg`, its two pictures and an interior map ([maps/README.md](../maps/README.md)), or an empty `interior_map` for one nobody goes into (the bell frame). |
| New building style | A section `[<building>.<style>]` after its building in `data/buildings.cfg` with its `name` and the keys it changes (its pictures, costs); it shares the building's footprint, door and inside. |
| New recipe | A section in `data/recipes.cfg` for an item that exists in `ItemTypes`; `station`, `skill`, `level` and `hours` are optional. |
| New station | A placed object kind (`WorldObjectTypes` with `drops` and `placeable_in`, `ItemTypes` with `places`, its picture in `tools/art/crafts.py`), a section in `data/stations.cfg`, and a recipe that makes it. |
| New skill (profession) | A section in `data/skills.cfg`, and recipes that name it. |
| New sound | An event in `tools/audio/generate.py`, a section in `data/sounds.cfg` ([tools/README.md](../tools/README.md)). |
| New object or item kind | An entry in `WorldObjectTypes` or `ItemTypes` (an object an item places also needs `placeable_in`), and its art ([tools/README.md](../tools/README.md)). Start the game or run `make test`: `CatalogCheck` names what is missing or wrong, item and field. |

### Adding a data file

There is no base class: each rules class is plain, so copy one that is shaped like yours
(`EnergyRules` for fixed sections and keys, `RecipeRules` for one section per thing).

1. Write `data/<topic>.cfg`, with the meaning of every key in the comment at the top.
2. Write `game/state/<topic>_rules.gd` with `DEFAULT_PATH`, a `static var _default`,
   `default_rules()` (loaded on first use), `from_file(path)` and the accessors. `from_file`
   is `DataFile.read_sections(path)` handed to the constructor, then a `push_error` for each
   of `problems()`; `DataFile` already reports a file that can't be read.
3. `problems() -> Array[String]` lists what is missing or wrong as `"[section] what"`, and
   `is_valid()` is `problems().is_empty()`.
4. Add `<Topic>Rules.default_rules().is_valid()` to the check in `Main._ready`.
5. Test it: the real file is valid, a file with keys missing reports them (the test counts
   the `push_error`s with `assert_push_error_count`), and so does a missing file.

## Saving

`SaveFile` writes one JSON file (`user://saves/world.json`) with a `version`. Every state
class that is saved has an explicit `to_dict` and a strict `from_dict` (`data["x"]`, never
`data.get(...)` with a default). When the format changes, raise `SaveFile.VERSION` and add an
upgrade step that gives old saves the new field (the rule is at the top of `save_file.gd`, which
keeps ten upgrade steps: versions VERSION - 10 to VERSION load). Things marked "not saved" in a
comment (cheats, a forced weather) live only for the session. A timed or quick save
(`SaveService`) takes `SaveFile.snapshot` on the main thread (the game of that moment, copied: the
big maps as they are, the rest as save data) and makes the save data of that, the text and the
write on a worker thread (`GameState.dict_of`, `SaveFile.text_of`), so a `snapshot` must copy
every array, dictionary or object of the running game that it hands out instead of sharing it.

## Settings and key bindings

The default key bindings are the input map in `project.godot` (in the Godot editor: Project
Settings → Input Map). The player changes them under Settings → Controls; `GameSettings`
applies them to Godot's `InputMap` and stores only the differences from the defaults in
`user://settings.cfg`. The same file keeps the display, game and audio settings and the
language model: the profiles (`LanguageModelProfiles`, held by `GameSettings.profiles`; a
profile is a provider with its endpoint, model, tokens, temperature and chat length, and the
provider is a row of `GameSettings.LANGUAGE_MODEL_PROVIDERS` with the protocol it speaks:
OpenAI-compatible, Claude or Gemini, which speaks the OpenAI protocol) and each provider's key
(`profiles.language_model()` is the profile in use with its provider's key; the key in plain
text, never in the save, never sent to another provider). The page of it
(`LanguageModelPage`) lists the models the endpoint offers in a drop-down.

## Tests

`make test` runs every `tests/test_*.gd` with GUT, headless. A test file is named after what
it covers and should start with a one-line comment saying what it checks. Shared setup
lives in the `tests/*_case.gd` base classes; extend the one that fits instead of building a game by hand:

- `ResourceCase` (`tests/resource_case.gd`): a `GameState` with a patch of grass in front of
  the player, helpers to put objects there and to let days pass. Felling, mining, foraging,
  chests, building, ground items and most world-change tests extend it.
- `EnergyCase` (extends `ResourceCase`): a game running on its own energy rules, whose numbers
  differ from `data/energy.cfg`. The console, cheat, energy and passing-out tests extend it.
- `LivestockCase`: a pen of grass ringed by water beside the camp and helpers to let the
  farm animals' time pass (`test_livestock.gd`, `test_livestock_following.gd`).
- `CropCase`: crops, their needs and days that meet them (`test_crops.gd`,
  `test_crop_withering.gd`).

`make test-changed` (BASE=main by default) runs only the tests the files of the whole branch
(BASE..HEAD, plus uncommitted files) need: tools/select_tests.py follows `class_name` uses, `res://`
paths and scenes from a changed script to the tests that reach it, and prints what it picked and
why; what it cannot place runs everything (it follows what the code spells out, so a path built
at run time is missed; the full run on main is the net). A change to a core script (`GameState`, `World`)
reaches almost every test, so the saving is for changes at the edges. Use it while developing; run
one full `make test` before reporting a task. The coordinator runs a full `make test` on main after
every 5 merges and at the end of a batch; if it fails, bisect over the merges since the last green
full run (each step a `make test`). See [tools/README.md](../tools/README.md).

Rendering and input are mostly not unit-tested: run
`make screenshot` and look at the picture, e.g.
`make screenshot AT=40,-20 TIME=21:00 OUT=/tmp/shot.png`. It starts a new game with its own
save and does not touch yours.

## Debug flags

Flags after `--` on the Godot command line put the game in a situation for a screenshot or
a manual check: the position (`--at=x,y`), day and time (`--day=`, `--time=`), weather
(`--weather=`), a held item, an open screen, a small field of crops, animals and more.
They are parsed once into typed fields by `StartupOptions`, whose header lists every flag
([game/scenes/startup_options.gd](../game/scenes/startup_options.gd)); Main, `PlayerView`,
`BuildMode` and `AudioService` read those fields. An unknown flag is a warning. Pass them to `make screenshot` with
`ARGS="--weather=rain --day=45"`.

## More

- [docs/art-style.md](art-style.md): the look the art aims for.
- [tools/README.md](../tools/README.md): the generators that draw every picture and make
  every sound. The art is code; there are no hand-drawn PNGs to edit.
- [TASKS.md](../TASKS.md): open work and the rules for every task;
  [docs/tasks-done.md](tasks-done.md): what is finished and why.
- [docs/code-review-2026-11-06.md](code-review-2026-11-06.md): the review this documentation
  comes from, with what is planned to get simpler.
