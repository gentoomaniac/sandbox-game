# The shop: a keeper who keeps hours and trades

[#10](https://github.com/gentoomaniac/sandbox-game/issues/10) (task 240). **Approved by the user
(issue comment, all defaults); built step by step, steps 1 to 4 so far** (each step's note below says what
changed from the plan). It is the first step of the economy draft in [README.md](README.md),
and it is built to carry [#11](https://github.com/gentoomaniac/sandbox-game/issues/11) (seeds from
the shop) with data alone. Needs the village (#9) and the routines (#7), both built.

What the plan rests on:

- There is **no money, no friendship and no price list** in the game yet. The shop is barter by
  value and needs none of them (it uses `data/shops.cfg` only). Friendship's price cut and the
  purse come later and change numbers, not the dialog.
- **#8 (villagers go through doors) is not built.** I assume the keeper stands **outside, at a
  stall**. The trade needs only "the keeper's entry is `keep_shop`, they have arrived, and the player
  is within reach on the same map", so a counter inside a building later is a change of data (a
  `workplace_building` instead of the spot), not of code.
- **The language model is never needed** for a trade.

## Who, where

- **Who:** a **new hand-written villager, Trienke Lorenzen** (`trienke`), a Höker, a small village
  shopkeeper, widow, about 41. None of the eight fits: each has a trade that is not shop-keeping
  (Ocke grinds, the Boysens farm), and the Krug has no keeper in the file. A ninth sheet is one
  section in `data/villagers.cfg`; the other sheets need no change (she names no `people`, so
  nobody has to name her back).
- **Where:** a **stall on the town square** (`square`, kept free "for a future market", #76), not in
  a building: the village plan has no shop and no type fits (`longhouse` stands in for the Krug
  and nobody goes in). A new world object `market_stall` (a counter with an awning, 2x1 tiles,
  solid) stands on the square's Krug side, clear of `meeting_spot`. Her workplace is a **spot**,
  "the market stall", like the landing and the post mill: `workplace_spot` in her sheet, its tile
  behind the counter in `workplace_spots` of `data/village_plan.cfg`. She lives in a cottage the
  plan gives her (`residents=["trienke"]` on the empty `kate` nearest the square).
- The village sheet says "There is no smith, doctor or shop in Wehlsbüll" (`data/village.cfg`).
  It changes to "no smith or doctor", with a line that Trienke Lorenzen keeps a stall on the
  square, so no villager contradicts the shop.
- **Old worlds** have the village already, so they get no stall and no Höker; `spawn npc trienke`
  gives her sheet but she has no stall. New worlds only (open question 6).

## Shop hours: the routine

One activity in `data/activities.cfg`, in a new set `shopkeeper` (with `meet_at_the_krug`):

```
[keep_shop]
verb="keep the shop"
target="workplace"
doing="stand"
at=[["07:00", 300], ["13:00", 300]]
days=["weekday", "saturday"]
priority=6
fixed=true
```

- **7 to 12 and 13 to 18**, Monday to Saturday, with dinner (12:00) and supper (18:00) between.
  **Sunday closed**, for church (`go_to_church` is in `base`; Easter and Christmas are Sundays).
- It is open in the rain: the stall has an awning (no `needs_dry`), or seeds would be out of reach
  on exactly the days the farm needs them.
- **`fixed=true`** is a new key: the activity is in every day at its `at`, so the model's day plan
  may add to the day but never moves or drops it. Without it the model could move the keeper and
  the opening hours would no longer be the routine's. `DayPlanner` keeps fixed entries when it
  merges a plan.
- **The shop is open** when the keeper's entry now is `keep_shop`, they have arrived (not still on
  the way) and are not asleep or in a skip. **One source** for the hours: the routine. The line
  "opens at 7" reads the activity's next `at` start.

## The trading dialog

E on the keeper **in hours** opens the trade screen (the game pauses, like the chat and the
chest). E on the keeper **out of hours** opens the chat (below).

```
+--------------------------------------------------------------+
|  Trienke Lorenzen, the Höker                         [Talk]  |
|  "Open until 12, then again from 1."                         |
+------------------------------+-------------------------------+
|  SHE SELLS         price stock|  SHE TAKES          value room|
|  Turnip seeds        3 Pf  40 |  Egg                 1 Pf  12 |
|  Candle             20 Pf   6 |  Turnip              3 Pf  10 |
|  ...                          |  Fibre               1 Pf  20 |
|                               |  Logs                4 Pf  10 |
|                               |  ...                          |
+------------------------------+-------------------------------+
|  You get:  5 Turnip seeds  (15 Pf)                           |
|  You give: 8 Egg, 7 Fibre  (15 Pf)          [-] [+] per row  |
|  "Short by 5 Pf."                      [Cover it]  [Trade]   |
+--------------------------------------------------------------+
```

- Two lists with a `[-] n [+]` on each row. Left rows are what she sells (price, stock); right rows
  are what the player carries that she takes (value, room left today). Rows with nothing in the bag
  or out of stock are grey.
- A line below says what is wrong or right: "Short by 5 Pf.", "Out of seeds today.", "Your bag
  is full.", "She has no room for more eggs today.", "She keeps the 2 Pf over." `Trade` is on only
  when the deal is fair; the line says why not otherwise.
- `Cover it` fills the "give" side with the cheapest takable items from the bag until the goods are
  paid for. It is a help; the player may change the counts.
- Escape leaves. Keys and layout follow `StorageScreen`.

### Barter rules

- Everything has a **worth** in Pfennig (the unit of the economy draft, the village sheet's prices).
  In this step the worths are in `data/shops.cfg`; they move to `data/prices.cfg` when money comes.
- She **sells at 125 %** of the worth, rounded up, and **takes at 60 %**, rounded down (the draft's
  ratios). A deal is fair when the value given is at least the price of what is got. Whole Pfennig
  throughout, no fractions.
- **No change:** an overpayment is hers and the line says so (open question 4).
- **Refused:** not enough value; not enough stock; not enough room for what she takes; the player
  does not carry what they offer; what they get does not fit the bag once what they give is out.
  `ItemSlots.can_exchange` checks the last exactly and `exchange` is all or nothing, so a refused
  deal changes nothing.
- **What she sells and takes in #10** (first values, tuned in play; the range of seeds is #11's):

| She sells | Worth | Price | Stock (max) | Back each day |
|---|---|---|---|---|
| Turnip seeds | 2 | 3 | 40 | 10 |
| Candle | 16 | 20 | 6 | 1 |

| She takes | Worth | Value | Room a day |
|---|---|---|---|
| Egg | 2 | 1 | 12 |
| Berries | 3 | 1 | 12 |
| Turnip | 6 | 3 | 10 |
| Fibre | 3 | 1 | 20 |
| Reeds | 3 | 1 | 20 |
| Hay | 3 | 1 | 20 |
| Logs | 8 | 4 | 10 |
| Clay | 4 | 2 | 10 |
| Flour | 10 | 6 | 6 |
| Bread | 12 | 7 | 6 |

  The farm can always start again: **a seed costs 3 Pf, and a day's room for fibre and logs alone is
  60 Pf**, so a lost harvest still pays for 20 seeds the next morning with wood and fibre found
  anywhere. One turnip (3 Pf) pays for a seed, and a harvest gives two.

### What "stock filling up over the days" means

- Each good she sells has a `stock` (now) and a `max`; each day adds `restock` to it, up to `max`.
  Turnip seeds: 40 at most, 10 a day, so 40 can be bought at once and then 10 a day. The room for
  what she takes is **back to its full number each day** (a field of turnips is not a gold mine:
  10 turnips a day).
- It is worked out **when the shop is looked at, not by a daily tick**: `days = today - restocked_day`,
  `stock = min(max, stock + restock * days)`, `room = max room`. A skip of time, a long absence
  and a reload give the same stock, and nothing runs at night. A new shop starts full.

### `data/shops.cfg`

One `[shop.<keeper id>]` and a section for each good, read once at start by `ShopRules`, which
reports what is wrong (`problems`): an unknown item or keeper, a worth below 1, a `restock` over
`max`, a good both sold and taken.

```
[shop.trienke]
keeper="trienke"
; Percent of an item's worth: what she asks, what she gives for what she takes.
sell_percent=125
take_percent=60

[shop.trienke.sells.turnip_seeds]
worth=2
max=40
restock=10

[shop.trienke.sells.candle]
worth=16
max=6
restock=1

[shop.trienke.takes.egg]
worth=2
room=12
```

#11 adds the other crops' seeds as `sells` sections and changes no code (a seasonal range would be
an optional `seasons=[...]` key, added there if wanted).

## The keeper's lines

- **In hours:** E opens the trade screen. Its `[Talk]` button opens the chat as with anyone.
- **Out of hours:** E opens the chat, and the first line, said by the keeper before the player
  writes, is scripted from the clock: "The shop opens at 7." (the next start of `keep_shop`); on
  Sunday "Closed on Sundays, neighbour. Church." (in `data/npc_talk.cfg`, with the other scripted
  lines); while she is away at dinner, "Back at 1."
- If she is not at the stall at all (asleep, away) the usual talk applies and no line is added.

## With a language model

- She chats as any villager, from her sheet. Her prompt gets one more fact from the game: "Your
  stall is open / closed; it opens at 7" and the names of what she sells and takes today, so she can
  voice it without inventing stock.
- **The chat never trades.** The model neither sets a price nor moves an item: the screen does it,
  with the numbers of `shops.cfg` (the draft's rule: the game decides, the model voices). The
  scripted closed line is also what a missing or failed model falls back on.

## Saving

- A `shops` part of the game state: for each keeper `{"stock": {item: n}, "room": {item: n},
  "restocked_day": d}`. The shop's rules are data and not saved.
- A shop missing from the save (a save of before, a new shop in the data) starts full. **The save
  version is 47 now; this takes the next free one (48)** (check at the build): the upgrade step adds
  an empty `shops`, and the oldest step goes (see [../tech/saving.md](../tech/saving.md)).
- Trienke is a villager and saved as one. The stall is a placed object, saved with the world.

## Steps

Built so far: 1 (the shop hours: `fixed`, `keep_shop`, the set `shopkeeper`; the model is not offered a
fixed activity), 2 (the stall, `WorldObjectVillage`, its art is a placeholder), 3 (Trienke's sheet and
story, [../villagers/villagers.md](../villagers/villagers.md); her `people` name Kerrin and Antje, who
name her back), 4 (`ShopRules`, `data/shops.cfg`).

Each is a commit that passes `make test` and `make lint`, with its tests and doc lines. Steps 1 to 3
are the keeper and need no trade; 4 to 8 are the trade.

1. **`fixed` and the shop hours.** The key in `ActivityRules` and the header of
   `data/activities.cfg`; `keep_shop` and the set `shopkeeper`; `DayPlanner` keeps fixed entries.
   Tests: the rules' `problems`; the default day on a weekday, Saturday and Sunday; a model plan that
   leaves the activity out still has it. Docs: routines.md (the format, the sets).
2. **The stall.** The world object type `market_stall` and its art (pixel-artist), placed by the
   village only. Tests: the catalogue check; the footprint is solid. Docs: the objects page.
3. **Trienke.** Her sheet in `data/villagers.cfg`, the cottage `residents`, the stall on the square
   and `workplace_spots` in `data/village_plan.cfg`, the village sheet's line. Tests: `VillagerRules`
   and `VillagePlan` `problems` pass; a built village has her at her door with the stall's spot as
   workplace; she stands at the stall on a weekday at 8:00 and is at church on Sunday. Docs:
   wehlsbuell.md (the tables, "Who"), villagers.md.
4. **`ShopRules` and `data/shops.cfg`.** The file and its `problems`. Tests: the file is clean; each
   kind of fault is reported. Docs: the file's header, this page.
5. **`Shops`: stock, restock and the trade.** Pure state: the quote, the trade, the lazy refill.
   Tests: a trade; a refused one for each reason of "Refused", with nothing changed; the refill
   after 1, 3 and 9 days and after a skip; an overpayment kept. Docs: the economy README's first step.
6. **The trade screen.** `TradeScreen` as in the sketch, opened by a console `shop` command for now
   (in its own file like the other commands; `shop restock` fills the stock). Tests: rows, counts,
   the line's texts, `Cover it`, the button's state, Escape. Docs: console.md, menus-and-hud.md.
7. **E on the keeper.** In hours E opens the screen, out of hours the chat with the scripted line;
   the prompt's fact for a model; `Talk` switches to the chat. Tests: open, closed, Sunday, at dinner,
   a model's prompt; a trade works with no model. Docs: dialogue.md.
8. **Saving.** The `shops` part and the upgrade to the next free version. Tests: save and load of a
   half-sold shop; a save of the version before loads with a full shop. Docs: saving.md.
9. **The handbook and the economy page.** A handbook page on the Höker (where, hours, what she
   takes); the economy README marks its first step built and its "until a shop exists" lines point
   here. Play-test: the keeper at the stall in the rain; a lost harvest paid in fibre and logs. #11
   then adds seeds as data.

## Open questions

Each has the default the work would go ahead with.

1. **Who keeps it:** a new Höker, Trienke Lorenzen? Default: yes.
2. **Where:** a stall on the town square, not a building? Default: yes.
3. **Hours:** 7 to 12 and 13 to 18, Monday to Saturday, open in the rain? Default: yes.
4. **Overpayment:** she keeps the difference, no change? Default: yes (`Cover it` avoids it).
5. **Ratios:** sells at 125 %, takes at 60 %, worths in `shops.cfg` until money has a `prices.cfg`?
   Default: yes.
6. **Old saves:** no keeper and no stall in worlds built before this? Default: yes.
7. **The model's plan can't move her hours (`fixed`)?** Default: yes.
8. **First range:** turnip seeds and candles, the rest of the seeds in #11? Default: yes.
