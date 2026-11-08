# Visual and asset review, 2026-11-08 (main @ 5fc9a3c)

Screenshots are in shots/ next to this file. The window was
1474x1372, so zoom 1 shows about 23x21 tiles at 4 screen px per art px.

## Summary: the top 5 problems

1. **Thin, open plants have no edge and vanish on the ground.** Tall grass, fern, the
   reeds in autumn and winter and the pollard willow's crown in every season are drawn as
   loose pale strokes with no outer edge and a 1-2 px foot shadow. On the dry (olive) and
   autumn (straw) ground they are nearly invisible; on summer green they are weak. Dense
   things with the darkest-ramp outline (shrub, berry bush, trees, boulders) and ink-outlined
   things (villagers, animals, items) read fine everywhere, day, dusk, night and snow. See
   contrast_sheet.png (atlas rows over green, dry, olive, meadow; autumn over autumn_light
   and dry; bare over bare and bare_light; snow over snow).
2. **The dyke reads as blocky terraces.** At the camp the dyke autotile forms 3-4 tile
   plateaus with 90-degree stair corners and a flat "top" fill (01_camp_summer_noon.png,
   worst in 06_camp_snow.png). A dyke is a long smooth bank 1-2 tiles across; this looks
   like a terraced lawn.
3. **The village of the sheets has no art.** data/village.cfg and villagers.cfg name a
   church with a wooden bell tower, a Krug, a post mill and mill house, a sluice, a landing
   with flat boats, a parsonage, a fisherman's turf-and-thatch house, a brick Kate at the
   dyke foot. The game has five buildings (shack, Kate, longhouse, hall house, barn) and no
   church, mill, inn, well, sluice or jetty. Every villager's `home` describes a house that
   does not exist as drawn, except the Boysens' (hall house or longhouse).
4. **The autumn ground is one straw yellow.** Day 75 turns all grass to `autumn_light`
   (04_camp_autumn.png), so autumn reeds, tall grass and the willow crown disappear into
   it, and the marsh looks like August stubble. On the North Sea marsh the grazed grass
   stays green until November; only the dry Geest, the salt marsh (red) and the reed beds
   turn.
5. **Eight private outline helpers, no shared one.** items.outlined (the only one with the
   "darkest colour of the pixel's own ramp" table), animals.outlined and outline_in_place,
   character.outlined, trees.shaded_blob, trunks._outline, interior.outline,
   buildings.outline, chest._outline, plus four in boundaries.py. The contrast fix needs one
   helper in canvas.py and one ramp table, or it will be done nine different ways.

## Contrast and outlines

### Findings (asset by asset)

| Asset (atlas row) | Summer green | Dry/olive | Autumn | Bare winter | Snow | Night |
|---|---|---|---|---|---|---|
| tall_grass (objects row 13, meadow.py) | weak: pale blades, 2 px shadow | invisible | invisible on autumn_light | weak | fine (dark stalks) | invisible |
| reeds (row 24, reeds.py) | fine (dark stems, cattails) | weak | invisible (straw on straw, 13_longhouse_autumn.png bottom) | weak on bare_light | fine | weak |
| willow crown (row 31, willow.py) | weak: pale yellow-green blob, no edge (09_coast.png) | invisible | invisible (gold on autumn_light) | invisible (pale rods on bare) | fine | weak |
| fern (row 10) | weak | invisible | weak | fine (brown) | fine | invisible |
| sapling (row 9) | small but reads (dark stem) | ok | ok | ok | ok | weak |
| shrub, berry bush (rows 7, 8) | fine: darkest-ramp outline | fine | fine | fine | fine | fine |
| trees, trunks, stumps, boulders | fine | fine | fine | fine | fine | fine |
| buildings | fine: ramp outline + eaves and ground shadow (docs/screenshots/buildings.png) | | | | fine | lit windows carry them |
| villagers, player, livestock, wildlife | fine: ink outline (sheet_npcs_livestock.png, sheet_wildlife_field.png) | | | | | fine |
| crops in the field (18_field.png) | fine: on dark tilled soil | | | | | |
| ground items | fine: ink outline (items.outlined) | | | | | |
| decoration layer (tufts, clover, flowers, leaves) | meant to blend; leave as is | | | | | |
| Knick, wattle, stone wall | fine (own outlines) | | | | | |

