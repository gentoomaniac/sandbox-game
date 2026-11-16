# Economy and currency

**Decided (the user, 2026-11-15, [#49](https://github.com/gentoomaniac/sandbox-game/issues/49)):
every default of the draft stands except the currency, which is Schilling only, in whole numbers.
The build is planned below, nothing of it is built.** When a step is done, its part moves to the
pages of this folder as "as built", as [shop.md](shop.md) does for #10.

## The user's words

> "Economy and currency: you can trade with villagers small things, but shops buy and sell for
> currency. Your own little shopping trailer offers your own produce or goods and villagers
> occasionally buy it" (the user, 2026-11-08)

> "All default but the currency: feels too complicated, make it Schilling only for simplicity.
> And whole numbers only" (the user, 2026-11-15)

So there are three ways to turn what the player makes into something else:

1. **Barter** with villagers: small things for small things.
2. **Shops**: buy and sell for money.
3. **The player's own stall** (the "shopping trailer"): the player sets out goods, villagers
   come by and buy.

## What exists today

- There is **no money**. The shop of #10 ([shop.md](shop.md), Trienke Lorenzen's stall) is **barter by
  value**: every good has a `worth` in Pfennig in `data/shops.cfg`, she sells at `sell_percent` (125)
  of it rounded up and takes at `take_percent` (60) rounded down, and a deal is fair when what the
  player gives is worth at least what they get. `ShopRules` (`game/state/shop_rules.gd`) holds the
  numbers, `ShopQuote` the result of a deal, `TradeScreen` shows it in "Pf".
- The worths today: seeds 2 to 5, egg 2, berries, fibre, reeds and hay 3, clay 4, turnip 6, logs 8,
  flour 10, bread 12, candle 16.
- **Quests are not barter** (#12, [../villagers/quests.md](../villagers/quests.md)): their rewards are
  items the shop does not sell (wax) or the seeds of the first help, and goodwill. They carry no price.
- The village sheet (`data/village.cfg`, topic `[money]`, lines 66 to 70) tells every villager that
  "People reckon in Mark and Schilling: 16 Schilling make a Mark, and 3 Mark a Reichstaler", with the
  prices of 1750 (butter 4 Schilling a pound, a maid 12 Mark a year, a cow 30 Mark). Hinrich Boysen's
  speech "names prices in Schilling and Mark", and two lines of speech name a Schilling price
  (Momme's shrimp, Trienke's candles). **These disagree with the shop**: her candle costs 20.
- The ideas pages mention an NPC smith, bulk orders, a baker who buys surplus and butter as a trade
  good ([crafting/ideas.md](../crafting/ideas.md)).

## The currency

**One unit: the Schilling.** No Mark, no Reichstaler, no Pfennig, no fractions.

- The player's money is **one whole number of Schilling**, the *purse*. Every price, value, deal and
  till is a whole number of Schilling.
- Shown as "32 Schilling" in text and "32 ß" in short (the old sign of the Schilling). The purse is
  on the inventory screen, not the hotbar.
- A purse has no weight and doesn't count towards the carry limit.
- **Start purse: 32 Schilling.** It buys the ten turnip seeds the first quest gives (3 each, 30
  Schilling), so the player can start a farm either way and is not rich for it. It is the 2 Mark of
  the draft (32 Schilling in the old count) and so keeps its number.
- **The game's Schilling is a game unit, not the one of 1750.** The old prices (a dozen eggs 2
  Schilling) make a single egg a sixth of a Schilling, which can't be a whole number. So the worths
  of the shop keep their numbers and only change their name: **what was a Pfennig is now a
  Schilling**. An egg is 2 Schilling, a loaf of bread 12. The ratios between goods are those of the
  village sheet, the size of the unit is not. Once the lore drops the Mark (below), nothing in the
  game states a historic rate that this could contradict.

### Why the worths keep their numbers

A shop sells at 125 % rounded up and takes at 60 % rounded down. For a worth:

| Worth | Sells at | Takes at | | Worth | Sells at | Takes at |
|---|---|---|---|---|---|---|
| 1 | 2 | **0** | | 6 (turnip) | 8 | 3 |
| 2 (egg, seeds) | 3 | 1 | | 8 (logs) | 10 | 4 |
| 3 (berries, fibre) | 4 | 1 | | 10 (flour) | 13 | 6 |
| 4 (clay) | 5 | 2 | | 12 (bread) | 15 | 7 |
| 5 | 7 | 3 | | 16 (candle) | 20 | 9 |

- **A worth of 1 sells but can't be taken**: 60 % of 1 rounds down to 0, so a shop would accept a
  good and pay nothing. The rule: **a good the shop takes has a worth of at least 2**, a good it
  sells at least 1 (the file check says so). Today's cheapest is 2, so no worth moves, and the
  cheapest thing costs at least 1 in every case.
- Cheap goods have a wide gap in whole numbers: an egg or a fibre costs 3 or 4 to buy and pays 1,
  so the shop keeps two thirds or three quarters, not 40 %. That is one more reason to sell to
  villagers and at the stall (100 %); the numbers stay whole and sensible, and the `room` keeps
  the volume small. A day's room of her raw goods is still worth more than the stock of any one
  seed costs (the test of #11 checks it and is re-run on the table).
- **Seeds are sold singly** (worth 2 to 5, price 3 to 7). Nothing is below 1, so no bundle is
  needed now. If a later seed is worth less than 2, it is sold in a **bundle** (one item of
  several seeds), never as a fraction.
- A smaller scale (worths 1 to 3) was weighed and rejected: at 60 % every cheap good would pay 0
  or 1. The old Schilling (worths times 12) would make a seed cost 36 and the start purse 384.
- **Percent changes round once, at the end.** A friendship cut or a season factor is applied to the
  percentage first, then the price is rounded in the keeper's favour (up when she sells, down when
  she buys, as now). So every price is whole, never below 1 and never past the full price.

## The value table, and where it lives

A new **`data/prices.cfg`**, one source for what a thing is worth:

```
[worth]
egg=2
turnip=6
...
[friendship]          ; step 10: the cut in percent by benefit level
[seasons.<kind>]      ; step 11: a factor in percent by season for a kind of good
```

- `[worth]` maps an item of the game (the names of `game/state/item_types.gd`) to a whole number of
  Schilling, from 1. Every item that can be bought, sold or bartered has one. An item with none
  cannot be traded (the check reports a shop good with no worth).
- **`data/shops.cfg`** keeps what is the shop's own: the keeper, the percentages, the stock (`max`,
  `restock`) and the `room`. Its `worth` keys **move to `data/prices.cfg`**, so barter, the stall
  and every shop use the same table.
- A new `Prices` class (`game/state/prices.gd`, plain state, no scene) reads the file with the
  checks the other rules have, and `ShopRules` asks it for a worth.
- The village sheet's money topic is **written by hand** from the file for now; a test keeps them
  in line (step 1). Making it from the file is a later idea.

## From barter to money: the shop of #10

The trade screen keeps its two sides (what you get, what you give) and gains the purse:

- **A deal is a price and a value.** The price is what she asks for what the player gets, the value
  is what she gives for what the player brings (both from the file, both whole). The **difference is
  paid in coin**: if the value is less than the price, the player pays the rest from the purse, and
  the deal is refused with "Short by N Schilling" when the purse can't; if the value is more,
  **she pays the rest in Schilling**, where today she keeps it (`keeps` of `ShopQuote` becomes the
  coin she pays).
- So the player can **sell for money** (give eggs, get nothing, receive coin) and **buy with money**
  (get seeds, give nothing, pay coin), and the mixed deal still works. The rows, the `room`, the
  stock, the hours and the keeper don't change.
- She has **no purse of her own** (the draft's default: no purses for villagers). The `room` per day
  is what keeps a field of turnips from being a gold mine, as it did for barter. A coin budget of
  her own is open question 4.
- `ShopQuote` speaks Schilling ("Short by 8 Schilling", "She pays you 3"), `TradeScreen` shows "(15 ß)"
  and the purse, the handbook page and [shop.md](shop.md) follow. `nocost` makes shops free.

## How quest rewards relate

A quest still pays **items and goodwill, no coin** (default). The play-test table of
[quests.md](../villagers/quests.md) is re-worded in Schilling and its numbers do not change: 5 fibre
are 5 Schilling at her rate (1 each), the 10 turnip seeds cost 30 there, wax is not sold and a candle
costs 20. So **no quest is a better deal than the stall**, as #12 already asserts, and no quest
needs money to be done. A coin reward (`reward.schilling`, a whole number from 1) is open question 3.

## Barter with villagers

- Any villager at the level **Neighbour** (5) or better trades small things for small things: the
  benefit `barter` of [relationships](../villagers/relationships.md), asked as
  `FriendshipRules.allows("barter", level)` and never by a number. Below it they don't.
- "Small" is a cap of **100 Schilling** a deal (the draft's one Mark, as a round number). Nobody
  barters a cow.
- Both sides use the value table. A villager accepts if what they get is worth at least what they
  give; at Friend (7) they accept up to a fifth less; the levels without `trade` (below 3) don't
  trade at all.
- What they offer comes from their trade and sheet (Antje butter and eggs, Momme smoked eel, Ocke
  flour, Gesche herbs); what they want is their `wants` and `likes`.
- It is a trade panel from the talk. **The game decides the numbers, the model only voices them.**
  Trading counts as a little contact for friendship (+5 a day).
- Barter has no coin: a villager has no purse, so where the values differ the player adds items.

## Shops

**Who sells and buys in Wehlsbüll** (the draft's default, it stands):

| Who | Buys | Sells |
|---|---|---|
| **Trienke Lorenzen**, the stall (built, #10) | Raw goods, flour, bread | Seeds, candles |
| **The Krug** (Tete and Telse Jacobsen) | Eggs, butter, eel, beer ingredients | Beer, brandy, a meal, news |
| **The mill** (Ocke and Gesche Hansen) | Grain | Flour |
| **A pedlar** (a Krämer, a new visitor) | Anything small that sells in Husum | Salt, nails, thread, cloth, a few tools |

- The Krug and the mill get counters (data and a keeper each, as Trienke has). The pedlar is new,
  added to the village sheet as a visitor. **No Husum trip yet**: the pedlar *is* the market that
  comes. The smith and the tool tiers are a later task.
- Each is a `[shop.<id>]` in `data/shops.cfg`; the code is that of #10.

**Prices:**

- **Sells at 125 %, buys at 60 %**, rounded in the keeper's favour (above).
- **Friendship** shaves the price by the benefit `better_prices` (level 6, Good neighbour): 5 % at
  6, 10 % at 8 and 15 % at 9, off what they sell and added to what they pay, never past the worth.
  This replaces the draft's levels, which predate the ten of
  [relationships](../villagers/relationships.md). The percentages go into `[friendship]` of
  `data/prices.cfg`. `best_wares` (9) adds goods.
- **Seasons change prices**: a factor by kind of good in `[seasons.<kind>]` (grain 80 % in autumn
  and 120 % in spring; butter and eggs 120 % in winter and 90 % in summer; fresh vegetables 80 % in
  their season and 130 % out of it; fish a little dearer in winter; salt, nails and cloth flat). A
  season is 35 days ([seasons-and-weather.md](../world/seasons-and-weather.md)). The factor is
  applied to the worth and rounded to the nearest whole, never below 1 (2 for a good she takes).
- **The weather of last year** moving grain is later, if the first is liked; not in this plan.
- A shop can't take everything: the `room` and `max` of #10 stay.

**Where seeds come from** (the draft's default, it stands): the shop sells them (#11), neighbours give
or swap them by barter, some are found wild, the harvest gives one back and the console's `give`
stays. Nothing new is built for it. The pedlar by season of the draft is dropped, as Trienke sells
seeds all year.

## The player's stall (the "shopping trailer")

A **hand cart with a board** (a *Verkaufskarren*), or a stall at the farm gate: one placed object.

- **Built** at the workbench (a new recipe: planks, wheels), placed like a chest and holding slots
  like one, with a **till**.
- **The player stocks it and sets a price per slot**, a whole number of Schilling from 1. By default it
  is the worth. The stall **pays 100 %** (shops pay 60 %).
- **Villagers come by** in fair weather between morning and evening, a few a day. Each visit is a
  roll: the chance is the villager's **need** (what their trade or sheet wants) times a friendship
  factor (x0.5 at Mistrusted, x1 at Stranger, up to x2 at Close friend). They buy one to three things
  they need if the price is not over their **limit** (the worth plus a fifth, rounded down, a little
  more at higher friendship); a greedy price gets a shrug and a line. What a villager likes sells with
  a bigger chance.
- **The takings** go into the cart's till, which the player empties by hand (the use key) into the
  purse. Goods can't be stolen.
- **While the player is away** the day is rolled in one go, from a seed fixed by the day, so a reload
  gives the same. Sales happen whether the player is near or not; a villager is shown at the cart
  only when the player is.
- **A sale is contact**: +3, a *needed* sale +10. A villager may mention it the next time, and the
  prompt may be told of it as a deed ([relationships](../villagers/relationships.md)).

## Lore: the village drops Mark and Reichstaler

**Built (step 1)**, with `tests/test_money_lore.gd`: the sheet's money topic names the worths of the
shop file (bread 12, egg 2, candle 16 and 20 at the stall) and no sheet or speech names another coin.
The plan of the change:

The default stands: **the village sheet and the speech lines no longer name coins the game lacks**,
or the model would talk of Mark that nobody can pay in. What changes (step 1):

- `data/village.cfg`, topic `[money]` (lines 66 to 70): "People reckon in Schilling", with prices in
  Schilling **as the game has them** (a loaf of rye bread 12, an egg 2, a candle 20 at the stall).
  The line of the Mark and Reichstaler, the maid's 12 Mark a year and the cow at 30 Mark go. The
  farmhand's day wage goes too, as nothing pays wages (it comes back if wages come). The miller's
  sixteenth stays.
- `data/villagers.cfg`: Hinrich's speech loses the Mark; Momme's shrimp line has a price that agrees
  with nothing (shrimp is not in the game) and loses the number; Trienke's "Candles, a Schilling the
  pair" says the real price. Inken's "a few Schilling" and the made-up villagers of `data/npcs.cfg`
  ("a few Schilling") stand.
- A test reads the village sheet and the sheets and fails on the coin Mark, Reichstaler and Pfennig,
  so a later edit can't bring them back.

## How money is saved

The current save VERSION is 52 and [#48](https://github.com/gentoomaniac/sandbox-game/issues/48)
takes 53, so **this work takes the next free number** (54 if #48 has merged first; look at
`SaveFile.VERSION` when the step starts, don't copy it from here) and **first drops the oldest
upgrade, as a commit of its own** titled `Save: drop the upgrade from version <N> (oldest read:
<N+1>)`, as `SaveFile` says.

- The purse is a whole number `money` in the player's part of the save. A save without it gets the
  **start purse of 32**: a world with seeds at 3 Schilling can't start with 0. The validator checks
  a whole number from 0.
- The till and the slot prices of a cart are saved with the cart in the world edits, like a chest.
- Each shop's stock and `room` are saved with the world's clock state, so a reload doesn't refill a
  sold-out shop (Trienke's are saved already; the new shops use the same).
- `data/prices.cfg` and `data/shops.cfg` are read at the start like the other data and are not saved.

## Console

`money <Schilling>` sets the purse; `give` works as before; `nocost` makes shops free.

## Build steps

Each step is one atomic commit with its tests and docs, passes `make test` and `make lint` on its own
and can be reverted on its own. Steps 1 to 8 are the first part (money and the shop), in this
order; 9 to 15 follow and are named with what they wait for.

1. **The lore drops Mark and Reichstaler.** The village sheet's money topic and the speech lines
   above, with prices as the game has them. Tests: no sheet or speech line names the coin Mark,
   Reichstaler or Pfennig; the prices the sheet names equal the worths of the shop file. Docs: this
   page, [shop.md](shop.md).
2. **Save: drop the upgrade from the oldest version.** A commit of its own, titled as `SaveFile`
   says, with the constants and helpers only it used and its tests. It comes before the step that
   raises the version, whatever number #48 has taken.
3. **The unit is the Schilling.** "Pfennig" and "Pf" become Schilling and "ß" in `ShopRules`,
   `ShopQuote`, `TradeScreen`, the comments of `data/shops.cfg`, the tests and the
   [handbook page](../../handbook/shop.md). No number changes. Tests: the existing ones, with the new
   words. Docs: [shop.md](shop.md), [menus-and-hud.md](../presentation/menus-and-hud.md).
4. **`data/prices.cfg` and `Prices`.** The `[worth]` of every good moves out of `data/shops.cfg`;
   `ShopRules` reads it from `Prices`; the file check reports a good with no worth, a worth below 1
   and a taken good below 2. Tests: the file, each check, the shop's prices as before, the rounding
   table above. Docs: this page, [shop.md](shop.md).
5. **The purse and its save.** A `Purse` of whole Schilling in the player's state, the start purse
   of 32, the save (the next free VERSION, its upgrade step and test, the validator) and `money` in
   the console. Tests: add, spend, never below 0, the start purse, a save without it loads with
   32, the validator. Docs: [../tech/saving.md](../tech/saving.md),
   [../presentation/console.md](../presentation/console.md).
6. **The purse is shown.** On the inventory screen, "32 Schilling". By hand with `make run`. Docs:
   [menus-and-hud.md](../presentation/menus-and-hud.md).
7. **The shop deals in coin.** `ShopQuote` and `ShopRules.quote` with the purse: the player pays a
   shortfall, she pays an excess, "Short by N Schilling" when the purse can't; the trade screen
   shows the purse and the coin. Tests: pay, receive, refused, coin only on either side, the room
   and stock as before, `nocost`. Docs: [shop.md](shop.md), the handbook page.
8. **Quest rewards in Schilling.** Text only: the play-test table of
   [quests.md](../villagers/quests.md), and a test that the rewards of the quest files are worth
   less to the stall than the work (re-run on the table). No code, unless the coin reward is wanted
   (question 3).
9. **Barter with neighbours.** A trade panel in the talk for `allows("barter", level)`, the cap of
   100, the rule of values, the offers from the sheets. After steps 1 to 9 of
   [relationships](../villagers/relationships.md#build-steps) (the benefits). Tests: a fair and an
   unfair deal, the cap, the level, the friendly fifth, the contact. Docs:
   [../villagers/dialogue.md](../villagers/dialogue.md), this page.
10. **Friendship in the price.** `better_prices` and `[friendship]` of `data/prices.cfg`, applied once
    before rounding. After step 10 of relationships, which builds `better_prices` in the shop and
    sets the level; this step gives it its percentages. Tests: each level, the rounding, never past
    the worth. Docs: [shop.md](shop.md).
11. **Seasons in the price.** `[seasons.<kind>]` and a kind for each good, applied to the worth.
    Tests: each season, a flat good, the minimum. Docs: this page.
12. **The stall's cart.** The object and its recipe, the slots with a price each, the till and the
    use key. Tests: the price rules, the till, the save in the world edits (a save version of its
    own). Art with the labels `art` and `needs-verdict`. Docs: this page,
    [../crafting/crafting.md](../crafting/crafting.md).
13. **Villagers buy at the cart.** The daily roll from a seed fixed by the day: need, friendship,
    limit, likes, the contact and the deed. Tests: a fixed seed, an away day equals a present day,
    bad weather, over the limit. Docs: this page.
14. **The Krug and the mill get counters.** Two `[shop.<id>]` with their keepers; the stock needs
    items that exist. Tests: the file checks and a day's trade. Docs: [shop.md](shop.md),
    [../villagers/villagers.md](../villagers/villagers.md).
15. **The pedlar.** A new visitor and a shop of salt, nails and thread. Tests: his stay, his shop.
    Docs: the village sheet and [../villagers/villagers.md](../villagers/villagers.md).

Not planned: Husum and the smith, wages and rent, purses for villagers, the weather's effect on
grain.

## Open questions

The answers of 2026-11-15 settled the draft's twelve (all defaults but the currency). These are
new ones, each with the default the work goes ahead with.

1. **Is the game's Schilling a game unit** (an egg 2, a loaf 12), and not the real one of 1750? Default:
   yes, the ratios of the village sheet and not its size.
2. **Does the start purse of 32 Schilling stand?** Default: yes (30 buy the ten turnip seeds), and
   an old save is given the same.
3. **Do quests ever pay coin?** Default: no, items and goodwill only.
4. **Has a shopkeeper a coin budget** a day, beside the `room`? Default: no, the `room` is the cap.
5. **Is the cap of a barter deal 100 Schilling?** Default: yes.
6. **The short sign:** "ß", or "Sch."? Default: "ß" in short, "Schilling" in text.
7. **Is a good worth less than 2 sold in a bundle**, never as a fraction? Default: yes, when such a
   good comes.
8. **Does a villager's sheet need a price list of its own**, or only the shared table? Default: the
   shared table, with the sheet's `benefit_level` for prices.
