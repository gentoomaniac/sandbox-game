

## 207. The tool grades as items, given with the console

- [x] Done

Done: 2026-11-13. The approved task-206 generator commits are merged; every tool comes in five
grades as items (`<grade>_<tool>`, "Rusty iron hoe" .. "Sharp steel hoe") from data/tools.cfg
(ToolGradeRules), only through the console `give`. New games and old saves (save version 33)
have the rusty iron tools, which play exactly as the old ones. The grades differ by level (what a
tool may hit: iron and up fell pines and break boulders), power (hit points per hit: 1, 2, 3, 3,
4) and energy share (100, 95, 95, 85, 75 %). No durability yet, so brittle steel does not chip.
SlotView draws the grade's Roman numeral bottom left from the approved 206 bitmaps; the icons
carry none. Known: `--switch-art` does nothing in headless screenshot runs (use `--classic-art`).

After task 206's designs are approved: the five grades of each tool (rusty iron, iron, brittle
steel, steel, sharp steel) as items in the game, named "Rusty iron hoe", "Iron hoe" and so on; the
current tools become the rusty iron ones (renamed; old saves keep working). For now they come only
through the console `give` (no recipes, no shops). How the grades differ in play (the tool `level`
of item_types.gd, hit points per hit, durability if any) is to be proposed in the brief with the
numbers in data/ (the user tunes them). Both arts from the approved generator code.
- Build on the approved designs of task 206: branch `tools-206-designs` (generator code only:
  tools/art/tool_grades.py, tool_icons.py, classic/tool_icons.py, character.py held tools,
  docs/art-style.md); rebase or cherry-pick it, regenerate the art (`make art`) and commit the
  generated files with it.
- The Roman numeral (I rusty iron .. V sharp steel) is drawn by the inventory UI, not baked into
  the art (the user, 2026-11-11): SlotView draws it bottom left of the slot (the count is bottom
  right, the badge top left), crisp in both arts at every scale; remove the numeral from the
  generated icons (the ground items stay clean).