The common cause: the four weak plants are drawn as single-pixel strokes in the lightest
two shades of their ramp (`dry_light`, `straw`, `spring_pale` after the remap), with
40-60 % of their cell empty, no dark edge and no real ground shadow. The eye has no
silhouette to catch. The blobs read because `shaded_blob` closes the shape and rims it in
the darkest shade.

### Recommended approach

Keep the project rule (SPEC, Art pipeline): no ink on vegetation, outlines in the darkest
colour of the object's own ramp, never on terrain. What is missing is not ink but a
silhouette. Three measures, cheapest first, all in the generators and all from existing
colours:

1. **A ground shadow like the trees'.** Call `trees.ground_shadow(canvas, half_width)`
   under tall grass, fern and reeds (the willow has it). The "shadow" logical colour is
   remapped per look by seasons.py, so it is right in every season at no extra cost.
2. **A dark foot and underside ("sel-out").** The lower third of a clump is in shade:
   draw the bottom 3-5 rows of blades in the two darkest shades (`green_dark`, `green_deep`
   for grass and fern; `olive`, `green_deep` for reeds), the upper two thirds in the light
   ones. This gives the clump a dark base that sits on the ground and a light top that
   reads against it, which is how 16-bit grass is drawn (Secret of Mana, Chrono Trigger:
   the dark half is the silhouette, the light half is the detail).
3. **A 1 px selective outline on the dense core.** A new `canvas.outline(picture,
   colour=None, keep_bottom=False)`, moved out of items.py with its `OUTLINE_OF` ramp table
   (move the table to palette.py as `DARKEST_OF`), draws a 1 px edge outside every drawn
   pixel in the darkest colour of that pixel's ramp. Apply it to the crown mass of the
   willow (draw the crown first with `shaded_blob` in `("dry_light", "dry", "olive",
   "green_dark")` with outline `green_deep`, then the rods over it) and to the body of the
   fern, not to loose blade tips: an outline on every 1 px blade clogs the sprite and makes
   it a dark blot. For tall grass and reeds, outline only the silhouette of the clump's
   lower half (the part drawn dense in step 2).
   Ramp table (darkest of): greens -> `green_deep`; dry/straw/reed -> `umber` in autumn,
   `olive` in summer; bare_light/bare -> `soil_dark`; snow -> `snow_deep`; already the way
   items.OUTLINE_OF maps them, extend as needed. Check the seasons remap keeps the edge
   dark: `green_deep` must map to a dark autumn and bare colour (seasons.py `_SPRING_GREENS`
   and the autumn and bare tables); if it maps to `umber` and `bare`, fine.
4. **Not for:** terrain, the decoration layer (decorations.png), paths, water, crops
   (dark soil carries them), buildings, items, characters, animals (already done).

Then the willow (TASKS.md "Later", was task 87): crown as a closed blob of 60 % coverage
with an outlined underside, rods and silver leaves on top, a 4-row shadow; the bare look
the same with `umber` on the rods' lower halves so it does not become pale straw on pale
ground.

**Effort:** S for the helper and the ramp table (and the four callers that already do the
same thing: trunks, interior, buildings, chest; animals and character keep theirs, they
outline in ink with special rules); S each for tall grass + fern and for reeds; M for the
willow. One worker, one day, plus a contact-sheet script (the one used for
contrast_sheet.png: atlas rows over the ground colours of every look) committed under
tools/ so every later art task can check contrast in one picture.

## Docs vs art (docs/art-style.md and SPEC.md against the assets)

Matches: the palette count (43 + 21 = 64, verified), materials, the Kate, longhouse, hall
house, barn and shack descriptions, the thatch courses and ridge sticks, the villagers'
layer list (every layer named in "Clothing and characters" exists in assets/character and
assets/character/portrait), the animals listed as done, the coast.

