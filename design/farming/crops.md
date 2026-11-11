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
    Clamping hour by hour is not the nightly clamp: soil that is already soaked loses the early
    rain of a day and then dries. The whole tile's brown shows it in four
    steps: light brown when dry, dark brown when soaked, lightening day by day as it dries.
    Where a tile is wetter than a tilled neighbour, its brown fades out into the neighbour over
    a few pixels, at the sides and the corners (the user, 2026-11-10, task 167); between tiles
    as wet there is no edge, and the bed's rim against the turf stays as it is.
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
  - Until a shop exists, seeds come from the console (`give`), and a harvest still gives
    one seed back.
- Wild crops can be foraged.
- The biome decides which resources are available and what the land is good for
  agriculturally (see [Biomes](../world/generation.md)).
