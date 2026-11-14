# Animals

Farm animals, the farm yard and the wild animals of the marsh and the coast.

Animals come from the [console](console.md) for now, for example `spawn cow 3`. They are saved with
the game. Milk and wool are not in yet.

## Livestock

- Cows, pigs, sheep, hens and rabbits wander, graze and keep out of water. Rabbits hop off when
  you come close.
- Each flock of hens has a rooster (`spawn rooster`); he lays no eggs.
- At night they lie down and sleep.
- Dogs, cats and horses keep them company: a heavy marsh horse, a dun pony, collies, tabbies.

![A mixed herd by the camp on a summer morning, and asleep after midnight](../docs/screenshots/livestock.png)

![The rooster among his hens, in the new and the classic art](../docs/screenshots/rooster.png)

![Horses, dogs and cats about the camp](../docs/screenshots/dogs-cats-horses.png)

### Dogs

- Hold a bone (`give bone`) and press the use key at a dog in front of you; the bone is used up.
- It follows you for three game hours, day and night, a tile or two behind.
- More than 15 tiles behind, it turns up at your side. Stuck behind a fence or water, it waits.

### Cats and mice

- Cats hunt mice, mostly at dusk and at night: they crouch, creep up and pounce.
- About half the pounces catch the mouse; then the cat rests for a minute.
- Cats sleep from a while after sunset, so dusk is the hunting hour.

![Three cats at dusk: crouched, creeping up, and after the pounce](../docs/screenshots/cats-hunting.png)

### Riding

- Hold a saddle (`give saddle`) and press the use key at a horse to saddle it.
- With an empty hand, the use key takes the saddle off again.
- Press E at a saddled horse to get on, and E again to get off beside it.
- A horse trots at twice your walking speed, costs no energy and never tires.
- On horseback you can only use the bag and hotbar and eat: no tools, building, crafting or doors.

![Trotting on a bay horse, walking a grey, and on a pony from behind](../docs/screenshots/riding.png)

### Petting

- Use key with an empty hand at an animal: cows, horses, sheep, pigs, hens, tame rabbits, dogs
  and cats.
- Each animal has a friendship with you from 0 to 100, starting at 0.
- The first petting each day while it is awake gives +10 and a heart; more that day do nothing.
- Petting it while it sleeps takes 5 and shows an anger mark, once a day too.
- Each day without petting takes 5, never below 0.
- Friendship has no use yet. `friendship` in the console shows it for the nearest animal.

![The heart over petted animals by day, the anger mark over sleeping ones](../docs/screenshots/petting.png)

## The farm yard

### Water and the draw well

- The watering can holds 20 waterings. Fill it at a draw well or at fresh water (river, pond or
  ditch, never the sea or salt marsh).
- Draw well: workbench, masonry 20, 12 stone, 3 planks, 2 logs and 2 fibre. Put it down outdoors.

### Troughs and hay racks

- Trough: woodworking 10, 5 planks and a log. Hay rack: woodworking 15, 4 planks and 2 logs.
- Each stands on two tiles outdoors and holds up to 100 units; its picture shows how full it is.
- Fill a trough with the can (10 units a pour) and a hay rack with hay (10 units each), using the
  use key.
- A feeding trough (made like the trough) holds hay, turnips, acorns or beech mast for pigs.

### Hunger and thirst

- Animals get hungry and thirsty as time passes (a cow goes from fed to hungriest in 12 hours,
  to thirstiest in 8). For now this has no other effect.
- They walk to fresh water or a trough to drink, and to a hay rack or feeding trough to eat.
  Grazers eat as they graze.
- Each drink or meal takes a few units (a cow 5, a hen 3).
- `noneeds` in the console stops the needs from rising.

### Chicken coop and eggs

- Coop: a building, 12 logs and 4 stone, 2x2, six hens to a coop.
- At bedtime, each hen within twelve tiles walks in; she lays an egg 7 times in 10, four eggs to
  a nest.
- Go in and press the use key at a nest with an empty hand to take the eggs.

### Pigs and the pig pen

- Pigs root about most of the day, which feeds them a little, and eat at a feeding trough.
- Make pen fences (a log splits into two), a pen gate and a pig shelter at the workbench and
  place them round a few tiles, with a trough and a feeding trough inside.
- You walk through the gate shut or open; animals only through an open one. A shut gate keeps
  pigs in, however long you sleep.
- Use key with an empty hand opens and shuts the gate.

![A pig pen at noon, in the new and the classic art](../docs/screenshots/pig-pen.png)

![The farm yard: coop, draw well, troughs and hay racks from empty to full, a cow and a sheep](../docs/screenshots/farm-yard.png)

## Wildlife

Wild animals come and go by the season, the time of day and the weather. They never stand on a
building, and they run from villagers as from you.

### Meadows, woods and marsh

- Birds peck on open ground, and flocks cross the sky: south in autumn, north in spring.
- Rabbits graze the meadows, squirrels dart between trees, roe deer come out at the woods' edge
  at dawn and dusk.
- Bees and butterflies keep to the flowers.
- Mice live by the fields, Knicks, walls and houses, mostly at dusk and night.
- Frogs sit at the water's edge from spring to early autumn; a stork that sees one strikes.
- Fireflies blink over meadows on warm, calm summer evenings, from dusk to a few hours after.

![Storks by the camp, a stork on the shack roof, geese grazing and flying over](../docs/screenshots/wildlife.png)

![Storks striking at frogs on a summer evening, and mice in the grass](../docs/screenshots/mice-and-frogs.png)

![Fireflies over a meadow on a summer night](../docs/screenshots/fireflies.png)

### Storks and their nests

- White storks hunt the marsh and wet meadows in spring and summer.
- About four in ten kates, longhouses, hall houses and barns carry a nest on the ridge.
- Early spring: a pair flies in. Late spring: young hatch. Summer: they grow. Late summer: they
  leave one by one. Autumn and winter: the nest is empty.
- Each nest keeps its own days, so they are not in step.
- In autumn and winter greylag geese graze the marsh, take off together when you come near, and
  fly over in a V.

![A stork's nest through the year, from the pair in spring to the empty nest under snow](../docs/screenshots/stork-nest.png)

### Crows and scarecrows

- Crows come to fields by day, most in autumn and winter and when fields were just sown.
- They eat from crops that nothing guards while you are far off: a sown seed is gone, a growing
  or ripe plant gives one item less (never below 1), at most a few a day.
- A scarecrow (made by hand, put down outdoors) guards crops within 5 tiles.
- It works fully for 3 days, then less over 12 as the crows get used to it, down to a quarter.
- Take it down and put it up again, and it starts anew. Crows don't settle where it guards.
- `crows` in the console shows the flocks and what they ate.

![A flock of hooded crows pecking on a tilled field in autumn](../docs/screenshots/crows.png)

![A scarecrow standing among the crops of a tilled field](../docs/screenshots/scarecrow.png)

### The coast

- Oystercatchers probe the tidal mud all year; tight flocks of dunlin come in spring and autumn.
- Herring gulls walk on the mud and swim on the sea.
- Common terns fish over the tideways in summer, hovering and plunging.
- When the tide comes in, the waders leave the mud and the gulls swim where they stood.

![Oystercatchers, dunlin, gulls and terns at the mud and the sea](../docs/screenshots/sea-birds.png)
