# Sandbox Game (working title)

A top-down farming and life sim with 16-bit pixel art, set in a semi-fantasy Nordic
countryside. It follows the tradition of Stardew Valley and Harvest Moon, but leans further
into exploration, and you can build anywhere you like. The weather, the seasons and the
light change the world as you play.

> **Status:** early prototype, under active development. The core loop works: you can
> walk, farm, fell, mine, gather, build and sleep through the seasons. There is no shop,
> combat or story yet.

![The starting camp on a summer morning](docs/screenshots/camp.png)

## Features

### Sound

Footsteps follow the walk and the ground (grass, soil, sand, wetland, ice, snow, a wooden
floor), and every tool, pickup, building and menu has a sound, played from where it
happens. Inside a house the world outside is muffled. Settings → Audio has Master, Effects
and Ambience volumes and "Sound in background" (off: silent while the window is not
focused). Which file each sound plays is in [data/sounds.cfg](data/sounds.cfg), so any
sound can be swapped for a recording.

The world has an ambience too: rain and wind loops that follow the weather (and swell with
gusts), thunder some seconds after each flash of lightning, birds chirping by day, deer,
rabbits and squirrels, bees buzzing at their flowers, frogs croaking near water on
warm spring and summer evenings and nights (and, where frogs are about, a quiet chorus of
them at dusk), a stork clattering its bill and geese honking,
and now and then a quiet moo, baa or cluck from the farm animals. How often and how loud is in
[data/ambience.cfg](data/ambience.cfg).

### A world that changes with the seasons

There are four seasons of 30 days each. The ground, the trees, the bushes and the
buildings each have a look for every season: fresh green in spring, full summer foliage,
autumn colours of the North Sea, and snow in winter. The woods are those of the region: grey
beeches under broad domes that turn copper, white birches that turn yellow, dark alders on
wet ground that stay green late and hang with cones in winter, and oaks in brown, ochre and
copper. A new season comes in over its first three days, tile by tile and tree by tree: in
spring the trees and bushes leaf out in steps, from bare twigs to a haze of buds, thin young
leaves and then the full crown. Scots pines, tall with a loose flat crown, and spruces stay
green all year; they are rare, in clumps on the dry Geest. Ground cover thins and fills over the year, ferns die back in
winter, and berry bushes only bear fruit in their season.

![A wood of beech, birch, oak and alder by a clump of pines on the Geest: on the second day of spring, in summer, on the third day of autumn and in the first snow](docs/screenshots/seasons.png)

The meadows flower from spring to late summer, in drifts and patches rather than sprinkled
evenly: the first daisies, dandelions and, in the beech woods, wood anemones in early spring,
cuckooflower on the wet meadows, then buttercups, red campion and red and white clover, and in
high summer yarrow, knapweed, meadowsweet by the water and the heather on the Geest. Each
drift has its few species that take over from each other, so a patch changes colour with the
weeks; the first and the last flowers of a species are small ones, and autumn sees them fade.
Fields, water and the woods have none or few. Bees keep to the flowers: they come only where
something blooms, more where more does, and their quiet buzz comes from where they are. Where
the flowers grow is in [data/flowers.cfg](data/flowers.cfg), when they bloom in
[data/vegetation.cfg](data/vegetation.cfg).

![The same meadow on the 8th and the 25th day of spring and the 15th and the 27th day of summer](docs/screenshots/meadows.png)

Where you walk often, the grass wears: first it is trodden, thin and flattened with the earth
showing through, then a path of bare earth with grass creeping in at its edges, and the
flowers and tufts on it are gone. Walk the same line a few times a day and a path forms in a
few days; leave it and it grows back over a week or two. Paths fade softly into the grass
around them, change with the seasons, lie dark in a winter without snow and show as a faint
trodden track under snow. Cows and the other farm animals wear the ground too where they keep
walking. A path is only a look: it walks, tills and builds like grass. The numbers are in
[data/paths.cfg](data/paths.cfg).

![A desire path through a meadow after three days, after eight days, five days after it was last walked, and under snow](docs/screenshots/desire-paths.png)

