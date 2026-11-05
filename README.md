# Sandbox Game (working title)

A top-down farming and life sim with 16-bit pixel art, set in a semi-fantasy Nordic
countryside. It follows the tradition of Stardew Valley and Harvest Moon, but leans further
into exploration, and you can build anywhere you like. The weather, the seasons and the
light change the world as you play.

> **Status:** early prototype, under active development. The core loop works: you can
> walk, farm, fell, mine, gather, build and sleep through the seasons. There is no shop,
> combat or story yet, and the weather and animals are still silent.

![The starting camp on a summer morning](docs/screenshots/camp.png)

## Features

### Sound

Footsteps follow the walk and the ground (grass, soil, sand, wetland, ice, snow, a wooden
floor), and every tool, pickup, building and menu has a sound, played from where it happens.
Inside a house the world outside is muffled. Settings → Audio has Master, Effects and Ambience
volumes and "Sound in background" (off: silent while the window is not focused). Which file each
sound plays is in [data/sounds.cfg](data/sounds.cfg), so any sound can be swapped for a recording.

### A world that changes with the seasons

There are four seasons of 30 days each. The ground, the trees, the bushes and the buildings
each have a look for every season: fresh green in spring, full summer foliage, red and
gold autumn forests, and snow in winter. Ground cover thins and fills over the year, ferns
die back in winter, and berry bushes only bear fruit in their season.

![The same forest in spring, summer, autumn and winter](docs/screenshots/seasons.png)

### Weather

The weather is simulated from humidity, wind, temperature and sunlight. It brings rain,
snow, drifting fog, wind, storms and thunderstorms with lightning. The climate is mild:
frost and snow only come in winter, and late winter thaws quickly into spring. The
weather is worked out from the world seed and the time, so the same world always has the
same weather.

![Rain in autumn, snow in winter, morning fog and a thunderstorm](docs/screenshots/weather.png)

### Day, night and light

The days follow a Nordic year: about 16 hours of daylight in midsummer and 8 in
midwinter, with dawn and dusk following sunrise and sunset. When it gets dark, the
campfire, the hearth and the lit windows glow, and clouds dim the daylight. A setting
lets you shrink or switch off the change in day length.

![Morning, dusk at the camp, a house at night and the interior by the hearth](docs/screenshots/day-and-night.png)

### Farming

You till the soil with the hoe, plant seeds, water them, and pick the crops by hand. There
are eleven crops: turnips, potatoes, carrots, cabbage, onions, wheat, peas, beans, tomatoes,
strawberries and pumpkins. Each grows in its own seasons, and the weather (warmth, rain,
frost) speeds it up, slows it down or damages it. A ripe crop doesn't wait forever: left
unpicked for as long as it took to ripen, it withers and gives nothing. The growing times,
seasons and the withering are in [data/crops.cfg](data/crops.cfg).

![A small field with turnips in every growth stage](docs/screenshots/field.png)

### Felling, mining and gathering

Use the axe on trees and the pickaxe on stones and boulders. A better tool needs fewer
hits, and some resources need a better tool. Everything you hit trembles and throws
leaves, snow or splinters. A felled tree topples to the side and leaves a stump and a
trunk; cut both into logs. A stump left alone rots away over about two weeks and may sprout
a sapling of its kind, and now and then a tree drops a seed (acorn or cone) you can plant on
grassland. Stones and boulders break into pieces of stone; a boulder needs a better pickaxe.

The scythe mows tall grass into hay and cuts reeds on river banks (reeds grow back in their
season). The shovel digs clay, but only where a faint patch on the ground hints at it. Berry bushes bear fruit again a few days after picking, and shrubs and ferns give
fibre.

What you gather hops out onto the ground: logs, stone, clay, hay, reeds, seeds and produce
lie there until you walk over them and pick them up.

![Two oaks felled from either side: the fall, the landing and the trunks they leave](docs/screenshots/harvest.png)

![A stump, a picked and a ripe berry bush and a sapling](docs/screenshots/forage.png)

### Build anywhere

Hold the hammer (press B to take it from the hotbar) and a ghost of a building follows the
mouse. Q and E pick the building: shack, Kate, longhouse or barn. A small panel lists the
logs, stone, clay and reeds it takes against what you carry; the spot is refused while
something is missing, and a click or Space builds it and takes the materials. The ghost
shows where it fits, and the game tells you why a spot doesn't work, for example when it is
unsafe wetland. Hold something else (or press Escape or right click) to stop building. You can
walk inside every building, and each has its own room: a bare shack with a straw mat, a
cottage room in the Kate, the longhouse with a living end and an animal end, and the barn with
stalls and hay. The last bed you slept in becomes your home. A new game starts at the camp
with your tools and the hammer, so the materials for the first house have to be gathered
first. The buildings, their sizes, costs and insides are in
[data/buildings.cfg](data/buildings.cfg).

