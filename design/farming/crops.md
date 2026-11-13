# Farming and foraging

- **Crops** (decided 2026-11-05, extended the same day): classic crops beside the
  turnip, all defined in a hand-editable data file (`data/crops.cfg`).
  - **One picture sheet per crop** (`assets/crops/<crop>.png`): 4 growth stages and a
    dead stage, side by side. A new crop is a new section in the config plus its sheet;
    no code. The built-in crops' sheets come from the art generator.
  - First set: turnip, potato, carrot, cabbage, onion, wheat, peas (regrow), beans
    (regrow), flax, strawberries (regrow) and pumpkin.
  - **The grains of the Geest** (task 109, from the art review of 2026-11-08): rye, the hardy
    bread grain of the sandy Geest (cool weather, little water, stands the wind), and
    buckwheat, quick and warm, killed by frost. Neither is eaten raw; both are ground to flour
    like wheat, and buckwheat is fried into pancakes at the fire (task 115).
  - **Flax replaced tomatoes** (task 52; tomatoes weren't a farm crop here before the 19th
    century): a cool-weather fibre crop with sky-blue flowers, pulled up whole (no regrow).
    It yields a new `flax` item (flax stalks), not `fibre`: flax is a material of its own
    (retted and scutched it becomes linen fibre, a later crafting step), and every crop's
    produce is its own item built from `data/crops.cfg`, while `fibre` comes from bushes.
    Flax isn't food. Save version 7 turns tomatoes and tomato plants into flax and flax
    seeds wherever they are. Strawberries are the small wild kind, and the pumpkin is
    drawn as a small green garden squash (its id stays `pumpkin`).
  - **Seed sacks tell their crop at a glance** (task 52): each sack is tied with a string
    of the crop's colour, has the crop painted large on its front and a few of its seeds
    spilled in front.
  - **Seeds and crops sit in the middle of their tile** (the user, 2026-11-11, task 174): the
    sown seeds, the sprouts and the low crops are centred on it; the grown tall crops stand on
    its lower part, so they rise from their own tile.
  - **Crops need light, water and warmth to grow**, with the needs per crop in the
    config: a temperature range (minimum, best, maximum), the sunlight they need per
    day, the soil moisture they need, and how much wind they stand. Every game hour a
    crop grows by a 24th of how well its day met its needs (good days count fully, poor
    days partly, bad days not at all; changed 2026-11-10, before it was once a night, with
    the same totals) and moves to the next stage after enough growth. A crop is counted as
    a day older at midnight (decided 2026-11-10). It grows from the hour it is planted
    (decided 2026-11-10): planted at 15:00 it gets the rest of that day pro rata, so it
    ripens at 15:00 nine days later instead of at a midnight, and waits that much longer.
  - **Crops can die:** days without enough sun or water, frost below the crop's
    minimum, or wind above its tolerance (beans and flax are fragile, wheat bends)
    damage the crop; enough damage and it dies and shows its dead stage, which the empty
    hand or the hoe clears (default, the user may change; decided 2026-11-10): the tile is
    tilled soil again, ready to plant, and the player gets nothing. The hoe's swing costs what
    tilling costs, the hand's what picking costs. The scythe leaves a dead crop alone. Damage
    heals slowly on good days.
  - **Ripe crops must be harvested in time** (decided 2026-11-05): a ripe crop waits as
    many days as it took to ripen (since planting, or since it regrew), times its
    `ripe_wait_factor` in the config (1 for all crops for now). One day more and it
    withers: it dies, shows its dead stage and gives nothing. The player harvests by hand.
  - **Soil moisture** belongs to each tilled tile: rain wets it, the watering can fills
    it, and warmth, sun and wind dry it out, hour by hour (changed 2026-11-10, a 24th of a
    day's drying each hour; it is worked out when it is looked at, so a month passes quickly).
    An hour with rain doesn't dry at all, and its rain is the mean of the rain seen through
    the hour, not only at its start (task 175: the user saw soil dry out in the rain). An hour
    of the heaviest rain adds 0.2 (`rain_wets`, 0.1 before task 175), so two hours soak fresh
    soil. The crops' needs stay: over a year of the camp's weather, unwatered soil is below a
    turnip's `moisture_min` on 75 of 120 days (84 before) and still near dry all summer, so
    watering stays the player's work in dry spells. After an hour with at least a light rain
    (0.1) the soil's surface is wet: it looks a step darker than its moisture until a dry hour
    has passed (`SoilWetness.RAIN_WETS_SURFACE_FROM`), so the rain shows on the soil within the
    hour, while the crops only know the moisture.
    Clamping hour by hour is not the nightly clamp: soil that is already soaked loses the early
    rain of a day and then dries. The whole tile's brown shows it in four
    steps: light brown when dry, dark brown when soaked, lightening day by day as it dries.
    Where a tile is wetter than a tilled neighbour, the line between their browns is the edge of
    a wet patch: it wanders across the tile edge, blotchy, steps through the browns between,
    runs on along the patch and rounds off its corners, so wet tiles read as a patch and not as a
    square (the user, 2026-11-11, task 175; it replaced the dithered fade along each side of task
    167); between tiles as wet there is no edge, and the bed's rim against the turf stays as it is. The bed itself
    comes to a pixel or two of its tiles' edges, ragged, its corners softly rounded (the user,
    2026-11-11, task 174).
  - **Fallow soil grows over** (the user, 2026-11-10, task 166): tilled soil with nothing on
    it (no crop, living or dead, no sapling or placed object, no building) that nobody tends
    comes up in a few weeds and grass tufts after `fallow_weedy_days` (5) and is grass again after
    `fallow_grass_days` (10), counted at midnight; the days of winter don't count
    (`fallow_rests_in_winter`), all in `data/crops.cfg` (defaults to be confirmed by the user).
    Hoeing (the hoe hoes the weeds away), sowing, planting, harvesting, clearing and watering
    tend the tile and the count starts anew; so does anything standing on it, so a planted tile
    never grows over. It goes back to grass, the one ground a hoe tills, with the look its place
    has (lush, dry); items lying on it stay. Saved, and seen to in loaded and unloaded chunks
    alike.
  - The calendar no longer gates planting: the weather does. Seeds plant on tilled soil
    any time; a crop planted in the wrong season simply won't thrive.
  - Each crop has its own seeds (a seed bag item, seed potatoes for potatoes) and its
    produce item; produce can be eaten (food values in `data/energy.cfg`).
  - Until a shop exists, seeds come from the console (`give`), and a harvest sometimes gives
    one seed back.
  - **Harvests vary** (the user, 2026-11-11, tasks 178 and 197: "carrots give mostly 2, rarely
    only 1 or 3"): each crop has a usual `yield`, and each harvest of a plant has the chance
    `poor_harvest_chance` of one less (never below 1, so a crop of 1 has only good harvests) and
    `good_harvest_chance` of one more. Both default to 0.15 in `[farming]` (70 % of plants give
    the usual amount) and a crop section can override them. The usual counts: turnip, onion, carrot,
    buckwheat, peas, beans and strawberries 2; potato, wheat, rye and flax 3; cabbage and pumpkin 1.
    A harvest also gives one seed back with the crop's `seed_chance`. Replanting only your own
    seeds shrinks a field by the harvests that leave none, so a crop with a chance of 0.6 keeps
    a field at about six tenths of its size each round: seeds have to be found or bought too.
    The grains and the pumpkin have the highest chance (0.7), the roots and flax 0.5 to 0.6,
    and the peas, beans and strawberries, which regrow and are picked again, 0.2. The dice are
    `GameState.harvest_rng`, seeded in tests; saves are not affected.
  - **Crows eat yield** (task 225): produce items the crows ate off a crop are kept in its state
    (`eaten`, saved with the crop; a save without it means none), come off every harvest and
    never take it below 1, so a crop with a yield of 1 can't be eaten off. A crop that regrows
    has new fruit.
  - **Crows raid the fields** (task 225, `CropRaids`, numbers in `data/crows.cfg`): every game
    hour each crow flock (the view tells `CropRaids` where its flocks stand) that has no player
    within 12 tiles raids with the chance 0.4, trying up to 2 of the living, unguarded crops
    within 3 tiles of it. A crop loses something by the chance of its growth stage (seed 0.5,
    young 0.15, grown 0.15, ripe 0.3): a seed is eaten whole (the plant is gone, the soil stays
    tilled), a later stage has one produce item eaten (`eaten` above). Caps per day for the whole
    world keep a field from being stripped: 2 plants and 6 items; the tally is not saved and
    starts again at a load. The dice are seeded by the world and the hour. Only crops of loaded
    chunks are raided: flocks stand near the player, so the crops of unloaded chunks are not. The
    hours of a skip of time pass like any, for the flocks standing then. The hook for the scarecrow (task 226) is
    `CropRaids.is_guarded`, a Callable from a tile to whether it is guarded; unset, nothing is.
    Fresh sowing draws crows: a flock appears `appearing_boost` times likelier near sown fields
    (0.1 more per crop at stage 0 within 6 tiles, up to 3 times). Console: `crows` shows the
    flocks and the tally, `crows raid` makes every flock raid now with the player by and eat from every crop it tries, `spawn
    crows [n]` puts flocks on the nearest crop (state only, until the view draws crows) and
    `killall crows` takes them away. No save version change: `eaten` is an optional
    number in the crop's state. The crows themselves: [wildlife](../world/wildlife.md).
- Wild crops can be foraged.
- The biome decides which resources are available and what the land is good for
  agriculturally (see [Biomes](../world/generation.md)).
