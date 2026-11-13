# Gossip and memory

**Decided; the deed log, memory, spreading, the judge and the topics of the village (tasks 125 to 129) are built, the rest is not.** Worked out with the user on
2026-11-09. The tasks are 124 to 130 in
[TASKS.md](../../TASKS.md). This page changes [dialogue.md](dialogue.md) (memory) and
[villagers.md](villagers.md) (who knows the village) once the tasks are done; until then those
pages describe the game as it is.

## The idea

What the player does near villagers is seen, remembered, judged and passed on. The villagers who
see it know at once. Others hear it later from someone they met, sometimes a little changed, and
say who told them: "Moiken told me you felled half the Boysen wood." What a villager thinks of
the player follows from what they saw and heard.

The same mechanism lets newcomers learn the village: what the locals know of Wehlsbüll spreads
to them as stories, one meeting at a time.

## Who does what

| | Game code | Language model |
|---|---|---|
| What happened (the fact) | Yes, always | Never |
| Who saw it, who heard it, when, from whom | Yes | Never |
| How the story changes as it travels | Yes (seeded random, from a table) | Never |
| The line in the villager's voice | A template line without a model | Yes, in the background |
| What the villager thinks of it (opinion change) | A fixed change per deed without a model | Yes, capped |
| Whether it touches them personally | Yes, where the game can tell | Yes, for what the game can't |

The model judges and words things; it never makes up facts or moves them. Everything works
without a model, only plainer.

The language model is never waited for: its calls run in the background in a saved queue. A
villager talked to before their line has come back still knows the plain fact. If the player
talks to someone before a rumour has reached them, they simply don't know yet, which is natural.

## Deeds

- **The deed log** (game code, saved): each deed the player does within 20 tiles of a villager
  is written down as `{day, minute, kind, count, place, witnesses}`. Deeds of the same kind and
  place on the same day merge into one entry ("felled 7 trees by Antje's house"), so a day's
  work makes a few entries, not hundreds.
- **Where deeds come from:** the deed log listens to `GameState.action_done`, which tells an
  `ActionOutcome` (who, kind, tile and map, object, items with counts) once for each finished action
  of the player (task 143): a felled tree is a `break` of a tree, a building a `build`. The log
  maps both `take_down` (a placed object, with the axe or the hammer) and `demolish` (a building).
  A refusal or a loaded game tells nothing.
- **First kinds:** felled a tree, built a building, took down a building, placed a fence or
  wall, tilled, sowed, harvested, dug clay, mowed. The list, its words and the fixed opinion
  changes are in `data/gossip.cfg`. Gifts, theft and helping come with
  [relationships](relationships.md).
