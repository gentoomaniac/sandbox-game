# Ambient wildlife

Decided 2026-11-05. Small animals that make the world feel alive. For now they are
atmosphere only: no player impact, not hunted, not saved.

- **Who and where:**
  - birds: hop and peck on open ground, fly off when the player comes close; small flocks
    cross the sky now and then (a shadow on the ground);
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
    then, mostly at dawn and dusk. A flock counts as one animal.
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
    may dive into it. A flock of waders counts as one animal.
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
- No animals inside buildings.