Mismatches and gaps:

- SPEC "Building and land" calls the longhouse "a larger farmhouse with the big gable door
  of the Lower Saxon hall house"; the art and art-style.md have it as a Geesthardenhaus
  entered on the eaves side (the arched green door is on the long side). Fix the SPEC
  sentence.
- art-style.md "Men: ... knitted stocking cap (white or red)": only one knitted cap
  (`head_knitted_cap`). Tricorne: none. "Women: apron (white, blue or striped)": no striped.
  Buckled shoes, island dress: listed as to-do, still open.
- "Props: hoe, spade with iron shoe, scythe, sickle, flail, wooden rake, pitchfork, axe,
  wooden buckets, yoke, watering can": the game has hoe, axe, pickaxe, scythe, shovel,
  hammer, watering can. No sickle, flail, rake, pitchfork, bucket, yoke. The pickaxe is the
  one tool with no period job in the marsh (no quarries; stone comes from the Geest till).
- "Carts and boats": only the Ewer object, "held to an object cell" (too small, as the doc
  says). No cart, wheelbarrow, rowing boat, sled.
- "Wells and water: draw well with a sweep", "Mills: post mills": none drawn (open item
  10 of "Changes to make", the only one left).
- "Details worth having: bench by the door, stork's nest on the ridge, Klöntür, wall
  anchors, sod-roofed outhouse": none; `roof_stork` exists as wildlife but no nest.
- "Livestock: pigs": none. Goats: none (fine, rare here).
- "Knicks: overstander oaks": still open. "Stackdeich and sluices": open.
- Colour name `maple_light` survives although maples are in "Avoid"; rename when touched
  (`leaf_orange`), not worth a task.
- The decorated 1-storey Kate chimney is white (lime) and tall: fine; the Kate in the
  screenshot has only a teal door and shutters, matching the paint rule.
- The "Changes to make" list is otherwise accurate and up to date.

## Characters and places without art

Villagers (data/villagers.cfg) all have their look layers; what is missing is their
homes, their trades' props and the places their sheets send them to.