- **The place** in words: the house of the villager whose home is nearest within 20 tiles ("by
  Antje's house"), else "out on the marsh" (a word per biome in the data file).
- **Witnesses:** every villager within 20 tiles (6 at night, when they stand still) sees it, not
  only the nearest. Each gets the deed as a story they **saw**, at once. No line of sight for
  now.
- **As built (task 125):** `DeedLog` (GameState `deeds`, saved) and `GossipRules`
  (`data/gossip.cfg`). A deed is written down only if some villager is within the radius, so
  the log is of what was seen. The kind comes from the outcome: `till`, `plant` of a crop, `harvest`,
  `mow`, `dig` that found clay, `break` of a tree, `place` of a fence or wall (an object that
  connects), `build`, and `demolish`. A hammer `take_down` of a placed object and the shovel
  digging up a bush are no deeds. Only the world is watched, not the inside of a house. "Nearest
  home" is the nearest villager's anchor; the first name is used in the place. The witnesses of
  an entry are their names. An entry is kept while it is under `keep_days` old (7 days, today's
  included); older ones are dropped when a deed is written, when a day begins and when a game is
  loaded. The stories (`Npc.stories`, saved, merged like the entries) are the villager's gossip
  buffer (task 126, see Memory): they stay until newer ones push them out, and the chat prompt
  tells all of them as the template line, each by `[story]` of the data file (Today / Yesterday /
  N days ago), after the long-term memories. The console's `deeds` lists the log.
- **As built (task 126):** a story is flat: the fact (`day`, `minute`, `kind`, `count`, `place`)
  and `origin` (the deed's day, kind and place as first seen: it names the story however it
  changes on the way, and a villager knows one version of it), `how` (seen or heard), `told_by`,
  `seen_by`, `hops`, `learned_at` (the game minute, task 127), `line` (the voiced
  line, "" until the model has worded it), `weight` and `personal`. A deed seen is `seen`, hops 0,
  weight high if the deed was by the witness's own house or that of someone on their sheet
  (`people`), else medium, and `personal` follows the high. Weights are `MemoryWeight` (saved as
  the words low, medium, high). The buffer is first in, first out, `stories_kept` long (default
  10, the setting "Stories a villager keeps", 1 to 100, one for each language model profile; Main
  gives it to the deed log, and lowering it applies once the menu is closed). The story that
  leaves is forgotten if low, else its line `On day N: you saw the newcomer ...` (`memory` of
  `[story]`) is a long-term memory of its day and weight. A story heard is told with
  the teller, by the `heard_` lines of `[story]`: "Today Moiken told you that the newcomer was seen
  to fell 7 trees by Antje's house." (the same in the memory line).
- **As built (task 127):** `GossipSpread` (a `SimulationSystem`, so it runs as the clock moves,
  after a skip too) and `SpreadRules` (`[meetings]` of `data/gossip.cfg`). Each time the clock
  moves it looks at every pair of villagers of the world, in view or not (they stand still where
  they are when out of view): two closer than 3 tiles meet if they have not met in the last hour
  (60 minutes; kept in memory only, so a loaded game lets pairs meet at once, and they only pass
  what the other lacks). Each way, if the teller has a story that the hearer lacks (by `origin`)
  that they have known for 2 hours, that has come fewer than 3 hops and whose deed is fewer than
  7 days old, the weightiest and then the newest is passed with the chance of the tie: 0.8 family
  and friends (the sheet of either, by id), 0.5 for one of the 3 villagers whose anchors are
  nearest to the teller's, 0.2 for anyone. The hearer keeps it as `heard`, `told_by` the teller,
  `hops` one more, `learned_at` now, weight low and not personal (the judge of task 128 may raise
  that), the same `seen_by` and `origin`. Village topics, which never stop, are not stories: see task 129 below.
  The dice are `GossipSpread.rng`, seeded by tests. Whispers: at each hop, with the chance of
  `[whispers]` (0.1), one of three things of the deed shifts, picked at random among those that
  can: the count grows to the next of `count_steps` (not past the last), the place moves to the
  house of one of the teller's neighbours (the `house` words, a house other than the one it was
  by), or the kind turns into the similar one of `[whisper_kinds]`. The hearer's version goes on
  from the changed fact, and its `origin` stays. `[counts]` words some counts ("a dozen"), true
  or whispered.

