# Villagers inside (#8, task 229)

The user, 2026-11-11: villagers enter their houses (and the church, workplaces) through the door
instead of waiting in front of it, and are seen in the interior. The activities and the planned
day are built ([routines.md](routines.md), #7), and so are the paths and the doors
([../tech/pathfinding.md](../tech/pathfinding.md)): until now a villager who "goes home to sleep"
stands in the yard. This is how they go in. Decided here, to be built in the steps below.

## The decisions

- **Which activities go inside:** the activity says so, a key `inside=true` in
  `data/activities.cfg`: `sleep`, `breakfast`, `dinner`, `supper`, `go_to_church`, and `work`,
  `milk` and `tend_animals` (which are in a building only when the workplace is one: the farmers'
  field and the fisher's landing are not). `rest`, the flowers, `mend_nets`, the Krug's meeting,
  visiting a friend and the walk about the village stay outdoors. The place has to be a building
  with an inside whose door the activity's spot is in front of (`ActivityPlaces.building_at_yard`);
  with none the villager stands in the yard as before. Rain and the dark send a villager to the
  yard, not in (`_stay_home`): a villager inside does not know it rains. Nothing else changes in
  the plan, the planner or the model's prompt: where they are is the routine's business only.
- **A villager with no workplace of their own** works at home (the target `workplace` falls back to
  the house), so they are in the house for their work. One whose house is taken from them is put
  out (`_follow_day`).
- **To go in they stand in the yard tile**, not near it: a villager with a spot within the stroll
  radius of the door still walks the last bit (`ActivityUpkeep._send`), so the step onto the door
  is a step from the tile in front of it.
- **Nothing is new for the language model:** a villager inside is "at home", "at work" or "at
  church" by their activity, as now.

## How a villager's inside state is kept

On the villager (`Npc`, not the building, so a building does not know who is in it):

- `inside: Building`, null outdoors. `inside_position: Vector2`: their feet in the tiles of the
  building's interior (`Building.inside()`, made the first time somebody goes in, as when the player
  does).
- `position` is **not** in the interior while they are inside: it stays at the yard in front of the
  door. Everything that reads where villagers are in the world (the planner's radius, the deeds
  they hear, gossip, the anchor, the trip a routine starts) keeps working and is none the wiser; a
  villager in their house is "at the door" for it. What must not see a villager who is inside
  filters on `inside` (the views, the speech bubbles, the villager E speaks to).
- `entering: Building`, not saved: they walk the last step from the yard onto the door tile and are
  inside when they reach its middle.
- `anchor` and `keep_radius` stay what `ActivityUpkeep` sets (the yard, the activity's radius); the
  room has its own spot, `inside_position`, picked when they go in.

## The door transition (`Npcs`)

- `Npcs.indoors.go_in(npc, building, is_instant)` (`NpcIndoors`, which also keeps the rest of this):
  the villager is in the yard of `building` (the trip ended there, or they were near enough:
  `ARRIVED_TILES`). They walk straight to the middle of the door tile (`entering`; the door is the
  one tile of a building that can be walked on) at the walking speed and are inside then: `inside`
  set, `inside_position` a free tile of the room (picked with the game's dice, which the tests
  seed), the walk off. Nobody stands on a building tile, so nobody is left on the door.
- Unseen (the player inside, `update_unseen`; the chunk not loaded; a skip: `is_instant`) they are
  inside at once: there is no one to see the step.
- `Npcs.indoors.come_out(npc)`: they are at the yard in front of the door, outdoors, as if they
  had come from it, and walk on from there. It also ends an `entering`. `ActivityUpkeep._send`
  calls it when the step they are sent to is not in the building they are in, so the next trip
  starts at the yard. `walk_to` and `place` do it too, so nothing walks or is put anywhere while
  still marked inside.
- A building taken down (`Households.building_gone`) puts out those inside it.
- No trip is ever made inside a building: the one step from the yard is the whole of the way, so the
  search and the masks stay out of interiors.

## Seen in the interior, and walking about in it

- While the player is in a building the villagers with `inside == that building` have an `NpcView`
  each, among the interior view's entities (`InteriorNpcViews`), the same sprites as outdoors and
  ordered with the furniture and the player as they are. The set is looked at each frame, so one who
  goes in or comes out while the player is there appears or leaves. Outdoors the world's `NpcViews`
  has none for a villager who is inside.
- **Walk about** (`NpcIndoors`, simple on purpose): a villager in the player's room does what they do
  outdoors, in the small: stands a while, then with the chance `walk_chance` heads straight for a
  free tile of the room, within `INDOORS_REACH` (2.5) tiles of where they are, at the walking speed,
  and stands again. A step that does not fit (furniture in the way) ends the walk: no search. They do
  not stand off from the player, who may walk through them (the room is small). `is_staying_put`
  (the activities of standing: a meal, sleep) and the villagers' rest time stand them still.
- No bed, chair or pose of their own: a sleeper stands on a free tile, as they stood in the yard.
  That is art and a place each; later (it changes nothing here).
- Not talked to indoors: `Interaction.npc_to_chat` is still null while the player is in a house.

## What happens when the player comes and goes

Nothing is made or lost: the villagers inside are where their `inside_position` says. When the
player comes in, those inside that building appear where they stand and go on from there; when the
player goes, they have no view and no stroll, and stand as they were. The player entering through
a door where a villager comes in at the same moment sees them either way, as the views follow
`inside`.

## The skip rule

`ActivityUpkeep.catch_up` puts a villager "at the place" with `Npcs.place` and then `_arrive`: when
the step is inside, `_arrive` calls `go_in` and a skip goes in at once (`is_skipping`). A villager
who has left too late to be at the place is "on the way": `place` at the place of the entry before
(which puts them out of the building they were in) and `walk_to`. One who stays where they are
keeps being inside if they were. So at the end of a night's sleep each is in the building the hour
has them in, or out in the world.

## Saving (version 48)

`inside` in each villager's saved data: `null`, or `{"building": origin, "position": [x, y]}`
(the origin as `house` has it). A save of version 47 has none: nobody is inside, and `resume` sends
them where the day has them, as before. A loaded game: `restore_places` finds the building by
origin, the validator checks that there is one; `ActivityUpkeep.resume` sends each villager by the
day as now, and one who is in the building of their step stays in. The oldest upgrade (37) is
dropped first, as `save_file.gd` says, a commit of its own.

## Cost

A villager inside a building the player is not in costs nothing a frame: `Npcs.update` passes over
them, and nothing looks at their room. The only costs are the room made the first time somebody
goes in (a Tiled map read, once a building: the same as the player's first visit) and the interior
of that building in the save (what a house with its own interior has already; some hundred bytes a
room). While the player is in a room the cost is one comparison for each villager of the village
a frame to find those in it, and a stroll for those that are, a handful. A skip puts a villager in
without a walk, so nothing is searched or walked.

## The steps (each a commit that passes on its own, with its tests and doc lines)

1. This plan.
2. **State, door and room:** `Npc.inside`, `inside_position`, `entering`; `NpcIndoors` (`go_in`,
   `come_out` and the step onto the door); `walk_to`, `place` and a building taken down put a villager out;
   `NpcIndoors` and `Npcs.update_inside` (Main calls it for the player's room, in step 4). Tests.
3. **The day sends them in:** `inside` in `data/activities.cfg` and its header, `ActivityPlaces`
   `building_at_yard`, `ActivityStep.building`, `ActivityUpkeep` (arrive, send, skip). Tests,
   routines.md and villagers.md lines.
4. **They are seen:** `NpcViews` has none for one who is inside, `InteriorNpcViews`, Main (which also calls
   `update_inside`), and `NpcBubbles.pick_speaker` and `Interaction.npc_to_chat` skip them. Tests.
5. **Saving:** drop the upgrade from 37; then version 48 with `inside`, its upgrade, the validator.
   Tests.
6. **Seeing it:** the debug flag for the screenshot, the handbook, the pictures.
