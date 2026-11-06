# Art style guide

How the game should look, for whoever draws next (a person or an agent working in
`tools/art/`). The general pixel rules (outlines, light, shadows, clusters) are in SPEC.md,
"Art pipeline"; this guide adds the period, the place and the things that live there. It
ends with a ranked list of art changes. Written 2026-11-06 from the art on `main` at 122ba59.

## Period and place

About 1700–1800, before industrialisation, on the North Sea and Baltic side of the Cimbric
peninsula: Friesland, Dithmarschen, Eiderstedt, Schleswig-Holstein, the Wadden coast with
its islands and Halligen, and Denmark. The Danish king rules Schleswig and Holstein. A flat
country of three bands: the rich **marsh** behind the dykes (grazing, wheat, beans, big
farms on mounds), the poor sandy **Geest** inland (heath, rye, buckwheat, sheep, small
farms) and the **Baltic hill country** in the east (beech woods, fields in hedgerows).
Thatch, lime-wash and brick, wood and fieldstone; cattle driven south on the ox road; men at
sea for whaling, women running the farms. There is no iron industry, no factory goods and
no railway; the potato arrives in the 1750s. The fantasy comes later and grows out of the
local folklore (see "Fantasy").

## Palette

The palette is in `tools/art/palette.py` (`BASE_COLOURS`, 43 colours) plus
`tools/art/seasons.py` (`COLOURS`, 21), and it is **full: 64 of 64**. Every new colour
needs a merge first.

Principles:

- **Earth first, saturation last.** Most of the screen is muted green, brown, grey-brown
  and grey-blue. Saturated colours (`flame`, `gold`, `ember`, `red_light`, `petal`) are
  accents for paint, flowers, fire and things the player should notice.
- **North Sea light:** cool, soft, often overcast. Water is grey-blue (`water*`), never
  turquoise; shadows lean blue-grey, not black.
- **Paint is a material.** Doors, shutters and window frames get the few strong colours a
  farm could afford: dark green, teal-blue, ox-blood red, white. Not on walls, not on
  roofs.
- **Magic colours stay rare.** `arcane` and `spirit` are meant for magic, and nothing
  else uses them: the Kate's door and shutters are `paint_teal`, and the purple berries,
  bean flowers, turnip shoulders and butterflies are `heather`. Keep these two for magic only.

The swaps made in task 52 (measured use before, in pixels across all of `assets/`):

| Change | Why |
|---|---|
| ~~Merge `meadow_light` (330 px) into `green_light`~~ kept | Now the Scots pine's lit needles (task 51). |
| Merge `meadow_dark` (722 px) into `green_deep` | Same. |
| Merge `lush` into `green` | Terrain only; the two read as one green. |
| Merge `crimson` (377 px) into `rust_dark` | Only for red autumn crowns, which should be rare (see Trees). |
| Merge `frost_light` (546 px) into `snow_shadow` | Same value and nearly the same hue. |
| Add `lime` (about `e8e4d8`) | Lime-wash is a chalky, slightly warm white. `cream` is butter-yellow and makes the Kate look yellow; `snow_light` is too blue. |
| Add `paint_teal` (about `3f7f86`) | The door and shutter teal, so `spirit` is free for magic again. |
| Add `heather` and `heather_dark` (about `8c5c86`, `5a3a5c`) | The Geest heath in August; also good for hand-dyed cloth. |