- **As built (task 128, the opinion):** `Npc.opinion` is the points (saved with the day and how far
  it has moved that day), `Npc.change_opinion` moves it by points up to the daily cap (the sum of
  the day's moves stays within it either way; also clamped to the bounds), `[opinion]` of
  `data/gossip.cfg` has the bounds (-100 to 1000), the cap (20) and the thresholds of the words
  (cold below -20, warm from 20, else neutral; the levels of [relationships](relationships.md)
  come when that page is decided). The chat prompt tells the word, `opinion_cold`, `opinion_neutral`
  or `opinion_warm` of `[prompt]` of `data/npc_talk.cfg`, in the last turn after the line that
  the player is a newcomer. `/clear` leaves it. The console's `opinion <villager> [points]` shows
  or sets it.
- **As built (task 128, the judge):** `StoryJudge` (`GameState.judge`) and `StoryJudging`, a node
  of Main that works through the queue. The queue is the stories with `is_judged` false (saved
  with them), the one learned first first: each story is judged once, when it comes (a deed seen,
  a rumour heard); deeds of one kind, place and day that merge into a story after it was judged
  are not judged again. `StoryJudging` looks at the queue twice a second and asks the model
  (`NpcDialogue.ask`) one story at a time: `NpcPrompt.judge_request`, the `[judge]` section of
  `data/npc_talk.cfg` (a system line that asks for JSON, then the villager's sheet, full or cut down
  as for a chat, and the story as the chat tells it, who told it included; temperature 0.2, at
  most 150 tokens). `StoryJudge.parse_verdict` takes the first `{` to the last `}` of the reply
  (a code fence or words around it do not matter) and wants `line` (text, cut to the reply's
  sentences), `change` (a whole number, -2 to 2) and `personal` (true or false); anything else is
  `fixed_verdict`: no line (the template is told), the deed's `change` of `data/gossip.cfg` and not
  personal. Without a model the fixed verdicts come at once, so a game without a model works the
  same, only plainer. `settle` marks the story judged, sets its `line`, makes a personal story
  high weight (a high one stays high) and moves the opinion by the change times `step_points` (10;
  one step of relationships.md is 10 friendship points), in full for a story seen and by
  `heard_share` (0.5) for one heard, within the day's cap. The chat prompt tells a story with a
  line as `voiced_` of `[story]` ("Today, in your own words: ..."), and a story that leaves the
  buffer leaves "On day N: <line>" as its memory. The model is asked quietly (`ask(request,
  true)`): when it fails, ModelNotices shows nothing, only the failures of the player's chat do.
  Known limits: a story that is pushed out of the buffer before it was judged is never judged;
  a voiced line keeps the count it was judged with (stories merging later change the count, not
  the line).

- **As built (task 129, topics known):** `Npc.topics` (saved, version 38) lists the topics of
  `data/village.cfg` a villager knows. A villager of `data/villagers.cfg` has them all (also when
  an older save is loaded), a made-up one none. `VillageSheet.text(full, known_topics)` tells just
  those, in the order of the file, and `NpcPrompt.system_text` leaves the village block out when
  nothing is told (a villager who knows none, or whose known topics have no cut-down). A topic is
  knowledge, not a story: it is not in the gossip buffer, is never judged and `/clear` leaves it.
  The console's `gossip <villager>` lists them.
- **As built (task 129, topics spread):** at a meeting (see above) each of the two may also teach
  the other one topic, after the stories: the first topic of `data/village.cfg`, in the order of
  the file, that the teller knows and the hearer lacks, with `chance_topic` (0.5, `[meetings]`),
  whoever they are (no tie: a topic is no secret). A topic has no wait before it is told, no hops
  limit, no age and no whispers; it goes into the hearer's `topics` and nowhere else, so a newcomer
  who has just learned one tells it at their next meeting, to a local (who knows it) or to another
  newcomer. The same pair still meets only once an hour.

- **The deed log is also the base of an end-of-day screen** (later: "Today: 7 trees felled, a
  Kate built, 12 beds sown").

## Stories

A story is what one villager knows of one thing:

- **The fact:** a deed (kind, count, place, day) or a village topic (a section of
  `data/village.cfg`).
- **Where it came from:** `seen` (they saw it) or `heard`, with who told them (`told_by`) and
  who first saw it (`seen_by`, kept in the data, not used in the line yet: the user wants only
  the direct source at first).
- **How far it has come:** hops from the one who saw it, and the day it was learned.
- **Its line:** the plain template line at first; the model's voiced line once it has come back.
- **Its weight** (see Memory) and whether it touches them.

A villager knows one version of a story: hearing it again from someone else changes nothing.

## How stories spread: meetings

Stories spread when villagers **meet**, all day, not at a set time:

- Two villagers within 3 tiles of each other meet. A pair meets at most once an hour of game
  time, so two who stand together don't pass everything at once.
- At a meeting, each may pass one story the other doesn't know, with a chance by how they are
  tied: family and close friends high, neighbours (the 3 villagers whose anchors are nearest)
  medium, anyone else low. Values in `data/gossip.cfg`.
- A story is passed on only once it has been known for 2 game hours: gossip takes time.
- The teller picks the weightiest and newest story the other lacks.
- A deed's story stops after 3 hops or 7 days. A village topic never stops.

Today villagers keep near their anchors, so few meet and rumours travel slowly. Once villagers
have routines, friends who spend time together and families in one house spread news among
themselves, and strangers run into locals at the inn or the church, without any change here.

## Whispers

At each hop there is a small chance (10%, in the data file) that one thing about a deed shifts,
in code:

- **The count grows:** 7 trees become "a dozen" or "half a wood" (a table of steps).
- **The place moves** to a neighbouring house.
- **The kind turns into a similar one:** felled into cleared, built into fenced in (a table).

The model then words the changed fact in the hearer's voice. The drift stays believable and can
be tuned and tested. Village topics don't drift.

## Memory

Today a villager has their sheet, the last lines of the chat, and up to 10 memories, with the
oldest two merged. That becomes three layers:

| Layer | What it holds | How it changes |
|---|---|---|
| **Knowledge** | What they know of the world: their sheet, and the village sheet for locals. Newcomers start without the village | Village topics learned as stories are added here and never forgotten |
| **Short-term** | Two first-in, first-out buffers: **chat** (lines with the player, as today) and **gossip** (stories seen and heard) | When a buffer is full, its oldest entry leaves for long-term |
| **Long-term** | Weighted memories, each `{day, text, weight}` | When full, the lightest goes; between equal weights, the oldest |

- **Weights:** low for hearsay that doesn't touch them, medium for what they saw or said with the
  player, high for what touches them: a deed by their own home or that of family on their sheet,
  or one the model calls personal ("that was my favourite tree").
- **Leaving the chat buffer:** summed up by the model into a memory (medium), as today.
- **Leaving the gossip buffer:** no model. A low story is forgotten outright; any other moves its
  line to long-term with its weight.
- **What they think of the player** is a number, not a memory: it stays when the details fade.
- **Sizes are settings:** "Lines a villager keeps" (chat, as today), "Stories a villager keeps"
  (gossip, default 10) and "Memories a villager keeps" (long-term, default 20).
- **The prompt** tells knowledge, long-term memories, the gossip buffer and the chat, in that
  order. A story the model has not worded yet is told by its template line.
- `/clear` in the chat forgets everything but knowledge.

## Locals and newcomers

- The villagers written by hand (`data/villagers.cfg`) are locals: they know the village sheet,
  as today.
- Made-up villagers know nothing of the village at the start, only the base line (they live in
  Wehlsbüll on the North Frisian coast in 1750). They learn the village sheet topic by topic from
  locals and from other newcomers who have learned it, as stories.
- Later, hand-written characters from elsewhere bring knowledge of their own ("lived in Husum
  for twelve years"): a sheet of their own place instead of the village's. Not part of these
  tasks.

## The judge: what the model is asked

For each story a villager gets (seen or heard), one queued call returns:

- `line`: one sentence in the villager's first person and voice, naming who told them if heard
  ("Moiken told me ...").
- `change`: -2 to +2, what this does to their opinion of the player.
- `personal`: yes or no.

It asks for JSON. A reply that doesn't parse, is out of range or doesn't come counts as no
model: the template line, the deed's fixed change, `personal` no. The change is full for those
who saw it and half for those who heard it, and the change a villager can take in a day is
capped. One call at a time, like the memory summaries; the queue is saved.

**Opinion** is the friendship points of [relationships](relationships.md) (one change step = 10
points). Until that page is decided and built, the judge task adds just the points, saved, and
the words for them in the prompt (built, see As built under Deeds).

## Bubbles

Short lines over a villager's head, now and then:

- Only villagers in view, at most one bubble on screen at a time and one a minute or so. Values
  in the data file.
- About the moment (weather, time of day, the place, what they do) or about the player when they
  are near, with what the villager thinks of them and their newest stories: "There goes the one
  who felled Antje's ash."
- Asked of the model in the background, shown when it arrives (dropped if the villager is out of
  view by then). Without a model, scripted lines per weather and part of the day.
- Not saved, not remembered.

## Settings

Besides the memory sizes, a **temperature** setting per profile (task 124), like "most tokens an answer
may take" (empty: the game's own, 0.5). It applies to what villagers say (chat and bubbles).
Summaries and the judge keep their own, low temperatures in the data file, as they need to be
steady rather than lively.

## Deliberately left out

- The model picking actions or reacting to events: rules do that better and cheaper.
- A day plan from the model: random from tables does as well.
- Line of sight for witnesses.
- Gossip at a set time (the night): it spreads at meetings all day.
- Naming the first witness in the line ("Antje saw it herself"): kept in the data for later.
- The end-of-day screen (later, from the deed log).
