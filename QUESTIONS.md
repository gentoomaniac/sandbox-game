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
8. **Art style changes** (2026-11-06, "implement them, quick ones first, then the longer
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
9. **Code review** (docs/code-review-2026-11-06.md): its findings became tasks 63-71 and run
   one at a time beside the art tasks. Default: go ahead.

## Questions

1. **The push key** `.deploy-key/` sits in the working tree (gitignored, so safe). The code
   review suggests keeping it under `~/.ssh` instead. Default: left where it is; moving it
   is your call, as it is your machine's setup.
