# Relationships

**Decided (the user, 2026-11-15, [#48](https://github.com/gentoomaniac/sandbox-game/issues/48));
the build is planned below; steps 1 to 13 are built and 14 is built with placeholder art.** When a step is done, its part moves to the
pages of [villagers](README.md) as "as built", as the pages of [gossip](gossip.md) and
[quests](quests.md) do.

**As built so far**

- Step 1: the ten levels are data (`data/friendship.cfg`, `[levels]`) and `FriendshipRules` says
  `level_of(points)`, `level_name`, `mood_of` and `first_point_of`.
- Step 2: the prompt, the bubbles and the console use the levels. `cold_below`, `warm_from` and
  `GossipRules.opinion_word` are gone; `NpcPrompt` tells the line `level_<n>` of `[prompt]` of
  `data/npc_talk.cfg` (`NpcTalkRules` checks all ten are there), the bubbles take the level's mood,
  quests are not posted by a villager of a cold mood (levels 1 and 2), and the console's
  `opinion` names the level.
- Step 3: the state. `Npc` has `last_gift_day`, `chat_counted_day`, `action_day` and
  `action_moved_today`, `rating_day` and `ratings_today`, and `bond` (`none`, the only word of
  `FriendshipRules.BONDS`). `Npc.change_friendship(points, today, friendship, bounds)` moves the
  opinion within the cap of the actions, `action_daily_cap_points` (60) of `[caps]` of
  `data/friendship.cfg`, which is counted apart from the stories' cap.
- Step 4: those fields are saved, version 53; `_upgrade_from_version_52` gives an old save the
  defaults (days 0, counts 0, `bond` none) and leaves the points as they are. `SaveValidator`
  checks days and counts are not negative, what the actions moved today is within the cap and the
  bond is known. Step 4b: the upgrade from version 42 is dropped (oldest read: 43).
- Step 5: gifts. `Gifts.give(state, villager)` gives the item in the player's hand: liked +40, neutral
  +10, disliked -20 (`[gifts]` of `data/friendship.cfg`, through `Npc.change_friendship`, so within the
  cap of the actions), once a day per villager (`Npc.last_gift_day`); the item leaves the inventory,
  a second gift of the day is refused and kept, and the villager answers with a line of `[gift]` of
  `data/npc_talk.cfg`. The taste is the sheet's `gifts_liked` and `gifts_disliked`
  (`data/villagers.cfg`, items of the game: Antje likes berry tart and eggs, Momme pottage and
  bread; butter and smoked eel come with the items) or, for a made-up villager, those of the set of
  activities of their trade (`[gifts]` of `data/npcs.cfg`, not saved). The deed `gave_gift` (change 0)
  is logged and told as gossip. In the chat window a **Give** button offers the held item. It is
  `Gifts`, not a method of `GameState`, which is near its size limit.
- Step 6: talking counts. The first line the player says to a villager on a day moves their opinion
  by `first_chat_points` (5) of `[talk]` of `data/friendship.cfg`, with no model, within the cap of the
  actions: `TalkFriendship.count_chat`, called by `NpcDialogue.say`. Later lines of the day count
  nothing (`Npc.chat_counted_day`).
- Step 7: rating the player's words. The use `word_rating` is in `LanguageModelProfiles.USES` (a
  Settings checkbox, saved in the profile, on by default). `WordRating`, a node of Main, asks
  quietly after an exchange when `has_model_for(&"word_rating")` and the villager has had fewer than
  `requests_per_day` (3) requests today; `NpcPrompt.word_rating_request` and
  `word_rating_from_answer` (`[word_rating]` of `data/npc_talk.cfg`; anything but `warm` and `rude`
  is neutral). Points: warm +5, rude -10, at most +5 up and -10 down a day from ratings
  (`[rating]` of `data/friendship.cfg`), then the cap of the actions: `TalkFriendship.apply_rating`.
  To count that daily total the villager has one more saved field, `rating_moved_today`, part of save
  version 53 from step 4 (the plan's table had none). See
  [dialogue.md](dialogue.md), "Rating the player's words".
- Step 8: harm. `Harm` (`GameState.harm`) listens to the finished actions and to the player's feet.
  **Stealing** (`stole`, -50): a harvest, a nest's eggs (`COLLECT`) or what is taken out of a chest
  (`ActionOutcome.TAKE_FROM_CHEST`, told by `StorageScreen` when it is closed). **Damage**
  (`damaged`, -20): cutting down or taking down a line across the land (a Knick, a fence, a wall).
  **Rudeness** (`rude`, -20): standing within `push_tiles` (0.4) of a villager outdoors, who
  otherwise keeps 0.8 from the player, once a day for each. The witnesses (`DeedLog.witnesses_at`,
  by night the smaller radius; indoors those inside that house) lose the points at once, within the
  cap of the actions, and the deed is told as gossip; nobody seeing it, nothing happens, the owner
  included. `Harm.owner_of(map, tile)`: a thing on **the village's land** is the villager's whose
  house is nearest within `owner_reach_tiles` (12; the first of a household), one inside a house
  the first of its residents'; a thing anywhere else, the player's own, is nobody's. Left out: the
  animals themselves (there is nothing in the game to take from one but eggs).
- Step 9: benefits as data. `[benefits]` of `data/friendship.cfg` gives each benefit of the table
  its lowest level; `FriendshipRules.allows(benefit, level, earlier)` answers, never a number in
  code. A sheet may give `benefit_level` ({"lends_tool": 5}, levels 2 to 10, checked by
  `VillagerRules`; `benefit_levels(id)` reads it) to open a benefit sooner or hold it back. Nothing
  asks it yet (step 10).
- Step 10: the first benefits at work, asked as `Benefits.allows(npc, benefit)`. **Level 1 turns
  away:** `NpcDialogue.reply` answers with a line of `turn_away` (`[scripted]` of `data/npc_talk.cfg`),
  asks no model and the first chat of the day counts nothing. **Levels 1 and 2:** a keeper does not
  trade (`Interaction`, `ShopHours`: "I have nothing to sell you."), and no quests are posted
  (`Quests`). **`better_prices`:** a keeper at level 6 asks 80 % (`ShopStanding`, `[shop]` of
  `data/friendship.cfg`), **`best_wares`:** goods marked `best` in `data/shops.cfg` from level 9 (none is
  marked yet: a content choice left open). **The prompt** tells after the level
  line `benefit_small_news` (from level 4) and `benefit_tells_wants` (from 5) or `benefit_keeps_wants`.
  There is no pedlar in the game yet, so none is shut; and `greets_by_name` waits for the player to have a
  name. See [../economy/shop.md](../economy/shop.md) and [quests.md](quests.md).
- Step 11: `romance` and the courting check. A sheet may say `romance=true` (default false; nobody
  does yet, Boy is sweet on Inken, the user names who is open), `VillagerRules.is_romance_open`.
  `Benefits.may_court(npc)` is `may_court` (level 10) and the sheet's romance and `bond` none. The
  console's `opinion` shows the bond and "may be courted". Nothing starts a bond.
- Step 12: the level in the talk panel. The villager's name under their portrait has their level's
  name under it, updated after a gift or a line; a villager at level 1 says a turn-away line when the
  window opens (`TalkFriendship.greet`) and to anything the player writes. See [dialogue.md](dialogue.md).
- Step 13: the Neighbours tab. `CharacterScreen` has a fourth tab (`Tab.NEIGHBOURS`, no key bound: the
  tab button) with `NeighboursPanel`: a row for each villager of the world from `NeighbourRows` (state, with
  tests: closest friends first, then by name), each with their portrait, name, level name and the
  ten `FriendshipMarks`, and a tooltip with the next level and what it brings ("Next: Neighbour.
  Brings: barters at the market price, says what they want this year."), from `[benefit_text]` of
  `data/friendship.cfg`. The points are never shown. **Placeholders for the art of step 14:** the marks
  are plain squares drawn in code (the first two dark blue, then ember red, the tenth gold, an empty
  one stone grey), to be replaced by drawn marks; the portraits are the villagers' own.
- Step 14, the code side with placeholders: the heart, the cloud and the level line. `FriendshipNotes`
  (state) looks at the villagers now and then (`FriendshipFlow`, a node of Main like `QuestFlow`)
  and tells what moved since the last look, whoever moved it: `moved` (a rise or a fall) and
  `level_crossed` (the line `crossed` of `[notice]` of `data/friendship.cfg`: "Antje now thinks of you as
  a good neighbour.", up or down, through `NotificationHud`). `FriendshipPopups` puts a heart (a rise) or a
  grey cloud (a fall) over the villager's head, which rises and fades in 1.4 s; none for a villager
  indoors or when the player is. **The art is still to be done** (labels `art` and `needs-verdict`): the
  heart and the cloud are shapes drawn in code, and the ten marks of the tab are squares; a pixel
  artist is to replace them with drawn pictures in both art sets (`FriendshipPopups.Mark`,
  `FriendshipMarks`). Nothing else of the design waits for the art.

## The user's words

> "A relationship system similar to stardew valley but with Sims elements so that not only gifts
> but also actions can influence the friendship level" (the user, 2026-11-08)

So: a friendship level per villager, as in Stardew Valley, where gifts count. From the Sims comes
the other half: what the player does counts too, whether it is talking, helping, being rude or
being there when it matters.

The answers of 2026-11-15 that shape this page:

1. Friendship has **10 levels**: 2 negative, 1 neutral, 7 up to best friends. At best friends the
   player can start a relationship (courting, later marriage). The system is **prepared** for
   marriage; marriage is not built now.
2. Gifts: one gift per villager per day.
3. Courting and marriage come later, but the levels already allow for them.
4. The player's words are rated by a second small model request, capped per day, and the game
   works without a model. It has its own per-profile switch, `word_rating`.
5. Stealing and damage cost friendship, only with those who see them (the user, 2026-11-15:
   nobody finds out later).
6. Events: later, kept in mind.
7. Friendship does **not** fade, not yet (see [Later](#later)).
8. Friends get benefits, which may open below best friends too. A bad name closes options:
   shops and services.

## What exists today

- A villager's **opinion** of the player is `Npc.opinion`, in points from -100 to 1000, starting
  at 0 ([gossip.md](gossip.md), task 128). The story judge moves it by a change of -2 to +2 steps
  of 10 points (`GossipRules.MAX_CHANGE`, `step_points`), in full for what the villager saw and
  by half for what they heard (`heard_share`). `Npc.change_opinion` keeps the day's moves within
  a cap of 20 points (`daily_cap_points`, saved as `opinion_day` and `opinion_moved_today`).
  Quests pay the deed `helped` of 1 or 2 steps, and a quest may need an opinion of some points
  ([quests.md](quests.md)). The numbers are `[opinion]` of `data/gossip.cfg`.
- The opinion is told to the model as one of three words, cold (below -20), neutral and warm (from
  20), by `GossipRules.opinion_word`, in `NpcPrompt` and `NpcBubbles`; the console has
  `opinion <villager> [points]`.
- Nothing else uses it: no gift, no benefit, no level, no screen. A villager's `likes` are free
  text for the model. There is no event calendar and no ownership of things
  ([land ownership is deliberately left out](../README.md#deliberately-left-out)).
- [Reputation](reputation.md) of a settlement is not built (only its one-hop rule is on paper).

So the points exist and stories move them. This page adds what the points **mean** (levels),
what else moves them (gifts, talk, help, harm), what they **open** (benefits) and how they are
**shown**.

## Two numbers: reputation and friendship

- **Reputation** is what a settlement or a group thinks of the player: "the people of
  Wehlsbüll". It moves slowly and spreads one hop ([reputation.md](reputation.md)).
- **Friendship** (the opinion) is what one villager thinks of the player.

They feed each other in one direction each, so there is no loop. Reputation is not built, so for
now a villager's level stands alone, and shops and services look at the keeper's own level (see
Benefits). When reputation is built, a new acquaintance starts at the village's reputation scaled
to -50 to +50 points, and a friendship change is a quarter of that change in the village's
reputation. Those numbers go into `data/friendship.cfg` then.

## The ten levels

The points do not change: -100 to 1000, 0 at the start. A level is a **range of those points**, so
a save keeps what it has (see Saving). The ranges widen going up: the first steps are quick and
best friends are earned. The cuts at -20 and 20 are today's cold and warm, so the neutral level
is -20 to 19.

| # | Level | Points | Mood | What it is like |
|---|---|---|---|---|
| 1 | **Shunned** | -100 to -61 | cold | Turns away: a scripted line instead of a chat. |
| 2 | **Mistrusted** | -60 to -21 | cold | Short answers, no trade, no quests. |
| 3 | **Stranger** | -20 to 19 | neutral | Where everyone starts. Greets, answers politely. |
| 4 | **Acquaintance** | 20 to 99 | warm | Greets by name, small news and the weather lore of their trade. |
| 5 | **Neighbour** | 100 to 219 | warm | Barters small things, says what they want this year. |
| 6 | **Good neighbour** | 220 to 379 | warm | Helps with work, lends a tool, better prices. |
| 7 | **Friend** | 380 to 559 | warm | Teaches a craft or a recipe of their trade. |
| 8 | **Trusted friend** | 560 to 739 | warm | Tells what the sheet's `secrets` hold, asks the player into their house. |
| 9 | **Close friend** | 740 to 899 | warm | The best of what they have. |
| 10 | **Heart's friend** | 900 to 1000 | warm | Courting may start (see below). |

The words are of a marsh village in 1900: a Nachbar and a good neighbour come long before a
friend, and a "Herzensfreund" is the one you tell everything. They are data and can change.

**Where the numbers live.** A new `data/friendship.cfg` holds the `[levels]` (name, first point,
mood), the action values below, the benefits and the rating limits. What stories move stays in
`[opinion]` of `data/gossip.cfg`: the bounds, `step_points`, `heard_share` and the story cap of
20 a day. `cold_below` and `warm_from` and `GossipRules.opinion_word` go; a new `FriendshipRules`
(state only, read once, reports what is wrong with the file as `GossipRules` and `QuestRules` do)
has `level_of(points)`, `level_name`, `mood_of(points)` and `first_point_of(level)`. A test holds
the file clean: levels 1 to 10 in order from -100, none missing or doubled, cuts at -20 and 20.

## What moves friendship

Each action is a small, explicit change in the game state ("it changes only through explicit
actions"): a method of the state, not of a scene. First values in points, all in
`data/friendship.cfg`, to tune in play.

| Action | Change | Limit |
|---|---|---|
| **Gift**, liked | +40 | One gift per villager per day, whatever it is. |
| Gift, neutral | +10 | |
| Gift, disliked | -20 | |
| **Talk**, first chat of the day | +5 | Once a day. |
| Talk, kind or interested (the model's rating) | +5 | At most +5 a day. |
| Talk, rude (the model's rating) | -10 | At most -10 a day. |
| **Help with work** the sheet names (hay for Antje, nets for Momme) | +30 | Once per job. |
| Bring what a villager `wants` this year | +50 | Once. |
| **Rudeness**: pushing through them, hitting them | -20 | Seen. |
| **Stealing**: taking from their chest, crops or animals | -50 | Only if seen. |
| **Damage**: cutting their Knick, breaking their fence | -20 | Only if seen. |

Later, with the events: attending an event with them (+10), a feast day doubling a gift, being
nearby in trouble and helping (+40).

- **Two caps.** What stories move stays within 20 points a day (as built). The actions above
  have a second, separate total, `action_daily_cap_points` (60), per villager, up and down alike:
  a gift and a deed can't carry a villager from stranger to friend in an hour, and a story isn't
  drowned by a gift. The quest reward is the deed `helped` and stays in the stories' cap, as built.
- **Gifts are liked or disliked per villager.** Today `likes` is free text, which the game cannot
  read. The sheet gets `gifts_liked` and `gifts_disliked`, lists of item ids (Antje: butter;
  Momme: smoked eel; items that don't exist yet come with the shops); everything else is neutral.
  Made-up villagers get theirs from the tables of `data/npcs.cfg` by trade. The free-text `likes`
  stays for the model. The player gives by handing an item over in the talk panel; the villager
  answers with a template line.
- **Rating the player's words.** The model's job is to say words and the game decides the
  numbers, so the player's line is rated by a second, small request (like the memory summaries):
  warm, neutral or rude, one word, no history, a few tokens (a new `[word_rating]` of
  `data/npc_talk.cfg` has its wording and `max_tokens`). It is asked quietly after the villager's
  answer is shown, and only when **`NpcDialogue.has_model_for(&"word_rating")`** holds: a model
  is set and the profile in use has the switch on. `word_rating` is a new use in
  **`LanguageModelProfiles.USES`**, on by default, saved in the profile like `quest_lines` and
  a checkbox of Settings > Language model. It is capped twice: at most `rating_requests_per_day`
  (3) requests per villager and day, so the cost is bounded, and the points above. An answer that
  doesn't come in time counts as neutral. Without a model, or with the switch off, only the first
  chat of the day counts. The model is never asked to set a level, so it can't be talked into one.
- **Help with work** needs a list of jobs the game can check. Quests already check them
  ([quests.md](quests.md), objectives), so the first version has quests only; jobs from the
  sheet's `wants` and `day` follow if wanted.
- **Seeing.** Rudeness, stealing and damage cost friendship with the villagers who see them:
  the witnesses of the deed log ([gossip.md](gossip.md), `DeedLog`: within the radius, by night
  a smaller one), and only with them: an unseen harm costs nothing, the owner included. The harms are **new
  deed kinds** (`stole`, `damaged`, `rude`, and `gave_gift`), so the log, the witnesses and the
  spread of stories carry them: a seen theft is also a story the village tells and the others
  hear it as gossip, by the gossip's rules, halved and capped. The witness's own loss is the
  table's value, not the story's change.
- **Whose things are whose.** No plots: ownership is **by villager and their home**. A thing is
  theirs if its home building (or the building nearest to it) is theirs: the home's chest and
  bed, the crops and animals on their Warft, the fences and Knicks round their fields. An
  `owner_of(tile)` on the state answers it, from the buildings and the sheet's `home`.

## What a level opens: benefits

A **benefit** is a name with the lowest level that has it, in `[benefits]` of
`data/friendship.cfg`. Code asks `FriendshipRules.allows(benefit, level)`, never a number.
Places that already exist ask it first; a benefit whose system does not exist yet comes with
that system. First values:

| Benefit | From level | What it is |
|---|---|---|
| `talk` | 2 | Chats at all (at 1 the villager turns away). |
| `trade` | 3 | The villager's shop or service is open to the player. |
| `quests` | 3 | The villager posts quests (as `opinion` of a quest asks already). |
| `greets_by_name`, `small_news` | 4 | The greeting uses the player's name; news and trade lore. |
| `barter`, `tells_wants` | 5 | Barters at the market price; says what they want this year. |
| `better_prices`, `lends_tool` | 6 | Better prices in their shop; lends a tool. |
| `teaches` | 7 | Teaches a craft or recipe of their trade ([crafting ideas](../crafting/ideas.md)). |
| `tells_secrets`, `invites_inside` | 8 | The sheet's `secrets` are open to the model; the door is open. |
| `best_wares` | 9 | The best goods of the shop or the pedlar. |
| `may_court` | 10 | Courting may start, if the sheet allows it. |

- **A benefit may open early** for a villager: the sheet may give a `benefit_level` for a named
  benefit (a hay farmer gives a hand sooner, a smith holds a recipe back to 8). The data check
  keeps it between 2 and 10.
- **A bad name closes options.** Level 1 shuts a shop, the pedlar or a service to the player;
  level 2 shuts them too (`trade` and `quests` are from 3). When reputation is
  built, a settlement with a bad name closes the shops of its villagers whatever their own
  levels: the rule is the lower of the two. The Krug's door is the first example.
- A benefit is **told to the model** in the level line (below) and **applied by the game**, so
  what a villager says matches what the game does.

## Courting and marriage: prepared, not built

What the system holds now, so that nothing later changes the saved shape:

- Each villager has a **`bond`**, saved as a word. `none` is its only value now; `courting` and
  `married` come with their own design.
- The sheet has a `romance` key (false by default). Who can be courted is decided villager by
  villager, single adults only; Boy is sweet on Inken already, so those two are not open.
- `may_court` is a benefit of level 10, so courting is one more benefit, not a special system:
  `allows("may_court", level) and sheet.romance and bond == none`.
- Friendship points keep their meaning while a bond runs: a bond is a state of the villager,
  not a level above 10.

Courting (a token and a talk), marriage (a shared household) and the end of a bond are **later
tasks** with a design page of their own. Nothing in the steps below starts a bond.

## What the villager says: the prompt

The chat prompt tells the level in **words, never numbers**. The three words (`opinion_cold`,
`opinion_neutral`, `opinion_warm` of `[prompt]` of `data/npc_talk.cfg`) become **ten lines**,
`level_1` to `level_10`, e.g. level 7: "{name} thinks of the player as a friend and is glad to
see them." A cold level tells the villager to be curt, and level 10 to be open about what they
hinted at. The sheet for local models stays small: one line. The bubbles (`near_player`) keep
their three lists and take the level's **mood**, so they need no new lines. Up to five short
deeds for the hosted model ("Gave her butter yesterday, which she liked") are later.

## Shown in the game

- **The talk panel** shows the level name beside the villager's name; at level 1 only the
  scripted turn-away line.
- **A "Neighbours" tab** on the character screen: a villager per row with portrait, level name
  and a strip of **ten marks**, filled up to the level; the two negative ones cold and dark, the
  rest in the warm palette, the tenth gilded. Hovering shows the next level's name and what it
  brings, so the player knows what to work for; the points are never shown.
- **A change shows**: a small heart over the villager's head when a gift or a deed counts, a grey
  cloud when something is lost, and a line at the bottom of the screen when a level is crossed
  ("Antje now thinks of you as a good neighbour"), up or down.
- **The console:** `opinion <villager> [points]` also names the level; no new command.
- The heart, the cloud and the marks are drawn by the art generator in both art sets, placeholder
  shapes first; the user judges them.

## Saving

Points need **no upgrade**: a level is computed from them, so every villager keeps what they have
and the level that goes with it. New fields per villager:

| Field | Meaning | Old save |
|---|---|---|
| `last_gift_day` | the day of the last gift | 0 |
| `chat_counted_day` | the day the first chat counted | 0 |
| `action_day`, `action_moved_today` | what the actions moved today, for their cap | 0, 0 |
| `rating_day`, `ratings_today`, `rating_moved_today` | the day, how many word ratings asked and how far they moved the opinion, for their caps | 0, 0, 0 |
| `bond` | `none` for now | `"none"` |

The version goes from **52 to 53** by the rules at the top of `game/state/save_file.gd`: write the
fields in `to_dict` and `from_dict`, raise `VERSION`, add `_upgrade_from_version_52` that gives
each villager the defaults, add the checks to `SaveValidator` (days not negative, `bond` a known
word, counts within their caps), add a test in `tests/test_save_upgrade*.gd`; then, as a commit of
its own, "Save: drop the upgrade from version 42 (oldest read: 43)" with the helpers and tests only
it used, so ten steps remain. (The drop follows the version commit, as earlier ones did, because
`OLDEST_VERSION` is `VERSION - 10`.) The `word_rating` switch is in the settings file, not the
save: a profile without it gets the default, on.

## Build steps

Each is one atomic commit with its tests and doc lines, passing `make test` and `make lint` on its
own. #48 gets a sub-issue per step when the plan is approved. 1 to 4 are the levels, 5 to 8 what
moves the points, 9 to 11 what the levels open, 12 to 14 what the player sees (the user judges
those by hand).

1. **The ten levels as data.** `data/friendship.cfg` with `[levels]`, and `FriendshipRules`
   (`level_of`, `level_name`, `mood_of`, `first_point_of`). Tests: every point from -100 to 1000
   has exactly one level, the cuts, the file is clean, a broken file is reported. Docs: this page
   as built.
2. **The prompt, bubbles and console use the levels.** `opinion_word`, `cold_below` and
   `warm_from` go; `NpcPrompt` and `NpcBubbles` take the mood and the ten `level_<n>` lines
   (checked by `NpcTalkRules`); the console names the level. Tests: each level's line in the
   prompt, bubbles by mood; the three-word tests move. Docs: [gossip.md](gossip.md) (the opinion
   as built), [dialogue.md](dialogue.md).
3. **The state for gifts, talk, rating and the action cap.** The new fields on `Npc`,
   `Npc.change_friendship(points, today, rules)` with its own cap next to `change_opinion`, and
   `bond` (`none`). Tests: caps up and down, the day turning, the bounds. Docs: this page.
4. **Save version 53**, as above, then **4b: drop the upgrade from version 42**. Tests: an old
   save loads, keeps the points, has the defaults. Docs: `save_file.gd`'s header, this page.
5. **Gifts.** `gifts_liked` and `gifts_disliked` on the sheets and the tables of `data/npcs.cfg`
   with their checks; `GameState.give_gift(villager, item)` (liked, neutral, disliked, one a day,
   the item leaves the inventory); the deed `gave_gift`; the handing over in the talk panel and
   a template line. Tests: each outcome, the second gift of a day refused, the item is gone,
   the deed is logged. Docs: [villagers.md](villagers.md) (the keys).
6. **Talking counts.** The first chat of the day gives +5 with no model. Tests: once a day,
   again the next. Docs: this page.
7. **Rating the player's words.** The use `word_rating` in `LanguageModelProfiles.USES` (saved,
   a Settings checkbox, on by default); `NpcPrompt.word_rating_request` and
   `word_rating_from_answer`, `[word_rating]` of `npc_talk.cfg`; a node of Main that asks quietly
   (as `QuestVoice` does) when `has_model_for(&"word_rating")` and within the request cap; the
   point caps. Tests: a model that answers, a late answer, no model, the switch off, over the
   cap, a garbage answer; the profile tests list the uses (`test_language_model_settings.gd`).
   Docs: [dialogue.md](dialogue.md), the Settings page.
8. **Harm: stealing, damage, rudeness.** `owner_of`, the deed kinds `stole`, `damaged` and `rude`
   in `data/gossip.cfg`, the hooks where the player takes from a chest, crop or animal, cuts a
   Knick, breaks a fence or pushes a villager; the friendship moves for the witnesses at once,
   and an unseen harm costs nothing. Tests: seen and unseen, owner away, night, the
   caps, the player's own things cost nothing. Docs: [gossip.md](gossip.md) (deeds).
9. **Benefits as data.** `[benefits]` and `allows(benefit, level)`, the sheet's `benefit_level`
   with its check. Tests: each benefit's level, an override moves it. Docs: this page.
10. **The first benefits at work.** Level 1 turns away; levels 1 and 2 close the shop and the
    pedlar and post no quests; `better_prices` and `best_wares` in the shop; `small_news` and
    `tells_wants` in the prompt. Tests: shop open or shut by level, price by level, quests by
    level, the prompt lines. Docs: [shop.md](../economy/shop.md), [quests.md](quests.md). Later
    benefits (`teaches`, `lends_tool`, `invites_inside`) come with the systems that give them.
11. **`romance` and the courting check.** The key and its check, `may_court`, the console shows
    the bond. No way to court yet. Tests: only level 10, only a sheet that allows it, only a
    villager with `bond` none. Docs: this page.
12. **The level in the talk panel.** Name beside the villager, the turn-away line at 1. By hand
    with `make run`. Docs: [dialogue.md](dialogue.md).
13. **The Neighbours tab.** Rows with portrait, name and ten marks (placeholder shapes), the
    next level and its benefit on hover; the list of rows is a state class with tests. By hand.
    Docs: the UI docs and [villagers.md](villagers.md).
14. **The heart, the cloud and the level line.** The pop-up over the head, the line of the screen
    on a crossed level, art for both sets (labels `art`, `needs-verdict`).

After 4, steps 5 to 8 go in any order. Step 7 needs 3.

## Later

Kept in mind, not planned in detail:

- **Friendship fading** (the user: "needs some more complexity, we'll discuss later"). The earlier
  draft had a decay (2 points a day after ten days away, never below the level before, cold
  slowly mending); it is **not** in this plan. Nothing reduces points by time.
- **Courting and marriage**: a page of their own (the bond, the token, the household, the end
  of a bond).
- **Events** (church on Sunday, the Biike fire, the Deichschau, Martinmas, the Husum market):
  needs an event calendar, then attending counts and a feast day doubles a gift.
- **Trouble** (a breach in the dyke, a stuck cow): being there when it matters, after events.
- **Reputation** of a settlement, as above.
- **Deeds in the hosted prompt**, five lines.

## Questions (answered)

Answered by the user on 2026-11-15: the defaults stand, except 6.

1. **How big is the action cap?** Gifts alone are +40 and the story cap is 20. Default: a
   separate `action_daily_cap_points` of 60 per villager, tuned in play.
2. **How many ratings a villager and day?** Default: 3 (`rating_requests_per_day`).
3. **Ten marks or hearts?** Default: ten marks (five hearts would hide half the levels).
4. **Are the level names right?** Default: Shunned, Mistrusted, Stranger, Acquaintance,
   Neighbour, Good neighbour, Friend, Trusted friend, Close friend, Heart's friend.
5. **Does a pop-up tell the points?** Default: no, only a heart or a cloud, and the line when a
   level is crossed.
6. **Does an unseen theft from a house cost anything?** No (the user, 2026-11-15): only what is
   seen counts.
7. **Who may be courted?** Default: `romance` off for everyone until the user names villagers.
8. **Does level 2 (Mistrusted) still trade?** Default: no, shops and quests are shut at 1 and 2
   (`trade` from 3). Tell if a Mistrusted villager should still sell, dearer.
