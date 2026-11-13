# Ambient wildlife

Decided 2026-11-05. Small animals that make the world feel alive. For now they are
atmosphere only: no player impact, not hunted, not saved.

- **Who and where:**
  - birds: hop and peck on open ground, fly off when the player comes close; small flocks
    cross the sky now and then (a shadow on the ground), in a V. They migrate (task 183): in
    autumn they fly south only, within 25 degrees of due south, in spring north only, in summer
    any way, and in winter there are none. They come twice as often in the middle two weeks of
    spring and autumn, and the season factor fades over 6 days either side of a season boundary
    (the factor is the mean of the two seasons at the boundary), so they thin out and return
    rather than stop and start. The greylag geese and the dunlin keep their own seasons and
    rules. A skein of flying geese migrates the same way, south in autumn and north in spring,
    and flies any way in winter, when they stay on the coast. A flock flying within 45 degrees of
    the screen's vertical shows its birds from the front (heading down) or from behind (heading
    up), further from it side on (task 220, `FlightView.HEAD_ON_DEGREES`), so migrating ones are
    always seen head on. Geese taking off from the ground (GroundFlock) follow the same rule
    (task 223); the oystercatchers, dunlin, gulls and storks have no front or back view and fly
    off side on. Head on, the V is wider across (`head_on_spacing`: 24 px for the
    sparrows, 44 for the geese), so that the spread wings of neighbours clear each other;
  - rabbits: grassland and forest edges, hop about, flee in zigzags from the player;
  - squirrels: forests, dart between trees, sit up, scurry off;
  - deer: rare, in forests and at forest edges, mostly at dawn and dusk; graze, look up,
    bound away when the player comes near;
  - bees: only at flowers in bloom, by day in spring and summer: one for every few tiles
    of flowers around the view (up to the cap), none where nothing blooms; they hop from
    flower to flower within a few tiles and fly off when none is left near (task 75);
  - butterflies: over meadows and flowers by day in spring and summer;
  - fireflies (task 135): the glow-worms of northern Germany (Lampyris and Lamprohiza), which
    fly from about June to mid July. In the game: summer (day 31 to 60), from the start of the
    dusk until 4 hours after sunset (past midnight in midsummer), up to 6 together, on grass, the
    floodplain and wetland within 3 tiles of a tree, a Knick or open water: over meadows, hedges
    and the edges of woods and water, not over open ground. They stay in for rain, a storm, fog,
    strong wind (above 0.3) and cold (below 10 degrees). Each drifts slowly in lazy curves,
    bobbing, and blinks: its point of light swells and fades every 2 to 4 seconds, with a real
    light over it (soft yellow-green, small radius) that shines as strongly as the other lights of
    the night (see [Look](../presentation/look.md)); in daylight it is a dim speck. They take no
    notice of the player. One is a 6x6 px sheet of three states (dark, glowing, brightest) in both
    art sets. `--wildlife=firefly` with `--day=45 --time=22:00` shows them. The rules have optional
    keys only fireflies use so far (`edge_radius`, `after_sunset_minutes`, `wind_limit`,
    `min_temperature`);
  - white storks (task 60): in spring and summer, by day only. They hunt on wetland, the
    floodplain and grass with open water within a few tiles (the wet meadows of the marsh),
    walking slowly with the head down and stabbing into the grass, and fly off with slow
    wingbeats and glides when the player comes near. Others fly in and stand on the ridge of a
    house near the view (one per roof; where they stand is read from the top of the house's
    picture as it is shown, snow and all) and take no notice of the player, leaving if the
    house is gone; storks clatter their bills now and then;
  - stork nests (task 152): a heap of sticks on the ridge of some houses (a kate, longhouse,
    hall house or barn; about 4 in 10, by where it stands and the world seed, so every game of a
    seed has the same nests) and the year of each, by the date (`StorkNests`, numbers in the
    `[stork_nest]` section of `data/wildlife.cfg`). Empty in winter; the pair flies in in early
    spring (days 3 to 8) and stands on the nest, clattering; the young (2 to 4) hatch in
    late spring (days 17 to 26) and grow through the summer; the parents
    go to the meadows by day for a few hours at a time (one always stays by the newly hatched)
    and are home at night; in late summer (days 41 to 52) the young stand on the rim and flap,
    and from two days later leave one by one, one every two days, the pair with the last (by day
    60 at the latest); empty in autumn. Each nest has its own days, drawn again every
    year, so they are not in step. Nothing of it is saved: the nests and who is in them follow from
    the world seed and the date (as the weather does), and the player changes one only by taking
    its building down, which takes the nest with it. On screen (`StorkNestView`, one for each nest
    near the view, drawn over its roof, sorted with the house) the heap of sticks shows all year;
    the pair are roof storks standing on its rim, which fly off to the meadows (out of the view) and
    back as the date has them, and clatter now and then; the young are small grey heads over the
    rim (hatchlings), then larger, then white with a red bill, and the grown ones stand on the
    rim, look round, flap and hop, and fly off one by one. A nest that comes near the view, or
    after a skip of time, has everyone on it at once. The random roof storks (`roof_stork`) stay
    where there is no nest: they keep off roofs with one, and the pair of a nest are not counted
    among them. Flaps and clatter are only seen, not kept. Only roofs: no nests on a pole or a
    dead tree yet;
  - greylag geese (task 60): flocks of 6 to 12 (fewer where a narrow shore has no room for them
    all) graze the marsh and the floodplain (grass within 7 tiles of water) in autumn and winter,
    fewer in spring, by day. They raise their heads together when the player comes near and take
    off together when nearer, closing up into a V. Skeins of 7 to 13 fly over high up now and
    then, mostly at dawn and dusk: south in autumn and north in spring (they migrate as the sky
    flock does), any way in winter. A flock counts as one animal.
  - mice (task 80): within 2 tiles of farmland (tilled soil, a crop, a Knick, a fieldstone
    wall or a building, with its hay), all year, mostly at dusk and at night and a few by day;
    they sniff and scurry, and dash off into cover (gone) when the player comes near;
  - frogs (task 80): on grass, the floodplain and wetland within 2 tiles of water, from spring
    to early autumn (fewer in autumn, none in winter), most at dusk, out in the rain; they sit
    puffing their throats, hop now and then and hop off from the player. A hunting stork that
    sees a frog within 3 tiles walks up to it, strikes and swallows it, and the frog is gone.
    The lookup (`WildlifeView.nearest_animal`) is the same a cat uses for mice (task 82).
  - the birds of the coast (task 99), the North Frisian Wadden Sea's commonest:
    oystercatchers in pairs and small groups (2 to 5) on the tidal mud and the salt marsh all
    year, a few at night, probing the mud, raising their heads when the player comes near and
    flying off low when nearer; tight flocks of 12 to 24 dunlin on the mud in the spring and
    autumn migration (fewer in winter, hardly any in summer), probing quickly and taking off
    together in a swinging wheel; herring gulls on the mud, the salt marsh and the sea all
    year, walking, pecking and calling on the ground and swimming on the water, flying off
    with long glides; and common terns over the sea and the tideways from late spring to the
    end of summer, by day, flying along over the water, hovering, plunging in with a splash
    and coming up now and then with a fish; they take no notice of the player. The tide counts:
    while it stands high over the mud (above `flooded_tide`) nothing stands there, the waders
    on it fly off and the dunlin find no mud until it falls, the gulls swim on it and the terns
    may dive into it. A flock of waders counts as one animal. Wild ground animals keep off the
    mud the tide covers, as the player does (`can_stand` asks the world, which says flooded mud
    is not walkable, see coast.md). The waders (oystercatchers and dunlin, `WildlifeRules.WADERS`)
    skip that rule and keep to `flooded_tide`: they may spawn, step and stay on mud the tide
    covers until it is water to them.
