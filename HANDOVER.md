# Handover, 2026-11-14

For the agent that picks this project up on another machine. The previous session worked
on the laptop. Its memory files and some untracked files stay there. This page carries what
you need from them. Read it once, then delete it from the repo in its own commit, or keep it
current if you hand over again.

## Where things stand

- `main` is at the commit that added this file. Everything is pushed. No branch, worktree or
  agent has work in flight.
- The last full `make test` on main passed: 3399 tests, 8 warnings (the usual ones). Five
  merges have gone in since then, so a full run is due early. Run it once before your first
  merge.
- Done in the last session (details in [docs/tasks-done.md](docs/tasks-done.md)):
  - Gossip, tasks 125 to 130: the deed log, villager memory, rumours that spread and change
    on the way, the judge and each villager's opinion, newcomers learning the village, and
    speech bubbles.
  - Music playing in the game, task 170.
  - Crows, task 225, and the scarecrow, task 226.
  - The thunder bolt, task 222. Task 212 was closed without a change.
  - Two stutter fixes:
    - Gossip meetings compared every pair of villagers each game minute; they now use a grid.
    - The flower snow check worked out the snow shelter even when no snow lay anywhere; it
      now skips that.
  - Speech bubbles got round corners and their text lost its shadow. The console log wraps
    long lines.
  - The README became a short page. The player text moved to [handbook/](handbook/README.md)
    and was rewritten as short, scannable pages. Developer material is in
    [docs/development.md](docs/development.md).
  - The Android port is planned in [design/tech/android.md](design/tech/android.md), written
    by OpenAI GPT 6.1 Sol. Nothing is built.

## What to do next

**The queue is on hold until Sunday 2026-11-16, 06:00 CET**, unless the user says go
earlier. After that, work [TASKS.md](TASKS.md) in order, without asking, unless there are
questions:

1. **227:** swing poses for the tools. Art first; the user judges the crops before the code
   uses them.
2. **228:** a home for each villager, and a way to give one a house.
3. **229:** villagers go inside. Needs 228.
4. **171:** the music director.
5. **224:** a fuller version of each piece of music for the 32 px art.
6. **230:** keep the 10 newest saves, oldest out first, and add a load dialog. Quick load
   (F8) always loads the newest save, with no dialog.

Questions still open with the user (no task yet):

- Should speech bubbles that are cut off at the left or right edge be fixed? The in-view check
  only looks at the top of the bubble.
- The flower snow check is still slow while snow lies: about 0.7 ms per flower in view, every
  second. Should that become a task, for example reading the snow per chunk that ground cover
  already computes?
- The Android plan has 10 open questions, each with a recommended default.
- [QUESTIONS.md](QUESTIONS.md) items 25 and 26 (relationships, economy) wait for the user.

## How the user wants the work done

These were the previous session's memory notes. They live only on the laptop.

### Delegating and agents

- Workers are `my-developer` and reviewers `my-reviewer` (both Sonnet); use Haiku for small or
  mechanical reviews. Specialists live in `.claude/agents/`: `pixel-artist` (Opus),
  `sound-designer` (Sonnet), `music-composer` (Opus). Never use Fable. Tell the user which
  model each agent runs on.
- Small fixes: do them yourself, then have a reviewer check them. Bigger tasks: give a worker a
  full brief, and have a reviewer check its work.
- For a second opinion from another model family, run
  `opencode run -m 'openai/gpt-6.1-sol#high' "<brief>" </dev/null` from the worktree. Always
  close stdin with `</dev/null`.
- Every brief says:
  - Work only in your worktree. Prefix every command with `cd <worktree> &&`. Never check out,
    commit or edit in the main checkout.
  - Prefix every make, test or game run with `taskset -c 0-10 nice -n 19` (half the cores; the
    user needs the rest).
  - Run tests in the foreground. No `pgrep` or `sleep` wait loops of any kind.
  - Never touch the user's real save. Run tests only through the make targets, or with an
    absolute `XDG_DATA_HOME` inside the worktree; a relative one falls back to the real user
    folder. A copy of the save is allowed for measuring.
  - Game windows use `--with-working-window-title`. Screenshots of the classic art use
    `--classic-art`; `--switch-art` does nothing headless. Runs are muted unless they test
    sound.
  - A fresh worktree lacks the gitignored `addons/` and `.venv`. Copy `addons/`, and make
    `.venv` a real directory of symlinks into the main checkout's `.venv` with its own
    `.gitignore` containing `*`. A single symlink counts as untracked and makes
    `make test-changed` run everything.
  - Update the handbook page, and the pictures if the look changed. Touch the README only if
    its short feature list or one of its six pictures changes.
