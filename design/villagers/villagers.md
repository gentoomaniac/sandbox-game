# Villagers

Decided 2026-11-06 (task 84, the old QUESTIONS.md item 22, in the git history): the first step towards the people of
[ideas.md](ideas.md). For now villagers are put in the world with the
console (`spawn npc [count]`, or `spawn npc <id>` or just `spawn <id>`, near the player); they
are state and saved.
Task 86 (2026-11-06) added who they are, words from a language model and memory.

- **Who:** each villager draws a sex, a name and a look from a seed. Names are period North
  Frisian and Low German first names by sex (Hinrich, Jens, Boy, Momme, Ocke, Tete; Antje,
  Elke, Inken, Kerrin, Wiebke) and surnames (Jensen, Petersen, Thiessen, Nissen, Carstensen;
  the hand-written families are the Boysens, Ketels, Hansens, Paulsens and Lorenzens). The look is layers
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
  Danish king holds all Schleswig since 1721, the floods of 1634 and 1717). **Who knows what
  (task 129):** a villager knows the topics in `Npc.topics` (saved): those written by hand all of
  them, a made-up one none at first, only the base line of the system line (Wehlsbüll, the North
  Frisian coast, 1750). The prompt tells just the topics they know, full or cut down by provider as
  before, and leaves the village out when there are none. A made-up villager learns topics from
  others at meetings (a local or a newcomer who knows one teaches the first they lack, with a
  chance of 0.5 in `data/gossip.cfg`), see [gossip.md](gossip.md).
