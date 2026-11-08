# Sandbox Game (working title)

A top-down farming and life sim with 16-bit pixel art, set in a semi-fantasy Nordic
countryside. It follows the tradition of Stardew Valley and Harvest Moon, but leans further
into exploration, and you can build anywhere you like. The weather, the seasons and the
light change the world as you play.

> **Status:** early prototype, under active development. The core loop works: you can
> walk, farm, fell, mine, gather, build and sleep through the seasons. There is no shop,
> combat or story yet.

![The starting camp on a summer morning, at the widest view](docs/screenshots/camp.png)

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

Tall grass, ferns and reeds have a ground shadow and a dark, dense foot that is rimmed in the
darkest green of their own ramp, so they stand out from the ground in every season (before on
the left, after on the right; `make contrast-sheet` draws this sheet for any plant):

![Tall grass, fern and reeds over grass, lush grass, dry grass and floodplain in spring, summer, autumn, bare winter, frost, snow and at night, before and after](docs/screenshots/outlines.png)

### The coast and the tidal flats

In the west the land ends at the North Sea. A sea dyke runs along the coast, and beyond it lie
the salt marsh, grey-green with sea purslane and glasswort, pink with thrift in early summer,
lilac with sea lavender later and red-purple in autumn; then the tidal mud of the Wadden Sea,
with ripple marks, lugworm casts and shells, cut by tideways that widen towards the open sea.
The tide comes in and goes out twice a day: the water fills the hollows first, then the flats
are under, and at low water the mud dries again. The mud can be walked at any tide. Out on the
salt marsh a Warft rises here and there, a dwelling mound with a pond on top, and now and then
an Ewer, a flat-bottomed sailing barge, lies on the mud. Storks and geese come to the salt marsh,
and oystercatchers, dunlin, gulls and terns to the mud and the sea (see [Wildlife](#wildlife)).

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
feeding come later. The numbers are in [data/livestock.cfg](data/livestock.cfg). Like the
people, the animals are drawn at 32 pixels per tile, with legs that bend at the joints, an eye
with a glint and the marks of their coats.

![A mixed herd by the camp on a summer morning, and asleep after midnight](docs/screenshots/livestock.png)

Dogs, cats and horses keep them company: a farm collie, a spitz and a hunting dog; tabby,
black and ginger cats; a heavy marsh horse, nearly three tiles long and taller than you at the
head, in bay, black or grey, and a dun pony. Dogs and cats sniff about, horses graze, and all of them dash off at a run now and
then; cats roam furthest. A dog barks now and then, a cat rarely meows, a horse whinnies or
snorts. Hold a **bone** (`give bone`) and press the use key at a dog in front of you: it takes
the bone and follows you for three game hours, day and night, keeping a tile or two from you
and running to catch up (left far behind or stuck, it turns up at your side).

![Horses, dogs and cats about the camp](docs/screenshots/dogs-cats-horses.png)

Cats hunt the mice. A cat that sees a mouse a few tiles off crouches low with its tail flat,
creeps up on it and pounces; about half the pounces catch the mouse, and the others are seen
coming and the mouse dashes off into cover. Then the cat rests a minute before it hunts again.
Mice are out mostly at dusk and at night, and the cats sleep from a while after sunset, so
dusk is the hunting hour. The numbers are in the `[hunting]` section of
[data/livestock.cfg](data/livestock.cfg).

![Three cats at dusk: crouched at their mice, creeping up on them, and after the pounce, the mice caught or fled](docs/screenshots/cats-hunting.png)

Horses can be ridden. Hold a **saddle** (`give saddle`) and press the use key at a horse in front
of you to saddle it; the use key with an empty hand takes the saddle off again. Press **E** at a
saddled horse to get on, and E again to get off: you land on free ground beside it, and the
horse stays there. A horse sets off at a walk and trots at twice your walking speed once you
keep riding; it costs no energy and tiredness doesn't slow it. On horseback you can only use
the inventory and the hotbar (dropping things too), and eat: no tools, no building, no
crafting, no doors, and nothing is picked up from the ground. Get off first. A game
saved on horseback loads with you standing beside the horse.

![Trotting on a bay horse, walking a grey towards the viewer, and on a pony from behind](docs/screenshots/riding.png)

### Villagers

The first people of the coast: villagers dressed in the clothes of the period, the men in
knee breeches, waistcoats and felt hats, tricornes or red and white stocking caps, the women
in long skirts, laced bodices, white, blue or striped aprons, shawls and white coifs or
headscarves, each with a skin, hair and clothes of their own and a North Frisian or Low
German name (Antje Boysen, Momme Ketels). Like you they are drawn at 32 px per tile, with
faces, buttons, stockings and clogs, and stand on a small shadow. They keep to within about
six tiles of the house or campfire nearest to where they came, stand about and stroll by day
and stand still at night; you walk through them, so they never shut you in. For now they come
from the console; they are saved with the game.

They all live in Wehlsbüll, a made-up marsh parish two hours north of Husum in 1750, which
[data/village.cfg](data/village.cfg) describes as everyone there knows it: the church, the Krug,
the mill, the dyke and its sluice, the Koog, the creeks and the Geest; who is who (Pastor
Johann Martens, the Deichgraf Peter Momsen, the Deichvogt Brar Feddersen, the innkeeper, the
Amtmann at Husum); prices in Schilling and Mark; this year's news (the cattle plague, the dyke
broken last autumn); the church year; and what people of the time know of the world (the Danish
king, the Duke of Gottorf, who speaks what).

Each villager has a sheet: age, trade, personality, background, home, how they speak (a manner,
so it holds in any language), lines in their voice, their family and friends with what they
think of each, likes, wants, their day, what they don't know or won't talk about, and a secret or
two. Eight are written by hand in [data/villagers.cfg](data/villagers.cfg), two families and
their friends, and come with `spawn npc <id>`: `antje` (Antje Boysen, a farmer's wife),
`hinrich` (her husband) and `boy` (their son), `momme` (Momme Ketels, a fisherman of the tidal
creeks) and `inken` (his daughter, Boy's sweetheart), `ocke` (Ocke Hansen, the miller) and
`gesche` (his wife, Antje's friend), and `kerrin` (Kerrin Paulsen, the late Deichvogt's widow,
Gesche's aunt, who lived through the Christmas flood of 1717). Everyone a sheet names as kin or
close friend is one of them, and the sheets agree with each other (a test checks that each names
the other back, the ages and the homes). Edit their sheets freely: a saved game takes them from
the file each time it loads. `spawn npc 3` makes villagers up, with a sheet drawn
from the tables of [data/npcs.cfg](data/npcs.cfg) once and kept: newcomers and people of the
outlying farms, kin to none of the families.

Face a villager and press E to talk: the name over their head shows whom E speaks to. The
chat is laid out like a messenger: the villager's portrait on the left and yours on the
right, and between them the talk as bubbles, the villager's on the left under their name,
yours on the right, each with the game time in its corner; a "..." bubble shows the villager
is still answering. Type a line and press Enter; Escape leaves. The game stands still
while you talk. A villager keeps the latest lines of your chat (24 by default, set under
Settings → Language model) for the next time, so a reopened chat goes on where it left off;
the older lines are summed up in one remembered line (by the model, else it is what you
said), and later talks build on it. Type `/clear` in a chat to make that villager forget
the chat and their memories (for debugging). With a language model set under Settings →
Language model (see [Talking NPCs](#talking-npcs-with-a-language-model)) villagers answer
in their own words; without one they say short scripted lines ("Aye.", "Is that so?").
While one villager is still answering you may leave and talk to another; the answer waits
in the first one's chat.

![Villagers by the camp, the name of the one E would speak to over their head](docs/screenshots/npcs.png)

![A chat with Antje Boysen: the villager's bubbles on the left, yours on the right, the villager still typing](docs/screenshots/npc-chat.png)

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
strikes and swallows it; the cats hunt the mice (see [Livestock](#livestock)). On the coast
oystercatchers in black and white probe the tidal mud all year, and tight flocks of dunlin in
the spring and autumn migration, swinging round together when you come near; herring gulls
walk and peck on the mud and swim on the sea, and in summer common terns fish over the
tideways, hovering and plunging in with a splash. When the tide comes in the waders leave the
mud and the gulls swim where they stood. The animals
come and go around you by the season, the time of day and the weather; the numbers are in
[data/wildlife.cfg](data/wildlife.cfg).

![White storks by the camp, a stork on the roof of the shack, geese grazing in autumn and a flock of them flying over](docs/screenshots/wildlife.png)

![Storks striking at frogs by the camp on a summer evening, and mice in the grass](docs/screenshots/mice-and-frogs.png)

![Oystercatchers and a flock of dunlin probing the mud at low water in spring; herring gulls on the mud; terns fishing over the sea, one just gone in with a splash, and gulls swimming; and the dunlin taking off together](docs/screenshots/sea-birds.png)

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
mouse. Q and E pick the building: shack, Kate, longhouse, hall house, barn, church or bell
frame. A small panel lists the logs, stone, clay and reeds it takes against what you carry; the
spot is refused while something is missing, and a click or Space builds it and takes the
materials. The ghost shows where it fits, and the game tells you why a spot doesn't work, for
example when it is unsafe wetland. Hold something else (or press Escape or right click) to stop
building. You can walk inside every building but the bell frame, and each has its own room: a
bare shack with a straw mat on a clay floor, a cottage room in the Kate, the longhouse with a
living end and an animal end, the hall house with its long Diele between the stalls and the
Flett with the hearth at its end, the barn with stalls and hay, and the church with its pews
and altar. The rooms are furnished like 18th-century farmhouses of the coast: brick floors in
the living rooms and beaten clay in the work rooms, an open hearth under a smoke hood with
Dutch tiles behind the fire, plate racks with Delft and pewter, a wall bench and box beds with
curtains. The last bed you slept in becomes your home. A new game starts at the camp with your
tools and the hammer, so the materials for the first house have to be gathered first. The
buildings, their sizes, costs and insides are in [data/buildings.cfg](data/buildings.cfg).

The buildings follow the reed-thatched farmhouses of Denmark and northern Germany: the Kate
with white lime walls and teal shutters, the brick longhouse with its arched barn door, the
half-timbered barn, and the shack: tarred black boards under a turf roof, which greens in
spring, browns in autumn and winter and lies under snow like the thatch. The biggest is the
Low German hall house of Holstein: its half-timbered gable to the front with red brick in
herringbone, the big arched barn door (the Grote Door), the owl hole under a little hip and
white bargeboards crossing in a pair of horse heads, under a huge thatch.
It is also the dearest: 100 logs, 40 stone, 50 clay and 80 reeds (the shack takes 20 logs
and 5 stone, the Kate 30, 15, 15 and 25).

The fisherman's hut is the shack's kin at the water: tarred boards under a reed thatch with a
turf ridge (25 logs, 5 stone, 15 reeds). Its landing is laid piece by piece: a plank jetty on
oak piles over the water or the mud, which you walk out on, joined up as you lay it and with
mooring posts at its head (a piece takes 3 planks and a log at the workbench); a flat rowing
boat to lie beside it (10 planks, 4 fibre); and, made by hand, a net frame with a tarred net
hung to dry (2 logs, 8 fibre) and wicker eel traps (4 reeds, 1 fibre).

![The fisherman's hut behind the sea dyke with its jetty, boat, net frame and eel traps at a tideway in summer, and on a winter night under snow, the player standing on the jetty](docs/screenshots/fisher-hut.png)

![The Kate, the longhouse, the hall house, the barn and the shack in summer, and the hall house on a winter night](docs/screenshots/buildings.png)

The village church follows the small marsh churches of North Frisia: a nave of grey-brown tuff
with a lower chancel, steep red pantile roofs, small arched windows of leaded glass that light
at night, and a white porch on the south side with the door (70 logs, 35 stone, 45 clay).
These parishes had no tower; the bell hangs in a wooden bell frame of its own, an oak frame
on a brick base under a shingled pyramid, which nobody goes into. For the churchyard, the
workbench makes grave markers (2 planks, 2 stone), which stand outdoors as an oak cross, a
headstone or a fieldstone slab.

![The churchyard at noon in summer, with its bell frame and a Kate beside it, and on a winter night with the church windows lit](docs/screenshots/church.png)

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
you carry 28 stacks. New items fill the free hotbar slots first. The screen shows the backpack
and the hotbar stays lit at the bottom, where you use it as the quick bar: click an item, then
a slot of the backpack, the hotbar or the equipment to put it there. A different item in that
slot swaps places and sticks to the mouse in turn, the same item stacks. Shift+click sends a
whole stack from the backpack to the hotbar and back (onto the same item first, if there is
room). Let go of a picked stack outside the screen, or press T for the held stack, and it lies
on the ground in front of you; walk away and back to pick it up again (a game saved right
after a drop picks the pile up when it loads). Energy and health bars track how tired you are,
and the more you carry, the more each action costs: up to 40 kg is free, and tools weigh
nothing. Below 20 % energy the character sweats with every action, and below 10 % even more. A "zzz" thought bubble pops up over the
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

![Waking in the shack and at the camp](docs/screenshots/waking-in-bed.png)

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
- **Woodworking** at the **workbench**: planks, a stool for the house, a grave marker for the
  churchyard, clogs, a painted Frisian chest with 20 slots, and as the master's piece a
  joined cupboard with 25.
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
to open it: your backpack is on the left (the hotbar below stays usable) and the chest's 15
slots (20 in a carved chest) on the right. Click an item and click a slot to move it, or
Shift+click to send a whole stack across (from the chest it goes to the backpack first, so the
hotbar isn't flooded). The
axe takes a chest down: outdoors what it held spills onto the ground, inside a house the
chest and its contents go into your inventory (or you are told there is no room).

![The storage screen of a chest](docs/screenshots/chest.png)

### Settings and controls

You can rebind every key, including mouse buttons. You can also switch between fullscreen
and windowed, scale the UI from 0.5× to 2× without touching the world view, and set the
energy drain and the day length variation, and set the language model villagers talk
through. Hover over a setting, a key or an item in the
hotbar, inventory or equipment for a short explanation: an item's kind, weight, what food
gives back, what seeds grow and where they are planted. The game starts at its widest view,
a native 640×360 art pixels (20×11 tiles of 32×32, ×3 on a 1080p screen and ×4 at 1440p);
Ctrl and the mouse wheel zoom smoothly in to 2×. The wheel alone steps through the hotbar.

![Rebinding the controls](docs/screenshots/controls.png)

The art is being redrawn at 32 px per tile, group by group. Settings → Display → Art, or F7
while playing, switches between the new art and the classic art, the 16 px art it replaces
(doubled); so far the player and the villagers have both. Everything not redrawn yet looks the
same in both.

![The camp with villagers in the new art and in the classic art](docs/screenshots/art-sets.png)

![Zoomed in to 2×](docs/screenshots/zoom.png)

### Console

Press `/` to open a console for testing and cheats. Tab completes commands and their
arguments.

| Command | What it does |
|---|---|
| `help`, `help <command>` | List the commands, or show what one takes (the names it accepts too). |
| `tp <x> <y>` | Teleport to a world tile; from inside a house you step out there (F3 shows your coordinates). |
| `reset` | Put yourself in your bed, the one you wake in, inside or out. |
| `give <item> [count]` | Put items in the inventory (e.g. `give bone` for a dog, `give saddle` for a horse). |
| `god`, `nodrain`, `noweight`, `nocost` | Toggle invincibility, free actions, weight costing nothing, and buildings and crafting needing no materials. |
| `freeze` | Toggle time standing still: the clock, the day, the crops and the weather wait; you and the animals still move. `skip`, sleeping and passing out still move time on. |
| `noclip` | Toggle walking through anything: water, trees, rocks, buildings, furniture (indoors within the room, outdoors on loaded ground). Turned off where you don't fit, it puts you on the nearest free ground. |
| `weather`, `weather <condition>`, `weather auto` | Show the weather, force a condition, or go back to the simulation. |
| `snow`, `snow <0..1>`, `snow auto` | Show the snow cover, force it, or go back to the weather. |
| `spawn npc [count]` | Put villagers nearby, each with a look, a name and a sheet of their own; they stay. |
| `spawn [npc] <villager>` | Put a villager written by hand nearby (`spawn kerrin` or `spawn npc kerrin`): `antje`, `momme`, `ocke`, `kerrin`, `hinrich`, `boy`, `inken` or `gesche`; each comes once. |
| `spawn <animal> [count]` | Put animals nearby: farm animals that stay (`cow`, `sheep`, `chicken`, `rabbit`, `dog`, `cat`, `horse`) or wild ones that come and go (`bird`, `wild_rabbit`, `squirrel`, `deer`, `bee`, `butterfly`, `flock`, `stork`, `roof_stork` on the nearest roof, `geese` grazing, `flying_geese`, `mouse`, `frog`, and on the coast `oystercatcher`, `dunlin`, `gull`, `tern`). `spawn` alone, or with an unknown name, lists them. |
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
| T | Drop the held stack on the ground in front of you (picked up again by walking away and back) |
| Tab | Character screen and inventory |
| K | Skills tab of the character screen |
| C | Crafting menu (by hand) |
| E | Get off the horse you ride; else talk to the villager in front of you, else get on the saddled horse in front of you, else open the chest or the station (its crafting menu) in front of you, else sleep until morning (next to a bed); with the hammer in hand it picks the next building |
| Enter, Escape | In a chat: send the line, leave the chat (Page Up and Down scroll back); `/clear` makes the villager forget the chat |
| B | Take the hammer: build mode |
| X | Switch the hammer between building and taking down (hold Space or click to take down) |
| Q, E | Previous and next building (while holding the hammer) |
| Mouse wheel | Next or previous hotbar slot |
| Ctrl + mouse wheel | Zoom |
| Escape | Pause menu |
| `/` | Console |
| F3 | Show coordinates and weather values |
| F7 | Switch between the new and the classic art |

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

Villagers talk through an OpenAI-compatible chat endpoint, or through Claude. Out of the box the game asks the
test LLM on `http://127.0.0.1:11434/v1` (see below); when nothing answers there, or a reply
takes longer than 30 seconds, villagers say short scripted lines instead, so the game never
needs a model.

**Configuring it.** Settings → Language model has a provider choice, four fields and the chat length, each
stored as you type or pick:

| Field | Default | What it is |
|---|---|---|
| Provider | OpenAI-compatible | OpenAI-compatible (the test LLM, Ollama, LM Studio, hosted APIs), Claude or Gemini. Each provider keeps its own endpoint, model and key: choosing Claude shows Claude's (starting with `https://api.anthropic.com/v1` and `claude-opus-5-5`), Gemini Gemini's, choosing back shows the test LLM's again, and a key is only ever sent to the provider it was typed for. |
| Endpoint | `http://127.0.0.1:11434/v1` | The base address of the chat API; the game posts to `<endpoint>/chat/completions`. Empty it to turn the model off (villagers then always speak scripted lines). |
| Model | `qwen2.5:7b-instruct` | The model name the endpoint should use: typed, or picked from the drop-down below it, which lists what `<endpoint>/models` answers (Claude's `/v1/models` with the key), asks again a moment after the endpoint or key is typed and by the Refresh button, and shows only the saved model with a note when the endpoint can't be asked. |
| Lines a villager keeps | 24 | A number from 2 to 200, one for all providers: how many of the latest chat lines a villager keeps in the save and tells the model. Older lines are summed up in a memory; lowering it sums up the lines it drops, once the menu is closed. Every kept line is sent with each question, so higher values make the answers slower (and cost more with a hosted model). |
| Key | empty | Only for endpoints that need one: sent as the header `Authorization: Bearer <key>`, and never sent along a redirect. |
| Max tokens per answer | empty | The most tokens a villager's line or memory may take, a number from 1 to 32000. Empty is the game's own: 60 for a line and 40 for a memory, 1000 with Claude. A model that thinks first counts its thinking too, so give one such as Gemini's Flash a few hundred or more. |

The same live in `settings.cfg` (in Godot's user folder, e.g.
`~/.local/share/godot/app_userdata/Sandbox Game/settings.cfg` on Linux): the chosen provider
and the OpenAI-compatible provider's endpoint, model and key under `[language_model]` (where
they were before there was a choice), Claude's under `[language_model.claude]` and Gemini's
under `[language_model.gemini]`. Only values
that differ from the defaults are written (the chat length is `chat_history_lines` under
`[language_model]`):

```
[language_model]
provider="claude"
endpoint="https://api.openai.com/v1"
model="gpt-4o-mini"
api_key="sk-..."

[language_model.claude]
api_key="sk-ant-..."

[language_model.gemini]
api_key="AIza..."
```

The key is stored as plain text there (never in the save, never logged; `make lint` fails on
anything that looks like a key in the repository, and `.gitignore` keeps any `settings.cfg`
out), and what you say to
villagers goes to that endpoint. Ollama, LM Studio (`http://127.0.0.1:1234/v1`), llama.cpp's
server and hosted OpenAI-compatible APIs work as the OpenAI-compatible provider. To try an
endpoint and key by hand:

```
curl -s <endpoint>/chat/completions -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <key>' \
  -d '{"model": "<model>", "messages": [{"role": "user", "content": "Moin!"}]}'
```

(Leave out the `Authorization` line for an endpoint without a key, like the test LLM.) When
the endpoint can't be reached, the game's output says so once, not for every line.

**Claude.** Pick the provider Claude under Settings → Language model and paste an Anthropic
API key (console.anthropic.com) into Key; the endpoint becomes `https://api.anthropic.com/v1`
and the model `claude-opus-5-5`. Everything the villager is told and everything you say to
villagers then goes to Anthropic over the internet, and the key sits in `settings.cfg` as plain
text. A line costs about 2,500 tokens in (the full sheets, more with a long chat) and 40 out: roughly 1 cent with `claude-opus-5-5`
($4 / $20 per million tokens), roughly 0.03 cents with `claude-haiku-5-5` ($0.10 / $0.50),
which is plenty for small talk: pick it from the model list. The game sends the Messages API's
`x-api-key` and `anthropic-version` headers, no temperature (current models refuse it), low
effort and room for 1000 tokens (a model's thinking counts against that; the reply is trimmed
to two sentences anyway); on Opus and Sonnet a refusal falls back server-side. A refusal, an
error or a time-out gives a scripted line, as with any endpoint. The numbers are in `[claude]`
of `data/npc_talk.cfg`. `ANTHROPIC_API_KEY=... make test` also asks the real Claude once.

**Gemini.** Free within Google's limits, with an API key from AI Studio
(aistudio.google.com/apikey: Create API key, in an existing or new Google Cloud project; without
billing the key stays on the free tier). Pick the provider Gemini under Settings → Language model
and paste the key (it starts with `AIza`); the endpoint becomes Gemini's OpenAI-compatible
`https://generativelanguage.googleapis.com/v1beta/openai` and the model `gemini-2.5-flash-lite`,
which answers fast and doesn't think first: a model that thinks may spend a line's 60 tokens
before saying anything (raise Max tokens per answer for one). The model list shows what the key may use. What villagers are told and
what you say goes to Google, and on the free tier Google may use it to improve its models. To
check a key: `curl -s https://generativelanguage.googleapis.com/v1beta/openai/models -H
"Authorization: Bearer <key>"`.

**The test LLM.** `make llm-up` runs Ollama with Qwen2.5 7B Instruct (4.7 GB, Apache-2.0) in a podman or docker container on `http://127.0.0.1:11434/v1`,
the default endpoint, so villagers talk as soon as it is up; `make llm-check` asks it one
question and `make llm-down` stops it. The container image (5.5 GB) and the model live in
the container tool's storage and the volume `sandbox-game-llm-models`; `make llm-down PURGE=1`
deletes the model. Details in [tools/README.md](tools/README.md). A reply takes a second or
two on the GPU, a few seconds on the CPU; one that takes longer than 30 seconds, or
fails, becomes a scripted line. To try another model, run
`make llm-pull LLM_MODEL=qwen2.5:3b-instruct` (twice as fast, but its lines are less
sensible) and set it as the model in Settings; [tools/README.md](tools/README.md) lists some
that fit, and says how `make llm-eval` compares models on the villagers' prompts.

What the model is told for each reply (the words are in [data/npc_talk.cfg](data/npc_talk.cfg),
shaped like a prompt that worked well with the test model): a system line (1750 on the North
Frisian coast, one or two sentences of small talk that answer what you said, in your language,
never break character, puzzled by what did not exist then; keep to the sheets and to what was
said earlier in the talk, never make up relatives, names or places that are not on them but say
they don't know, speak in one's own manner, of which the sample lines show the manner and not
the language) with the village's sheet and the villager's, one example exchange (of a
blacksmith who is not one of the villagers, so that the model does not copy a villager's words
into the others' mouths), the lines of your chat with them that they keep (24 by default; the
older ones are in their memories), and then the villager's name, trade, age, look in words and
what they remember of earlier talks, the moment
(the date as the clock shows it and how far into the season, the time and part of the day by the
sun, the weather as it is: rain, snow, fog or the sky, the temperature, frost, the wind and
where it blows from; and the house or fire they stand by), that you are a newcomer whose name
they don't know, what you said, and the language they answer in. The game tells that itself: it
recognises English, German and Danish by common words and letters (the lists are in the data
file), so the prompt says "Antje answers in German." right before the answer, and a line too
short to tell ("Moin", "Hej") keeps the language of your last line that could be told. A
language it does not know (Swedish) is not named; the villager is then only asked to answer in
the language you spoke (switch language mid-chat and they follow). Only the reply and the memory
lines are kept (a memory is one sentence the villager writes in the first person); nothing else
in the game changes by what the model says.

**Full or cut-down sheets.** A hosted model (a provider that needs a key: Gemini, Claude) is
told the full sheets, about 2,000 tokens a line. A local model (the OpenAI-compatible provider,
such as the test LLM) is told cut-down ones, so that a 3B or 7B stays fast: the villager's
essentials, family and friends by name, manner of speaking and one sample line, and the
village facts most likely needed (where it is, who is who). The rule is `needs_key`
of the provider's row in `GameSettings.LANGUAGE_MODEL_PROVIDERS` (`NpcDialogue.has_full_sheets`).

To screenshot a talk, start the test LLM (`make llm-up`; screenshots read
`build/settings.cfg`, where the default endpoint applies) and run

```
make screenshot SCREENSHOT_TIMEOUT=120 ARGS="--villager=antje '--chat=Moin, Antje!;Do you have butter?'"
# or canned lines, no model asked (you and the villager in turn; a last "..." is them typing)
make screenshot ARGS="--villager=antje '--chat-script=Moin, Antje!;Moin!;...'"
```

`SANDBOX_LLM_URL=http://127.0.0.1:11434/v1 make test` also runs the tests that ask the real
model.

### For developers

Start with [docs/architecture.md](docs/architecture.md): how the code is organised and where
to look. `make help` lists the targets and their variables.

| Command | What it does |
|---|---|
| `make help` | Lists the targets and variables (the default). |
| `make test` | Runs the GUT test suite headless, in `TEST_JOBS` parallel Godot processes (default 8; `TEST_JOBS=1` runs one process). A shard running longer than `TEST_TIMEOUT` seconds (default 600) is killed and fails. `build/test.log` is the shard logs joined plus a summary; `build/test-<i>.log` are the single logs, and `build/test-times` the file durations that balance the next run. |
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
- **Art style:** period, place, materials and what to avoid are in [docs/art-style.md](docs/art-style.md); `make contrast-sheet` shows plants over the ground of every look.
- **Data files:** gameplay numbers you might want to tune live in
  [data/](data/) (energy, crops, buildings, recipes, weather, seasons, vegetation, flowers, wildlife, sounds, ambience).
- **Design:** the design is in [SPEC.md](SPEC.md).
- **Debug flags:** command-line flags for screenshots and debugging (time, day, weather,
  position and more) are listed in the header of [game/scenes/startup_options.gd](game/scenes/startup_options.gd).
