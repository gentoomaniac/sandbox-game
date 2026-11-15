# Quests: small goals from the villagers

**Decided (the user, 2026-11-15); built step by step** (#12; needs #11 seeds, #7 routines, #9 gossip;
it fits the shop of #10). This page says what is built; each step adds its section.

Why: the first days have nothing to work towards before the first turnips are ripe (nine good
days), and production needs a reason. A quest is a reason that fits the village: a neighbour is
short of something, a notice says so roughly, the neighbour says it properly, and is glad of it
later. No quest chain (a quest may need an earlier one done, that is all), no fail: one that is not
taken or not finished in time goes away and nothing is lost.

## What a quest is

A villager wants one small thing. The **objective** is of a kind: `bring` an item, a count ("five
fibre for the bean rows"). More kinds are one new file each, see below. A quest has a **time limit
in days**, **prerequisites**, **dialogue** (what the giver says to give it, and to take it in), a
**reward** and a **giver**: a named villager or, by default, any villager, picked at random when
the quest is posted.

## The data: `data/quests/`

Every `*.cfg` in `data/quests/` but `_limits.cfg` is a quest, and its id is the file name. They are
found by scanning the folder (like the console's commands in `game/state/console/commands/`), so a
new quest is a new file and no code. `QuestRules` reads them once when the game starts and
reports what is wrong, by file (`problems`, also pushed as errors); the test `test_quest_rules.gd`
holds the folder clean. The header of `data/quests/fibre_for_beans.cfg` lists every key.

| Key | Rule |
|---|---|
| `giver` | a villager id of `data/villagers.cfg`, or `"any"` (default) |
| `days` | 1 to 60, from the day it is posted (default: `default_days` of `_limits.cfg`) |
| `starter` | true if it may be the quest of the first day; it may then require only `day` and `season` |
| `notice` | the rough line of the board, at most 100 characters; `{giver}` is filled in |
| `dialogue`, `turn_in` | one to six lines each: what the giver says to give it, and to take it in |
| `short` | optional: said when too little is brought; `{have}` and `{count}` |
| `objective` | `{"type": ..}` and what that kind needs |
| `requires` | optional list of prerequisites, all must hold for it to be posted |
| `reward` | `items` (item to count) and `opinion_steps` (1 to 3), at least one |

Items are those of `game/state/item_types.gd` (there is no `items.cfg`); a count is at least 1 and a
line may use only the braces named above.

### Limits: `data/quests/_limits.cfg`

- `[villagers]`: `max_open` (10) is the most villager quests there are at once, posted and taken
  together, `per_day` (1) the most posted in a day, `repeat_after_days` (20) how long after it was
  done or went away a quest is not posted again, and `default_days` (8). Another source of quests
  later gets a section of its own with its own `max_open`.
- `[log]`: `quest_log_size` (10) is the most quests the player has taken, from all sources
  together. Taking one with the log full is refused ("Your quest log is full").

### Objectives and prerequisites are open lists

Each **kind** is one small script in `game/state/quests/objectives/` or
`game/state/quests/conditions/` that extends `QuestObjective` or `QuestCondition` and is found by
scanning its folder (`QuestKinds`); a script that is no kind, or has no name or one that another
has, is reported. A kind says what its fields are (`problems`, so a quest file is checked), and later
what it does at play.

| Objective | Fields |
|---|---|
| `bring` | `item`, `count` |

| Prerequisite | Fields |
|---|---|
| `opinion` | `at_least` (points), optional `villager` (default: the giver) |
| `skill` | `skill` (`data/skills.cfg`), `at_least` |
| `season` | `seasons` |
| `day` | `at_least` and/or `at_most` |
| `quest_done` | `quest` |

To add a kind: a new file in the folder with a `kind()` and its `problems`, and a line in the table
above.