### Knicks, ditches and dykes

The land is worked, as in Schleswig-Holstein around 1700–1800. On the dry Geest the fields
are bounded by Knicks, hedges of hazel and hawthorn on earth banks that blossom in spring,
turn yellow and brown in autumn and stand bare in winter, and here and there by a fieldstone
wall or a wattle fence. Down in the marsh along the river the fields are cut by straight
ditches of water lined with reeds and pollard willows, and turfed dykes run along the
floodplain. Every boundary has a gap or a crossing, so no field is shut in. The axe cuts a
Knick down for logs and fibre, the pickaxe takes a wall apart for stone, and willows are
felled like the other trees.

![The Geest running into the marsh, with a Knick, a wood, ditches, reeds and pollard willows, in summer and in the first snow](docs/screenshots/landscape.png)

### The coast and the tidal flats

In the west the land ends at the North Sea. A sea dyke runs along the coast, and beyond it lie
the salt marsh, grey-green with sea purslane and glasswort, pink with thrift in early summer,
lilac with sea lavender later and red-purple in autumn; then the tidal mud of the Wadden Sea,
with ripple marks, lugworm casts and shells, cut by tideways that widen towards the open sea.
The tide comes in and goes out twice a day: the water fills the hollows first, then the flats
are under, and at low water the mud dries again. The mud can be walked at any tide. Out on the
salt marsh a Warft rises here and there, a dwelling mound with a pond on top, and now and then
an Ewer, a flat-bottomed sailing barge, lies on the mud. Storks and geese come to the salt marsh.

![The coast: a Warft on the salt marsh behind the sea dyke at low water in summer, the salt marsh red in autumn with the tide rising, an Ewer lying on the mud, and the coast under snow with the tide coming in](docs/screenshots/coast.png)

### Weather

The weather is simulated from humidity, wind, temperature and sunlight. It brings rain,
snow, drifting fog, wind, storms and thunderstorms with lightning. The climate is mild:
frost and snow only come in winter, and late winter thaws quickly into spring. The
weather is worked out from the world seed and the time, so the same world always has the
same weather.

The world moves with the wind: trees, bushes, grass, reeds and crops sway, barely on a
calm day and hard in the gusts of a storm; the water ripples and glints, choppier in wind;
the campfire and the hearth burn, their flames licking up and falling back, and throw
sparks; the campfire's flames lean and stretch downwind, more in a strong wind; rain
splashes on the ground; lily pads drift and bob.

![Rain in autumn, snow in winter, morning fog and a thunderstorm](docs/screenshots/weather.png)

### Day, night and light

The days follow a Nordic year: about 16 hours of daylight in midsummer and 8 in
midwinter, with dawn and dusk following sunrise and sunset. When it gets dark, the
campfire, the hearth and the lit windows glow, and clouds dim the daylight. A setting
lets you shrink or switch off the change in day length.

![Morning, dusk at the camp, a house at night and the interior by the hearth](docs/screenshots/day-and-night.png)

### Farming

You till the soil with the hoe, plant seeds, water them, and pick the crops by hand. There
are eleven crops: turnips, potatoes, carrots, cabbage, onions, wheat, peas, beans, flax
(for its fibre, not to eat), wild strawberries and small green squashes (pumpkins). Each
grows in its own seasons, and the weather (warmth, rain, frost) speeds it up, slows it
down or damages it. A ripe crop doesn't wait forever: left unpicked for as long as it took
to ripen, it withers and gives nothing. The growing times, seasons and the withering are
in [data/crops.cfg](data/crops.cfg).

![A small field with turnips in every growth stage](docs/screenshots/field.png)

### Livestock

Cows, sheep, chickens and rabbits of the region: red-brown Angler, black pied and red pied
cattle; white, grey and black-faced sheep; brown and white hens and a rooster; agouti, white
and Dutch rabbits, each with a slight tint of its own. They wander, graze (the hens peck for
seeds and worms), keep out of water and away from anything solid, and the rabbits hop off
when you come close. At night they lie down and sleep until the morning. For now they come
from the console (`spawn cow 3`); they are saved with the game. Milk, wool, eggs, pens and
feeding come later. The numbers are in [data/livestock.cfg](data/livestock.cfg).

