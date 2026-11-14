# Economy and currency

**Planned, not decided.** This is a first draft for the user to change. Nothing here is built.
When the user has decided, the decided parts move into this folder as decisions, and the
tasks go onto the [project board](https://github.com/users/gentoomaniac/projects/2).

## The user's words

> "Economy and currency: you can trade with villagers small things, but shops buy and sell for
> currency. Your own little shopping trailer offers your own produce or goods and villagers
> occasionally buy it" (the user, 2026-11-08)

So there are three ways to turn what the player makes into something else:

1. **Barter** with villagers: small things for small things.
2. **Shops**: buy and sell for money.
3. **The player's own stall** (the "shopping trailer"): the player sets out goods, villagers
   come by and buy.

## What exists today

- There is no money and nothing to buy. Tools are given at the start; upgrades are meant to come
  from a smith "in a settlement" ([inventory-and-character.md](../player/inventory-and-character.md)).
- Seeds come from the console (`give`) and one seed comes back with each harvest
  ([crops.md](../farming/crops.md)). "Until a shop exists" is the standing promise.
- The village sheet (`data/village.cfg`, the `[money]` topic) already tells every villager the
  prices of 1750: "People reckon in Mark and Schilling: 16 Schilling make a Mark, and 3 Mark a
  Reichstaler." A pound of butter is 4 Schilling, a dozen eggs 2, a loaf of rye bread 1, a measure
  of shrimp 2, a pot of beer 1, a glass of brandy 2. A farmhand earns about 6 Schilling a day at
  the harvest, a maid 12 Mark a year, a milk cow costs about 30 Mark and a sheep about 6.
  **The game's prices must agree with these**, or the villagers will contradict the shops.
- The same sheet says: "There is no smith, doctor or shop in Wehlsbüll: those are in Husum."
  Who trades in Wehlsbüll is below.
- The ideas pages mention an NPC smith, bulk orders for a reward, a baker who buys surplus and
  butter as a trade good ([crafting/ideas.md](../crafting/ideas.md)).

## The currency

The village sheet already uses the Courant system, and so does the real history:

- The unit of account in the Duchies of Schleswig and Holstein in the 18th century was the
  **Mark Courant**: 1 Mark = 16 Schilling, 1 Schilling = 12 Pfennig, so 1 Mark = 192 Pfennig.
  A **Taler Courant** is 3 Mark = 48 Schilling. A Speciestaler (the silver taler of the king's
  realm) is worth 60 Schilling Courant, which is 3 3/4 Mark.
- The Courant reckoning came to the region from Hamburg and Lübeck (when exactly is not checked
  against a coin catalogue). A silver currency of its own for the Duchies, the
  *Schleswig-Holsteinischer Courant*, followed only in 1788. So around 1750 people reckon in Courant, but pay in whatever silver they
  have (Danish and Hamburg coin): the game just says Mark, Schilling and Pfennig.
- Small coins: a Schilling is two Sechslinge, a Sechsling two Dreilinge, a Dreiling is
  3 Pfennig.

Sources: [Kurantmark (Wikipedia, German)](https://de.wikipedia.org/wiki/Kurantmark) and
[Schleswig-Holstein speciethaler (Wikipedia)](https://en.wikipedia.org/wiki/Schleswig-Holstein_speciethaler).
These came from a web search on 2026-11-08 and were not checked against a coin catalogue; the
ratios agree with the village sheet.

**In the game:**

- The player's money is one whole number of **Pfennig**, so there are no rounding errors.
  It is shown as "2 Mark 5 Schilling" (and Pfennig when there are any): `M`, `ß`, `Pf` in
  short. It lives in the player's state, shown on the inventory screen (not the hotbar).
- A purse has no weight, as coins weigh little. Default: it doesn't count towards the carry limit.
- Item **values**: every item that can be sold has a `base` value in Pfennig in a
  `data/prices.cfg`, anchored on the village sheet's prices (butter 4 Schilling a pound = 48 Pfennig,
  and so on). The village sheet's `[money]` topic can later be made from this file, so it
  has one source.
- A start purse: 2 Mark, enough for a first bag of seeds. Default, open below.

## Barter

- Any villager at the level **Neighbour** or better ([relationships](../villagers/relationships.md))
  trades small things for small things. Strangers don't.
- "Small" is a cap of about 1 Mark (192 Pfennig) a deal. Nobody barters a cow.
- Both sides use the item values. A villager accepts if what they get is worth at least what
  they give. At **Friend** they accept up to a fifth less (a friendly deal); at **Cold** they
  don't trade.
- What they offer comes from their trade and their sheet: Antje butter and eggs, Momme smoked
  eel, Ocke flour, Gesche herbs, and so on. What they want is their `wants` and `likes`.
- It is done in a trade panel from the talk: two rows of items, a value on each side, and a
  button. The **game decides the numbers; the model only voices them** ("that's a fair
  swap, neighbour"), as the NPC ideas say the model proposes and the game disposes.
- Trading also counts a little as contact for the friendship (+5 a day).

## Shops

**Who sells and buys in Wehlsbüll** (a first reading of `data/village.cfg`):

| Who | Buys | Sells |
|---|---|---|
| **The Krug** (Tete and Telse Jacobsen, the inn by the church) | Eggs, butter, eel, shrimp, beer ingredients | Beer, brandy, a meal, news (a hint of what is wanted this week) |
| **The mill** (Ocke and Gesche Hansen) | Grain: rye, wheat, buckwheat; pays the sixteenth he keeps as his due in coin if asked | Flour |
| **A pedlar** (a Krämer who comes through, new) | Anything small and sells well in Husum | Seeds, salt, nails, thread, cloth, a few tools |
| **The smith and the market in Husum** (two hours south; not in the world yet) | Everything | Tools in tiers (copper, iron), nails, cloth, tools for the boat |

- Today the sheet says "no shop": the Krug and the mill are not shops, they are a place where
  things are had. Nothing in the sheet has to change if they are given a counter. The pedlar
  is a new person, and would be added to the village sheet as a visitor.
- **Husum** is not in the world (the world is a generated land, and the village is made of the
  villagers around the player). A first version has no trip to town: the pedlar *is* the market
  that comes. A trip by cart or boat, with the smith, is a later task.
- Shop keepers and the pedlar are villagers: they have sheets and chat, and their friendship
  matters for what they sell (below).

**Prices:**

- The shop **sells at 125 % of the base value and buys at 60 %**. Antje already grumbles that the
  Husum dealers "pay too little for butter": the gap is the reason to sell to people directly,
  by barter or from the player's stall (which pays 100 %).
- **Friendship** shaves the price: a Neighbour 5 %, a Friend 10 %, a Close friend 15 %, off what
  they sell and added to what they pay (never past the base value).
- **Seasons change prices.** A multiplier by season on each kind of good (first values):
  grain 0.8 in autumn after the harvest and 1.2 in spring; butter and eggs 1.2 in winter, 0.9
  in summer; fresh vegetables 0.8 in their season and 1.3 out of it; fish a little dearer in
  winter; salt, nails and cloth stay flat. A season is 30 days
  ([seasons-and-weather.md](../world/seasons-and-weather.md)).
- **The weather of last year** can move grain: a wet harvest makes it dear, as the village
  news already says. Later, and only if the first is liked: the crops' bad days over the
  year (the farming rules already count them) raise grain by up to a quarter the next year.
- A shop can't take everything: a **stock** and a **budget** per shop a day (the Krug takes
  six eggs a day, not sixty). It is back the next week. This keeps a field of turnips from
  being a gold mine.
- A price list is data: `data/prices.cfg` for values and season factors,
  `data/shops.cfg` for who stocks and takes what.

**Where seeds come from:**

- The pedlar sells seeds of what the land grows, by season (turnip, cabbage, carrot and peas
  in spring; rye and wheat in autumn), for 2 to 6 Schilling a bag (first values).
- Villagers give or swap seeds of their own crops by barter at the Neighbour level.
- The harvest still gives one seed back, so a farm can keep going without buying.
- The console's `give` stays for testing.

## The player's stall (the "shopping trailer")

The user calls it a shopping trailer. For 1750 it is a **hand cart with a board** (a
*Verkaufskarren*), or a **stall at the farm gate**. Both are the same placed object. The
word "trailer" is kept in the user's quote only.

- **Built** at the workbench (planks, wheels: a new recipe), placed like a chest, and it holds
  slots like a chest does. It is a station: it keeps its own goods and a till.
- **The player stocks it** and may set a price per slot. By default the price is the base
  value. A lower price sells faster, a higher one sells less.
- **Villagers come by** on days with fair weather, between morning and evening (not at night,
  not in storms), a few of them a day. Each visit is a roll:
  - the chance is the villager's **need** (what their trade or sheet wants: the cook wants
    flour, the fisherman wants rope; a made-up villager by trade) times a **friendship**
    factor (x0.5 for a Cold, x1 for Stranger, up to x2 for a Close friend);
  - they buy one to three things they need, at the price, if it is not over their *limit*:
    the base value plus a fifth (a bit more at higher friendship). A greedy price just
    gets a shrug, and an extra line they say;
  - a villager that likes something on the stall buys it with a bigger chance (the same lists
    as for gifts).
- **The takings** go into a **till** on the cart that the player empties by hand (use key), so
  sales don't happen into a purse the player isn't looking at. Goods can't be stolen, and
  the till is the cart's own.
- **While the player is away:** the day is rolled in one go at the time of day, from a seed
  that is fixed by the day, so it is the same on a reload. Default: sales happen whether
  or not the player is near, and a villager is shown at the cart only when the player is.
- **Friendship gets a bonus:** a sale is a small contact (+3), a **needed** sale to a villager
  who was waiting for it +10. A villager may mention what they bought the next time they talk.
- **It is seen:** the villager's prompt may be told "bought flour from the neighbour's cart
  yesterday" as a deed (the same list as for [relationships](../villagers/relationships.md)).

## How money is saved

- The purse (one whole number of Pfennig) is saved with the player: a save upgrade, as the game
  keeps the last ten versions, adds it as 0 to older saves or as the start purse if the user
  would rather give old saves a first purse.
- A cart's slots, prices and till are saved with it, like a chest and its contents, in the
  world edits.
- Each shop's stock for the week and its budget are saved with the world's clock state, so a
  reload does not give back a sold-out shop.
- Item values and the shops are data files, read at the start, as the other data is.

## Console

`money <Pfennig>` sets the purse; `give` works as before; `nocost` should also make shops free.

## Open questions

Each has the default that the work would go ahead with.

1. **Currency: Mark Courant, Schilling, Pfennig, as above?** Default: yes, held as Pfennig.
2. **Does the player start with money?** Default: 2 Mark.
3. **Who sells in Wehlsbüll?** Default: the Krug and the mill get counters, a pedlar
   comes by (a new visitor), and there is no Husum trip yet.
4. **Where do seeds come from?** Default: the pedlar by season, barter with neighbours, and
   the harvest's own seed.
5. **Buy and sell ratio:** shops sell at 125 % and buy at 60 %? Default: yes.
6. **Do seasons and last year's weather change prices?** Default: seasons yes; the weather
   effect later.
7. **Barter: from Neighbour on, up to 1 Mark a deal?** Default: yes.
8. **The stall: a cart that is placed, with a till, sales rolled by the day whether or not the
   player is near?** Default: yes.
9. **Can the player set prices?** Default: yes, a price per slot; the base value by default.
10. **Do villagers have money?** Default: no purses: a villager buys within a need and a
    limit, and the shop's own budget stands in for the rest.
11. **Do wages or rent exist** (the clerk comes for dues at Martinmas, the village sheet says)?
    Default: no, not in the first version. It would be a good money sink later.
12. **Is a first version without Husum and the smith enough?** Default: yes; tool upgrades stay
    a later task with the smith in town.
