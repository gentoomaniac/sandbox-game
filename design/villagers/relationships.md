# Relationships

**Planned, not decided.** This is a first draft for the user to change. Nothing here is built.
When the user has decided, the decided parts move to the pages of [villagers](README.md) and
the tasks go into [TASKS.md](../../TASKS.md).

## The user's words

> "A relationship system similar to stardew valley but with Sims elements so that not only gifts
> but also actions can influence the friendship level" (the user, 2026-11-08)

So: a friendship level per villager, as in Stardew Valley, where gifts count. From the Sims
comes the other half: what the player does counts too, whether it is talking, helping,
being rude or being there when it matters.

## Gossip

[gossip.md](gossip.md) (decided 2026-11-09) feeds this page: what villagers see and hear of
the player changes their friendship points (one step of its judge is 10 points), and its
meetings are how a change reaches family and friends, instead of the one-hop rule of
[reputation](reputation.md) applied at once.

## What exists today

- Villagers have a sheet in `data/villagers.cfg` (hand-written ones) or are drawn from the tables
  of `data/npcs.cfg`. The sheet has free-text `likes`, `wants`, `habits`, `avoids` and `secrets`,
  and `people`: family and friends by id, each with a kind ("husband", "friend", "sweetheart").
  See [villagers.md](villagers.md).
- Talking is a chat with a language model ([dialogue.md](dialogue.md)). The villager keeps the
  last lines and short memories of earlier talks. They know the weather, the time and how the
  player looks, but nothing about what the player has done to them.
- [Reputation](reputation.md) is decided on paper only: building inside a settlement costs
  reputation, and a change spreads one hop through friends and enemies. It is not in the code yet.
- There is no gift action, no calendar of events, and no notion of who owns a thing.
  [Land ownership is deliberately left out](../README.md#deliberately-left-out).

## Two numbers: reputation and friendship

- **Reputation** is what a settlement or a group thinks of the player: "the people of
  Wehlsbüll". It moves slowly and spreads one hop, as decided.
- **Friendship** is what one villager thinks of the player. It moves with what that villager
  sees and gets.

They feed each other in one direction each, so there is no loop:

- A new acquaintance starts at a friendship that follows the village's reputation: a good name
  gives a head start, a bad one a cold start (first values: reputation scaled to -50 to +50
  points).
- A friendship change is also a small reputation change in the village (a quarter of it, so
  one friend's quarrel is not the whole village's). The existing one-hop rule then applies
  to it, through the `people` of the villager: family and friends get half of the change
  as friendship, enemies the opposite.

## Friendship levels

Friendship is points per villager, from -100 to 1000. The level is a word, not a number, in
the game's period voice. First values, to tune in play:

| Points | Level | What changes |
|---|---|---|
| below 0 | Cold | Short answers. Will not trade or help. At -100 the villager turns away: a scripted line instead of a chat. |
| 0 | Stranger | Where everyone starts (but see reputation above). Greets, answers politely. |
| 100 | Acquaintance | Greets by name. Tells small news and the weather lore of their trade. |
| 300 | Neighbour | Barters small things (see [economy](../economy/README.md)). Will say what they want this year. |
| 500 | Friend | Teaches a craft or a recipe from their trade, lends a tool, helps with work, better prices. |
| 750 | Close friend | Tells what they only hinted at (the `secrets` of the sheet), asks the player into their house. |

Later, past the close friend: **courting** (a sweetheart, with a token and a talk) and
**marriage** (the player and a villager share a household). Both need design of their own and
are not part of the first version. Which villagers can be courted is an open question.

## What moves friendship

Each action is a small, explicit change in the game state, like every change in the game
("it changes only through explicit actions"). First values in points, to tune in play.

| Action | Change | Limit |
|---|---|---|
| **Gift**, liked | +40 | One gift per villager per day. |
| Gift, neutral | +10 | |
| Gift, disliked | -20 | |
| Gift on a feast day | x2 | |
| **Talk**, first chat of the day | +5 | Once a day. |
| Talk, kind or interested (from the model) | +5 | At most +5 per day. |
| Talk, rude (from the model) | -10 | At most -10 per day. |
| **Help with work** the sheet names (the hay for Antje, the nets for Momme) | +30 | Once per job. |
| Bring what a villager `wants` this year | +50 | Once. |
| **Attend an event** with them (a church service, the Biike fire, the Deichschau) | +10 | Once per event. |
| **Be nearby in trouble** (a breach in the dyke, a stuck cow) and help | +40 | Once per incident. |
| **Rudeness**: pushing through them, hitting them | -20 | |
| **Stealing**: taking from a villager's chest, crops or animals while they can see | -50 | They must see it (see below). |
| **Damaging their things**: cutting their Knick, breaking their fence | -20 | |

Notes on the table:

- **Gifts are liked or disliked per villager, from their sheet.** Today `likes` is free text
  ("Likes good butter, a dry hay harvest ... Dislikes idleness, waste"), which the game cannot
  read. The sheet gets two more keys, `gifts_liked` and `gifts_disliked`, lists of item ids
  (for example Antje: butter; Momme: smoked eel; Ocke: a pipe of tobacco; the items that don't
  exist yet come with the shops). Everything else is neutral. Made-up villagers get theirs from the tables
  of `data/npcs.cfg` by trade. The free-text `likes` stays: it is what the model reads.
- **Talking (sentiment):** the model's job is to say words, and the game decides the numbers.
  So the player's line is rated by a second, small request (like the memory summaries already
  are): "warm, neutral or rude". The result is capped per day, so a model can't be gamed or
  run away with. With no model (offline, or the scripted lines), only the first chat of the day
  counts. A model that doesn't answer in time counts as neutral.
