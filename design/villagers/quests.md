# Quests: small goals from the villagers

**Decided (the user, 2026-11-15) and built** (#12; needs #11 seeds, #7 routines, #9 gossip;
it fits the shop of #10). This page says what is built.

Why: the first days have nothing to work towards before the first turnips are ripe (nine good
days), and production needs a reason. A quest is a reason that fits the village: a neighbour is
short of something, a notice says so roughly, the neighbour says it properly, and is glad of it
later. No quest chain (a quest may need an earlier one done, that is all), no fail: one that is not
taken or not finished in time goes away and nothing is lost.

## What a quest is

A villager wants one small thing. The **objective** is of a kind: `bring` an item, a count ("five
fibre for the bean rows") or `build` a placed object, a count, near the giver's home ("a wattle
fence by my garden, six pieces"). More kinds are one new file each, see below. A quest has a **time limit
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

Items are those of `game/state/items/` (there is no `items.cfg`); a count is at least 1 and a
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
scanning its folder (`KindFolder`); a script that is no kind, or has no name or one that another
has, is reported. A kind says what its fields are (`problems`, so a quest file is checked), and later
what it does at play.

| Objective | Fields | Done when |
|---|---|---|
| `bring` | `item`, `count` | the player holds the count of the item in hand and hands it in |
| `build` | `object`, `count`, `near` ("home"), `radius` | that many pieces **put down after the quest was posted** stand within `radius` tiles of the giver's home door |

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
  the villager its file names or, with `giver="any"`, any villager of the world. Neither one who
  gives the player no quests (the benefit `quests`, from level 3 of [relationships](relationships.md):
  Shunned and Mistrusted give none) nor one who has a quest gives one. A quest
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

**E on the giver** for a `build` quest counts the world: the pieces put down on or after the day the
quest was posted (the `placed_day` the game stamps on the objects quests ask for,
`QuestRules.placed_objects`), standing, within `radius` of the giver's home door (their anchor when
they have no house). A piece taken down does not count, and one that stood before the quest does
not, so an old fence is no cheat. Enough: done, nothing taken (the fence stays, the player's to
keep), the `turn_in` lines and the reward. Too few: the `short` line.

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

## Saving

A part `quests` of the game state (save version 52): `{"open": [{"id", "giver", "posted_day",
"is_taken"}], "done": {id: day}, "ended": {id: day}}`. `ended` is the last day a quest was done or
went away (for `repeat_after_days`), `done` the day each was done (for `quest_done`). The day a quest
goes away is worked out (`posted_day` plus the file's `days`), and the rules are data and not saved.
A quest whose id is no longer in the data is dropped on load. The validator checks the part, and a
save of version 51 loads with none. The pieces of a build quest are `placed_day` in the state of the
placed objects, saved with the world. See [../tech/saving.md](../tech/saving.md).

## The player's list

A third tab, **Quests**, in the character window (`CharacterScreen`, after Character and Skills; key
**J**), is `QuestsPanel`, drawn from `QuestRows`. It shows the **taken** quests, the oldest first:
who gave it (name and trade), what it asks ("5 fibre", "put up 6 wattle fence by the home"), how
far the player is ("you carry 3", "2 of 6"; the kinds say it), the days left ("6 days left", "last
day") and, as a tooltip, the reward. A posted quest that is not taken is not in it. It is read-only:
handing in is done at the villager. An empty list says "No open quests." The counts follow the bag
and the world while the tab is open (looked at again four times a second).

## The notice board

The village has a **notice board** on the town square ([../world/wehlsbuell.md](../world/wehlsbuell.md)),
and the player may put one up anywhere outdoors: it is an item with no recipe (`give notice_board`),
and the axe takes it down for the item again (it loses no quest; the board just has no "!" until it
stands again).

- **A new quest** puts a "!" (`QuestMarkView`: a small mark that bobs, over each board) while any
  posted quest is not yet taken, and tells the player "A new notice on the board in Wehlsbüll." (the
  village's name; "A new notice on the board." in a world with no village). With no board in the
  world the notice is "Gesche Hansen has something for you." instead: a world built before the board
  gets its quests as messages only, and no board is added to it later. A quest going away is told
  with or without a board.
- **E on the board** (`Interaction.Kind.READ_BOARD`; a villager in front of it comes first) opens its
  window (`NoticeBoardScreen`) with the rough line (`notice`) of each quest posted and not taken,
  the oldest first, and whom to see ("Fibre is wanted for the bean rows. Go and see Antje Boysen,
  a farmer's wife."), or "Nothing new on the board.". It gives no quest. A quest already taken is not
  on it.
- **E on that villager** gives the actual quest (see Taking a quest). The board is a way in, not a
  gate: a posted quest is given the same way whether the player read the board or not.

## Dialogue: with and without a model

- **Without a model**, or with the profile's "Quest lines" switch off: the `dialogue`, `turn_in` and
  `short` lines of the file, said in order as chat lines. It works with no endpoint, with the test
  endpoint down, and on an error.
- **With a model** and the switch on (#107): the villager says each in their own words, one line for
  each fixed line, the fixed lines as the fallback. The game decides everything and the model only
  voices it: see [dialogue.md](dialogue.md), "Quest lines". The board's rough lines are not voiced.

## The numbers, and the play-test

All in data: `data/quests/_limits.cfg` (10 open per source, 10 taken in all, one posted a day, a quest
rests 20 days after it was done or went away, 8 days by default) and each quest's file.

| Quest | Asks | Needs | Days | Reward |
|---|---|---|---|---|
| `fibre_for_beans` (starter) | 5 fibre | none | 8 | 10 turnip seeds, 1 step |
| `berries_for_the_pot` (starter) | 8 berries | not winter | 8 | 8 turnip seeds, 1 step |
| `stool_for_the_loom` | a stool | day 4 | 12 | 2 wax, 1 step |
| `turnips_for_the_pot` | 5 turnips | day 12 (the first turnips are ripe) | 10 | 2 wax, 2 steps |
| `wattle_for_the_garden` | 6 wattle fence by the home, radius 8 | day 10, not winter, opinion 0 | 10 | 2 wax, 2 steps |

In Schilling (#49), against the shop of #10 (buys at 60%, sells at 125% of a worth, rounded): 5
fibre are 5 Schilling to the stall and the 10 seeds of the first quest cost 30 there, a loan to
start the farm that the player does only once (the start purse of 32 buys the same); the starters
ask only for what lies about from the first hour. The other rewards are wax, which the shop does not
sell (two wax make about two candles, 20 Schilling each at the stall), for work that costs more
than that: a stool is 3 planks and skill 10, the fence 3 logs and 12 fibre. So no quest is a better
deal than the stall, and none pays coin (open question 3 of the economy plan: items and goodwill
only). `tests/test_quest_rewards.gd` keeps it so: a starter's reward costs at most the start purse,
the others pay nothing the stall sells.

`tests/test_quest_playthrough.gd` plays the first days in a new game with the village and the real
files: day 1 posts a starter that is read on the board, taken, handed in and paid with its deed told;
a quest comes each day within the limits and one nobody takes goes away; the fence quest is done by
putting fence up by Gesche's house.

