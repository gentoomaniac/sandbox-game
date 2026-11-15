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
| `reward` | `items` (item to count) and `opinion_steps` (1 or 2), at least one |

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

## When quests are posted

- **At the start of each day** (`GameClock.new_day`, so a long skip too, a day at a time):
  `Quests.post_today()` lets the quests whose days are up go away, then posts one. Nothing runs at
  night. The pick is **random but seeded by the world and the day**, so a reload or a skip gives the
  same quests.
- **At most `max_open` open at once, `per_day` a day.** Open counts the posted and the taken ones.
  One giver has one quest open at a time, and a quest id is not posted again for
  `repeat_after_days` after it was done or went away.
- **How a quest is picked:** the quests whose prerequisites hold now with a giver who may give it:
  the villager its file names or, with `giver="any"`, any villager of the world. Neither one who is
  cold to the player (`cold_below` of `data/gossip.cfg`) nor one who has a quest gives one. A quest
  is picked at random of those, then its giver.
- **How long:** `days` from the day it was posted, taken or not: the last day it stays is the posting
  day plus `days` less one, and on the morning after it is gone. Nothing else happens: no opinion is
  lost.
- **The first day:** a new game with a village posts at once a random quest marked `starter`, with
  a random giver. A world with no village has none.

The state is `Quests` (`game/state/quests/quests.gd`, `GameState.quests`), with the signal `noticed`
(a line for the player); the console's `quest` is its test tool (handbook console page).

## Taking a quest

E on the giver **while the quest is posted** opens the chat, and the giver says the `dialogue` lines
of the quest as lines of the chat (`QuestTalk`); the quest is then **taken**, which is when it is in
the player's list. A quest taken is recalled with its first line when the player speaks to them
again. Taking one with the quest log full (`quest_log_size`) is refused with the notice "Your quest
log is full." in the chat, and the quest stays posted. A giver not at hand just waits: E works
wherever the player meets them. A quest need not be taken before its days are up: it goes away as
it is.

**Notices:** when a quest is posted the player is told "Antje Boysen has something for you." (the
notice board of a later step changes that line), and when one goes away, taken or not, "Antje Boysen
no longer needs the fibre."

## Handing in

**E on the giver with the item in hand** (the selected hotbar slot) for a `bring` quest: when the
player has at least the count, the whole count leaves the bag and no more. Holding the item with
too little says the `short` line (a default says it when the file has none), and holding something
else gives the first line of the `dialogue` as a reminder; nothing is taken then. Done, the giver
says the `turn_in` lines, the reward is the player's (what does not fit the bag falls at their
feet) and the quest is marked done with its day: it is no longer open, and `quest_done`
prerequisites and `repeat_after_days` count from it. The objective kinds do the checking
(`progress`, `goal`, `is_offered`, `hand_over`), so a new kind decides what handing in is.

**Rewards** are items that exist, mostly what the shop of #10 does not sell, so a quest is not a
second barter: seeds on the first help only, **wax** (candle makings: its first source apart from
the console), and a better tool grade for a big quest. The opinion reward is the deed `helped`
(below). No recipes as rewards in this task (the user, 2026-11-15; later, once recipes are
learned).

## The opinion reward: the deed `helped`

`reward.opinion_steps` is 1 or 2 (most a deed is worth). Handing in the quest tells the deed `helped`
(a step: +1, 10 points) or `helped_much` (two: +2) to the giver and to the villagers outdoors within
the witness radius of `data/gossip.cfg` (20 tiles by day) of where the player stood, so the village
hears of it and the judge words it. With no model the deed's fixed change counts; with one the
verdict may differ, within the day's cap of 20 points. A reward with no `opinion_steps` tells no
deed. Nothing in the quests moves an opinion directly.