- **The world decides how many:** time of day (birds and insects by day, deer at dawn and
  dusk, fewer animals at night), season (no insects in winter; fewer birds; rabbits and
  squirrels still about), weather (animals hide in heavy rain, storms and dense fog), and
  the land (each kind has its terrain).
- **Size relative to the character (27–28 px tall):** deer about 20 px tall with the head
  up, body about 18 px long; rabbit about 8×7 px; squirrel about 7×7 px; birds about
  5×4 px; butterfly 3–4 px; bee 2–3 px; mouse and frog about 8×5 px (larger than life, to be
  seen); a dunlin about 7×6 px, an oystercatcher about 10×7 px with its bill, a tern 12 px long,
  a gull about 13×11 px. Each has a few animation frames, palette only, in the art style of the world.
- **How:** animals appear only near the player, out of sight or at the edge of the view,
  and vanish when far away. Behaviour is a simple per-animal state machine (idle, move,
  flee). The rules for how many and where are plain, testable logic; the animals
  themselves are view nodes.
- **Buildings (task 201):** no wild animal ever stands on a building tile, the door included, and
  none appears or settles on one (`WildlifeView.can_stand`; the farm animals have the same rule in
  `is_walkable_for_animals`). The mice are no exception. The roof storks and the stork nests stand
  on roofs by design and do not use it.
- **Return gap (task 202):** a kind with `return_gap_minutes` in data/wildlife.cfg (the storks)
  stays away for that many game minutes after one of it has left, flown out of the view or sent
  away by the weather or the hour. Neither the spawner nor `settle` (a skip of time) brings
  another before then, so a stork that flies off is not replaced at once and sleeping does not top
  them up again. Animals made by hand and the pairs of the nests start no gap, and settling
  itself, which clears the view, is no leaving.
- **Storks are rare (task 202):** at most one hunting stork and one roof stork near the player
  (the pairs of the nests are not counted), a hunting stork appearing at about 0.008 a second at
  full activity (about once in two game hours with none about, a day in a few spent walking past
  it) and a roof stork at 0.003 (now and then, once or twice a day when none is about), and after one has left the
  `return_gap_minutes` above (2 and 4 game hours). Before, with cap 2 and chances of 0.03 and
  0.02, a player walking by the meadows scared a stork off and saw another within the hour,
  0.3 to 1 new storks an hour (see tools/bench/storks.gd); now it is 0 to 0.12 an hour. The nest
  pairs of task 152 are as before. Tests: `test_stork_rate.gd`.
- **Distance from buildings and villagers (task 201):** most kinds don't appear or settle within
  `building_tiles` of a building (rabbit 3, deer 6, squirrel 2, birds 2, geese 5, stork 4, frog 2,
  waders 4, gull 2) or within their `flee_tiles` of a villager. The mice are the exception: they
  live by the houses and the fields (`ignores_villagers`, no `building_tiles`), but still never
  stand on a building tile. Roof storks and nests are not placed this way. A building is looked up
  by tile (`World.building_at`) in a square of `building_tiles`; there is no spatial lookup of
  villagers, so the view copies their feet into the short list `villager_feet` each tick and frame
  and the check scans it. The numbers are in data/wildlife.cfg.
- **Villagers scare animals like the player (task 201):** a villager within an animal's
  `alert_tiles` or `flee_tiles` makes it look up, flee or turn away as the player does; the nearest
  of the player and the villagers counts (`Animal._nearest_threat`, which scans `villager_feet`).
  The mice ignore villagers (`ignores_villagers`) and are not driven off by them, though they still
  dash off from the player. `--wildlife-calm` makes the animals ignore the player and the
  villagers.
- No animals inside buildings.