- **Who they are:** every villager has a sheet, told to the language model: age, trade,
  personality, background (the essentials of family and story; the dead are told only here),
  home, speech (the manner of talking, written so that it holds in any language: no English words
  to say, the user's "Aye." in a German talk), sample lines in their voice (they show the manner,
  not the language), people (family and close friends, each a villager by id with the kind and
  what they think of them), likes, wants (this year), day (where they are when), habits, avoids
  (what they don't know or won't talk about) and secrets (only hinted at). Nine are written by
  hand in `data/villagers.cfg` with a fixed look, spawned by id and once each: `antje` (Antje
  Boysen, a farmer's wife: the user's prompt example), her husband `hinrich` and their son `boy`;
  `momme` (Momme Ketels, a fisherman) and his daughter `inken`, Boy's sweetheart; `ocke` (Ocke
  Hansen, the miller) and his wife `gesche`, Antje's friend; and `kerrin` (Kerrin Paulsen, the
  late Deichvogt's widow), Gesche's aunt; and `trienke` (Trienke Lorenzen, the Höker, issue #10). Everyone a sheet names as kin or close friend is a
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
- **Trienke Lorenzen, the Höker (issue #10):** the ninth sheet and the keeper of the shop
  ([../economy/shop.md](../economy/shop.md)). The user's note was a story that fits the village, so
  she is an outsider who stayed, like Antje, and a widow, like Kerrin, with a trade that none of
  the eight has. **Born Trienke Matthiesen in Husum, 1709, a chandler's daughter** who grew up
  behind her father's counter among rope, tallow candles, salt and pins. At 25 she married **Nis
  Lorenzen, a carter of Wehlsbüll** who hauled the parish's butter, eggs and hides to the Husum
  market and brought back salt, iron, thread and tar: for fifteen years the village's shop in all
  but name. **Six winters ago Nis went through the ice of a ditch on the Husum road at night**,
  with his horse and cart. She had no land and a debt for the horse, and her brother Hark, who keeps
  their father's shop in Husum, offered her a room as his housekeeper. **She stayed** and put Nis's
  last load of salt, candles and thread on a board on the town square. That is why she keeps the
  stall: it is the only trade she knows, the village has no other shop, and going back to Husum as
  her brother's housekeeper is what she will not do. Her wish is a little shop with a door and a
  bell. Her secrets are the debt to her brother for the first stock, and a slate of salt and
  candles for the poorest that she does not mean to collect in full.
  **Ties to the eight.** **Kerrin Paulsen** spoke for her to the pastor and the parish so that she
  may keep a stall on the square, never mentioned it again, and orders the church's candles from her
  every Saturday: Trienke is a little afraid of her sharp eye and would do anything for her.
  **Antje Boysen**, a bride from the Geest herself, was the first to be kind to the Husum bride, four
  years after Antje's own arrival, and taught her hens and cows; Antje sells her eggs and butter at
  the stall, which is also why Antje has a second outlet than the Husum dealers. Both name her back
  as a `friend`, so **the `people` of Kerrin and Antje each got one line** (the format makes the
  sheets agree, see below); no other sheet changed. Her surname is now a family of the village
  sheet, so `Lorenzen` left the surnames of the made-up villagers in `data/npcs.cfg` (Thiessen is
  the new one).
- **Where:** each keeps near its anchor: the yard in front of the door of its home (below) if it
  has one, else of the nearest building or the nearest fireplace within 16 tiles of where it
  came, else that spot. It never walks further than 6 tiles from it (one outside the circle
  only walks back in). A villager with a house follows their day (issue #7, `ActivityUpkeep`,
  [routines.md](routines.md)): the place of the entry that is on becomes the anchor when they
  arrive, and the activity's radius the circle (`Npc.keep_radius`; an activity of standing keeps them
  still); between entries and for rain or the dark it is the yard of their house. One with no house
  keeps to the anchor as above.
  The activities that say `inside` (sleep, meals, work in a building, church; `data/activities.cfg`) take
  them in through the door of the building at the spot, where they stand in the room until the entry
  is over ([inside.md](inside.md)).
- **Home and workplace (task 228):** a villager's home is a building (`Npc.house`, saved), not a
  spot; the free text `home` of the sheet stays for the language model. A building type says how
  many may live in it (`residents` in `data/buildings.cfg`: a hall house 5, a fisher's hut 2, a
  shack 1, a barn none), and a house holds one household: the couple and their children, as the
  sheets' `people` name them (husband, wife, father, mother, son, daughter; `Households`). A made-up
  villager has no kin on a sheet, so they have a house to themselves. The anchor of a villager with
  a house is its yard; one whose house is taken down is free of it and keeps near where it stood. A
  villager's workplace is a building (`Npc.workplace`: the barn, the church, one's own house for the
  dairy, but never a house others live in, #69) or a spot with a name where there is no building
  (the landing at the sluice, a field), saved as a tile. The sheets of `data/villagers.cfg` name
  them by `home_building`, `workplace_building` (a building type) and `workplace_spot` (a name):
  when such a villager comes into the world (`spawn npc`), they get the house of the type where
  family of theirs lives, else the nearest one of the type with room, and as workplace their own
  house if it is of the type, else the nearest building of it they may work in, within `home_search`
  tiles (`data/npcs.cfg`). Where none stands they have none until given, and a spot has no place in the world until
  given. Wehlsbüll's nine are spawned at their doors when a new game builds the village, with the
  houses and spots of `data/village_plan.cfg` (`VillagePeople`; the mill house is no building type,
  so the plan names it as Ocke's and Gesche's house).
  Made-up villagers have neither at first. A sheet may also name `home_interior`, the map of the
  inside of its house (task 237, [routines.md](routines.md)). For what they do in a day it names
  `work_set`, `activities`, `skips` and `church_feasts_only` (a made-up villager has the set of
  their trade, the third entry of the trades of `data/npcs.cfg`; `VillagerActivities`, issue #7).
  The player gives and moves them with
  the console (`home` and `work`, `HomeCommands`) and the hammer's menu on a house (middle click on
  it with the hammer in hand: `BuildMode` asks, `HouseMenu` shows a `ChoiceDialog` of
  `Households.offers`: the villagers within `give_reach` tiles that the house may hold, "Give to
  ..." or "Move ... in", then "... works here"). A routine (task 239) asks the villager for their
  home's door (`house.door_tile()`) and their workplace's spot (`Workplace.spot()`).
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

- **Saved:** the house and the workplace as references to buildings by their origin, a spot by
  name and tile (version 39; an older save has none); name, sex, look, who they are (id, age, trade, personality, background, habits;
  save version 19; the rest of the sheet, version 23), the chat's kept lines (version 17), the
  memories, the lines that dropped out and wait for their memory (version 21), so none is lost
  when the game is saved while a summary is asked for, and how many of the oldest kept lines a
  version 20 memory already holds (they drop out without a second summary); what a villager is
  doing, and an answer still owed, are not. The file wins for a villager written by hand (decided
  2026-11-07, as the user will edit the sheets): a loaded one takes their sheet from
  `data/villagers.cfg` as it is now, and the saved sheet only stands in when their id has left
  the file. A version 22 made-up villager is made up anew from the tables by their name (the old
  tables had "Says Aye"), with another surname if theirs is now a family of the village sheet.
- **Their day:** a villager with a house follows a day of activities (default, or planned by the
  model for the villagers nearest the player): [routines.md](routines.md), "Activities and the
  planned day".
- **Later:** intentions, NPC to NPC talk (see the ideas doc).