![A mixed herd by the camp on a summer morning, and asleep after midnight](docs/screenshots/livestock.png)

Dogs, cats and horses keep them company: a farm collie, a spitz and a hunting dog; tabby,
black and ginger cats; a heavy marsh horse, about two tiles long, in bay, black or grey, and a
dun pony. Dogs and cats sniff about, horses graze, and all of them dash off at a run now and
then; cats roam furthest. A dog barks now and then, a cat rarely meows, a horse whinnies or
snorts. Hold a **bone** (`give bone`) and press the use key at a dog in front of you: it takes
the bone and follows you for three game hours, day and night, keeping a tile or two from you
and running to catch up (left far behind or stuck, it turns up at your side). Horses can't be
ridden yet.

![Horses, dogs and cats about the camp](docs/screenshots/dogs-cats-horses.png)

### Villagers

The first people of the coast: villagers dressed in the clothes of the period, the men in
knee breeches, waistcoats and felt hats or knitted caps, the women in long skirts, laced
bodices, aprons, shawls and white coifs or headscarves, each with a skin, hair and clothes
of their own and a North Frisian or Low German name (Antje Boysen, Momme Ketels). They keep
to within about six tiles of the house or campfire nearest to where they came, stand about
and stroll by day and stand still at night; you walk through them, so they never shut you
in. For now they come from the console; they are saved with the game.