- The user's model settings (Gemini) may be read for a manual check, never printed or
  committed.
- After every task, check `ps` for leftover godot, make or test processes. `kill` is blocked
  for agents, so give the user the command.

### Commits and merging

- Commits are atomic: one change with its code, tests, generated files and doc lines. Each
  passes on its own and can be reverted alone. Never squash them together.
  - Fix an unmerged commit with fixup + autosquash.
  - Never rewrite a merged commit.
  - Pure refactors go first, in commits of their own.
  - Tests go in the commit of the code they test.
- Trunk flow: review each branch, then merge it yourself with `git merge --ff-only` onto
  `main`, and push right after every merge.
- Merge check: run `make test-changed BASE=main` and `make lint` on the branch tip, rebased
  onto main. A worker's green full `make test` on a branch already rebased onto main counts too.
- Run a full `make test` on main every 5 merges. If it fails, bisect over the merges since the
  last green run.
- Never delete the `.godot` import cache in the main checkout.
- Commit attribution line: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Use
  your own model name.
- After each merge:
  - Add a line to the untracked `TO-TEST.md` in the main checkout: what to try by hand,
    starting with the task number. Never commit that file.
  - Move the finished task with its full text and a "Done:" note to `docs/tasks-done.md`.

### Code and data

- Game state classes hold no rendering code. Tuning numbers go into `data/`. Pick them yourself
  and don't ask the user to confirm them.
- No lint suppressions. Split a file before gdlint's 1000-line or public-method limits.
- Save upgrades are kept for the last 10 versions.
  - A version bump comes with its upgrade step, SaveValidator checks and tests.
  - Dropping the oldest upgrade is its own commit, titled "Save: drop the upgrade from version
    N". The save is at version 38 now, and the oldest version it reads is 28.
- The first Godot start or import sometimes segfaults; a second try works. Retry once.

### Talking with the user

- The user often reads on the phone. Send the pictures, crops and listening files you mention
  with SendUserFile, one per file with a caption, and give their absolute paths too.
- Art, sound and music need the user's verdict before they are merged.
- New tasks need the user's yes and go to the end of TASKS.md unless the user names a place.
  The existing queue runs in order without asking.
- When the user is away, don't block: take the sensible default and write the question and the
  default into QUESTIONS.md (committed).
- The design tree (`design/`) and TASKS.md are living docs. Update and commit them with every
  decision.
- `/good-morning` (in `.claude/skills/`) summarises what happened since the user's last
  message and sends the files.

## Untracked files from the laptop

`TO-TEST.md` is not in git. These are its 93 unticked lines from 2026-11-14, so the user can test
on this machine. Copy them into a fresh untracked `TO-TEST.md` here and keep adding to that.

<details>
<summary>The open TO-TEST lines</summary>

