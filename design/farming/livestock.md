# Livestock

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
  cats livestock: each mouse tells Livestock where it is (`Prey`), Livestock decides and moves
  the whole hunt, the views only show it, and nothing of a hunt is saved (a game saved mid-hunt
  loads with the cat looking about). Mice live only in the wildlife near the camera, so with
  no mice about nothing hunts, and a hunt whose mouse goes ends with the cat resting where it
  stands. The numbers are in `data/livestock.cfg` (`[hunting]`).
- **The bone:** an item (from the console for now). The use key at a dog in front of the
  player gives it the bone, which is used up; the dog follows the player for 3 game hours,
  day and night, then wanders again. It waits within 2 tiles of the player, walks after them
  beyond that and runs beyond 4, until it is 1 tile from them. It never blocks the player; one
  more than 15 tiles behind, or stuck for 2 seconds, is put beside the player. The numbers are
  in `data/livestock.cfg`.
- **Size** (drawn at 32 px per tile since task 114, in scale with the 61 px people): a cow
  about 66 px long and 40 px to its back, a sheep about 38 px long and 22 px to its back, a
  dog about 40 px long, a horse about 88 px long (nearly three tiles) and 57 px to the
  withers, its back free of the neck and head for a saddle and a rider, the pony four fifths
  of it; the hen (about 22 px), the cat (about 28 px) and the rabbit (about 20 px) are drawn a
  little larger than life. They are rounded forms shaded from the top left like the people,
  with legs through their joints, an eye with a glint, and the outline in the darkest colour
  of the coat; each stands on a contact shadow. (Was 16 px art: a cow 22 px long, a horse 32.)
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
  no held item shows. A saddled horse shows its saddle, on a blue saddle cloth that sets the
  rider's breeches off from the horse (task 114). The camera follows the rider as the
  player, and what hides the player hides the rider and the horse too.