Four were merged and four added. `meadow_light` was **kept**: since task 51 it is the lit
needle colour of the Scots pine, and `green_light` would turn the dark blue-green crowns
yellow-green (`meadow_dark` there became `green_deep`, which looks the same). So the
palette is full again; the next colour (for example a pale glowing `wisp` green-white for
will-o'-the-wisps, about `c8f0c8`) needs a merge first. After the `lush` merge, lush grass
differs from grass only by its darker blades: still a visible patch, but softer.

## Materials

Light from the top left, outline in the darkest colour of the object's own ramp, 2–4 px
clusters. One material gets one ramp of 3–4 colours; do not invent a ramp per building.

- **Reed thatch** (`THATCH` in buildings.py: `sand`, `bare_light`, `bare`, `mud_dark`,
  `soil_dark`). New thatch is golden (`straw`, `gold`); after a few years grey-brown, with
  moss (`MOSS`) on the north side and low on the slope. Thatch is thick (30–40 cm): draw
  the eaves as a rolled edge 3–4 px tall with a dark shadow under it. Texture as **courses**:
  horizontal bands 3–4 px high, each lighter at its top edge, with short vertical strokes in
  groups, not single-pixel streaks over the whole roof. Ridge: a turf strip (`olive`,
  `green_dark`) in the west, or straw/heather held by **crossed ridge sticks**
  (*kragtræer*, split oak, every 30–40 cm: a row of little X's on the ridge).
- **Lime-washed walls:** flat, almost no texture. `lime`/`cream` lit, `sand_light` in shade
  and under the eaves. A few grey-brown pixels where the wash has flaked near the base.
- **Brick:** small, handmade, irregular. Red (`rust`, `red_light`) in Holstein and Denmark,
  buff-yellow (`sand_light`, `sand`) in the marsh and on the islands. Draw courses as 2 px
  rows with the joint every 4 px, offset per row; joints one step darker, not a grid of
  bright lines. At 1× brick should read as a warm texture, not as a pattern.
- **Half-timber** (*Fachwerk*, *bindingsværk*): oak frames, dark (`soil`, `soil_dark`), 2 px
  wide; posts, sills, a rail at mid-height and **short** diagonal braces near the corners.
  Infill brick or lime-washed wattle and daub. In Denmark the frame is often tarred black
  or washed over with the wall colour.
- **Wood:** oak boards silver-grey when weathered (`bare_light`, `bare`), brown when
  oiled (`soil_mid`, `soil`). Sheds and boats are often **tarred black-brown** (`soil_dark`
  with `ink` seams). Planks run vertically on walls and doors.
- **Fieldstone:** round granite boulders from the glacial till, grey with a warm and a cool
  variant; set as a low base under walls, as dry walls, and as the fireplace ring.
  Rounded, not cut blocks.
- **Metal:** rare and small. Iron is dark grey (`stone_dark`, `ink`) with one light pixel;
  copper and brass (`ochre`, `gold`) for pots, buttons and buckles. No shiny steel, no
  tin-plate grey surfaces.
- **Cloth:** linen (`sand_light`, `cream`), undyed wool (`bare`, `mud`), dyed wool in
  madder red (`rust`), indigo (`water_deep`, `water`) and plant green (`olive`).

## Buildings

All buildings in the region share a long, low body, a huge roof and small windows. Draw
the roof as two clear planes with a straight ridge and hip lines; the bulge of the thatch is
in the eaves and the swells over dormers, not a dome over the whole house. Windows have
**small panes** (6–9 per window, 1 px wooden bars), white or green frames, sometimes
shutters.

- **Kate** (cottage of a day labourer or craftsman): 1 storey, lime-washed or brick, hipped
  thatch, one eyebrow dormer, one door, a small chimney. Often at the foot of a dyke or on
  the edge between marsh and Geest. Good as is.
- **Geesthardenhaus / Danish længehus:** a long house, eaves side to the road, living end and
  byre in one row, entered from the long side. Our longhouse is this type. Danish farms
  add wings around a yard (2, 3 or 4 wings, *firlænget gård*).
- **Uthland Frisian house** (islands and Halligen): long, low, red or white brick, thatch,
  white or green paint, with a **Frisian gable**, a steep cross gable over the front door
  (it keeps burning thatch off the escape route). Always runs east–west, living end east.
- **Low German hall house** (*Hallenhaus*, Niedersachsenhaus), Holstein and the south:
  **gable end to the road** with the big arched barn door (*Grote Door*), half-timber,
  half-hipped roof with the **owl hole** (*Uhlenloch*) under the peak and **crossed horse
  heads** (carved bargeboards) on top. Our hall house (task 59) is this type.
- **Haubarg** (Eiderstedt): the giant of the marsh, an almost square house under a towering
  pyramid of thatch over a central hay store, on a mound. A late-game status building.
- **Barn:** half-timber or boards, big plank doors, no windows; a hay loft hatch.
- **Shack:** boards tarred black or silver-grey with a turf roof (the user chose turf over
  reeds); a fisherman's or herdsman's hut, not a frontier log cabin.
- Details worth having: a bench by the door, a **stork's nest** on the ridge, the door
  split in two halves (*Klöntür*), a date or initials in iron wall anchors, a sod-roofed
  outhouse, a draw well with a sweep.

## Clothing and characters

Period peasant dress, simplified to 16×32 pixels. Men at sea dressed like the port towns,
so there was no single male costume; that gives freedom, as long as it is 18th-century.

- **Men:** white or undyed linen shirt; **waistcoat**, often red, with a row of tin or
  silver buttons; short jacket or long coat in blue, brown or grey wool; **knee breeches**
  (leather or wool) with **white knitted stockings**; **wooden clogs** (*Holzschuhe*,
  *træsko*) for work, buckled shoes or boots for best. Hats: a black felt hat with a broad
  brim or turned up (tricorne for the better-off), or a knitted stocking cap (white or red).
  Hair long, tied back, or shoulder length.
- **Women:** linen chemise, laced bodice, long wool skirt (dark red, blue, black) to the
  ankle, a big **apron** (white, blue or striped), a shawl crossed over the chest, a white
  cap or headscarf. Field work: a sun hood or scarf, sleeves rolled up. Island women have
  distinctive dress with silver filigree (Föhr, Amrum), good for NPCs later.
- **At 16×32:** the readable cues are clogs (pale, wide feet), stockings (pale lower legs
  below dark breeches), the waistcoat colour, the apron and the headwear. Spend pixels on
  those, not on folds.
- **Not period:** baseball-cap shapes, pith helmets, modern long trousers with belts as the
  default (long trousers are fine for sailors and farmhands later in the century), T-shirt
  cuts, sneakers.

## Landscape

The region's landscape is shaped by work; that is what will make it read as North Sea and
not "generic RPG forest".

- **Knicks** (hedges on earth banks, 1–1.5 m bank, hazel, hawthorn, oak overstanders, a
  ditch on each side): the field boundaries of Schleswig-Holstein and Denmark, mostly made
  in the second half of the 18th century. An autotiled 1-tile-wide wall.
- **Dykes:** long smooth green banks of clay faced with turf, sheep grazing on them; a
  wooden plank wall (*Stackdeich*) on the sea side where there is no foreshore; sluices.
- **Marsh:** dead flat green land cut into strips by straight water-filled **ditches**
  (*Gräben*, *Grüppen*) instead of fences; reeds along them; **pollard willows**; cattle.
- **Warften:** farms and villages on dwelling mounds; a pond (*Fething*) on top for the
  cattle.
- **Tidal flats:** wet grey-brown mud with ripple marks, tideways, mussel beds, a few
  stranded boats; salt marsh with samphire turning red in autumn.
- **Geest heath:** heather, juniper, sand, Scots pine, birch, peat cuts with stacked turf.
- **Meadows and pasture** (task 75, `tools/art/flowers.py`): flowers in drifts, never an even
  sprinkle. Spring: daisy, dandelion, cuckooflower (`blossom`) on wet meadows, wood anemone
  in the beech woods; early summer: buttercup, red campion, red and white clover; high summer:
  yarrow, knapweed, meadowsweet by ditches and banks, heather on the Geest. Heads are 1–3 px in
  the flower accents (`gold`, `lime`, `cream`, `petal`, `blossom`, `heather`) on a stem of
  their own; no blue: the cornflower belongs in the rye, and fields have no flowers.
- **Woods:** beech and oak in the east, birch and alder in wet ground. **Spruce and pine
  were not common here before the heath plantations of the late 18th and 19th century**:
  keep them few, in clumps, as planted or Geest trees.
- **Fields:** long strips; rye, oats, barley, buckwheat on the Geest; wheat, beans and
  rapeseed in the marsh; flax (blue flowers) and hemp; kale and cabbage in gardens.
- **Weather:** wind is always there: bent trees, flying clouds, seabirds.

## Props and animals

- **Tools:** wooden-handled, iron only at the edge: hoe, spade with an iron shoe, scythe,
  sickle, flail, wooden rake, pitchfork, axe, wooden buckets with iron or willow hoops, a
  yoke for two buckets, a copper or wooden watering can with a big rose.
- **Carts and boats:** two- and four-wheeled wooden carts with spoked wheels, a
  wheelbarrow, sleds; flat-bottomed sailing barges (*Ewer*) with leeboards that sit on the
  mud at low tide, small rowing boats.
- **Fences and walls:** wattle (woven hazel or willow), split-rail fences, fieldstone dry
  walls, Knicks. No barbed wire, no sawn picket fences.
- **Wells and water:** draw well with a long sweep (*Ziehbrunnen*), a wooden pump later
  in the century, rain barrels, the Fething pond.
- **Mills:** wooden **post mills** (the whole body turns on a post, a tail pole to the
  ground) were the common mill until about 1800; Dutch smock/cap mills arrive during the
  century. Small drainage mills in the marsh.
- **Interior:** open hearth with a smoke hood, or the iron **jamb stove** (*Bilegger*) fed
  from the kitchen; box beds in the wall; blue-and-white Dutch **tiles** on the walls of
  richer houses; benches along the walls; a long table; chests; pewter and earthenware on
  plate racks; clay or brick floors, sanded boards in the best room.
- **Livestock:** red-brown cattle (Angler), black-and-white or red-pied marsh cattle,
  sheep on the dykes, geese, pigs, workhorses, hens. **White storks** on the roofs, lapwings,
  oystercatchers, geese flying over the marsh, seals on sandbanks.

## Avoid

- **Industrial and later things:** factory machinery, steam, iron stoves in a modern shape,
  barbed wire, corrugated iron, glass greenhouses, paper seed packets, tin cans, modern
  sleeping bags, tents, rubber boots, bicycles, railways, telegraph poles.
- **New World crops as staples:** tomatoes (an ornamental curiosity here until the 19th
  century), maize, big orange field pumpkins as a hero crop, modern large garden
  strawberries (use small wild strawberries). Potatoes are fine after about 1750.
- **Wrong regions:** Alpine chalets, Bavarian balconies, Tudor black-and-white with jetties,
  log cabins, Norwegian stave churches and turf houses, Dutch stepped town gables on farms,
  Viking longships and horned helmets (wrong millennium), New England maple reds as the
  default autumn.
- **Generic fantasy:** castles, plate armour, glowing crystals, purple mushroom forests,
  elves with pointed ears. Fantasy here is small, local and a bit uncanny.
- **Rendering:** single-pixel noise, pillow shading, pure black outlines on terrain or
  buildings, gradients, colours outside the palette.

## Fantasy

The spirits come from North Sea and Danish folklore (Müllenhoff's collection of the
duchies' legends is the main source). They are drawn **in the same materials and palette**
as everything else; what makes them strange is proportion, behaviour and a little light,
not new art styles.

- **Nis Puk / nisse:** the house spirit, knee-high, big head, long arms, short legs, small
  clever eyes, grey or red wool clothes and a red cap. Helpful if he gets his porridge with
  butter; spiteful if not. Lives in the barn or the loft (owl hole!). Drawn like a tiny
  farmhand, never cute-cartoon.
- **Klabautermann:** the ship's spirit, a small figure with a pipe, a hammer or caulking
  mallet, sailor's clothes. Seen on boats and at the harbour.
- **Will-o'-the-wisps** (*Irrlichter*): small pale lights over the marsh and the flats at
  night, the one place for a glowing colour (`spirit`, or a new `wisp`). Light, not
  sprites: 2–4 px cores with the game's point lights.
- **Wiedergänger / Gonger:** the drowned dead who walk back from the sea: a figure in wet,
  dark, period clothes, seaweed, grey-green skin (`frost`, `bog`), dripping. Use sparingly.
- **Sea spirits:** Ekke Nekkepenn (a sea man of the North Frisian islands), mermaids on
  the sandbanks, the drowned town of Rungholt glimpsed at low tide.
- **Magic,** if it comes, is folk magic: runes and signs cut into wood, herbs, salt, iron,
  horse heads on the gable, a witch's broom. Effects in `arcane` and `spirit`, small and
  dim, in pixel particles like the fire.

## References

Links only; no images are copied into the repo.

- The first art review (2026-11-05), with the measured sizes behind SPEC.md's scale rules:
  [archive/art-review-2026-11-05.md](archive/art-review-2026-11-05.md). It is a snapshot of
  that day; this guide is the current word.

- Houses and farms:
  - Uthland Frisian house: <https://en.wikipedia.org/wiki/Uthland-Frisian_house>,
    <https://de.wikipedia.org/wiki/Uthlandfriesisches_Haus>; Frisian gable:
    <https://de.wikipedia.org/wiki/Altfriesisches_Haus>
  - Geesthardenhaus: <https://en.wikipedia.org/wiki/Geestharden_house>
  - Haubarg: <https://en.wikipedia.org/wiki/Haubarg>, Gulf house:
    <https://en.wikipedia.org/wiki/Gulf_house>, IG Baupflege:
    <https://www.igbaupflege.de/de/lexikon/bauernhaustypen/haubarg.php>
  - Low German hall house: <https://en.wikipedia.org/wiki/Low_German_house>,
    <https://de.wikipedia.org/wiki/Niederdeutsches_Hallenhaus>, its gable (Uhlenloch,
    Grote Door): <https://de.wikipedia.org/wiki/Niedersachsengiebel>
  - Kate: <https://de.wikipedia.org/wiki/Kate_(H%C3%BCtte)>,
    <https://geschichte-s-h.de/sh-von-a-bis-z/k/kate/>
  - Danish country houses 1750–1870 (længehus, timber framing, thatch; a municipal style
    sheet): <https://vordingborg.dk/Media/638488637241544260/byggeskik-pa-landet-1750-1870.pdf>,
    <https://www.bolius.dk/landhuset-18799/>
- Thatch and ridges: Danish heritage agency guide
  <https://slks.dk/fileadmin/user_upload/SLKS/Omraader/Kulturarv/Bygningsfredning/Gode_raad_om_vedligeholdelse/4.5_Straatage.pdf>,
  ridge types (turf, crossed sticks, Holstein ridge)
  <https://www.bygningsbevaring.dk/uploads/files/udstillingsplancher/UDST_Straatage-2018.pdf>,
  <https://lex.dk/str%C3%A5tag>
- Open-air museums:
  - Frilandsmuseet (Lyngby): <https://frilandsmuseet.dk/en/experiences/farms-houses-and-mills>,
    building list <https://da.wikipedia.org/wiki/Frilandsmuseets_bygninger>, Rømø
    commander's farm
    <https://natmus.dk/museer-og-slotte/frilandsmuseet-det-gamle-danmark/huse-og-gaarde/gaarde-og-huse/roemoe/>,
    photos <https://commons.wikimedia.org/wiki/Category:Frilandsmuseet>
  - Freilichtmuseum Molfsee (Haubarg 1743, Geesthardenhaus 1770, Hallig house, post mill):
    <https://de.wikipedia.org/wiki/Freilichtmuseum_Molfsee_%E2%80%93_Landesmuseum_f%C3%BCr_Volkskunde>
  - Den Gamle By (Aarhus, 18th-century town): <https://www.visitaarhus.com/aarhus-region/plan-your-trip/den-gamle-by-the-old-town-museum-venue-gdk603711>
  - Museumsdorf Cloppenburg (hall houses 1700–1800): <https://museumsdorf.de/en/visit/hauser-en/>
  - Ostfriesisches Landwirtschaftsmuseum Campen (Gulfhäuser):
    <https://de.wikipedia.org/wiki/Ostfriesisches_Landwirtschaftsmuseum>
  - Photos: <https://commons.wikimedia.org/wiki/Category:Thatched_roofs_in_Schleswig-Holstein>
- Clothing: Danish folk costume 1750–1850
  <https://nationalclothing.org/europe/136-denmark/1001-danish-traditional-clothing-%E2%80%93-a-farewell-from-the-1750s-1850s.html>,
  <http://folkedragt.dk/Folder/2019%20Folder%20ENGELSK.pdf>, Slesvig costume
  <https://www.danishfolkcostumes.com/dannevirke>, Schleswig-Holstein costumes
  <https://de.wikipedia.org/wiki/Schleswig-Holsteiner_Trachten>, Föhr women's dress
  <https://www.foehr.de/tracht>
- Paintings: Jens Juel, *A Zealand farm under a gathering storm* (1791–93)
  <https://open.smk.dk/artwork/image/KMS137>; Oluf Braren (Föhr, about 1800)
  <https://en.wikipedia.org/wiki/Oluf_Braren>,
  <https://commons.wikimedia.org/wiki/Category:Oluf_Braren>
- Landscape: Knicks <https://de.wikipedia.org/wiki/Wallhecke>,
  <https://schleswig-holstein.nabu.de/natur-und-landschaft/knicks/geschichte/03233.html>;
  dyke building <https://geschichte-s-h.de/sh-von-a-bis-z/d/deichbau/>,
  <https://geschichte-s-h.de/sh-von-a-bis-z/s/stackdeich/>; Warft
  <https://de.wikipedia.org/wiki/Warft>, Fething <https://de.wikipedia.org/wiki/Fething>,
  Halligen <https://en.wikipedia.org/wiki/Halligen>; Ewer <https://de.wikipedia.org/wiki/Ewer>
- Mills: <https://geschichte-s-h.de/sh-von-a-bis-z/m/muehlen/>,
  <https://de.wikipedia.org/wiki/Liste_der_Windm%C3%BChlen_in_Schleswig-Holstein>
- Crops and livestock: potato
  <https://geschichte-s-h.de/sh-von-a-bis-z/k/kartoffeln/>,
  <https://en.wikipedia.org/wiki/Potato_Germans>; Angler cattle
  <https://de.wikipedia.org/wiki/Angler_(Rind)>; ox road
  <https://de.wikipedia.org/wiki/Ochsenweg>
- Folklore: Nis Puk <https://en.wikipedia.org/wiki/Nis_Puk>, Klabautermann
  <https://en.wikipedia.org/wiki/Klabautermann>, Müllenhoff's text
  <http://www.zeno.org/Literatur/M/M%C3%BCllenhoff,+Karl/M%C3%A4rchen+und+Sagen/Sagen,+M%C3%A4rchen+und+Lieder/Drittes+Buch/500.+Das+Klabauterm%C3%A4nnchen>,
  North Frisian legends <https://www.nordfriiskfutuur.eu/nordfrieslandlexikon/sagen/>

## Changes to make

What the current art does well: the buildings (Kate and longhouse especially) already
look right for the region, from the user's photos; the palette is earthy and calm; light,
outlines and contact shadows follow the rules; the seasons and lighting are strong. The
gaps are period details on the character and props, a few anachronisms, the noisy thatch,
and a landscape that is still generic forest and meadow rather than marsh, Geest and
hedgerows.

Ranked by how much each improves the look for its effort.

### Quick wins

All eight are done (task 52): a straw bedroll, the new straw hat and a red knitted cap, flax
instead of tomatoes, wild strawberries and a green squash, brown, ochre and copper autumn
oaks, small-paned windows, the palette swaps, seed sacks told apart by colour, and a
copper watering can. Kept here as the record of why.

1. **Sleeping bag → bedroll** (small). The red-and-white sleeping bag at the camp is a
   modern camping item. Draw a straw sack with a rolled grey wool blanket, or a sheepskin.
2. **Straw hat shape** (small). It reads as a pith helmet. A low crown with a wide, slightly
   drooping brim, or a black felt hat; add a red knitted cap as a second hat.
3. **Tomatoes** (small–medium). Not a farm crop here before the 19th century. Replace them
   in data and art with broad beans, flax or kale (or keep tomatoes as a rare imported
   seed). Make strawberries the small wild kind and the pumpkin a smaller, greener garden
   squash.
4. **Autumn colours** (small, in `seasons.py`). Many crowns turn crimson and orange like
   New England maples. Here oaks go brown and ochre, beeches copper, birches yellow. Make
   red rare (rowan, cherry) and merge `crimson` away. Coordinate with task 51.
5. **Window panes** (small). Windows are 4-pane modern casements. Use 6–9 small panes
   with 1 px bars, on all buildings and the interior window.
6. **Palette swaps** (small). Merge the five colours listed under Palette and add `lime`,
   `paint_teal`, `heather`, `heather_dark`; repaint the Kate wall in `lime` and its door in
   `paint_teal`, so `spirit` is free for magic.
7. **Seed sacks** (small). All seed icons are the same sack with a tiny mark and can't be
   told apart at 1×. Draw the seed or the crop's colour large on the sack, or tie it with a
   coloured string per crop.
8. **Watering can** (small). The grey tin can with a long spout looks modern. Copper
   (`ochre`) with a big rose, or a wooden bucket with a dipper.

### Bigger items

1. ~~**Period clothes for the character**~~ done (task 53). The most-seen sprite wore a
   generic tunic and long trousers. Now: brown knee breeches over white stockings, pale
   wooden clogs, a red waistcoat with tin buttons over a linen shirt, a short blue jacket in
   a coat slot of its own, and long hair tied back with a ribbon as a third hair style. All
   from existing colours. Still to do: women's dress for NPCs (apron, bodice, cap), and
   buckled shoes for best.
2. ~~**Knicks, dykes and marsh ditches**~~ done (task 54). The features that make the land
   read as Schleswig-Holstein: autotiled Knick hedges of hazel and hawthorn on earth banks,
   turfed dykes along the floodplain, straight water ditches with reeds and pollard willows
   in the marsh, and wattle fences and fieldstone walls as rarer field boundaries, all with
   their seasons (tools/art/boundaries.py and willow.py). Still to do: sheep on the dykes
   (bigger item 8), overstander oaks in the Knicks, a Stackdeich and sluices, and a look per
   season for a whole line rather than per tile.
3. ~~**Thatch texture**~~ done (task 55). The thatch was single-pixel streaks over the
   whole roof and looked like grey fur at 1×, over a dome. Now: courses of combed reed about
   4 px high with wavy edges, a broken lit top and reed ends of mixed length; three clear
   planes (lit left hip, front, shaded right hip) under a straight ridge, so the roofs read
   as steep hipped roofs; crossed ridge sticks on the Kate (the turf ridge is an option).
   Under snow the planes show but no stripes.
4. ~~**Tree species**~~ done (task 56). The woods were oak and conifers half and half. Now
   beech (smooth grey bole, broad dome, copper in autumn), birch (white trunk with black marks,
   narrow open crown, yellow in autumn) and alder (dark stem, narrow cone of dark leaves, green
   late, cones and catkins in winter) are the common trees with the oak, each with every
   season look, its trunks and its seed; spruce and pine stand only in clumps on the Geest,
   and the Scots pine is taller and quieter, no longer a bonsai with an orange trunk. Pollard
   willows and the Knicks' hazel and hawthorn are task 54's. No new colours. Still to do:
   overstander oaks in the Knicks, beech woods for the Baltic hill country once it exists,
   heath with juniper.
5. ~~**Interior hearth and furnishing**~~ done (task 57). The hearth looked like a modern
   stone fireplace. Now: an open hearth of buff brick under a lime-washed smoke hood on an
   oak mantel, with an iron pot, Dutch tiles under the hood and soot behind the fire; red
   brick in a herringbone in the living rooms, beaten clay in the byre, the barn and the
   shack; plate racks with Delft and pewter plates, a spindle-backed wall bench in the Kate;
   the Kate's bed boxed in like a Durk and the longhouse's box bed an Alkoven cupboard, both
   with red curtains and a checked indigo blanket. No new colours. Still to do: the jamb
   stove (*Bilegger*) for a best room, sanded boards there, lime-washed inner walls, and a
   long table.
6. ~~**Shack**~~ done (task 58). It read as a frontier cabin in brown planks under a roof
   of boards. Now upright boards tarred near-black with battens, the tar's blue-grey sheen
   on their edges, a ledged ox-blood door and shutter and a white window on a low
   fieldstone base, under a turf roof on birch bark (the user chose turf over reeds): grass
   in clumps with dry patches and a few flowers, a ragged crest and a thick lip of turf
   with blades hanging over the bark. The houses got a look per season for it: the grass
   on a roof greens in spring and browns in autumn and winter (a turf ridge too); under
   snow the turf is lumpy snow over the lip. No new colours. Still to do: silver-grey
   weathered boards as a variant, a turf-roofed outhouse, frost on the turf.
7. ~~**A hall house with the gable front**~~ done (task 59). The strongest period landmark
   was missing. Now the Low German hall house (`hall_house`, 7x5 tiles) shows its gable to
   the front: oak framing with red brick in it, herringbone between the gable's posts and
   slanting courses beside them, the top boarded in oak with the Uhlenloch under a little
   half-hip, the green Grote Door under a flat white arch and a carved door beam, small
   stable windows. The half-hipped thatch runs back up the picture in two planes, its
   courses running along the side eaves, with a reed ridge; white bargeboards cross over the
   hip in a pair of horse heads, clear of snow in winter. Inside, the Diele between rows of
   stall posts, and the Flett with the open hearth, box beds and plate rack at its end. No
   new colours. Still to do: a Haubarg on a mound for a rich marsh farm, a stork's nest on
   the ridge, a Klöntür in the Grote Door, side doors to the Flett, cattle in the stalls.
8. **Animals of the region** (large). White storks on roofs, red-brown cattle, sheep on
   the dykes, geese; the roe deer and rabbits stay. Task 73 drew the livestock
   (tools/art/livestock.py) without a new colour: Angler, black pied and red pied cattle;
   white, grey (Heidschnucke) and black-faced sheep; brown and white hens and a rooster;
   agouti, white and Dutch rabbits. Still to do: storks, geese, pigs, horses.
9. **Coast and flats** (large). Tidal mud with ripples and tideways, salt marsh turning red
   in autumn, an Ewer on the mud, a Warft with its Fething. Needs map and terrain work
   too.
10. **Post mill and draw well** (medium). Landmark props that date the world at a glance.
