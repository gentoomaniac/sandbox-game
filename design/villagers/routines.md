# Homes, workplaces, routines and finding the way

Decided 2026-11-14 (the user): tasks 228, 237, 238, 239, 229 and 240 in
[TASKS.md](../../TASKS.md). Built so far: homes and workplaces (task 228). Today a villager keeps near an anchor (the yard of the nearest
building or fireplace, [villagers.md](villagers.md)) and walks about it at random.

- **Places of their own:** each villager has a home (a building) and a workplace (a building,
  or a named spot where there is none, such as a landing or a field). The hand-written sheets
  name them; the player can give a made-up villager a home and a workplace (task 228, built:
  see [villagers.md](villagers.md), `Npc.house`, `Npc.workplace`, `Households`).
- **Interiors:** a building type has one default interior. A building can carry its own
  interior instead, so a villager's house is their very own inside while the outside stays the
  type's standard look (task 237).
- **Routines are generic:** a routine says what happens when, such as "work from 7 to 15, home
  at 15, sleep at 22", with a Sunday plan and changes for rain and the dark. The villager's own
  home and workplace fill in where that is, so many villagers share a few routines (task 239).
- **Finding the way:** villagers walk to their places by a path search that keeps to lanes and
  goes round fences and through gates and doors, within a set cost per frame so the game doesn't
  stutter. Far from the player, a villager is simply where its routine says (task 238).
- **Inside:** the routine says when they go in, and they are seen in the interior (task 229).
- **Next step, the shopkeeper:** a villager with the shopkeeper routine stands in their shop in
  the shop hours and offers a trading dialog (barter, no money yet); the shop sells seeds, so the
  farm can always start again (tasks 240 and 235).

Task 238's plan (the path search, its limits, chunks and doors) and task 239's plan (the
routine format and the routines themselves) are written here, for the user's approval before
code.