- **Behaviour:** an awake animal stands idle (and now and then turns round), walks or grazes;
  chickens peck for seeds and worms. Grazing doesn't change the grass. It walks only onto
  walkable ground under its feet and its nose, so it keeps out of water and away from
  anything solid. Rabbits hop and run from a player who comes close. At night every animal
  sleeps where it stands (lying down, or tucked in; hens go into a chicken coop if there is one, see
  the farm yard): from a while after sunset (hens go to
  roost before it) until about sunrise, each animal up to half an hour later than its
  species. They stand still while the player is in a house, like the rest of the world.
  **Skipping time** (the console's `skip`, sleeping, passing out; decided 2026-11-10): the
  first 3 game minutes are walked through as the same seconds of play; for the rest of it
  each animal in a loaded chunk is put on a random tile it could have walked to (as its steps,
  never across water, fences or walls) up to 6 tiles from where it was, asleep or doing
  something new as the hour has it. A dog that follows is put beside the player, and the
  horse they ride stays with them. Animals in chunks that are not loaded stay as they are,
  as in play. The dice come from the world seed and the time, so the same game skipped the
  same way ends the same.
- **Sound:** now and then a moo, a baa, a cluck, a bark, a whinny or a snort, quiet and rare
  (a cat's meow rarer still); none while asleep.
- **Saved:** species, look, tint and position (save version 13), until when a dog follows the
  player (save version 16), whether a horse wears a saddle (save version 22) and how hungry and
  thirsty it is (save version 25); what an animal is doing is not.
- Animals don't avoid each other or the player yet. No hoofbeats are heard while riding yet.
- **Later:** milk and wool, pens (task 165), owning and breeding, and animals that are neither
  hungry nor thirsty giving better produce (eggs, feeding and drinking are in the farm yard below).

## The farm yard (task 122, decided 2026-11-10)

Four things for the farm, each its own commits: the draw well, the trough, the hay rack and the
chicken coop. All are made at the workbench or built with the hammer and stand outdoors.

- **Draw well:** a 1x1 world object, an oak well head on a fieldstone ring with a forked post and
  the balanced sweep (a pole with a bucket on its long end and a weight stone on its short one)
  drawn above it, reaching over the tile beside it, and see-through when the player stands behind
  it. Its ring blocks walking. Made at the workbench (masonry 20) from 12 stone, 3 planks, 2 logs
  and 2 fibre; the pickaxe takes it up again (4 hits) and it drops the well.
- **The watering can's water** (decided 2026-11-10): the can holds `[can] capacity` (20) in
  data/energy.cfg and a new game starts with it full; wetting a tile of soil takes 1. The use
  key with the can at a draw well or at fresh water (`Tile.is_fresh_water`: the terrain WATER, so
  the rivers, ponds and ditches; never the sea, the tidal mud or the salt marsh) fills it, unless
  it is full. With the can empty the use key at dry soil does nothing and says so. The water in the
  can is saved (save version 25) and shown as a small number on the can in the hotbar. The well gives the water for the can, and so for the troughs and
  the soil; water for the house (cooking, washing) comes with those.
- **Trough and hay rack** (2x1 world objects; the trough holds water, the hay rack feed; a feeding
  trough for pigs and the like is the same code with `stock_kind` feed, task 165): each holds a
  **stock** of up to 100 units (`stock_capacity` in WorldObjectTypes; the `stock` in its state,
  saved with the object) and starts empty. Its picture shows how full it is in four steps: empty,
  low (up to 35% of the capacity), half (35% to 70%) and full (70% and over). The trough is a
  plank box on two feet made at the workbench (woodworking 10: 5 planks, 1 log), the hay rack
  oak posts with slats and the hay behind them (woodworking 15: 4 planks, 2 logs); both stand
  outdoors and the axe takes them down (3 hits).
- **Filling them** (decided 2026-11-10): the use key with the watering can at a trough pours
  `[yard] pour_units` (10) units of water in and takes 1 from the can (and the energy of
  watering); the use key with hay at a hay rack puts `[yard] feed_items` (hay: 10) units in and
  uses the item up. A full trough or rack takes no more (the can keeps its water, the hay stays
  in the inventory), an empty can says so. Hay is the only feed so far: any item in `feed_items`
  of data/livestock.cfg feeds, so grain for the hens or a swill for the pigs is a line there.
  What was put in stays until the animals take it (see the needs below); nothing spoils.
- **The needs of the animals** (decided 2026-11-10, the user's decisions; task 122): every farm
  animal has a **hunger** and a **thirst**, each from 0 (it just ate or drank) to 1, that rise with
  game time by the hours of its species (`hunger_hours` and `thirst_hours` in data/livestock.cfg:
  a cow 12 and 8 hours from fed to hungriest, a hen 8 and 10) and are saved with it (save version
  25). **They have no consequence at all**: nothing suffers, nothing dies, nothing slows down.
  This is the basic need system; later (Stardew Valley's way) animals that are neither hungry nor
  thirsty will give better milk, wool and eggs, and that is where to put it: read `hunger` and
  `thirst` of the animal where the product is worked out (task 165 and the milk, wool and egg
  tasks). Nothing reads them yet but the animal itself.
  - **They follow the game clock**, not the frames: the animals are brought up to the clock once
    each `update` (`Livestock._account_needs`), so a slow frame, a fast-forward and a skip all give
    the same rise, a frozen clock (`freeze`) gives none and a ridden horse gets hungry too. The player
    in a house stops the animals' updates while the clock runs, so a save brings them up to the
    clock first (`Livestock.account_needs` in `GameState.snapshot`): the hours indoors are in the
    saved game, and the game loaded from it.
  - **Looking for what meets a need:** when an awake animal picks what to do next and a need has
    reached `seek_at` (0.5), it looks within `search_tiles` (10) of where it stands, over the
    ground it can walk to, for the nearest thing that meets it and walks there at its own pace
    (giving up after `trip_seconds`, 30 s, or when it is blocked). There it stands with its head
    down for `drink_seconds` or `eat_seconds` and the need is 0. A search that finds nothing is not
    repeated for `retry_seconds` (30 s), nor is one whose trip was blocked or took too long: it walks
    straight at its goal (round small things, as every animal's step turns), has no way to find a long
    one, and gives up. No more than `searches_per_update` (2) searches are made in one update of the
    animals, counted search by search (an animal with two needs and one search left makes one; each
    is a flood fill), so a herd's searches spread over frames; an animal that did not
    get one asks when it next picks what to do. None are made in the minutes of a skip that are
    walked through. The stronger need goes first. Asleep, following the
    player or running from them, it looks for nothing.
  - **Thirst is met** at **fresh water** in the map: the terrain `WATER`, which is the rivers,
    ponds and ditches (`Tile.is_fresh_water`, the same the watering can fills at); **never** the
    sea, the tideways, the tidal mud (the Wadden), the salt marsh or the coast; or at a **trough
    with water**. Every species drinks.
  - **Hunger is met** at a **hay rack with feed** by those that eat feed (`eats_feed`: cows,
    sheep, horses and rabbits), and by **grazing** by those that graze for food
    (`grazes_for_food`: the same and the hens, which peck for seeds and worms): while it grazes its
    hunger falls by `graze_relief_per_second` (0.003) a second. Chosen from what they do today: the
    animals that graze already eat grass; dogs and cats only sniff about, so they eat nothing there,
    and have no feeder yet (a bowl, a caught mouse for the cat, grain for the hens come later), so
    their hunger just rises to 1 and stays. The trough holds water only; a feeding trough for pigs is
    the same object with `stock_kind` feed.
  - **Stocks go down:** each drink or meal takes the species' `drink_units` or `eat_units` (a cow
    5 of each, a sheep 3, a hen 3 drink, a rabbit 1, a dog 3 drink and a cat 1) out of the trough or
    the rack, whose picture follows. The player refills them (see above). Nothing is used up by the
    animals' own watering at a river.
  - **Skipped time:** a skip (sleeping, `skip`) raises the needs by the minutes that passed and
    counts the meals of the animals in loaded chunks: an animal that could reach fresh water or a
    trough with water (or a rack, or grass for a grazer) has met each need that rose to `seek_at`
    at some point in them, so the need ends somewhere between 0 and `seek_at` by the dice, and a
    trough or rack loses that many drinks or meals (at least one); one that could reach nothing
    stays as risen, up to 1. The skip is made up for over frames, a few animals a frame
    (`Livestock.catch_up_over_frames`, `Simulation.frame_budget_usec`), in the same order and with the
    same dice as in one go.
  - **Console:** `noneeds` toggles the rise off and on again (the HUD shows "No needs"); like the
    other cheats it lasts for the session and is not saved. What is already risen stays.
- **Chicken coop** (decided 2026-11-10; task 122; the building is in design/building/first-buildings.md,
  the numbers in the `[coop]` section of data/livestock.cfg): the hens sleep in it and the eggs are
  collected in it.
  - **Roosting:** when it is time to sleep (they go before sunset, see above), a hen within
    `call_tiles` (12) of the front of a coop's door that she can walk to (not across a river or a
    fence) and that has a free roost (`roosts`, 6 hens a coop; those on their way count, and the
    capacity is checked again at the door) walks to it, goes in and sleeps on a tile of its footprint, **not shown** while she is in; she
    comes out in front of the door in the morning, when her sleep time ends. A hen with no coop to
    go to (none near, or every roost taken) sleeps where she stands, as before; no other animal
    goes in, and only a building of the coop's type houses hens (not a house whose door she
    stands on). Nor is a hen standing on the coop's own door tile, which is walked on, inside it:
    only entering puts her on a tile of its footprint other than the door's, and then the roost
    count applies. A coop taken down leaves its hens standing where it was. Hens in a coop are not
    saved as such: they are saved at their place on its footprint and are inside after the load
    (`FarmAnimal.is_housed` is worked out from where she stands). They are not drawn in the room
    when the player is inside either (nothing in a house shows animals yet).
  - **Eggs:** going in, a hen lays an egg with the chance `egg_chance` (0.7) in a **nest** of the
    coop with room, the hay piles of its inside (`Coop.nests`), each holding up to `nest_eggs` (4)
    in `eggs` in its state, so saved with the building's inside. The use key with an empty hand at a
    nest takes all its eggs (the eggs item, a stack in the inventory; the empty hand's slot always
    has room). The inside is made when the first egg is laid if nobody has been in. Nothing spoils,
    nothing else uses the eggs yet (cooking comes later). Whether a hen was hungry or thirsty makes
    no difference yet: that is where the later production effect of the needs goes, in
    `Coop.lay_egg`.
  - **Skipped time:** a skip that lasts over a hen's bedtime counts the egg of that night for her
    (by `egg_chance`), if she is in a coop or could go to one; she then is in the coop if it is
    time to sleep when the skip ends, else out in front of its door. The walked minutes at the start
    of a skip count too (no hen goes to a coop in them, she sleeps where she stands until the skip
    settles her), a night's roost is used up even when the skip ends in the morning (only for that
    skip: nothing is kept after it), and a hen settled in a coop meets her needs like the others.
    The hens' bedtimes are counted one by one, so a two-day skip lays two nights' eggs, as many as
    the nests have room for. A skip shorter than the walked minutes has no catch-up: a hen that
    fell asleep outdoors in it goes to the coop when play goes on (`FarmAnimal.missed_roost`).
  - **Left open (decided as the mildest, the user may change):** a coop taken down loses its eggs
    (they are not what the player put in, so they do not stop it); a hen far from any coop sleeps
    outdoors as ever.
