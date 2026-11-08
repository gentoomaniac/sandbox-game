# Time, seasons and weather

- Days and seasons work as is usual for the genre: crops grow day by day, and the season
  decides what grows.
- **Seasons fade into each other; snow and frost come from the weather** (decided
  2026-11-05; replaces the hard switch of the art at a season's first day):
  - **Snow cover is weather-driven:** snow on the ground builds up while it snows and
    melts above 0 °C (faster in sunshine). It is derived from the weather history (no
    save needed). The ground, objects and roofs show snow only where there is snow
    cover, so the first frosty days of winter are not white yet.
  - **Patches:** each tile has a fixed threshold; snow shows on a tile while the cover is
    above it. So snow arrives as a dusting in patches, and in a thaw it melts away in
    patches over 2–3 days. By the start of spring it is gone.
  - **Frost:** below 0 °C without snow, grass and plants get a frosty look (pale,
    rimed), stronger the colder it is, fading as it warms by day.
  - **Foliage and grass blend** (changed 2026-11-06): every change of look takes 2 to 3
    days from the first day of its season to the full look, tile by tile and tree by tree
    (each has its own threshold), not on one morning and not over weeks. In spring the
    trees and bushes leaf out in visible steps within those days: bare, buds, small leaves,
    full leaves. Autumn colours and leaf fall come in the same way. Winter without snow is
    bare and brown-grey, not white. As built (task 51): each change starts the day before
    its season, so on the first day about a sixth has changed, half on the second, five in
    six on the third, and all is done on the fourth. Leaf fall is the change to the bare
    look at the start of winter (day 91). Each tree or bush leafs out over most of those
    days and shows each step for about a day; conifers, ferns and grass have no steps.
  - **Pines look like pines** (decided 2026-11-06): a Scots pine with a tall bare reddish
    trunk and a few flat dark blue-green needle clumps high up, so they don't read as
    young leafy trees; evergreen like the spruce, which stays as the second conifer. As
    built (redrawn in task 56, which found the first one bonsai-like and its orange trunk too
    loud): about 75 px tall, the trunk slightly crooked, grey-brown and furrowed below with a
    few dead branch stubs, a warm brown with a little red in its shade up in the crown; the
    crown is a loose, flat-topped umbrella of needle clumps on thin dark branches spreading from
    the top third. Snow lies on the clumps, frost pales them.
  - **Trees of the region** (task 56, 2026-11-06): the woods are broadleaved, as docs/art-style.md
    asks. Each species has its own silhouette and bark and every look: the **beech** a tall,
    smooth grey bole under a broad round dome, copper in autumn, a fan of fine grey twigs in
    winter; the **birch** a slender white trunk with black marks and a dark foot under a narrow,
    open crown with hanging strands, yellow in autumn, white limbs and fine brown twigs in
    winter; the **alder** a straight dark stem through a narrow, lumpy cone of dark leaves,
    which stays green late and goes dull green-brown, and in winter carries black cones and
    catkins; the **oak** stays as it was. All four leaf out in steps. Pine and spruce are the
    rare ones (below). Pollard willows by the ditches and hazel and hawthorn in the Knicks are
    those of task 54. No new colours: the birch's bark is `lime`, `stone_light` and `stone`.
- **Vegetation density follows the year** (decided 2026-11-05):
  - Ground cover (grass tufts, flowers, small plants, fallen leaves; the visual decoration
    layer) has a density per kind that follows a smooth yearly curve: grass tufts sparse
    in early spring, fullest in summer, thinning in autumn, a few dry stalks poking
    through the snow in winter; flowers bloom in spring and summer (each species on a
    curve of its own, see "Flowering meadows" in [Art pipeline](../presentation/art-pipeline.md)), fallen leaves in
    autumn.
  - Each spot has a fixed random threshold (from the seed and position), and a plant shows
    while the current density is above it. So plants come and go one by one over days,
    not all on one morning.
  - Seasonal plants among the world objects (fern bushes and similar soft plants) die back
    in late autumn and regrow in spring the same way: while dormant they are not drawn,
    don't block and can't be harvested. Woody plants (trees, berry bushes, shrubs) stay
    all year and only change their look.
  - Fruit follows the season too: berry bushes carry berries from early summer to late
    autumn (each bush starting and ending on its own day, by the same threshold rule).
    Outside that window a bush shows without berries and can't be picked; picking within
    the window works as before (bears again after a few days).
  - Harvesting a seasonal plant still removes it as before; regrowth follows the existing
    rules.
- **Weather state** (decided 2026-11-05):
  - Four values: **humidity** (0–100 %), **wind speed** (m/s, with a direction),
    **temperature** (°C) and **sunlight** (0–100 %, cloud cover dims it).
  - Weather is a deterministic function of the world seed, the region and the game time
    (smooth noise over hours and days around a per-season baseline, plus a daily cycle:
    cool nights, warm afternoons, morning fog). Nothing needs saving, and any past or
    future moment can be asked for, e.g. "has it rained for three days?" for floods
    later.
  - Regions: the world is split into weather regions (for now one region for the whole
    world, since biomes don't exist yet; the API already takes a position).
  - **Conditions** are derived from the values: rain (high humidity, above freezing),
    snow (high humidity, at or below freezing), fog (very high humidity, little wind,
    mostly mornings), strong wind and storms, thunderstorms with lightning (warm, humid,
    windy). Each has an intensity 0–1.
  - **Seasons set the baselines:** spring mild and showery; summer warm and mostly dry
    with occasional thunderstorms; autumn cooler, windy, foggy and rainy; winter cold
    with snow.
  - **Ambient motion** (decided 2026-11-05, view only): plants sway with the wind (tree
    crowns, bushes, tall grass, reeds, crops, ground tufts; gentle on calm days, hard with
    gusts in a storm, each plant with its own phase, in whole art pixels with the stems
    fixed); water shimmers and ripples, choppier in wind; the campfire and hearth burn
    (decided 2026-11-05, task 48): their flames are a short loop of drawn frames (tongues
    that rise, split, lick sideways and fall back, tips that break off and go out), played
    at about 9 frames a second, each fire starting its loop at a frame picked by its place
    so neighbours don't burn in step; the logs and stones stay still and only the flame
    moves. Outdoors the flames lean and stretch downwind, more in a strong wind, and
    sparks drift with it; rain splatters small splashes on the ground (more in heavy
    rain); lily pads drift and bob a little; the tide comes and goes on the mud (task 61). It is
    all done by shaders, with no nodes or
    scripts per plant or fire: a pixel's sideways shift grows with its
    height above the plant's foot (the trunk or stem stays put), plants lean downwind and
    gust fronts sweep across the world with the wind; only the wind across the screen
    leans them. At a light air (about 2 m/s) only the tips of the bendiest plants flick a
    pixel now and then; in a storm tree tops swing up to 3 pixels. Water ripples only
    change plain water pixels, so banks, foam and lily pads keep their shape. Splashes are
    drawn under the objects and the player. The hearth's fire burns indoors too, but
    there is no wind inside, so it does not lean. Dead trees (bare snags), pebbles, fallen
    leaves, toadstools and puddles stay still; so does a tree while it is see-through or
    falling (it is a sprite then).
  - **Effects for now are visual only:** rain and snow particles (slanted by the wind),
    fog drifting over the world, wind streaks and blowing leaves, lightning flashes, and
    overcast skies dimming daylight. Nothing in the game reacts yet (crops, floods,
    frozen rivers, energy and the like come later); the state is ready for it. No
    effects inside buildings. Rain, snow, streaks, leaves and fog are anchored to the
    world, not the screen: they stay in place when the player walks.
- **Day length follows the year** (decided 2026-11-05, made milder the same day for
  gameplay): the game is set in the Nordics, but moderately. Sunrise and sunset move
  smoothly over the year (a curve, no steps between seasons): longest day in mid-summer
  about 16 hours (about 05:00–21:00), shortest in mid-winter about 8 hours (about
  08:15–16:15), 12 hours in mid-spring and mid-autumn. Solar noon moves with summer
  time (about 13:00 in summer, 12:15 in winter). Dawn and dusk tints follow sunrise and
  sunset. A setting (Settings → Game, "Day length variation", 0–100 %, default 100 %)
  scales the swing: 0 % gives 12-hour days all year.
- **A moderate climate that blends across seasons and follows the sun** (decided
  2026-11-05, made milder the same day): the season baselines are points on a smooth
  yearly curve, not plateaus, so late autumn already leans towards winter. Temperatures
  stay moderate for gameplay, roughly: spring 5–15 °C, summer 15–25 °C, autumn 15 down
  to 3 °C, winter −10 to 0 °C. **Below 0 °C happens only in winter**, so snow and frost
  only fall in winter; random variation brings warmer or cooler spells within those
  limits. Temperature rises while the sun is up and falls at night, by how strong the
  sunlight is (clouds warm less by day and cool less at night). Sunlight is 0 at night.
  Plant growth can later depend on these values.
- **Calendar** (decided 2026-11-05): four seasons of 30 days (Spring, Summer, Autumn,
  Winter), so a year has 120 days. The game starts on the 1st day of Spring, Year 1. The
  HUD shows "10th day of Spring Year 2 · 06:00".
- **The world looks like its season** (decided 2026-11-05): the current art is summer.
  Spring is a lighter, fresher green; autumn is North Sea autumn (task 52): oaks brown,
  ochre or copper, beeches copper, birches yellow, alders a dull green-brown (task 56), bushes
  yellow and ochre, red rare (no tree has it yet); the grass of the marsh stays green until
  November, only its tips olive and its flowers withered, and only the dry grass of the Geest
  turns straw; the salt marsh keeps its olive turf, with patches of red-purple glasswort
  (task 107, from the art review of 2026-11-08); winter is snow-covered (snow on the ground,
  snow on evergreens, bare deciduous trees). The look changes when the season changes. This is
  the visual season only: frozen rivers, deep snow and other weather effects on tiles stay with
  the weather system. The season's look is only the base: the blend, snow and frost above
  decide per tile and per plant which look shows.
- **How the looks are drawn** (decided 2026-11-05): there are seven looks of the ground
  (spring, summer, autumn, bare = winter without snow, frost, snow and its thin fringe,
  dusting), each a recolour of the summer art made by the generator, and for objects two
  more, the steps of the leaf-out (buds and young leaves, drawn over the bare tree). The
  base terrain is summer; a look is drawn over it as a dual-grid overlay layer of its own
  (the same edge shapes as the terrain layers), so patches of autumn, bare ground, frost and
  snow have soft edges and no seams. The season looks and the frost have stacked layers for
  lush and dry grass and the desire paths too, like the terrain. Snow and frost lie over the season's look. Decorations,
  objects and houses pick their art by look instead. Snow cover comes from
  `data/seasons.cfg` ([snow]: snowfall adds, warmth and sun melt, counted hour by hour from
  the start of autumn; none from the first day of the year), the blend windows too; the view
  updates once a game hour, a few milliseconds per frame.
- **Weather and seasons change the map:**
  - frost freezes rivers so they can be crossed;
  - heavy, deep snow makes some areas unreachable;
  - several days of heavy rain make rivers swell.
- **Weather is per biome:** e.g. snow in the mountains while it rains in the lowlands.
  Weather is simulated per region, not as one global value.
- **Floods only reach floodplains.** The generator marks floodplains along rivers. Water
  from swelling rivers spreads only there.
- **Floodplains are farmland with a risk:**
  - their soil is especially fertile;
  - a flood washes away and destroys crops on them;
  - a flood leaves some debris items behind, for immersion.
