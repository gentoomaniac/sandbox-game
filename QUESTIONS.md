# Open questions

Questions for the user that came up while they were away. Each has the default that work
went ahead with, so nothing is blocked; answer or change any of them when you are back.
Answered questions move into SPEC.md and are removed here.

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
5. **After passing out the player wakes standing by the bed**, not lying in it (task 46).
   Default: keep.
6. **Shift+click from a chest fills the backpack before the hotbar** (task 50). Default: keep.
7. **Art style changes** (2026-11-06, "implement them, quick ones first, then the longer
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
8. **The thatch redraw** (task 55): the roofs are now steep hipped planes with the reed laid in
   ragged courses instead of the soft streaky dome; the Kate and longhouse got crossed ridge
   sticks; snow covers the roof evenly. A first pass looked like shingles and was redone.
   Compare: docs/screenshots/buildings.png. Each piece is its own commit (courses and planes,
   ridge sticks, door swells, snow), so any one can be reverted. Default: keep.
9. **Hedges, walls, fences, dykes and ditches** (task 54): Knicks, stone walls, wattle
   fences and ditches block walking, with one gap per stretch as gate or crossing; dykes can
   be walked on. The axe cuts a Knick (1 log, 2 fibre) or a fence (2 fibre), the pickaxe takes
   a wall apart (3 stone); dykes and ditches can't be removed yet. Nothing can be built or
   tilled on them. **Old worlds get them too**, away from the farm: the save upgrade keeps 3
   tiles around buildings and placed things and 2 around the tilled fields clear, so your
   farm is untouched, but natural trees and rocks that stood on the new lines elsewhere are
   gone. New land takes about 6.5 ms per chunk to generate (was 3.7). Default: keep.
10. **Tree species** (task 56): the oak stays common beside beech, birch and alder. Wet ground
    (the marsh, and the Geest within 5 tiles of wetland) grows mostly alder; the dry Geest
    mostly beech, then oak and birch; pine and spruce only in clumps on the Geest. Woods are now
    about 28 % beech, 24 % oak, 19 % birch, 16 % alder, 7 % pine and spruce, 4 % willow. Beech is
    the toughest (5 hits, 3 logs), birch the weakest (3 hits, 2 logs). Seeds: beechnut, birch
    catkin, alder cone and willow cutting, each a 25 % drop. Trees in your world stay where they
    are, but the ones you haven't touched may turn into another species. Default: keep.
11. **Code review** (docs/code-review-2026-11-06.md): its findings became tasks 63-71 and run
    one at a time beside the art tasks. Default: go ahead.

## Questions

No open questions right now.