- [ ] 181: No villager, farm animal or pet stands in a doorway any more.
- [ ] 183: In autumn the sky flocks (the V) fly north to south, in spring south to north, in summer any way.
- [ ] 183: No sky flocks in winter; more of them in the middle two weeks of autumn and spring.
- [ ] 183: Skeins of geese also fly south in autumn and north in spring; in winter any way; none in summer.
- [ ] 183: Numbers in data/wildlife.cfg [flock] (`migration_spread_degrees`, `migration_days`, `migration_boost`, `fade_days`).
- [ ] 186: Walk across light snow: where snow is drawn under your feet you hear the crunch, on bare spots the grass step.
- [ ] 188: Energy and health bars sit in the top right corner at your window size and UI scale; F3 readout below them.
- [ ] 190: A satchel button sits right of the hotbar; clicking it or pressing B opens the bag, right of the screen centre. B or the button closes it.
- [ ] 190: Tab does nothing now.
- [ ] 190: B no longer picks the hammer; select the hammer in the hotbar and use it to build. After Escape or a right click, a hotbar key or the mouse wheel resumes building.
- [ ] 191: C opens the character window (figure, equipment, trash can, Skills tab); Escape or C closes it. K opens it on Skills.
- [ ] 191: Shift+C opens crafting; Shift+C over the character window does nothing.
- [ ] 191: The bag (B) has only the backpack, weight and trash can; right click in the bag wears clothes; dragging from the hotbar onto an equipment slot works too.
- [ ] 191: The Controls page shows "Shift+C" for crafting and "C" for the character window.
- [ ] 187: The character window (C) lists Strength, Agility, Stamina, HP at 10 and Max energy 100, Max health 100, Carry capacity 40 kg; the bag reads "Carrying x / 40 kg".
- [ ] 187: `attribute stamina 20` in the console: the energy bar's maximum doubles, and a night's sleep fills it.
- [ ] 187: `attribute strength 20`: carrying up to 80 kg no longer makes tool use costlier.
- [ ] 187: An old save loads with all attributes at 10.
- [ ] 187: Numbers in data/attributes.cfg.
- [ ] 194: `weather cloudy` at midday: soft shadows drift over the ground in the wind's direction; faster with more wind.
- [ ] 194: `weather overcast`: no moving shadows, just a slightly darker scene; `weather clear`: none.
- [ ] 194: They fade at dusk, none at night or indoors.
- [ ] 194: Numbers in data/lighting.cfg [cloud_shadows] (strength 0.28 is gentle).
- [ ] 196: Every window has a × in its top right corner; it does what Escape does (the pause menu's settings page goes back first, a yes/no question answers no).
- [ ] 196: A left click on the dimmed area outside a window does the same; clicks on the hotbar, between its slots and on the bag button don't close the bag.
- [ ] 196: Dropping a dragged stack outside the bag still drops it on the ground and keeps the bag open; dragging a window and letting go outside doesn't close it.
- [ ] 195: At high water (`--time=12:25` on day 1) you can't walk from dry ground onto the flooded mud; at low water (18:37) you can walk out on it.
- [ ] 195: Stand far out on the mud as the tide comes in: you can still walk back to land.
- [ ] 195: Villagers and animals don't walk into the water; oystercatchers and dunlins still wade at the edge.
- [ ] 195: Dropping an item on flooded mud is refused.
- [ ] 176: `weather` at 5 m/s: only a soft rustle when the grass bends; no loud gust while nothing moves.
- [ ] 176: In a storm the gusts are loud and come as the grass and trees bend near you; indoors they're faint.
- [ ] 176: Numbers in data/ambience.cfg (`gust_front_from`, `gust_soft_level`, `gust_swell`).
- [ ] 199: Open the kiln: the Bricks recipe on the side with -/+/Max, a 3x3 grid, a fire button; items that can't go in are greyed in your bag.
- [ ] 199: Click Bricks (or drag raw bricks and logs in): the button only lights up for whole loads; press it: a progress bar, the grid locked; after 12 game hours the bricks are in the grid.
- [ ] 199: Nothing new goes in until every brick is taken out; a full bag leaves the rest in the kiln.
- [ ] 199: The oven: putting berries in greys out bread; bread takes an hour and a log per load.
- [ ] 199: Masonry 50 / 70 (`skill masonry 70`): extra bricks from a run.
- [ ] 199: An old save with a firing kiln: the bricks come out at the same time as before.
- [ ] 199: Numbers in data/recipes.cfg (bonus, hours, logs) and data/stations.cfg.
- [ ] 201: No wild animal stands in a doorway or on a building any more (mice neither).
- [ ] 201: Rabbits and deer run from a villager walking up to them; mice don't mind villagers and come close to houses.
- [ ] 201: Wild animals no longer appear right next to houses or villagers. Distances in data/wildlife.cfg (`building_tiles`).
- [ ] 202: In spring and summer by the wet meadows a stork comes only now and then, at most one at a time; after one flies off, none for a couple of hours. Roof storks are rare.
- [ ] 202: Numbers in data/wildlife.cfg [stork] / [roof_stork] (`cap`, `spawn_chance`, `return_gap_minutes`).
- [ ] 203: At the workbench (woodworking 5): Wattle fence, 1 log + 4 fibre for 2 pieces. By hand (masonry 5): Stone wall, 3 stone for 1.
- [ ] 203: Place pieces next to a generated fence or wall: they join up, the ghost shows where, you can't walk through.
- [ ] 203: The axe takes a fence piece down for 2 fibre, the pickaxe a wall piece for 3 stone; the hammer's take-down (X) works on them too, generated ones included.
- [ ] 203: Numbers in data/recipes.cfg.
- [ ] 210: `nolate` in the console: "No late" on the cheat HUD; stay up past 01:00 with no zzz warning and no passing out. `nolate` again: 01:00 sends you to bed as before.
- [ ] 216: Esc → Game settings: "Frame rate limit 60" slider. Check the CPU is calmer at 60; slide down (e.g. 10, the game gets choppy but runs at the same speed) and to the last stop "Frame rate: no limit" (back to the screen's rate). Quit and restart: the choice is kept.
- [ ] 217: F3: the last line shows the frames per second (60 by default); move the Game settings frame rate slider and watch it follow.
- [ ] 218: The Windows binary (sandbox-game.exe from the release zip) on a Windows machine: never tried.
- [ ] 185: In autumn and winter the grass is a darker green, not yellow or grey (still in the old patches until the overlay step lands); the dry heath grass has a little straw in autumn.
- [ ] 185 step 4: The ground changes evenly through the seasons; fallen leaves build up in autumn, frost on cold mornings, snow lies and thaws as an overlay (not in tile patches). Dykes, hedges, trees and houses still use the old looks until the next steps.
- [ ] 185 step 4: New start options --frost=0..1 and --melt=0..1 next to --snow.
- [ ] 185 step 5: Trees, bushes, stones, fences, dykes and hedges get snow from the top down and frost as an overlay; no white specks on trees in summer.
- [ ] 185 step 6: Snow on house roofs builds from the ridge to the eaves and thaws evenly (Kate, longhouse, hall house; lit at night; the see-through fade near a snowy roof), both arts.
- [ ] 185 step 7: The build ghost of a house shows its summer picture in every season (no snowy ghost).
- [ ] 185 step 8: Trees, bushes and roofs carry clearly more snow; snow edges on the ground look finer; walking past tilled fields is smooth again (no stutter).
- [ ] 204: The rooster crow sounds (3 variants) are fine in the game, not too loud or too often.
- [ ] 204: Each chicken flock (chickens within 12 tiles, or of one coop) has exactly one rooster; he lays no eggs; `spawn rooster` and `killall rooster` work; an old save gets one rooster per flock.
- [ ] 204: The rooster crows a run around sunrise and now and then by day, never at night or in the coop; heard across the farm, faint indoors.
- [ ] 207: Your tools are now "Rusty iron …" (old save upgraded); `give iron_axe`, `give sharp_steel_hoe` etc. give the other grades; they look like the approved 206 designs in hand and in the bag, both arts.
- [ ] 207: Better grades take fewer hits and a little less energy; an iron axe or pick fells pines and breaks boulders the rusty ones cannot. Numbers in data/tools.cfg.
- [ ] 207: Tools in the bag, hotbar and chests show the grade numeral I-V bottom left, crisp at every UI scale, in both arts.
- [ ] 208: The shovel digs up a berry bush, shrub or fern (3 hits rusty, 2 iron); it goes to the bag; holding it shows a ghost; it plants on free outdoor grass only (not water, soil, paths, buildings, before a door); a replanted berry bush bears again after 3 days. Try planting on tall grass, and save/load mid-dig.
- [ ] 209: Animals at a fence (horse, cow, dog...) no longer spin left and right; they give up and turn away after ~2 s; a following dog that cannot reach you waits facing you. Try a trough just beyond a fence corner, and a horse along a fence.
- [ ] 211: Sleeping farm animals and pets show a few rising "z"s over their head now and then (every 6-20 s for 3-5 s), gone when they wake or are petted; both arts.
- [ ] 213: With the pause menu (or a chat / choice dialog) open, all game sounds fade out in about 0.3 s, music and menu clicks keep playing; closing brings rain, fire loops etc. back at the right level, no click.
- [ ] 213: In the audio settings (pause menu), dragging the Effects, Ambience or Master slider plays a click at the new level, at most every 0.15 s, the last one at the final level.
- [ ] 214: In a thunderstorm (--weather=thunder) most flashes are a faint sky glow with a quiet dull rumble long after; some a middle roll; rarely a bright close flash with a crack almost at once. Indoors muffled. Check the far end (about -40 dB) is still audible, and the three sound kinds by ear.
- [ ] 204: The 32 px rooster stands a head taller than his hens, upright, arched sickle tail; his sleeping z s rise from his own head.
- [ ] 215: B and C open the bag (bottom right) and the character window (middle) together; you keep walking, using tools and switching hotbar slots; drag gear from the bag onto the figure and back; Escape closes both; at UI scale 1.75/2.0 the second closes the first. With the hammer in take-down mode, holding the mouse on the bag never takes a building down.
- [ ] 219: Cloud shadows (cloudy weather by day) are soft on this laptop, no blocky rectangles; rain, water, mud, fire and lily pads look as before.
- [ ] 221: Rain comes in spells of hours with dry hours between (try skip 1h a few times in rain); autumn the wettest, spring the driest. Winter has noticeably fewer snowy hours than before (snow on most winter days still). `make weather-probe` prints a year per seed.
- [ ] 220: Migrating flocks (spring north, autumn south) show the birds from behind or the front with spread wings; side view when crossing the screen; wings of neighbours do not overlap.
- [ ] 223: Geese and sparrows taking off from the ground up or down the screen are seen from behind or the front; oystercatchers, dunlin, gulls and storks stay side on.
- [ ] 125 Deed log: fell a few trees and till near a villager, then type `deeds` in the console (who saw it, where); talk to that villager and check the "Today you saw the newcomer..." line reads well; at night only villagers within 6 tiles see you; load an old (version 33) save.
- [ ] 222 Bolt: in a thunderstorm (`weather thunder`) watch a close strike draw a forking bolt in the sky for a few frames and a middle one a faint bolt; check both arts and a few zoom levels.
- [ ] 126 Villager memory: the language model page has "Stories a villager keeps" and "Memories a villager keeps" next to "Lines a villager keeps" (layout ok?); fell trees by a villager's house, then `gossip <name>` shows a high story; chat until a summary is made (a medium memory); `/clear` in chat empties stories and memories; load a version-34 save.
- [ ] 127 Rumours: fell trees by a villager, `skip` a few hours, then `gossip <other villager>` shows the story as heard ("<teller> told you ..."), sometimes changed (more trees, another house, another deed); load a version-35 save.
- [ ] 128 Judge: with a model set, fell trees by a villager, then `gossip <name>` shows the story in their own words and `opinion <name>` has dropped; chat and see if they sound colder; set `opinion <name> 50` and chat again (warm); stop the model and check no error toast appears for judging (only for chat replies); load a version-36 save.
- [ ] 129 Newcomers: `spawn npc` near a local, `gossip <new one>` says it knows no topic; `skip` a few hours with them near each other and it learns topics; chat with a newcomer to check replies stay sensible without village knowledge; load a version-37 save.
- [ ] 130 Bubbles: stand among villagers for a few minutes: about one line a minute over a head, readable at every zoom, never cut off at the screen edge; with and without a model; near a villager after felling trees the line is about you; no bubble indoors or while chatting.
- [ ] 170 Music: start the game; Tide plays after about a second, Harbour evening crossfades in after 3 loops (~96 s) on the beat, then back; no clicks at the loop seams; music keeps playing in the pause menu; the Music slider works; a second start begins at once (cache); `play test_reel` and `stop` in the console; quit while music plays.
- [ ] 225 Crow raids (state, nothing drawn yet): sow seeds, `spawn crows`, walk more than 12 tiles away or `crows raid`, then `crops`/`crop` shows "eaten by crows" and the harvest is one smaller (never below 1); `crows` lists the flocks and the day's tally.
- [ ] 225 Crows in view: in autumn sow a field, crow flocks come and peck, caw now and then (volume ok?), rise together with the flock call when you approach; `spawn crows` / `killall crows`; both arts.
- [ ] 226 Scarecrow: craft it by hand (Shift+C), put it next to a field, crows no longer settle within 5 tiles; `crows` shows its strength; in wind it sways smoothly (also as the wind changes), still when calm; take it down with the hammer or axe; save and load keep it; both arts.
- [ ] Gossip fix (e7ce1f64): walk about a village for a minute: no stutter every 1-2 s; sleep through a night: no hitch; FPS back near 60 (if not, something on the GPU side, tell me).
- [ ] Flower snow check fix: stand in a meadow with flowers in summer: no hitch every second; FPS back near 60. In winter with snow lying, check whether a hitch comes back (the snow check is still costly there).
- [ ] Console wrap: `help` and `gossip <name>` lines wrap at the panel edge instead of being cut off; scrolling still works. Speech bubbles: round corners, crisp text.
- [ ] README/handbook: read README.md on GitHub (pictures load, links work), click through handbook/ pages; `--free-build` debug flag makes the build ghost green.

</details>

The laptop also has a leftover worktree, `.claude/worktrees/agent-abe0e6a95b86f3fa5`, that the
agent could not remove. It concerns only that machine.
