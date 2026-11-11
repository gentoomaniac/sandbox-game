# Villagers

Decided 2026-11-06 (task 84, QUESTIONS.md 22): the first step towards the people of
[ideas.md](ideas.md). For now villagers are put in the world with the
console (`spawn npc [count]`, or `spawn npc <id>` or just `spawn <id>`, near the player); they
are state and saved.
Task 86 (2026-11-06) added who they are, words from a language model and memory.

- **Who:** each villager draws a sex, a name and a look from a seed. Names are period North
  Frisian and Low German first names by sex (Hinrich, Jens, Boy, Momme, Ocke, Tete; Antje,
  Elke, Inken, Kerrin, Wiebke) and surnames (Jensen, Petersen, Lorenzen, Nissen, Carstensen;
  the hand-written families are the Boysens, Ketels, Hansens and Paulsens). The look is layers
  like the player's: a skin, a hair style and colour (short, long or tied for men; a bun or
  plaits for women), and period clothes (men: shirt or
  waistcoat, knee breeches, sometimes a jacket, a red or white stocking cap, a straw or felt
  hat or a tricorne; women: a laced bodice over the chemise, a long skirt, often a white, blue
  or striped apron or a shawl, a white coif or a headscarf), all in existing palette colours.
  The lists are in `data/npcs.cfg`.
- **The village (task 96):** all villagers live in Wehlsbüll, a made-up marsh parish two hours
  north of Husum in 1750, and share its sheet, `data/village.cfg` (`VillageSheet`): one topic a
  section (the village, places, who is who, money and prices, this year's news and worries, the
  church year, what people know of the world), each with a full text and a cut-down one (empty
  leaves the topic out of the cut-down). Made-up people there who are not villagers (Pastor
  Johann Martens, the Deichgraf Peter Momsen, the Deichvogt Brar Feddersen, the innkeeper Tete
  Jacobsen, the sexton Claus Thomsen) have names; the offices and the history are real (the
  Danish king holds all Schleswig since 1721, the floods of 1634 and 1717).
- **Who they are:** every villager has a sheet, told to the language model: age, trade,
  personality, background (the essentials of family and story; the dead are told only here),
  home, speech (the manner of talking, written so that it holds in any language: no English words
  to say, the user's "Aye." in a German talk), sample lines in their voice (they show the manner,
  not the language), people (family and close friends, each a villager by id with the kind and
  what they think of them), likes, wants (this year), day (where they are when), habits, avoids
  (what they don't know or won't talk about) and secrets (only hinted at). Eight are written by
  hand in `data/villagers.cfg` with a fixed look, spawned by id and once each: `antje` (Antje
  Boysen, a farmer's wife: the user's prompt example), her husband `hinrich` and their son `boy`;
  `momme` (Momme Ketels, a fisherman) and his daughter `inken`, Boy's sweetheart; `ocke` (Ocke
  Hansen, the miller) and his wife `gesche`, Antje's friend; and `kerrin` (Kerrin Paulsen, the
  late Deichvogt's widow), Gesche's aunt. Everyone a sheet names as kin or close friend is a
  villager of the file, and `VillagerRules` checks that the sheets agree: each names the other
  back with a matching kind (husband and wife, father or mother and son or daughter, aunt or uncle
  and niece or nephew, brother or sister, sweetheart, friend) of the right sex, a parent is 15 or
  more years older than the child, and a married couple has the same home. The others draw their
  sheet from tables in `data/npcs.cfg` along with their name, once (it is saved): an age of 18 to
  70, a trade with its day and a family by sex (the spouse a first name of the other sex with the
  villager's surname), a personality, a worry, a home on the edges of the parish (newcomers and
  outlying farms), a speech with its sample lines, likes, wants, a habit, what they avoid and a
  secret; no people, and no surname of the village sheet, so they are kin to none of its
  families.
- **Where:** each keeps near its anchor: the yard in front of the door of the nearest
  building or the nearest fireplace within 16 tiles of where it came, else that spot. It
  never walks further than 6 tiles from it (one outside the circle only walks back in).
- **Behaviour:** by day it stands about and strolls (at a third of the player's speed) only
  where its body fits on walkable tiles, and stops short of the player rather than walk into
  them; the player walks through villagers, so they never shut the player in. It never stands
  on a tile of a building: the door is walkable for the player, not for a villager, which stops
  on the tile in front of it (drawn in front of the wall). One found on a building (an old
  save, a building built round it) is put on the nearest free tile. At night (from
  half an hour after sunset to sunrise) it stands still. Like the animals it stands still
  while the player is in a house.
  **Skipping time** (the console's `skip`, sleeping, passing out; decided 2026-11-10): the
  first 3 game minutes are walked through as the same seconds of play; for the rest each
  villager in a loaded chunk is put on a random tile of the circle it keeps to around its
  anchor that it could have walked to, standing, as the hour has it; those in chunks that are
  not loaded stay as they are. This is the place where a villager's schedule (where they are
  at what time) will put them for the new time, once there is one.

- **Saved:** name, sex, look, who they are (id, age, trade, personality, background, habits;
  save version 19; the rest of the sheet, version 23), the chat's kept lines (version 17), the
  memories, the lines that dropped out and wait for their memory (version 21), so none is lost
  when the game is saved while a summary is asked for, and how many of the oldest kept lines a
  version 20 memory already holds (they drop out without a second summary); what a villager is
  doing, and an answer still owed, are not. The file wins for a villager written by hand (decided
  2026-11-07, as the user will edit the sheets): a loaded one takes their sheet from
  `data/villagers.cfg` as it is now, and the saved sheet only stands in when their id has left
  the file. A version 18 villager is given a background from the tables, the same for the same
  name. A version 22 made-up villager is made up anew from the tables by their name (the old
  tables had "Says Aye"), with another surname if theirs is now a family of the village sheet.
- **Later:** homes, schedules, intentions, suggestions from the model, NPC to NPC talk (see
  the ideas doc).
