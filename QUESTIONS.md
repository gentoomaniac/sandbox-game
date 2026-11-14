# Open questions

Since 2026-11-14 new questions are GitHub issues labelled `question`, in the "Needs answer"
column of the [project board](https://github.com/users/gentoomaniac/projects/2). Each says the default that
work went ahead with, so nothing is blocked. This file keeps the decisions taken before then
for the user to confirm ([#47](https://github.com/gentoomaniac/sandbox-game/issues/47)). Answered questions
move into the [design](design/README.md).

## Decisions taken without you (please confirm or change)

1. **Chest storage moves items by clicking, not dragging** (task 49): click an item, then
   click a slot, as on the character screen; Shift+click sends a whole stack. Default: keep.
2. **Indoors, the axe puts a chest and its contents into the inventory** (task 49), since
   there is no ground inside to spill onto; refused with a message when it doesn't fit.
   Outdoors the contents spill as agreed. Default: keep.
3. **Crafting with a full inventory is refused** ("Inventory full") instead of dropping the
   item on the ground (task 49). Default: keep.
4. **`skip` never makes the player pass out** at 01:00 (task 46), so `skip 1d` stays usable
   for testing crops. Default: keep.
5. **Shift+click from a chest fills the backpack before the hotbar** (task 50). Default: keep.
6. **Art style changes** (2026-11-06, "implement them, quick ones first, then the longer
   ones one after the other"): all of docs/art-style.md's list became tasks 52-62. Where
   the guide left a choice, its suggestion was taken:
   - **tomatoes are replaced by flax** (a fibre crop; old saves turn tomatoes into flax);
   - **beech, birch, alder and pollard willow become the common trees**, spruce and pine
     rarer (task 56, after the Scots pine of task 51);
   - **the shack gets tarred boards and a turf roof**;
   - **the player wears period clothes** (task 53).
   - **flax yields a new `flax` item, not `fibre`** (task 52): flax stalks are a material
     of their own (linen after retting), and `fibre` stays what bushes give. Not food;
   - **`meadow_light` was not merged** (task 52): it is now the Scots pine's needle colour,
     so the palette is full again (64 of 64);
   - **a new game carries the red knitted cap** besides the straw hat (task 52).
   - **the jacket has an equipment slot of its own, `coat`** (task 53), so it goes over
     either body item and comes off; **old saves get clogs** on their bare feet; and **the
     clothes got lighter** (0.3 to 0.6 kg each), so a new game still carries under the free
     20 kg.
7. **The thatch redraw** (task 55): the roofs are now steep hipped planes with the reed laid in
   ragged courses instead of the soft streaky dome; the Kate and longhouse got crossed ridge
   sticks; snow covers the roof evenly. A first pass looked like shingles and was redone.
   Compare: docs/screenshots/buildings.png. Each piece is its own commit (courses and planes,
   ridge sticks, door swells, snow), so any one can be reverted. Default: keep.
8. **Hedges, walls, fences, dykes and ditches** (task 54): Knicks, stone walls, wattle
   fences and ditches block walking, with one gap per stretch as gate or crossing; dykes can
   be walked on. The axe cuts a Knick (1 log, 2 fibre) or a fence (2 fibre), the pickaxe takes
   a wall apart (3 stone); dykes and ditches can't be removed yet. Nothing can be built or
   tilled on them. **Old worlds get them too**, away from the farm: the save upgrade keeps 3
   tiles around buildings and placed things and 2 around the tilled fields clear, so your
   farm is untouched, but natural trees and rocks that stood on the new lines elsewhere are
   gone. New land takes about 6.5 ms per chunk to generate (was 3.7). Default: keep.
9. **Tree species** (task 56): the oak stays common beside beech, birch and alder. Wet ground
    (the marsh, and the Geest within 5 tiles of wetland) grows mostly alder; the dry Geest
    mostly beech, then oak and birch; pine and spruce only in clumps on the Geest. Woods are now
    about 28 % beech, 24 % oak, 19 % birch, 16 % alder, 7 % pine and spruce, 4 % willow. Beech is
    the toughest (5 hits, 3 logs), birch the weakest (3 hits, 2 logs). Seeds: beechnut, birch
    catkin, alder cone and willow cutting, each a 25 % drop. Trees in your world stay where they
    are, but the ones you haven't touched may turn into another species. Default: keep.
10. **Hearth and furnishing** (task 57): an open hearth under a smoke hood (the jamb stove,
    Bilegger, is left for a best room later); herringbone red brick floors in the living rooms,
    beaten clay in byre, barn and shack; Delft tiles only under the hood; a plate rack in the
    Kate and longhouse; a wall bench only in the Kate (the longhouse has no free wall for it);
    the Kate's bed is a curtained box bed, the longhouse's an Alkoven cupboard. Old saves get
    the new floors and wall pieces; your own furniture stays put. Default: keep.
11. **Code review** (docs/code-review-2026-11-06.md): its findings became tasks 63-71 and run
    one at a time beside the art tasks. Default: go ahead.
12. **The shack** (task 58): tarred near-black boards with battens (not silver-grey ones), an
    ox-blood red door and shutter, a white window, on a low fieldstone base; a turf roof with
    a few flowers. For the turf to brown in autumn and winter, **every house now has a picture
    per season** (spring, summer, autumn, winter, snow) chosen like the ground's; only roofs
    with grass on them change (the shack, the barn's turf ridge), the thatch and its moss stay
    as they were, and the build ghost still shows only summer or snow. Under snow the dark grass
    turns to snow instead of shadow, which also takes a few grey flecks off the snowed-over
    thatch. Each piece is its own commit (walls, roof, seasons and snow). Default: keep.

14. **Livestock** (task 73): `spawn rabbit` is the tame rabbit, the wild one is `wild_rabbit`;
    only rabbits flee; hens roost before sunset, cows lie down an hour after it; activity and
    bedtime aren't saved. Default: keep.
15. **Professions** (task 74): skills 0-100, a craft teaches 2 points at or below its level,
    falling to nothing 40 above it; at 200 total, a skill grows only by taking points from one
    marked Fade on the skills tab (none fades on its own). Flour is 3 wheat ground by hand;
    bricks so far only build the bake oven; the houses' own stools can be taken down. Master
    recipes at level 70 (oak cupboard, feast cake, a master's firing) let a skill reach 100.
    Default: keep.
16. **Meadows** (task 75): flower communities per habitat, drifts about 14 tiles across,
    heather in early autumn, no blue flower (cornflower grows in rye fields). Default: keep.

17. **Desire paths** (task 77): thin grass after 8 steps on a tile, a path after 24 (about
    4-5 days of walking a line 8 times a day); grows back to thin grass in 5 nights and to
    grass in about two weeks; cows wear tracks at half a step each; frost on lush and dry
    grass now shows their own frosted look. No mud in rain yet. Default: keep.

18. **Hall house** (task 59): costs 100 wood, 40 stone, 50 clay, 80 reed; half-hipped thatch
    with a reed ridge, white bargeboards and a green door; the inside is larger than the
    screen and scrolls. Default: keep.

19. **More animals** (tasks 79-82): dogs (collie, spitz, hunting dog), cats (tabby, black,
    ginger) and horses (bay, black and grey marsh horse, a pony) as livestock; a bone makes a
    dog follow for 3 game hours. Mice near fields, hay and houses, mostly at dusk and night;
    frogs at water and in wet meadows from spring to early autumn, croaking on evenings;
    storks catch frogs, cats catch about half the mice they pounce on. Riding: the saddle
    stays on the horse, the use key mounts and dismounts, about twice walking speed, no
    tools, building or doors while riding. Default: keep.

20. **Storks and geese** (task 60): greylag geese; at most a few storks and geese flocks near
    the view at once; a stork stands on a roof or hunts wet meadows; lapwings and
    oystercatchers left for later. Default: keep.

21. **Taking down** (task 83), as the user set it: X with the hammer switches modes, shown on
    the HUD; the thing to take down is highlighted; hold the use button a second; a building
    returns about half its materials at the door, and only once nothing the player placed
    is left inside; not from inside; waking falls back to the camp's sleeping bag. Crafted
    placed things go back into the inventory whole; no salvaging. Default: keep.

22. **First NPC** (task 84): `spawn npc`, a randomised look from layers like the player's,
    North Frisian / Low German names, stays within about 6 tiles of the nearest building or
    campfire, stands still at night; saved with its chat history (last 200 lines); the
    chat pauses the game; lines as `[08:15] <You> hello`. Default: keep.

23. **Test LLM** (task 85): Ollama in a container with Qwen2.5 3B Instruct (about 2 GB) on
    the CPU; `make llm-up`, `make llm-down`, `make llm-check`. Its licence is the Qwen
    Research License (non-commercial), not Apache-2.0 as first written: fine for local
    tests, never to ship. Apache-2.0 alternatives: qwen2.5 1.5B or 7B. Default: keep 3B for
    testing. **Decided 2026-11-07 (task 94):** the 7B (Apache-2.0) is the default; with the
    refined prompts the 3B was not about as good.

24. **Coast** (task 61): the coast in the west, about 260 tiles out, the river running into
    it; a sea dyke without gaps; mud walkable at any tide, one look in every season; the tide
    a look only (high water every 12 h 25 min); salt marsh red-purple in autumn; Warften on
    the salt marsh (buildable, not tillable, uninhabited); Ewers smaller than life (atlas
    limit). Not yet: ice on the mud, mussel beds, seals, sluices, Halligen. Default: keep.

## Questions

25. Relationships: moved to [#48](https://github.com/gentoomaniac/sandbox-game/issues/48).
26. Economy and currency: moved to [#49](https://github.com/gentoomaniac/sandbox-game/issues/49).
