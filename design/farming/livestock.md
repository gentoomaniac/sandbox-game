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
  sleeps where it stands (lying down, or tucked in): from a while after sunset (hens go to
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
- **Later:** milk, wool and eggs, pens, feeding, owning and breeding.

## The farm yard (task 122, decided 2026-11-10)

Four things for the farm, each its own commits: the draw well, the trough, the hay rack and the
chicken coop. All are made at the workbench or built with the hammer and stand outdoors.

- **Draw well:** a 1x1 world object, an oak well head on a fieldstone ring with a forked post and
  the balanced sweep (a pole with a bucket on its long end and a weight stone on its short one)
  drawn above it, reaching over the tile beside it, and see-through when the player stands behind
  it. Its ring blocks walking. Made at the workbench (masonry 20) from 12 stone, 3 planks, 2 logs
  and 2 fibre; the pickaxe takes it up again (4 hits) and it drops the well.