The buildings follow the reed-thatched farmhouses of Denmark and northern Germany: the Kate
with white lime walls and teal shutters, the brick longhouse with its arched barn door, the
half-timbered barn, and the plank shack.

![The Kate, the longhouse, the barn and the shack in summer](docs/screenshots/buildings.png)

![Build mode: the ghost of a Kate and what it costs](docs/screenshots/build.png)

### Character, inventory and equipment

The character is drawn in layers, so anything they wear shows in the world. Press Tab to
open the character screen, where you move items between the inventory and the equipment
slots. The hotbar holds your tools and seeds. Energy and health bars track how tired you
are, and the more you carry, the more each action costs.

![The character screen with equipment slots and the inventory](docs/screenshots/character.png)

### Settings and controls

You can rebind every key, including mouse buttons. You can also switch between fullscreen
and windowed, scale the UI from 0.5× to 2× without touching the world view, and set the
energy drain and the day length variation. Hover over a setting, a key or an item in the
hotbar, inventory or equipment for a short explanation: an item's kind, weight, what food
gives back, what seeds grow and where they are planted. The mouse wheel zooms smoothly
from 0.5× to 2×.

![Rebinding the controls](docs/screenshots/controls.png)

![Zoomed out to 0.5×](docs/screenshots/zoom.png)

### Console

Press `/` to open a console for testing and cheats. Tab completes commands and their arguments.

| Command | What it does |
|---|---|
| `help` | List the commands. |
| `tp <x> <y>` | Teleport to a world tile outside (F3 shows your coordinates). |
| `give <item> [count]` | Put items in the inventory. |
| `god`, `nodrain`, `noweight`, `nocost` | Toggle invincibility, free actions, weight costing nothing, and buildings needing no materials. |
| `weather`, `weather <condition>`, `weather auto` | Show the weather, force a condition, or go back to the simulation. |
| `snow`, `snow <0..1>`, `snow auto` | Show the snow cover, force it, or go back to the weather. |
| `spawn <animal> [count]` | Put animals nearby. |
| `skip <n>m\|h\|d` | Let minutes, hours or days pass, e.g. `skip 2h` or `skip 3d`. |
| `crop` | Show the growth, damage and needs of the nearest crop. |

![The console after a few commands](docs/screenshots/console.png)

## Controls

These are the default keys; all of them can be changed under Settings → Controls.

| Key | Action |
|---|---|
| WASD or arrow keys | Walk |
| Space or left click | Use the held item on the targeted tile |
| 1–0 | Pick a hotbar slot |
| Tab | Character screen and inventory |
| E | Sleep (next to a bed; with the hammer in hand it picks the next building) |
| B | Take the hammer: build mode |
| Q, E | Previous and next building (while holding the hammer) |
| Mouse wheel | Zoom |
| Escape | Pause menu |
| `/` | Console |
| F3 | Show coordinates and weather values |

## Running the game

The game uses Godot 4.7.2 with GDScript. Make targets wrap every multi-step job.

```sh
make setup   # checks for Godot, Python 3, git, curl and Tiled; downloads GUT; creates a Python venv
make run     # starts the game
```

Start the game with `make run`: it imports new art first. Starting Godot directly after
pulling new art makes the game stop with a list of pictures that aren't imported yet; run
`godot --headless --import` once then.

`make setup` never installs system packages. If something is missing, it prints what to
install, with Gentoo package names where there are some. If your Godot binary has a
different name, pass its path: `make GODOT=/path/to/godot run`.

Saves go to `user://saves/world.json` and settings to `user://settings.cfg`. To start a
fresh world, run `godot --path . -- --new-game`.

### For developers

| Command | What it does |
|---|---|
| `make test` | Runs the GUT test suite headless. |
| `make lint` | Runs `gdlint` and `gdformat --check`. |
| `make format` | Formats the GDScript. |
| `make assets` | Regenerates all pixel art from the palette and all sounds (deterministic). |
| `make screenshot` | Saves one frame, e.g. `make screenshot AT=40,-20 TIME=21:00`. |

- **Art:** all art is generated by a Python script, [tools/art/generate.py](tools/art/generate.py),
  from a fixed palette of at most 64 colours.
- **Sound:** all sounds are synthesised by [tools/audio/generate.py](tools/audio/generate.py)
  into assets/sounds/; its docstring explains how to tune or replace one.
- **Data files:** gameplay numbers you might want to tune live in
  [data/](data/) (energy, crops, buildings, weather, seasons, vegetation, wildlife, sounds).
- **Design:** the design is in [SPEC.md](SPEC.md).
- **Debug flags:** command-line flags for screenshots and debugging (time, day, weather,
  position and more) are listed at the top of [game/scenes/main.gd](game/scenes/main.gd).