- **Help with work** needs the game to know what a villager's work is. First step: a short list
  per villager of jobs the game can check (bring N of an item to a place; mow a stretch of the
  meadow; mend a stretch of fence), taken from `wants` and `day` in the sheet. The same list is
  what the crafting ideas call "bulk order deeds".
- **Events** need an event calendar that the game doesn't have. Villagers who are at an event
  when the player is there count it. The village sheet already names church on Sunday, the
  Deichschau in spring and autumn, Martinmas and the Husum market on Thursdays.
- **Seeing:** rudeness, stealing and damage cost friendship only with a villager who can see
  them (within sight, awake, daylight or lit) and with the owner when the owner finds out the
  next day (a smaller share, half). A villager's things are their home's chest and bed, the
  crops and animals on their Warft, and the fences and Knicks round their fields. The game has
  no land ownership and wants none, so ownership is **by villager and their home**, not by
  plot: the thing is theirs if its home building (or the building nearest to it) is theirs.
- **Trouble** needs events the game doesn't have yet (the storm tide that breaks the dyke is the
  first candidate, as the village sheet already worries about it).

## Decay

Friendship fades when the player stays away, as neighbours do in a village, but not to nothing:

- After 10 days without any contact (talk, gift, help, a shared event), a villager's friendship
  falls by 2 points a day.
- It never falls below the start of the level before the one the player has reached. A friend
  can become a neighbour again, but not a stranger.
- Cold does not mend itself: negative points move up by 1 a day, so that one slip is forgiven
  after a while and a theft is not forgotten for weeks.

## What the villager sees: the prompt

The villager's prompt already has the sheet, the village, the memories, the look of the player
and the moment ([dialogue.md](dialogue.md)). It gets one more line about the player, in words
and never in numbers. The cut-down sheets for local models stay small:

- **Local model (short):** one line with the level word and the mood:
  "{name} thinks of the neighbour as a friend and is glad to see them."
- **Hosted model (full):** that line, and up to five short "deeds" the game noted, newest first:
  "Gave her butter yesterday, which she liked. Helped with the hay on Thursday. Was seen
  picking Hinrich's turnips last week." A deed is one line from the action table, with its day;
  old deeds drop out as chat lines do, so nothing grows without bound.
- A **cold** villager is told to be curt, and a **close friend** to be open about what they
  hinted at. The wording is in `data/npc_talk.cfg`, as the rest of the prompt is.
- The model is told the level, never asked to set it. It can't give friendship away by
  saying it likes the player.

## How it is saved and shown

- **Saved** with each villager: points, the day of the last contact, what was counted today
  (gift given, chat counted), and the last deeds. A save upgrade is needed (the game keeps the
  last ten versions) that gives every villager 0 points, or the reputation's start.
- **Shown:** a "Neighbours" tab of the character screen: a villager per row with a portrait, the
  level word and five hearts (one per 200 points). A small heart pops up beside the villager's
  head when a gift or a deed counts. The talk panel shows the level word.
- **Console:** `friend <villager> <points>` to set it, as `skill` does for skills.
- **Code:** a `Friendship` state class under `game/state/`, apart from rendering and input,
  changed through explicit actions; the numbers in a `data/friendship.cfg`.

## Open questions

Each has the default that the work would go ahead with.

1. **Hearts or words?** Stardew shows hearts. Default: the level is shown as a word with five
   hearts beside it (as above).
2. **Gifts: once a day or a few a week?** Default: once a day per villager.
3. **Can the player court and marry a villager?** Default: not in the first version; later,
   for adult villagers whose sheet allows it (a `romance` key), and only for single ones
   (Boy is sweet on Inken already, so those two are not open to it).
4. **Is friendship with the model's sentiment too risky for a 7B model?** Default: yes, so
   the rating is its own small request, capped by day, and the game works without it.
5. **Does stealing need a witness?** Default: yes, a villager who sees it, or the owner a day
   later at half the cost; unseen theft from a chest in a house costs nothing but may be noticed
   by the owner later (a chance).
6. **Ownership by villager and home** (no plots) as described above? Default: yes.
7. **Do events and trouble come in the first version?** Default: no. First: gifts, talking and
   helping with small jobs. Events and trouble follow once an event calendar exists.
8. **Does friendship decay?** Default: yes, slowly, never below the level before (as above).
9. **Do levels unlock recipes?** Default: yes, a friend teaches one craft or recipe from their
   trade (the ideas on [crafting](../crafting/ideas.md) have a "learn from a neighbour" idea).
10. **What does reputation unlock** (the open question that was already there)? Default: shops
    and the pedlar open their best wares at a good name, and a bad name closes the Krug's door.
