# Time, seasons and weather

- Days and seasons work as is usual for the genre: crops grow day by day, and the season
  decides what grows.
- **Seasons fade into each other; snow and frost come from the weather** (decided
  2026-11-05; replaces the hard switch of the art at a season's first day):
  - **Snow cover is weather-driven:** snow on the ground builds up while it snows and
    melts above 0 °C (faster in sunshine). It is derived from the weather history (no
    save needed). The ground, objects and roofs show snow only where there is snow
    cover, so the first frosty days of winter are not white yet.
  - **Patches** (changed by task 185): snow does not switch tiles. Every art pixel of the ground,
    the objects and the roofs has a place in a noise map; snow shows on the pixels whose place
    is below the cover the tile gets, so it arrives as a soft dusting that thickens evenly, and
    in a thaw it melts away evenly, the paths and the open ground first. By the start of spring
    it is gone.
  - **Frost:** below 0 °C without snow, a rime of single pixels lies on the grass, the plants
    and the objects (pale blue-white, on the light tips first), stronger the colder it is and
    gone as the day warms, minute by minute. Under a tree's crown it lies less.
  - **Foliage and grass blend** (changed 2026-11-06): every change of look of the plants takes
    2 to 3 days from the first day of its season to the full look, tree by tree (each has its
    own threshold; the ground's colour has its own, much gentler mix), not on one morning and
    not over weeks. In spring the trees and bushes leaf out in visible steps within those days:
    bare, buds, small leaves, full leaves. Autumn colours and leaf fall come in the same way.
    Winter without snow is dark green on the ground (the plants are bare), not white or grey.
    As built (task 51): each change starts the day before its season, so on the first day about
    a sixth has changed, half on the second, five in six on the third, and all is done on the
    fourth. Leaf fall is the change to the bare
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
  - **Falling leaves** (task 182, view only, numbers in data/leaf_fall.cfg): in wind, broadleaved
    trees near the player shed leaves now and then, in the colours of their season look (the
    felling leaves of the hit particles). Not every tree is watched: a few tiles are picked at
    random around the player each second, and a pick on a tree may shed. The chance is the
    foliage the tree still has (autumn colours in full, so early winter too until the tree is
    bare; a little for green trees from late summer; none while bare or in spring leaf; spruce and
    pine only a rare needle) times the wind (none at or below a calm speed, full at a strong one),
    and more while a gust front, the same fronts the plants sway in, is over the tree. Most
    leaves drop and sway down beside the tree; in wind some are carried off downwind, tumbling,
    for a few tiles before they fade out. At most 24 leaves are in the air at once. Nothing is
    saved and nothing falls indoors. The sound
    of the gusts follows the same fronts (see the ambience in presentation/sound.md).
  - **Effects for now are visual only:** rain and snow particles (slanted by the wind),
    fog drifting over the world, wind streaks and blowing leaves, lightning flashes, and
    overcast skies dimming daylight, and **cloud shadows** (task 194): by day, with the sun out
    and some cloud, soft dark patches drift over the ground with the wind's speed and direction
    (no cloud is drawn). More cover gives more and larger shadows, a clear sky none; a closed
    sky has none either, only the day tint's dimming (task 177), so the ground is not darkened
    twice; they fade out with dusk and with rain or snow, and are never indoors. One shader
    overlay in world pixels (cloud_shadows.gdshader), numbers in data/lighting.cfg
    [cloud_shadows]. Nothing in the state follows them: sunlight, crops and drying do not.
    Nothing in the game reacts yet (crops, floods,
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
- **The world looks like its season** (decided 2026-11-05, changed 2026-11-12 by task 185): the
  current art is summer. Spring is a lighter, fresher green; autumn is North Sea autumn (task 52):
  oaks brown, ochre or copper, beeches copper, birches yellow, alders a dull green-brown (task 56),
  bushes yellow and ochre, red rare (no tree has it yet). The grass itself does not change look:
  it shifts evenly to a darker green in autumn and the darkest in winter, the dry grass of the
  Geest keeping a little straw in autumn; the salt marsh keeps its olive turf, with patches of
  red-purple glasswort and its red-purple autumn (task 107). Fallen leaves, frost and snow lie over
  all of it, and snow lies on the evergreens, the bare deciduous trees and the roofs. This is the
  visual season only: frozen rivers, deep snow and other weather effects on tiles stay with the
  weather system.
- **How the looks are drawn** (decided 2026-11-05, rebuilt by task 185): the art generator
  recolours the summer art into looks: for the ground spring, summer, autumn, bare (winter
  without snow: the darkest green), frost and snow, for objects also the steps of the leaf-out
  (buds and young leaves, drawn over the bare tree). Terrain and decorations are drawn in the
  summer look only (the atlases of the other looks have the same layout), and the ground shader
  mixes the colours of two seasons by the day and lays the cover over them; the plants and the
  houses pick the picture of their season by the day, and the cover shader lays the snow and
  the frost over them. So the view refreshes only when the day changes (the pictures of the
  plants, and the decorations), while the ground and the covers follow the weather by the minute.
  Snow cover comes from `data/seasons.cfg` ([snow]: snowfall adds, warmth and sun melt, counted
  hour by hour from the start of autumn; none from the first day of the year), the blend windows
  too.
- **The ground follows the year as one base colour plus overlays** (task 185, built; see
  docs/plans/185-season-overlays.md):
  - The grass keeps one look all year and only shifts its colour, evenly all over the world: the
    ground shader (`ground.gdshader`, `GroundLook`) mixes the summer atlas into the atlas of the
    next season by `SeasonBlend.ground_mix` (windows in [ground_mix] of `data/seasons.cfg`, wider
    than the plants' blend windows), fresh in spring, darker green in autumn and deepest in
    winter. There is no yellow or grey, and no patch changes before another. The salt marsh keeps
    its red-purple autumn.
  - Fallen leaves (`SeasonBlend.litter`, [litter]), frost (from the temperature, per minute) and
    snow (`SnowCover`, per minute) are overlays on top, decided per art pixel: a pixel shows the
    cover where its threshold in `ground_noise` (a noise of patches a few tiles across with a
    grain; the same histogram everywhere, so a cover of 0.3 covers 30 % of the pixels) is below the
    share of cover the tile gets. They build up and melt evenly, with soft organic edges, never
    along the tile grid, in both art sets (the pixel of the classic art is 16 px).
  - What a tile catches, from `GroundCover` ([cover]): leaves thicker under and near broadleaved
    trees and thinner on fields and paths; snow thinner under crowns, in the lee of houses (east
    of them, a fixed westerly) and on paths; frost sheltered under crowns; and the thaw takes the
    snow off paths and open ground first. Water and the tidal mud catch nothing; tilled soil,
    paths, floodplain and wetland do. `CoverMap` keeps one texel per world tile in a 512 x 512 ring
    texture that the shader filters, so the cover is smooth across tile edges; it is redrawn when
    a chunk loads or something near a tile changes (a tree, a house, a path).
  - What stands on the ground (trees, bushes, stones, roofs) catches `object_snow_gain` (1.7)
    times the snow share of the ground it stands on, at most all, as it is not under its own
    crown and snow lies thicker on a branch or a roof.
  - The weather of the moment is set once per game minute as global shader parameters
    (`ground_cover.gdshaderinc`); nothing is redrawn per tile, per hour.
  - Trees, bushes, stones, fences and the like keep their picture of the season (their own look
    of each tree, see the foliage windows) and get the frost and the snow over it by shader
    (`object_cover.gdshaderinc`): the art generator draws, per object, only the pixels that its
    snow and frost looks add (the atlases `objects_snow_cover` and `objects_frost_cover`, with each
    pixel's rank in the alpha channel, the snow's growing from the top of the picture down), and a
    pixel shows once the cover of the ground the object stands on is above its rank. So snow
    settles on a spruce from the top down, thickens, thaws from the bottom up, and lies thinner
    on what stands in the shade or the lee. The stand-in sprites (a tree that fades while it hides
    the player, a falling tree) have the same shader, with the same atlas picture; crops have no
    cover (their sheet is no part of the atlas). Hit effects ask whether snow lies on the ground
    under the object.
  - Houses keep the picture of the season (a turf roof's grass follows the grass of the ground)
    and get the snow of the roof from a picture of its own, `<house>_snow_cover.png`: the pixels
    that the snow look adds to the roof, ranked from the ridge down, so the snow builds up from
    the ridge to the eaves, by the cover of the ground at the middle of the house, and keeps the
    roof's shape and the lit windows (the same picture serves the lit and the unlit house).
  - `--frost` and `--melt` start the game with a forced frost or thaw, like `--snow`.
  - The game's own questions (footsteps, the animals, the flowers under snow) ask `GroundCover` for
    the snow share of the tile and call it snowed at 0.5 or more, while the shader blends per
    pixel, so at the edge of a patch they can differ a little from what is drawn.
  - Cost: a chunk fills about 5-7 ms of cover texels when it loads, and the ground costs a few
    texture samples per pixel in place of about 40 overlay layers.
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
