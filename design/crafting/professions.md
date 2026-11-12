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
  has, wherever it stands. The campfire (6 stone, 3 logs) and the bedroll (6 hay, 4 fibre: no
  wool or linen item exists yet) are made by hand too and placed like a chest, outdoors only
  (task 137). Where one is placed is the object's `placeable_in`: the kiln is OUTDOORS only, the
  stool and the cupboard INSIDE a house only, the others ANYWHERE. The axe takes down the
  workbench, the stool and the chests, the pickaxe the kiln and the oven (inside a house one
  swing, into the inventory). The house's own furniture can't be taken down; the stools of the
  maps can (a free stool, accepted).
- **E on a station** opens the crafting menu of its recipes, titled with its name, with the
  player's points in the skills they practise; E or Escape closes it. A note after a craft
  says what it taught. The tooltip of a recipe says what a craft teaches, or what it needs.
- **Process stations: the kiln and the bake oven** (task 199, decided by the user 2026-11-11).
  One reusable kind of station (ProcessStation), made one by its section in
  `data/stations.cfg` (`process`, `grid`, `button_icon`); a later forge, smokehouse, saw mill or
  fish pond is a config section and its recipes, no code. The kiln and the oven have a 3x3 grid
  and a fire on the button. There is no fuel concept: the logs are a material of the recipe.
  - **The window:** the recipes on the left, each with an amount of loads under it (a field, -
    and +, Max: no more than the player's materials, the grid and what is in it allow); the grid
    in the middle, the progress bar above it, the button below it; the bag on the right. Stacks
    move in and out by dragging and Shift+click, like a chest's. A recipe click moves what that
    many loads take, counting what the grid holds.
  - **Only what fits a recipe goes in** (ProcessLoad, one pure rule): the grid's contents must
    always be part of whole loads of a recipe the player may make, at an amount that fits the
    grid (materials and, at the highest bonus, the result). A recipe still possible is open; one
    the contents rule out is greyed, and so are the bag's stacks that can't go in. A drag or
    Shift+click moves only as many as keep a recipe open; taking out opens recipes again. The
    user's example (a wood and stone recipe beside a coal and stone one: coal first leaves only
    stone) is a test, with quantities.
  - **The run:** the button starts it when the grid is whole loads of a recipe (the first in
    the file, if it could be more than one; a part load greys the button and says what is
    missing). It takes the recipe's `hours`, whatever the amount (bricks 12, bread 1, a berry
    tart 1.5, a feast cake 3), on the game clock, also while the player is away: nothing ticks,
    whoever looks settles it. The grid is greyed and locked meanwhile. Then the materials are
    used up and the grid holds the result; as the grid only ever holds whole loads, nothing is
    left over (no ash, no burnt food). The player takes it out as from a chest, as much as
    fits; until all of it is out nothing goes in and nothing starts. A station broken down gives
    its grid: the unfired load, or the result once done. The kiln and the oven show no fire in
    the world while they run (they have no lit look yet).
  - **Skill:** levels stay recipe locks, and each run practises the recipe's skill once. The
    masonry of the old large and master firings is a bonus (`bonus` in `data/recipes.cfg`, a
    setting of any recipe): from masonry 50 a firing gives a quarter more bricks, from 70 half
    again, rounded down, and it practises the skill as a recipe of that level would, so masonry
    still reaches 100. The oven has no bonus yet.
  - **Saved:** the grid with the station (save version 31); a version 30 kiln that was firing
    keeps its load and its bricks to come. The workbench and the hearth keep the crafting
    menu.
- **The skills tab** is a second tab of the character screen (B opens the character, K the
  skills; the key of the shown tab closes it): a row per skill with a bar, the points and the
  Fade button, the total against 200, and the rule of the cap in a sentence.
- **Recipes** (levels in brackets):
  - Woodworking at the workbench: planks, 2 from a log (0); stool from 3 planks (10); a grave
    marker from 2 planks and 2 stone, only outdoors (15); clogs from a log (25); a carved
    chest, painted the Frisian way, 8 planks, 20 slots (45); the master's piece, a joined oak
    cupboard, 12 planks and 2 logs, 25 slots, only in a house (70).
  - Cooking at the hearth: roast turnip (0); pottage, 2 from cabbage, carrot and onion (10);
    buckwheat pancakes, 2 from 3 buckwheat (15, task 115); pea soup, 2 from 4 peas and an
    onion (20). At the bake oven, each load with a log: 2 loaves from 4
    flour in an hour (30), 2 berry tarts from 2 flour and 12 berries in an hour and a half (50),
    a feast cake from 2 flour, 4 strawberries and 4 berries in 3 hours (70). Flour is ground by hand from 3 wheat, rye or buckwheat (a hand
    quern, not drawn): the simplest chain, as there was no flour. It is one item; the menu
    tells the three recipes apart by a name of their own (`name` in data/recipes.cfg: "Rye
    flour"). Cooked food restores more
    energy than its ingredients raw (roast turnip 12, buckwheat pancakes 14, pottage 15, pea soup 16, bread 30,
    tart 35, feast cake 60; in `data/energy.cfg`).
  - Masonry: raw bricks from clay at the workbench, 2 from 2 (0), 3 from 2 (25); bricks in the
    kiln, 6 raw bricks and 2 logs make 6 in 12 hours, a quarter more at 50 and half again at
    70. Bricks build the bake oven, so bread needs the mason.
  - Each craft has a master recipe at 70, which teaches up to 109, so every skill can reach
    100 (a test keeps it so).
- **Saved:** the skills and the fade marks with the player (save version 14; older saves
  start with none).
- Not yet: quality, tool wear, recipe books, more professions, a look for a kiln that fires
  (and leftovers turned to ash or burnt food),
  more uses of bricks (houses, paths).