Each has an age, a trade, a personality, a background and habits of speech. Four are written
by hand in [data/villagers.cfg](data/villagers.cfg) and come with `spawn npc <id>`: `antje`
(Antje Boysen, a farmer's wife, whose husband Hinrich works their marsh farm), `momme` (Momme
Ketels, a fisherman of the tidal creeks), `ocke` (Ocke Hansen, the miller) and `kerrin`
(Kerrin Paulsen, the dyke reeve's widow, who lived through the Christmas flood of 1717).
`spawn npc 3` makes villagers up, with a trade, family, worry and habit drawn from the tables
of [data/npcs.cfg](data/npcs.cfg).

Face a villager and press E to talk: the name over their head shows whom E speaks to. The
chat shows your portrait and theirs, and between them a chat window with the game time,
like `[08:15] <You> hello`. Type a line and press Enter; Escape leaves. The game stands still
while you talk, and the chat keeps its last 200 lines for the next time. With a language
model set under Settings → Language model (see
[Talking NPCs](#talking-npcs-with-a-language-model)) villagers answer in their own words;
without one they say short scripted lines ("Aye.", "Is that so?"). When you leave a chat,
the villager remembers it in one line (the model sums it up, else it is what you said), and
later talks build on it. While one villager is still answering you may leave and talk to
another; the answer waits in the first one's chat.

![Villagers by the camp, the name of the one E would speak to over their head](docs/screenshots/npcs.png)

![A chat with Antje Boysen through the test LLM: both portraits, and the lines with the game time](docs/screenshots/npc-chat.png)

The pixel font has the Latin-1 letters (ä ö ü ß å æ ø é ç ñ ...), the Latin Extended-A letters
of the neighbours' languages (Polish, Czech, Turkish and others) and the typographic quotes,
dashes and « » ¿ ¡ …, so the villagers' German, Danish and Dutch show as written.

![A chat with German and Danish lines, and the accented capitals](docs/screenshots/font-umlauts.png)

### Wildlife

Birds hop and peck on open ground and small flocks cross the sky, rabbits graze the meadows,
squirrels dart between the trees, roe deer come out at the edge of the woods at dawn and
dusk, and bees and butterflies keep to the flowers. On the marsh and the wet meadows white
storks hunt in spring and summer, stepping slowly with the head down; they come to stand on
the roofs of the houses, clatter their bills now and then and fly off on slow wingbeats.
In autumn and winter flocks of greylag geese graze the marsh and the floodplain, raise their
heads when you come near and take off together, and skeins of them fly over in a V. Mice
live by the fields, the Knicks, the walls and the houses, out mostly at dusk and at night, and
dash off into cover when you come close; frogs sit and hop at the water's edge and on the wet
meadows from spring to early autumn, and a hunting stork that sees one walks up to it,
strikes and swallows it. The animals come and go around you by the season, the time of day
and the weather; the numbers are in [data/wildlife.cfg](data/wildlife.cfg).

![White storks on the marsh, a stork on the roof of a Kate, a flock of geese grazing in autumn and a skein of them flying over](docs/screenshots/wildlife.png)

![Storks striking at frogs by the camp on a summer evening, and mice in the grass](docs/screenshots/mice-and-frogs.png)

### Felling, mining and gathering

Use the axe on trees and the pickaxe on stones and boulders. A better tool needs fewer
hits, and some resources need a better tool. Everything you hit trembles and throws
leaves, snow or splinters. A felled tree topples to the side and leaves a stump and a
trunk (a dead tree a grey, splintered one); cut both into logs. A stump left alone rots
away over about two weeks and may sprout a sapling of its kind (not a dead tree's), and
now and then a tree drops a seed (an acorn, a beechnut, a catkin or a cone) you can plant
on grassland. Stones and boulders break into pieces of stone; a boulder needs a better
pickaxe.

The scythe mows tall grass into hay and cuts reeds on river banks (reeds grow back in
their season). The shovel digs clay, but only where a faint patch on the ground hints at
it. Berry bushes bear fruit again a few days after picking, and shrubs and ferns give
fibre.

What you gather hops out onto the ground: logs, stone, clay, hay, reeds, seeds and produce
lie there until you walk over them and pick them up.

![Two oaks felled from either side: the fall, the landing and the trunks they leave](docs/screenshots/harvest.png)

![A stump, a picked and a ripe berry bush and a sapling](docs/screenshots/forage.png)

### Build anywhere

Hold the hammer (press B to take it from the hotbar) and a ghost of a building follows the
mouse. Q and E pick the building: shack, Kate, longhouse, hall house or barn. A small panel lists the
logs, stone, clay and reeds it takes against what you carry; the spot is refused while
something is missing, and a click or Space builds it and takes the materials. The ghost
shows where it fits, and the game tells you why a spot doesn't work, for example when it
is unsafe wetland. Hold something else (or press Escape or right click) to stop building.
You can walk inside every building, and each has its own room: a bare shack with a straw
mat on a clay floor, a cottage room in the Kate, the longhouse with a living end and an
animal end, the hall house with its long Diele between the stalls and the Flett with the
hearth at its end, and the barn with stalls and hay. The rooms are furnished like 18th-century
farmhouses of the coast: brick floors in the living rooms and beaten clay in the work rooms,
an open hearth under a smoke hood with Dutch tiles behind the fire, plate racks with Delft
and pewter, a wall bench and box beds with curtains. The last bed you slept in becomes your home. A new game
starts at the camp with your tools and the hammer, so the materials for the first house
have to be gathered first. The buildings, their sizes, costs and insides are in
[data/buildings.cfg](data/buildings.cfg).

The buildings follow the reed-thatched farmhouses of Denmark and northern Germany: the Kate
with white lime walls and teal shutters, the brick longhouse with its arched barn door, the
half-timbered barn, and the shack: tarred black boards under a turf roof, which greens in
spring, browns in autumn and winter and lies under snow like the thatch. The biggest is the
Low German hall house of Holstein: its half-timbered gable to the front with red brick in
herringbone, the big arched barn door (the Grote Door), the owl hole under a little hip and
white bargeboards crossing in a pair of horse heads, under a huge thatch.
It is also the dearest: 100 logs, 40 stone, 50 clay and 80 reeds (the shack takes 20 logs
and 5 stone, the Kate 30, 15, 15 and 25).

![The Kate, the longhouse, the hall house, the barn and the shack in summer, and the hall house on a winter night](docs/screenshots/buildings.png)

![Inside the Kate and the longhouse at night, by the hearth](docs/screenshots/interiors.png)

![Build mode: the ghost of a Kate and what it costs](docs/screenshots/build.png)

Press X with the hammer in hand to switch from building to taking down: the panel reads
"Taking down", the tile under the mouse gets a red frame, and the building or the thing you
placed (a chest, a workbench, a kiln) under it is tinted red, with a message of what it gives.
Hold Space or the click for a second to take it down. A building gives back half of each
material, rounded down, in front of its door; the furniture it came with goes with it. It
stands while you are inside, or while anything you put in it is left (the message says so).
If your bed was in it, you wake at the camp's sleeping bag again. A placed thing goes into the
inventory whole, with what it holds, or onto the ground when the inventory is full. X again
goes back to building.

![Taking down: a shack marked red, and what it gives](docs/screenshots/take-down.png)

### Character, inventory and equipment

The character is drawn in layers, so anything they wear shows in the world. They dress as
on the North Sea coast in the 18th century: a red waistcoat over a linen shirt, knee breeches
with white stockings, wooden clogs, and a short blue jacket and hats to put on. Press Tab to
open the character screen, where you move items between the inventory and the equipment
slots. The hotbar (the eight slots at the bottom of the screen, keys 1 to 8) holds your tools
and seeds and is extra room: it takes nothing from the backpack's 20 slots (4 rows of 5), so
you carry 28 stacks. The screen shows the backpack with the hotbar as its own row below it, and
new items fill the free hotbar slots first. Energy and health bars track how tired you
are, and the more you carry, the more each action costs: up to 40 kg is free, and tools
weigh nothing. Below 20 % energy the character
sweats with every action, and below 10 % even more. A "zzz" thought bubble pops up over the
head at midnight and again at half past, while you are still awake: you pass out an hour
after midnight.

![The character screen with equipment slots and the inventory](docs/screenshots/character.png)

### Sleeping and passing out

Press E next to a bed to sleep: the screen fades to black, shows the new day and wakes you
at 06:30 the next morning (or the same morning, if it is already past midnight). A bed fills
your energy and health, and the last one you slept in is home.

Don't run out of energy, and don't stay up past 01:00: you sink to your knees, tip over and
fall asleep where you stand. You sleep until 06:30 but at least ten hours, and wake in your
home bed, still worn out for the rest of that day: walking slowly, with low health and half
your energy. A message says what happened before the morning fades in.

![Passing out: kneeling, tipping over, asleep, and the message on waking](docs/screenshots/passing-out.png)

After sleeping or passing out you wake lying in the middle of the bed, head on the pillow
and under the blanket (also on the bedroll at the camp), and get up with your first step.
Beds don't block walking, so you can't get stuck behind one.

![Waking in the shack, the Kate, the longhouse and at the camp](docs/screenshots/waking-in-bed.png)

### Crafting and professions

Press C for the crafting menu of what you make by hand: a chest, the stations below and flour.
It lists what you can make with what you carry; a recipe you can't afford yet is greyed, with
the missing materials marked, and hovering shows what is missing. The recipes are in
[data/recipes.cfg](data/recipes.cfg).

![The crafting menu by hand: chest, workbench, kiln, bake oven and flour](docs/screenshots/crafting.png)

Three crafts can be learnt, each at its own **station**: press E at one for its menu.

- **Cooking** at the hearth of a house or the camp's fire (anyone can roast a turnip; pottage
  and pea soup take practice) and at the **bake oven** (bread from flour, a berry tart,
  a feast cake). Cooked food gives more energy than what it is made of, eaten raw.
- **Woodworking** at the **workbench**: planks, a stool for the house, clogs, a painted
  Frisian chest with 20 slots, and as the master's piece a joined cupboard with 25.
- **Masonry**: clay is moulded into raw bricks at the workbench and fired in the **kiln**.
  A firing takes 12 game hours and goes on while you are away; open the kiln's menu
  afterwards to take the bricks out; a skilled mason fires more for the same fuel. The bake
  oven is built of those bricks.

The workbench, kiln and bake oven are made by hand and placed like a chest (the kiln only
outdoors); the axe or the pickaxe takes them down again.

![A kiln firing, the workbench, the bake oven and the carved chest by the camp](docs/screenshots/stations.png)

Crafting raises the recipe's skill: the most at the recipe's level, less the further you are
above it, nothing from a recipe 40 points below you. Better recipes need a skill level (the
master recipe of each craft 70, which teaches it to 100); the
menu shows them greyed with the level they need, and the tooltip what a craft teaches.

![The menus of the hearth, the workbench and the kiln](docs/screenshots/station-menus.png)

Each skill goes up to 100, but all of them together only to 200: one craft at the top and
two at half, or three around two thirds. Press K for the skills tab of the character screen.
At 200, a skill only grows by taking points from one you marked **Fade** there; nothing
fades on its own. The skills are in [data/skills.cfg](data/skills.cfg), the stations in
[data/stations.cfg](data/stations.cfg).

![The skills tab: three skills, one marked to fade](docs/screenshots/skills.png)

### Chests

Hold a chest and a ghost shows where it would go: green where it fits, red where it
doesn't (not on water, wetland or floodplain, not on something else, not in front of a
door). Use it to place the chest, outdoors or inside a house. Press E in front of a chest
to open it: your backpack and hotbar are on the left and the chest's 15 slots (20 in a carved
chest) on the right. Click an item and click a slot to move it, or Shift+click to send a whole stack
across (from the chest it goes to the backpack first, so the hotbar isn't flooded). The
axe takes a chest down: outdoors what it held spills onto the ground, inside a house the
chest and its contents go into your inventory (or you are told there is no room).

![The storage screen of a chest](docs/screenshots/chest.png)

### Settings and controls

You can rebind every key, including mouse buttons. You can also switch between fullscreen
and windowed, scale the UI from 0.5× to 2× without touching the world view, and set the
energy drain and the day length variation, and set the language model villagers talk
through. Hover over a setting, a key or an item in the
hotbar, inventory or equipment for a short explanation: an item's kind, weight, what food
gives back, what seeds grow and where they are planted. The mouse wheel zooms smoothly
from 0.5× to 2×.

![Rebinding the controls](docs/screenshots/controls.png)

![Zoomed out to 0.5×](docs/screenshots/zoom.png)

### Console

Press `/` to open a console for testing and cheats. Tab completes commands and their
arguments.

| Command | What it does |
|---|---|
| `help`, `help <command>` | List the commands, or show what one takes (the names it accepts too). |
| `tp <x> <y>` | Teleport to a world tile; from inside a house you step out there (F3 shows your coordinates). |
| `reset` | Put yourself in your bed, the one you wake in, inside or out. |
| `give <item> [count]` | Put items in the inventory (e.g. `give bone` for a dog). |
| `god`, `nodrain`, `noweight`, `nocost` | Toggle invincibility, free actions, weight costing nothing, and buildings and crafting needing no materials. |
| `noclip` | Toggle walking through anything: water, trees, rocks, buildings, furniture (indoors within the room, outdoors on loaded ground). Turned off where you don't fit, it puts you on the nearest free ground. |
| `weather`, `weather <condition>`, `weather auto` | Show the weather, force a condition, or go back to the simulation. |
| `snow`, `snow <0..1>`, `snow auto` | Show the snow cover, force it, or go back to the weather. |
| `spawn npc [count]` | Put villagers nearby, each with a look, a name and a background of their own; they stay. |
| `spawn npc <villager>` | Put a villager written by hand nearby: `antje`, `momme`, `ocke` or `kerrin`; each comes once. |
| `spawn <animal> [count]` | Put animals nearby: farm animals that stay (`cow`, `sheep`, `chicken`, `rabbit`, `dog`, `cat`, `horse`) or wild ones that come and go (`bird`, `wild_rabbit`, `squirrel`, `deer`, `bee`, `butterfly`, `flock`, `stork`, `roof_stork` on the nearest roof, `geese` grazing, `flying_geese`, `mouse`, `frog`). `spawn` alone, or with an unknown name, lists them. |
| `skip <n>m\|h\|d` | Let minutes, hours or days pass, e.g. `skip 2h` or `skip 3d`. |
| `crop` | Show the growth, damage and needs of the nearest crop. |
| `skill <skill> <points>` | Set a skill's points (`woodworking`, `cooking`, `masonry`). |

![The console after a few commands](docs/screenshots/console.png)

## Controls

These are the default keys; all of them can be changed under Settings → Controls.

| Key | Action |
|---|---|
| WASD or arrow keys | Walk |
| Space or left click | Use the held item on the targeted tile |
| 1–8 | Pick a hotbar slot |
| Tab | Character screen and inventory |
| K | Skills tab of the character screen |
| C | Crafting menu (by hand) |
| E | Talk to the villager in front of you; else open the chest or the station (its crafting menu) in front of you, else sleep until morning (next to a bed); with the hammer in hand it picks the next building |
| Enter, Escape | In a chat: send the line, leave the chat (Page Up and Down scroll back) |
| B | Take the hammer: build mode |
| X | Switch the hammer between building and taking down (hold Space or click to take down) |
| Q, E | Previous and next building (while holding the hammer) |
| Mouse wheel | Zoom |
| Escape | Pause menu |
| `/` | Console |
| F3 | Show coordinates and weather values |

## Running the game

The game uses Godot 4.7.2 with GDScript. Make targets wrap every multi-step job.

```sh
make setup   # checks for Godot, Python 3, git and curl (Tiled is optional); downloads GUT;
             # creates a Python venv
make run     # starts the game
```

Start the game with `make run`: it imports new art first. Starting Godot directly after
pulling new art makes the game stop with a list of pictures that aren't imported yet; run
`godot --headless --import` once then.

On Linux the game uses the X11 display driver (XWayland under a Wayland desktop), set in
project.godot: Godot 4.7.2's Wayland driver sometimes never finishes quitting, leaving the
window open. The game has saved by then. To try Wayland anyway:
`godot --path . --display-driver wayland`.

`make setup` never installs system packages. If something is missing, it prints what to
install, with Gentoo package names where there are some. If your Godot binary has a
different name, pass its path: `make GODOT=/path/to/godot run`.

Saves go to `user://saves/world.json` and settings to `user://settings.cfg`. To start a
fresh world, run `godot --path . -- --new-game`.

### Talking NPCs with a language model

Villagers talk through an OpenAI-compatible chat endpoint. Out of the box the game asks the
test LLM on `http://127.0.0.1:11434/v1` (see below); when nothing answers there, or a reply
takes longer than 30 seconds, villagers say short scripted lines instead, so the game never
needs a model.

**Configuring it.** Settings → Language model has three fields, each stored as you type:

| Field | Default | What it is |
|---|---|---|
| Endpoint | `http://127.0.0.1:11434/v1` | The base address of the chat API; the game posts to `<endpoint>/chat/completions`. Empty it to turn the model off (villagers then always speak scripted lines). |
| Model | `qwen2.5:3b-instruct` | The model name the endpoint should use. |
| Key | empty | Only for endpoints that need one: sent as the header `Authorization: Bearer <key>`, and never sent along a redirect. |

The same three live in `settings.cfg` (in Godot's user folder, e.g.
`~/.local/share/godot/app_userdata/Sandbox Game/settings.cfg` on Linux), under
`[language_model]`; only values that differ from the defaults are written:

```
[language_model]
endpoint="https://api.openai.com/v1"
model="gpt-4o-mini"
api_key="sk-..."
```

The key is stored as plain text there (never in the save, never logged), and what you say to
villagers goes to that endpoint. Ollama, LM Studio (`http://127.0.0.1:1234/v1`), llama.cpp's
server and hosted OpenAI-compatible APIs work; Claude's own API would need an adapter of its
own. To try an endpoint and key by hand:

```
curl -s <endpoint>/chat/completions -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <key>' \
  -d '{"model": "<model>", "messages": [{"role": "user", "content": "Moin!"}]}'
```

(Leave out the `Authorization` line for an endpoint without a key, like the test LLM.) When
the endpoint can't be reached, the game's output says so once, not for every line.

**The test LLM.** `make llm-up` runs Ollama with Qwen2.5 3B Instruct (1.9 GB, Qwen Research
License: for testing only) in a podman or docker container on `http://127.0.0.1:11434/v1`,
the default endpoint, so villagers talk as soon as it is up; `make llm-check` asks it one
question and `make llm-down` stops it. The container image (5.5 GB) and the model live in
the container tool's storage and the volume `sandbox-game-llm-models`; `make llm-down PURGE=1`
deletes the model. Details in [tools/README.md](tools/README.md). A reply takes a second or
two on the GPU, about five seconds on the CPU; one that takes longer than 30 seconds, or
fails, becomes a scripted line. To try another model, run
`make llm-pull LLM_MODEL=qwen2.5:7b-instruct` and set it as the model in Settings;
[tools/README.md](tools/README.md) lists some that fit.

What the model is told for each reply (the words are in [data/npc_talk.cfg](data/npc_talk.cfg),
shaped like a prompt that worked well with the test model): a system line (1750 on the North
Frisian coast, one or two sentences of small talk, never break character), one example
exchange, the last 24 lines of your chat with them (also from earlier talks), and then who the villager is (name, trade,
age, their look in words, personality, background, habits, and what they remember of earlier
talks), the moment (the date as the clock shows it and how far into the season, the time and
part of the day by the sun, the weather as it is: rain, snow, fog or the sky, the temperature,
frost, the wind and where it blows from; and the house or fire they stand by), that you are a
newcomer whose name they don't know, and what you said. Only the reply and the memory lines
are kept; nothing else in the game changes by what the model says.

To screenshot a talk, start the test LLM (`make llm-up`; screenshots read
`build/settings.cfg`, where the default endpoint applies) and run

```
make screenshot SCREENSHOT_TIMEOUT=120 ARGS="--villager=antje '--chat=Moin, Antje!;Do you have butter?'"
```

`SANDBOX_LLM_URL=http://127.0.0.1:11434/v1 make test` also runs the tests that ask the real
model.

### For developers

Start with [docs/architecture.md](docs/architecture.md): how the code is organised and where
to look. `make help` lists the targets and their variables.

| Command | What it does |
|---|---|
| `make help` | Lists the targets and variables (the default). |
| `make test` | Runs the GUT test suite headless. |
| `make lint` | Runs `gdlint` and `gdformat --check`. |
| `make format` | Formats the GDScript. |
| `make assets` | Regenerates all pixel art from the palette and all sounds (deterministic). Needs Python only, not Godot. |
| `make llm-up`, `llm-check`, `llm-down` | A local test LLM in a container (see above); no test needs it. |
| `make llm-pull`, `llm-models`, `llm-rm` | Fetch, list and delete other models for it, e.g. `LLM_MODEL=qwen2.5:7b-instruct`; then set that model under Settings → Language model. |
| `make clean` | Deletes build/ (test log, screenshots). |
| `make screenshot` | Saves one frame, e.g. `make screenshot AT=40,-20 TIME=21:00`. Muted (`SOUND=1` keeps the sound), the window doesn't take the focus, and it uses its own save in build/ (`KEEP_SAVE=1` loads yours). |

- **Art and sound:** all art is generated by Python scripts, from a small fixed palette, and all sounds are synthesised. [tools/README.md](tools/README.md) has the
  module map and how to add things; the entry points are
  [tools/art/generate.py](tools/art/generate.py) and
  [tools/audio/generate.py](tools/audio/generate.py).
- **Interiors:** the rooms inside the buildings are Tiled maps, see
  [maps/README.md](maps/README.md).
- **Art style:** period, place, materials and what to avoid are in [docs/art-style.md](docs/art-style.md).
- **Data files:** gameplay numbers you might want to tune live in
  [data/](data/) (energy, crops, buildings, recipes, weather, seasons, vegetation, flowers, wildlife, sounds, ambience).
- **Design:** the design is in [SPEC.md](SPEC.md).
- **Debug flags:** command-line flags for screenshots and debugging (time, day, weather,
  position and more) are listed in the header of [game/scenes/startup_options.gd](game/scenes/startup_options.gd).
