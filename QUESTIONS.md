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
4. **The backpack is shown as 2×10** instead of 4×5 (task 50), so it lines up with the
   10-wide hotbar row below it. Default: keep.
5. **`skip` never makes the player pass out** at 01:00 (task 46), so `skip 1d` stays usable
   for testing crops. Default: keep.
6. **After passing out the player wakes standing by the bed**, not lying in it (task 46).
   Default: keep.
7. **Shift+click from a chest fills the backpack before the hotbar** (task 50). Default: keep.

## Questions

1. **Art style: which changes should be made?** The style guide is in
   [docs/art-style.md](docs/art-style.md); its last section ranks 8 quick wins and 10 bigger
   items. Nothing has been changed yet. Suggested first batch, all small: the sleeping bag
   as a straw bedroll, a new straw hat shape, autumn colours towards brown, ochre and
   copper (oak, beech, birch) instead of maple reds, small-paned windows, the palette swaps
   (lime wall and painted teal door on the Kate, so the magic colour `spirit` is free), seed
   sacks that can be told apart, a copper watering can. Default: wait for you.
2. **Tomatoes** are not a farm crop on this coast before the 19th century. Replace them
   (broad beans, flax or kale), or keep them as a rare imported seed? Default: keep for now.
3. **Tree species:** the guide says beech, birch, alder and pollard willow fit the region
   better than spruce and pine, which were mostly planted later. You asked for the Scots
   pine and to keep the spruce (task 51, in progress). Keep both as common trees, or make
   them rarer (planted clumps, Geest) and add beech, birch, alder, willow later? Default:
   task 51 as decided, no change to how common they are.
4. **The shack** reads like a frontier log cabin; the guide suggests tarred black or
   weathered silver boards with a turf roof (you said it needs no reeds, so not thatch).
   Default: wait for you.
5. **Period clothes for the player** (knee breeches, stockings, clogs, waistcoat, linen
   shirt) are the guide's top bigger item. Default: wait for you.
