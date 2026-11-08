# Professions

Task 74, decided by the user 2026-11-06: the first three crafts of
[ideas.md](ideas.md), the
woodworker, the cook and the mason, and a UI for them.

- **Skills grow both ways.** Each craft has a skill (woodworking, cooking, masonry; in
  `data/skills.cfg`), 0 to 100 points, shown as numbers. Crafting a recipe practises its
  skill: 2 points while the skill is at or below the recipe's level, falling evenly to
  nothing 40 points above it (no gain from trivial recipes). Points count in tenths. A
  recipe may need a level (`level` in `data/recipes.cfg`): below it the recipe is locked, and
  the menu shows it greyed with the level it needs. Recipes without a skill (by hand) teach
  nothing.
- **The total cap** (decided by the implementation, as the user's suggestion): all skills
  together have at most 200 points, so one can reach 100 with two at 50, or three can stand
  around 66. At 200 a skill only grows by taking the points from a skill the player marked
  **Fade** on the skills tab (from the first marked, in the order of the file, that has points
  left); with none marked the craft still works but teaches nothing, and the menu says to let
  a skill fade. A mark does nothing below the cap: nothing ever fades on its own. The console's
  `skill <skill> <points>` sets points (and ignores the total cap).
- **Stations are placed objects** (`data/stations.cfg`): the workbench (6 logs), the kiln
  (6 clay, 8 stone) and the bake oven (12 bricks, 2 clay, 4 stone) are made by hand and placed
  like a chest; the house hearth and the camp's fire are the hearth station, which everyone
  has. The kiln stands only outdoors (`outdoors_only`), the others also in a house; a stool
  only in a house. The axe takes down the workbench, the stool and the chests, the pickaxe
  the kiln and the oven (inside a house one swing, into the inventory). The house's own
  furniture can't be taken down; the stools of the maps can (a free stool, accepted).
- **E on a station** opens the crafting menu of its recipes, titled with its name, with the
  player's points in the skills they practise; E or Escape closes it. A note after a craft
  says what it taught. The tooltip of a recipe says what a craft teaches, or what it needs.
- **The kiln fires over time.** A recipe with `hours` puts its materials into the station,
  which holds that one work (the recipe and the game minute it is done, in the station's
  saved state) until it is taken out; the bricks take 12 game hours, so a firing started in
  the evening is done in the morning. Nothing runs while the player is away: the clock is
  compared with that minute. Opening the station's menu when the work is done takes the
  result into the inventory (or says there is no room, and it stays). While it fires, the
  menu says what and for how long, and the slow recipes are greyed. A kiln broken down gives
  back its unfired load, or the bricks once done. No new save field: the work is in the
  object's `state`, which is saved already.
- **The skills tab** is a second tab of the character screen (Tab opens the character, K the
  skills; the key of the shown tab closes it): a row per skill with a bar, the points and the
  Fade button, the total against 200, and the rule of the cap in a sentence.
- **Recipes** (levels in brackets):
  - Woodworking at the workbench: planks, 2 from a log (0); stool from 3 planks (10); a grave
    marker from 2 planks and 2 stone, only outdoors (15); clogs from a log (25); a carved
    chest, painted the Frisian way, 8 planks, 20 slots (45); the master's piece, a joined oak
    cupboard, 12 planks and 2 logs, 25 slots, only in a house (70).
  - Cooking at the hearth: roast turnip (0); pottage, 2 from cabbage, carrot and onion (10);
    pea soup, 2 from 4 peas and an onion (20). At the bake oven: bread from 2 flour (30), a
    berry tart from a flour and 6 berries (50), a feast cake from 2 flour, 4 strawberries and
    4 berries (70). Flour is ground by hand from 3 wheat, rye or buckwheat (a hand
    quern, not drawn): the simplest chain, as there was no flour. Cooked food restores more
    energy than its ingredients raw (roast turnip 12, pottage 15, pea soup 16, bread 30,
    tart 35, feast cake 60; in `data/energy.cfg`).
  - Masonry: raw bricks from clay at the workbench, 2 from 2 (0), 3 from 2 (25); bricks in the
    kiln, 6 raw bricks and 2 logs make 6 (0), 12 and 3 logs make 12 (50), a master's firing of
    18 and 3 logs makes 18 (70). Bricks build the bake oven, so bread needs the mason.
  - Each craft has a master recipe at 70, which teaches up to 109, so every skill can reach
    100 (a test keeps it so).
- **Saved:** the skills and the fade marks with the player (save version 14; older saves
  start with none).
- Not yet: quality, tool wear, recipe books, more professions, a look for a kiln that fires,
  more uses of bricks (houses, paths).