| Who / what | Described | Art that exists | Missing |
|---|---|---|---|
| Boysens (Antje, Hinrich, Boy) | "long thatched hall house with the cows under the same roof", on a Warft, cows, 2 horses, sheep | hall house, longhouse, Warft terrain, cattle, horses, sheep | the farm yard: trough, hay rack, well, a Fething pond with cattle (pond exists) |
| Momme and Inken Ketels | "small turf and thatch house by the landing at the sluice, outside the dyke"; flat boat, shrimp, eel traps, nets | shack (turf roof, tarred boards) comes close; Ewer | fisherman's hut variant, landing/jetty, rowing boat, nets on a frame, eel traps, a net needle in Inken's hands |
| Ocke and Gesche Hansen | post mill on the rise, mill house, grain sacks, flour, ledger | sacks, flour item, oven | post mill, mill house (Kate variant), a quill |
| Kerrin Paulsen | "small brick and thatch house at the foot of the dyke, by the sluice road"; walks the dyke with a stick | Kate (lime-washed), dyke | brick Kate variant, sluice, the stick |
| The church, pastor, sexton | highest Warft, churchyard, wooden bell tower, parsonage, school room | stone wall autotile (churchyard) | church, Glockenstapel, parsonage, graves, pastor and sexton as villagers (black coat, bands) |
| The Krug, Tete and Telse Jacobsen | inn by the church, beer, brandy, carters | none | Krug building, a sign, a cart |
| Trades in data/npcs.cfg | farmhand, fisherman, carter, thatcher, shepherd, peat cutter, cooper, dyke worker, day labourer, tailor; farmer's wife, dairymaid, spinner, fisherman's wife, washerwoman, weaver, seamstress | reeds (thatcher), barrel (interior only), sheep | cart and horse harness, peat stack and spade, cooper's tools, spinning wheel, loom, butter churn, milk pail, wash tub and copper, needle and cloth; a shepherd's crook |
| Village places | Koog meadows, ditches, salt meadows, creeks, Geest fields of rye and buckwheat, heath, peat bog, Husum (off map) | all the land types | rye and buckwheat crops (crops: wheat, beans, peas, flax, cabbage, carrot, onion, turnip, potato, pumpkin, strawberries: no rye, oats, barley, buckwheat, which are the Geest's grain), heath with juniper, peat cuts |

Also missing although named in SPEC/art-style: Nis Puk and the other spirits (deliberately
later), the stork's nest, lapwings and oystercatchers (TASKS.md 99 covers the sea birds).

## Proposed buildings (period-true for North Frisia, 1750)

Footprint = tiles on the ground (w x h); the roof rises above it like the existing sprites.
Looks use the existing ramps (THATCH, brick in `rust`/`red_light` or buff `sand`, tarred
boards `soil_dark`/`ink`, lime `lime`/`sand_light`); no new colours needed.

| # | Building | Footprint | Look | For | Priority |
|---|---|---|---|---|---|
| 1 | Chicken coop (Hühnerstall) | 2x2 | low boarded hut, tarred or silver-grey, a ramp with cleats to a small hatch, a nest-box lid on the side, thatch or board roof | hens sleep in it, eggs are collected there; chickens exist already | P1, S |
| 2 | Trough (Tränke) and hay rack (Raufe) | 2x1 each | trough: a hollowed oak log or a plank box, water `water_light` with a lit rim; rack: oak posts with slanting slats, hay `straw` behind them; a feeding station, not a building (no interior) | feeding and watering cows, horses and sheep, the "feeding" item under Livestock in SPEC | P1, S |
| 3 | Draw well with sweep (Ziehbrunnen) | 1x1 (+ sweep above) | square oak well head on a fieldstone ring, a forked post with a long balanced pole, bucket on a rod, a weight stone | water for the can, animals and the house; the landmark prop of art-style item 10 | P1, S |
| 4 | Post mill (Bockwindmühle) | 3x3 on a 5x5 mound | tarred board body on an oak trestle, 4 lattice sails with cloth (2-3 wind frames), tail pole with the ladder to the ground, on a grass mound; a mill house beside it is a Kate variant | Ocke's mill; grinding (move the flour recipe from the oven to the mill) | P1, M-L |
| 5 | Church with Glockenstapel | church 6x4, bell frame 2x2 | nave of buff or red brick (tuff was used in the Romanesque ones: grey-brown `stone`), steep tile roof `rust` (village churches here were tiled or leaded, not thatched), small arched windows with lead glazing, a low porch on the south side; the free-standing wooden bell frame: an open oak A-frame on a brick base under a pyramid of shingles, the bell in `ochre`; a fieldstone churchyard wall (existing autotile) and a few grave crosses | Sunday, the pastor, the churchyard on the highest Warft; Kerrin's wish to be buried beside Jens | P1, L |
| 6 | Fisherman's hut (Fischerkate) | 4x2 | a shack variant: turf or thatch roof, tarred boards, one window, a net drying frame and eel traps (wicker, `straw`/`sand`) beside the door; a plank jetty 1x3 on posts at the water; a rowing boat 2x1 beside it | the Ketels' home at the landing; nets and traps as props | P1, M |
| 7 | Kate variants | 5x3 (existing) | a red-brick wall look (`rust`, `red_light`, joints `sand`) with white frames and a green door; a Geest look in lime with black tarred base | Kerrin's brick house, the mill house, the sexton's house; cheap variety for a village | P1, S |
| 8 | Uthland-Frisian house | 7x3 | long, low, red brick with white-painted joints, hipped reed roof with a steep Frisian cross gable over the front door, white window frames, green door, brick base, runs east-west | the islands' and Halligen's farm; the second big farmhouse so that a village has two kinds of farm | P2, L |
| 9 | Krug (inn) | 7x3 | a longhouse variant with a hanging sign (a wreath or a tankard on a bracket), a bench and a hitching rail by the door, a second chimney; inside a long table and benches, barrels | Tete and Telse's inn; beer and the news; Saturday evenings for Hinrich and Momme | P2, M |
| 10 | Hay barrack (Heuberg) | 3x3 | four oak posts with a thatched pyramid roof that slides on them, the hay stack under it in 3 heights (full, half, empty) | hay storage shown as a stack that goes down over winter | P2, M |
| 11 | Sluice (Siel) | 2x2 in the dyke line | brick or timber head walls, two oak doors, a walkway with a rail, the ditch water running out | the village sheet's "sluice by the landing"; a dyke crossing for ditches | P2, M |
| 12 | Jetty / landing (Anleger) | 1x3 | plank deck on posts, mooring posts, a flat boat alongside | the landing where Boy and Inken meet | P2, S |
| 13 | Pig sty (Schweinekoben) | 3x2 | boarded pen with a low board roof over half of it, a stone trough, mud floor | pigs (need art and livestock rules first) | P3, M |
| 14 | Haubarg | 9x7 on a Warft | near-square, grey-buff brick walls, a towering pyramid of thatch over the central hay store (Vierkant), two small chimneys, a wagon door on the long side, few small windows | the late-game status farm of the marsh (SPEC) | P3, L |
| 15 | Outhouse, peat stack, bakehouse | 1x1, 1x1, 2x2 | sod-roofed privy; stacked turf; brick bakehouse with the oven's chimney | yard detail; the peat cutter; the oven moved outdoors as fire risk demanded | P3, S each |
| 16 | Stork's nest | 1 object on a ridge | a wheel of sticks on the ridge, the `roof_stork` standing in it | the landmark detail of every marsh farm | P2, S |

Not proposed: a smithy, a shop, a doctor (the village sheet says there are none), stave
or turf houses, a tower church (the small marsh parishes had bell frames).

## Other findings

- **Dyke terraces** (problem 2): the dyke object tiles have only straight and 90-degree
  pieces and the mask is 3-4 tiles wide, so the camp sits among green terraces. Needs
  diagonal and rounded corner tiles in boundaries.py (like the Knick's) and a crest 1-2
  tiles wide in the world generator, with slopes on both sides, not a flat top fill.
- **Autumn ground** (problem 4): `autumn_light` on everything; keep marsh and floodplain
  grass olive-green in autumn (`olive`, `dry`), straw only for dry grass and the Geest.
  Also the frost look (05 bare winter) is good; the bare winter ground is a believable
  grey-brown.
- **Tilled rows look like stacked logs at zoom 2** (18_field.png): the soil ridges have a
  strong lit top and dark underside with rounded ends. Flatten the ridge highlight to one
  pixel row and square the ends; the furrows should read as earth, not as timber.
- **Willow trunks read as stone pillars** (09_coast.png): `bare_light` bark on a short
  thick trunk with a grey knobbly head looks like a stump of masonry at zoom 0.75. Warmer
  bark (`mud`, `mud_dark` instead of `bare_light`) would help; part of the willow task.
- **Reeds stand in the water tile** (sheet_buildings.png): the stands on the bank also
  cover the first water row; fine for reeds, which do grow in the water, but their foot
  shadow is drawn on water. Harmless.
- **Dusk and night** (sheet_dusk_night.png): the tint is good and the fire's light is warm;
  at night the weak plants vanish entirely, which is acceptable; the villagers and animals
  (ink outlines) stay readable.
- **HUD and chat at zoom 1** (20_chat.png, 01): the 5 px font, the date line, the hotbar
  and the chat panel with the 32x32 portraits are all readable at the 1474 px window; the
  name label over a villager ("Lorenz Nissen") too. No change needed. The chat script in my
  shot broke at the spaces in ARGS, not a game fault.
- **Scale:** villagers (32 px) against the Kate (door about 20 px high) are a shade large
  but consistent with the player; cows and horses are in scale with people; the storks are
  right (16 px); the boulder beside the camp is as big as the player, fine. The Ewer is
  the known under-scale object.
- **Palette use:** no stray colours (the palette check passes by construction). `heather`
  is used on the Geest only; `arcane`/`spirit` unused: good. Reeds use `reed`/`straw` for
  their stems in autumn, the same as the autumn ground: that is the autumn contrast loss.
- **--time=23:00 screenshot** (08_camp_night.png) shows the HUD at "16th day of Summer,
  06:30" under a night tint. Either the flag set the time and the clock then ran into the
  passing-out hour, or the HUD lags the tint. Not investigated.

## Proposed tasks (one worker each, in order)

1. **Shared outline helper and a contrast sheet** (S). Move `items.outlined` and
   `OUTLINE_OF` to canvas.py / palette.py as `outline()` and `DARKEST_OF`; point trunks,
   interior, buildings and chest at it; add tools/art/contrast_sheet.py that renders chosen
   atlas rows over the ground colours of every look into build/. Files: tools/art/canvas.py,
   palette.py, items.py, trunks.py, interior.py, buildings.py, chest.py; tools/README.md.
2. **Tall grass, fern and reeds that stand out** (S-M). Ground shadow, dark foot and
   underside, selective outline on the dense core; check all nine looks on the sheet.
   Files: tools/art/meadow.py, trees.py (fern), reeds.py, seasons.py remap check; regenerate
   objects*.png; README screenshot of the meadow.
3. **Willow crown** (M, TASKS.md "Later" item). Closed crown blob with outlined underside,
   rods over it, warmer bark, bare look with dark rod feet. Files: tools/art/willow.py,
   seasons.py; README landscape screenshot.
4. **Autumn stays green on the marsh** (M). Autumn remap by terrain: olive-green for
   grass, floodplain and meadow, straw for dry grass and the Geest, red for the salt marsh
   (already). Files: tools/art/seasons.py, terrain.py; data/seasons.cfg if the look per
   terrain is data; README seasons screenshot.
5. **Dyke as a bank** (M). Corner and diagonal pieces, crest 1-2 tiles wide with slopes
   both sides. Files: tools/art/boundaries.py, game/world/world_generator.gd,
   data/landscape.cfg.
6. **Farm yard: chicken coop, trough, hay rack, draw well, stork's nest** (M). New
   objects/buildings in tools/art/buildings.py or a new tools/art/yard.py, data/buildings.cfg
   (coop) and the world object types (trough, rack, well, nest), recipes, interior map for
   the coop; README livestock section.
7. **Kate variants: brick and Geest** (S). A `style` per building in data/buildings.cfg
   (SPEC "presets with customisation"), two looks of the Kate. Files: tools/art/buildings.py,
   data/buildings.cfg, game/state/building_rules.gd.
8. **Post mill and grinding** (M-L). Mill on a mound, sails in the wind, the flour recipe
   at the mill. Files: tools/art/buildings.py (or mill.py), data/buildings.cfg,
   data/recipes.cfg, data/stations.cfg, maps/interiors/mill.tmx.
9. **Church and Glockenstapel** (L). Two buildings and the churchyard; no interior at
   first (a door that does nothing, or a 9x6 nave with benches). Files as above.
10. **Fisherman's hut, jetty, nets and traps, rowing boat** (M). Files: tools/art/
    buildings.py, coast.py, data/buildings.cfg, world object types.
11. **Uthland-Frisian house** (L) and **Krug** (M), each its own task with an interior.
12. **Trade props** (M): cart, spinning wheel, loom, butter churn, milk pail, peat stack,
    wash tub; and the Geest grains (rye, buckwheat) as crops (M, data/crops.cfg, crops.py).
13. **Hay barrack, sluice, pig sty, Haubarg** (M, M, M, L): later, in that order.
14. **Docs** (S): SPEC's longhouse "gable door" sentence; art-style.md's open list
    (stocking cap in two colours, striped apron, tricorne, sickle/flail/rake/pitchfork,
    buckets); rename `maple_light` when seasons.py is next touched.
