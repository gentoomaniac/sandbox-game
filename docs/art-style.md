# Art style guide

How the game should look, for whoever draws next (a person or an agent working in
`tools/art/`). The general pixel rules (outlines, light, shadows, clusters) are in
[design/presentation/art-pipeline.md](../design/presentation/art-pipeline.md); this guide adds
the period, the place and the things that live there. It ends with a ranked list of art
changes. Written 2026-11-06 from the art on `main` at 122ba59.

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

## Resolution: 32 px per tile

A tile is **32×32 art pixels** (decided 2026-11-08, task 106; see
[design/presentation/look.md](../design/presentation/look.md)),
and the widest view is 1280×720 art pixels: 40×22 tiles (task 118), shown ×1.5 on a 1080p screen
(an art pixel is a window pixel at 1280×720; below that the view is averaged down), the closest
320×180: 10×5.6 tiles. The art was drawn at 16 px per tile (`canvas.TILE`) and scaled up to
the game's tile pixel for pixel while tasks 107 to 116 redrew it group by group; since task 111,
the last group, everything is drawn at the game's tile (`canvas.GAME_TILE`, 32) and nothing is
scaled up. The object atlas is one picture with cells of 96×160; the Ewer's picture is three
cells wide.

Tasks 107 to 116 redrew the art group by group at 32 px: the people (task 113, see
"Clothing and characters"), the farm animals (task 114, see "Props and animals", item 8),
the wild animals and the effects (task 116, below), the ground (task 107, below), the
buildings (task 110, see "Buildings"), the plants (task 108, below), the crops (task 109,
below), the interiors (task 112, below) and the walls, fences, the dyke and the placed objects
(task 111, below). How a group was taken native, for any art still to come from the 16 px
art:

- draw it at 32 px per tile (its cells, frames and offsets are twice the numbers below);
- keep its 16 px art as the classic art (task 117; the player switches with F7): move its old
  generator code, as it was before the redraw, to tools/art/classic/, call it from `main` there
  and put its doubled files in that file's `DOUBLED`, so `make art` writes them as `_16x16` files
  and `make assets` builds assets/classic/ with the names of the new files (tools/README.md says how). The classic files
  need the new files' cell sizes; a picture with no classic version (one first drawn at 32 px)
  shows the new art in both sets. In the game, load the group's pictures through
  `ArtSet.path`; a view or tileset that keeps them joins the group `ArtSet.VIEWS` and loads them
  anew (a tileset rebuilds, the chunks redraw) in `show_art_set()`. The numbers measured on the
  art are the new art's; where the classic art is visibly off by them, choose by
  `ArtSet.is_classic` (the rider's seat on the classic horses, `PlayerView.CLASSIC_SEAT`);
- in the game, a number measured on a picture is either its 16 px number times
  `TerrainTileset.ART_16_SCALE` (a frame size in `WildlifeSprites`, a hop in `Rabbit`) or, once
  its group is native, the number measured on the 32 px picture, without the factor. A number
  that joins two groups is measured on both: the rider's `SEAT` in `PlayerView` (the people's
  seat row on the horse's saddle) was measured anew when the horse was (task 114). Grep for
  `ART_16_SCALE`; the factor also hides in `BuildMode.OUTLINE_WIDTH` and `PROGRESS_HEIGHT`.
  Numbers in the
  pictures' own pixels in data (`sprite_height` in world_object_types.gd, `window_lights` in
  data/buildings.cfg) are the pixels of the files, so they are measured anew too;
- the shaders of its pictures (sway, water, mud, lily pads) work on the art's pixels through
  `art_scale` (game/scenes/art_scale.gdshaderinc), which AmbientMotion sets to `ART_16_SCALE`:
  at 32 px they do without it (as the fire, the rain's splashes and the weather do), and their
  numbers (sway profiles) are measured anew.

The wild animals (task 116: tools/art/animals.py, birds.py, sea_birds.py) are drawn at 32 px
like the people: rounded forms shaded from the top left (forms.py), eyes with a glint, legs
with joints, each outlined in the darkest colour of its own coat or plumage and standing on a
contact shadow (`Animal.draw_contact_shadow`, a flat oval in the game's pixels; the birds in
flight cast one too, `GroundShadows`). The birds are put together by bird_forms.py: a body, a
tail, a neck up to a round head with an eye and a bill, a folded wing, legs drawn over the
outline in two pixels (one for the sparrow, the dunlin and the tern), and in flight open wings
with coloured tips and trailing edges, seen a little from above. Their cells are twice the 16 px
ones; the small animals (sparrow, rabbit, bee, butterflies, mouse, frog, dunlin) are drawn a
little larger than life, so that they read beside a 61 px person: the sparrow about 15 px long,
the mouse 24, the frog 22, the rabbit 22 sitting, the squirrel 22 tall, the roe deer 40 tall,
the stork 38. The effects are native too: the flame's loop of the campfire and the hearth
(fire.py; the fireplace around it is native since task 111, the hearth since task 112), the hit particles (leaves of a few pixels with their corners left out
and a shaded side, long thin needles, round snow clumps, chips, drops), the rain's splashes
(a streak, a crown of droplets, a ring) and the weather (one pixel raindrops, round flakes of 2
to 4 pixels, one pixel wind streaks, leaves with a darker lower row, fog dithered on single
pixels). The animals' and the flames' 16 px art stays as the classic art (tools/art/classic/).

The ground (task 107: tools/art/terrain.py; the clay hint in meadow.py) is drawn at 32 px in
the style of the mockup, and calm, so that people, animals, crops and items read on it without
an outline: a base colour with single blade roots and small tufts (a dark root fanning up to
lit tips, `terrain.tufts`) gathered in patches by a noise (`patch_noise`), few light pixels, no
outline on any terrain; where a layer lies over another its edge is a rim in its own dark
shade or a dither. Round things (pebbles with their shadow, lily pads with their notch,
toadstools, pools) are shaded with forms.py. Tilled soil has four ridges to a tile, the crest
one broken row of `soil_light`, the bands ragged by a pixel and the field's edge dark under
the turf, so the rows read as earth and not as stacked logs; its wet look darkens the same
ridges in patches (`terrain.soil_wet`). The path is packed earth worn pale in patches, dark
under the turf at its edge with blades leaning in; the tidal mud has wavy ripple marks with
dark troughs, which the tide fills first. In autumn the grass of the marsh stays green with
olive tips and only the dry grass of the Geest turns straw (`seasons.LAYER_REMAPS`); the salt
marsh keeps its olive turf, with patches of red-purple glasswort. The ground's 16 px art
stays as the classic art too.

The plants (task 108: trees.py, beech.py, birch.py, alder.py, willow.py, trunks.py, the tall
grass in meadow.py, reeds.py and the meadow flowers in flowers.py) are drawn at 32 px in the
style of the mockup. A crown is `trees.foliage`: clumps drawn from the back (the top) to the
front, each a ragged dome lit from the top left and broken into sprays of leaves, each spray lit
on its own upper left with a dark seam where it meets the next, the crown darker towards its
foot and rimmed in its darkest green (oak, beech, alder, birch, the bushes and the sapling; the
leaf size and the clumps give each tree its build). Trunks are round, furrowed and spread into
roots at the foot (`trees.tree_trunk`); a bare tree parts into thick, elbowed limbs fanning out
into twigs (`trees.crown_limb`, `trees.twigs`). The spruce hangs in tiers of drooping sprays, the
Scots pine keeps its flat umbrella of needle clumps. Tall grass and reeds are blades two pixels
wide with a lit left edge (`trees.blade`), the fern's fronds combs of leaflets. The pollard
willow (from the art review) has a dense, rounded crown with a dark edge and a shaded underside
on the upper parts of its rods, the rods showing below it and over it, a few silver leaves, a
knobbly head and a trunk in `mud` and `mud_dark`; bare, its rods are `umber` up to the middle so
it does not fade into pale ground. No plant is outlined in ink, the dead tree and the trunks
neither: they are rimmed in their darkest bark. The meadow flowers are a stem over a leaf or two
and a head of a few pixels lit on its upper left. The plants' 16 px art stays as the classic
art.

In the wind the plants sway on their own pixels (`AmbientMotion.SWAY_PROFILES`), calmly: half as
far on screen as the doubled 16 px art did (the user, 2026-11-08). Small plants move more than
big ones: tall grass, reeds, fern and the meadow flowers most, so their tips flick in a light
air; the bushes and the sapling less; the big trees least and slowest, still in a light air.
The crops (task 109) bend like the grass (`CROP_SWAY`), so more than the trees.

The crops (task 109: tools/art/crops.py) are drawn at 32 px after the field of the mockup: a
cell a tile wide, two tiles tall for the tall crops (wheat, rye, buckwheat, peas, beans, flax),
the plants' feet 4 px above the cell's bottom, on the lowest ridge of the tilled soil, on a
shadow of dark earth. Leaves, heads, roots and fruit are rounded forms shaded from the top left
(forms.py) and rimmed in the darkest shade of their own colours (`crops.RIMS`), never ink;
stalks, awns, flowers, tendrils and pods, too thin for a rim, are drawn over them in their
light shades. On the dark soil they read without more. The wheat is golden with paired grains
and long awns, the rye of the Geest taller, blue-green when young and ripe a pale grey-yellow
with nodding ears, the buckwheat on red stems with white and pink flowers; a crop dies to
browns and greys (`crops.DEAD_COLOURS`). The crops' 16 px art stays as the classic art.

The item icons (task 115: tools/art/items.py, tool_icons.py, crop_icons.py and the icon parts
of meadow.py, reeds.py, crafts.py, church.py and landing.py) are drawn at 32 px, in the style
of the 32 px art: rounded forms shaded from the top left (forms.py), wood with its grain, cloth
with its folds, iron flat but for a lit top and left rim, a dark bottom and right rim and a
bright edge, copper for the watering can. Each is a body outlined all round in the darkest shade
of its own ramp (`items.RIMS`), none where its edge already is that shade. The UI shows them at
half size, in the 20 UI pixel slots, so an icon's pixel is as big as a world pixel at the
widest zoom. The tools lie on the diagonal, wooden with iron only at the edge: the spade has an
iron shoe, and the pickaxe is the Geest's pick (a point and a chisel) that grubbed the
fieldstones of the till out of the fields and split them. The seed sacks are one linen sack,
told apart by the crop's string, its produce painted on the front at half size and its seeds
spilled in front. An item on the ground is its icon's body at half size (16 px), outlined the
same way, on a contact shadow the game draws. The items that place a world object (the chest,
the stations, the grave marker, the landing's pieces) are icons of its picture, still 16 px
(task 111). The old 16 px icons and ground items are the classic art. The other UI pictures
(slots, frames, the chat portraits' frame) are drawn for the UI's own 640×360 base and scale.

The interiors (task 112: tools/art/interior.py) are drawn at 32 px, as calm as the ground:
old red floor bricks 16×8 in a herringbone, one colour of brick (a second colour repeats with
the tile into a pattern) with joints one step darker and a worn spot on every third, and beaten
clay trodden darker and paler in soft
patches with bits of straw, calm behind the figures; an oak ceiling beam over plaster smoked
warm, a wainscot of raised panels lit on their top and left edges, oak wall plates with their
grain; a window set deep in the wall with daylight brightest at its top left. The furniture is
lit from the top left like everything outdoors, outlined in the darkest shade of its own ramp
(`soil_dark` for oak, `mud_dark` for straw and sacking), and what stands free on the floor
casts a dithered `soil_dark` shadow to its bottom right, which reads on brick and clay alike.
The beds are as long as the 61 px figure lying in them (`PlayerView.LYING_POSES`): the head on
the pillow, the blanket and the cover down to the foot board, so the clogs never show (in the
box bed the figure lies 2 px left and up of the middle, so that its head is on the pillow);
the bedroll at the camp reaches the foot of its footprint for the same reason, and the classic
set keeps the old, shorter bedroll with its own cover. The hearth keeps its flame's box, so the
flame and its profile need no new numbers. The rooms' 16 px art stays as the classic art.

The walls, fences, the dyke and the placed objects are drawn at 32 px since task 111
(boundaries.py, camp.py, chest.py, crafts.py, church.py, landing.py, coast.py), each placed
thing as big as its doubled picture was, so it stands where it stood. The lines across the
land are solids worked out tile by tile (boundaries.py): the Knick a turfed bank with a low dark
core of leaves and hazel and hawthorn bushes on it drawn as leafy domes (sprays of leaves lit on
their upper left, rimmed in their darkest leaves; a tile draws the bushes standing on its own
ground whole, so they never break at a seam); the wattle fence rods 2 px thick woven in and out
round stakes; the fieldstone wall squat granite domes in two courses with grain and moss; the
dyke a turfed bank with a flat crest and a sheep track along it, bending round each corner in a
quarter circle, so a dyke on the slant is one bank winding along rather than terraces (the art
review), and green in autumn like the marsh. The camp's fireplace: a ring of rounded field
stones, ash with embers and three split logs with pale cut ends; the bedroll a quilted sack of
linen ticking with the grey blanket rolled at its head. The chest of oak planks with iron bands
and a brass lock, the carved chest painted blue-green with tulips, the workbench with its vice
and saw, a beehive kiln in courses of clay and a brick oven on footings of field stones, the
cupboard with raised panels, an oak cross, a sandstone headstone and a granite slab; the jetty's
planks with grain and nails on weedy piles, the rowing boat, the net frame and the eel traps.
The Ewer is in scale with the people: a hull about seven tiles long and a mast more than twice
a person's height, a picture three cells of the object atlas wide on a 7×1 footprint. Each is
rimmed in the darkest shade of its own colours (not the dyke, which is turf like the ground)
and stands on a ground shadow. Their item icons are made from these pictures (`items.icon_of`).
Their 16 px art stays as the classic art.

The sizes in this guide (a 48×80 object cell) are those of the 16 px art, but for the
characters' 32×64, the farm animals' (item 8 of "Props and animals") and the object atlas's
96×160.

## Materials

Light from the top left, outline in the darkest colour of the object's own ramp, 2–4 px
clusters. One material gets one ramp of 3–4 colours; do not invent a ramp per building.

Outlines come from `canvas.outline` (a ring outside the drawing; the colour is a name, or
`palette.darkest_of`, which picks the darkest of the ramp of the pixel it surrounds, from
`palette.DARKEST_OF`, ink for anything else) and `canvas.outline_edge` (recolours the drawing's
own border; `keep_bottom` leaves the row that stands on the ground). Use them instead of a
private loop. `character.outlined` and `trees.foliage` stay their own: the first skips
pixels the body already outlines, the second rims a crown of clumps while it shades them.
`make contrast-sheet` shows plants over the ground of every look (tools/README.md).

**Plants with loose blades** (tall grass, fern, reeds) are thin and light, so they vanish on
ground of a similar value. They get `trees.ground_shadow` (remapped per look), a dense foot
from `trees.dense_foot` (the two darkest shades, rimmed in the darkest of the ramp: green_deep
in green looks, umber from autumn on through the remaps in seasons.py), and the lower third of
the blades in the dark shades with the light shades above. Never rim single blade tips: that
clogs the sprite into a dark blot. The reeds' and tall grass' foot colours are remapped in
seasons.py (`_DARK_FOOT`, `_GOLDEN_REEDS`) so the foot stays dark in autumn, bare, frost and snow.

- **Reed thatch** (`THATCH` in buildings.py: `sand`, `bare_light`, `bare`, `mud_dark`,
  `soil_dark`). New thatch is golden (`straw`, `gold`); after a few years grey-brown, with
  moss (`MOSS`) on the north side and low on the slope. Thatch is thick (30–40 cm): draw
  the eaves as a rolled edge 12 px tall (at 32 px per tile: a lit lip over a shaded round and a
  dark underside with a ragged hem). Texture as **courses**: horizontal bands 7 px high, each
  lighter at its top edge, with reed ends of mixed length hanging below it and a shadow line
  at its foot that the longest reed ends break, not single-pixel streaks over the whole roof. Ridge: a turf strip (`olive`,
  `green_dark`) in the west, or straw/heather held by **crossed ridge sticks**
  (*kragtræer*, split oak, every 30–40 cm: a row of little X's on the ridge).
- **Lime-washed walls:** flat, almost no texture. `lime`/`cream` lit, `sand_light` in shade
  and under the eaves. A few grey-brown pixels where the wash has flaked near the base.
- **Brick:** small, handmade, irregular. Red (`rust`, `red_light`) in Holstein and Denmark,
  buff-yellow (`sand_light`, `sand`) in the marsh and on the islands. Draw bricks 8 px long
  and 2 high in 1 px joints, each course offset by half a brick, a few with a lighter corner;
  joints one step darker, not a grid of bright lines. At 1× brick should read as a warm texture, not as a pattern.
- **Half-timber** (*Fachwerk*, *bindingsværk*): oak frames, dark (`soil`, `soil_dark`), 4 px
  wide and lit on their top or left edge; posts, sills, a rail at mid-height and **short** diagonal braces near the corners.
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
**small panes** (6–9 per window: panes 5 px square in 1 px white bars, a glint in the top
left of each), white or green frames, sometimes braced shutters on iron hinges.

Drawn at 32 px per tile since task 110, after the Kate of the 32 px mockup, each picture as
big as its 16 px picture doubled. The doors are about 60 px high, so the 61 px people fit
through them (a door of the 16 px art was some 20 px, doubled 40, a head shorter than a
person). Every building keeps the outline in the darkest shade of its roof's ramp
(`soil_dark`), the shadow under its eaves on the wall and a ground shadow two rows deep
along its foot.

- **Kate** (cottage of a day labourer or craftsman): 1 storey, lime-washed or brick, hipped
  thatch, one eyebrow dormer, one door (a split *Klöntür*), a small chimney. Often at the
  foot of a dyke or on the edge between marsh and Geest. Ours is lime-washed on fieldstones,
  and comes in two more styles (task 120): the brick Kate, red brick in sand joints with
  green paint and a brick chimney, and the Geest Kate, lime over a foot tarred black under a
  turf ridge.
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
- **Church** (task 102, `church.py`): the small marsh churches had no tower. A nave of tuff
  ashlar (grey-brown `stone` and `sand` blocks 15x6 px lit along their top, `stone_dark`
  joints) with a lower chancel, steep roofs of red **pantiles** (columns 10 px wide, each roll
  lit on the left and the trough dark, courses 10 px high with a lit lip over a shadow line; a few
  darker replaced tiles, lichen and moss low down), small round-arched windows of diamond
  leaded glass in red brick arches, a lime-washed porch with its gable to the front (so it
  stands out from the grey nave) and an iron cross on the gables. Under snow the pantiles
  keep their light and shade. Beside it the **bell frame** (*Glockenstapel*): an open oak
  frame on a brick base under a pyramid of silver-grey oak shingles (`stone` ramp), the
  bell in `gold`, `ochre`, `ochre_dark`. The churchyard has the fieldstone wall and graves:
  an oak cross, a sandstone headstone (`sand` ramp, a cut cross and lines of letters) and a
  low granite slab.
- **Fisherman's hut** (*Fischerkate*, task 103): the shack's boards and fieldstones on 4x2
  tiles under a hipped reed thatch with a turf ridge (`turf_ridge`), one small white window,
  a low door in faded teal (`water_light`, `paint_teal`, `water_deep`) and an oar against
  the wall. Its landing is objects (tools/art/landing.py): a jetty of weathered planks
  (`bare_light`, `bare`, joints `mud_dark`) across the way it runs, its free edges
  `soil_dark`, on oak piles (`soil_mid`/`soil_dark`) green with weed at the foot, two mooring
  posts at its head with a rope; a flat rowing boat, tarred outside with a lit wale, floor
  boards, thwarts and oars inside; a net frame with a tarred net (`umber`, `soil`) in open
  4 px diamond meshes so the ground shows through, cork floats along the hem; wicker eel
  traps (`straw`, `sand_light`, `sand`, `mud`, hoops and outline `mud_dark`). Snow covers
  the deck and the boat's floor (a remap, as the planks lie flat), and caps the rest.
- Details worth having: a bench by the door, a **stork's nest** on the ridge, a date or initials in iron wall anchors, a sod-roofed
  outhouse, a draw well with a sweep.

## Clothing and characters

Period peasant dress, simplified to 32×64 pixels. Men at sea dressed like the port towns,
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
- **At 32×64** (task 113, after the mockup in review/resolution-mockup-2026-11-08, "Die
  Siedler 1 level of fidelity"): the figure is 61 px from the crown of a hat to the soles,
  the head 16 px wide. The readable cues are still clogs (pale, wide, lit on top, a dark
  sole), stockings (pale lower legs below dark breeches with a band and a button at the
  knee), the waistcoat colour with its buttons and pockets, the apron and the headwear; the
  pixels beyond them go to the face (eyes with a glint, brows, a nose shadow, cheeks, a mouth),
  a collar and full sleeves gathered at the wrist, not to folds. The parts are rounded forms
  shaded by the light from the top left (`tools/art/forms.py`), each in the 2-3 shades of its
  own colour; every layer is drawn on one `Figure` (character.py), so they line up, and only
  the silhouette has the ink outline. A small contact shadow is drawn under the feet in the
  game.
- **Tools in the hand** (task 119, `HELD_TOOLS` in character.py): every tool is in the right
  hand, in the colours of its icon (ash handle, iron head with a `snow_light` cutting edge, the
  watering can copper). The long ones (hoe, shovel, scythe) stand on the ground beside the
  figure, their working end up (the shovel on its blade); the short ones (axe, pickaxe, hammer,
  watering can) hang in the hand, the head just above it, and from the side swing with the
  near hand. From the front a tool is at the left of the figure, from behind at the right and
  behind it, from the side in front of it; the head points away from the body (forward from
  the side), so it shows beside the figure. The classic art has only the hoe; the others show
  the new picture in both sets.
- **Not period:** baseball-cap shapes, pith helmets, modern long trousers with belts as the
  default (long trousers are fine for sailors and farmhands later in the century), T-shirt
  cuts, sneakers.
- **Villagers** (task 84, `tools/art/villagers.py`) are put together from the same layers as
  the player, on the same figure: four skins (`skin`, a fair `cream`, a tanned
  `skin_shade` and a dark `soil_light` face), five hair colours (brown, blond, red, grey,
  black) in the styles short, long, tied, a bun and plaits with red ribbons; waistcoats and
  breeches in other wools (indigo, plant green, brown, black; leather breeches), brown and
  black jackets, a black felt hat with the straw hat's brim, a tricorne of black felt edged in
  a pale braid, the stocking cap in white as well as red; for the women a laced bodice over
  the chemise, a long skirt to the ankles (madder red, indigo, brown, black, heather), a
  white, blue or blue-and-white striped apron, a shawl (red, cream, heather), a white coif or
  a red or blue headscarf. No new colours. The trades' props in hand (the fisherman's net, the
  shepherd's crook) are not drawn yet.
- **Portraits** for the chat (`tools/art/portraits.py`): a 32x32 head and shoulders for
  every layer that shows in a bust, shown at 2x: the top 32 rows of the layer's frame facing
  the viewer, standing still, so the portrait has the figure's own face.

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
- **Fields:** long strips; rye, oats, barley, buckwheat on the Geest (rye and buckwheat are
  crops, task 109); wheat, beans and rapeseed in the marsh; flax (blue flowers) and hemp; kale
  and cabbage in gardens.
- **Weather:** wind is always there: bent trees, flying clouds, seabirds.

## Props and animals

- **Tools:** wooden-handled, iron only at the edge: hoe, spade with an iron shoe, scythe,
  sickle, flail, wooden rake, pitchfork, axe, wooden buckets with iron or willow hoops, a
  yoke for two buckets, a copper or wooden watering can with a big rose; the pick
  (Kreuzhacke) for grubbing out and splitting the fieldstones of the Geest till. The game has
  the hoe, axe, pick, scythe, spade, hammer and watering can; the sickle, flail, rake,
  pitchfork, buckets and yoke wait for a job in the game (the grain harvest and threshing,
  hay, carrying water).
- **Carts and boats:** two- and four-wheeled wooden carts with spoked wheels, a
  wheelbarrow, sleds; flat-bottomed sailing barges (*Ewer*) with leeboards that sit on the
  mud at low tide, small rowing boats (a flat-bottomed one lies at the fisherman's landing,
  task 103).
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

## The pixel font

The UI font (`assets/ui/font.fnt`, generated by `tools/art/ui.py`) is 5 px wide (Ø is 6) with a 7 px
cap height and a 12 px line: the top two rows are kept for the marks of accented capitals, so
no label clips them. It covers ASCII, the Latin-1 letters (À-ÿ, with ß), the Latin Extended-A
letters of German, Danish, Norwegian, Swedish, Dutch, Frisian, Polish, Czech and Turkish, and
the punctuation and symbols language models write (« » ‹ › ¿ ¡ ‘ ’ “ ” „ ‚ – — … • € £ © § µ ² ³).
Accented letters are a base letter plus a two-row mark. Add a letter by drawing it in
`GLYPHS` or by listing it in `COMPOSED`.

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

- The first art review (2026-11-05), with the measured sizes behind the scale rules of the design:
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
   from existing colours. Task 84 added the women's dress for the villagers (bodice, skirt,
   apron, shawl, coif and headscarf) and more colours of the men's clothes, skins and hair.
   Still to do: buckled shoes for best, island dress with silver (Föhr, Amrum).
2. ~~**Knicks, dykes and marsh ditches**~~ done (task 54). The features that make the land
   read as Schleswig-Holstein: autotiled Knick hedges of hazel and hawthorn on earth banks,
   turfed dykes along the floodplain, straight water ditches with reeds and pollard willows
   in the marsh, and wattle fences and fieldstone walls as rarer field boundaries, all with
   their seasons (tools/art/boundaries.py and willow.py). Sheep can graze on the dykes, which
   are walked on like grass. Still to do: overstander oaks in the Knicks, a Stackdeich and sluices, and a look per
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
8. ~~**Animals of the region**~~ done (tasks 73 and 60). Task 73 drew the livestock
   (tools/art/livestock.py): Angler, black pied and red pied cattle; white, grey
   (Heidschnucke) and black-faced sheep; brown and white hens and a rooster; agouti, white and
   Dutch rabbits; they can graze the dykes, which are walked on like grass. Task 60 drew the
   big birds of the marsh (tools/art/birds.py): the white stork (38 px tall at 32 px), white
   (`lime`, `stone_light`) with black flight feathers (`ink`) and a red bill and legs
   (`red_light`, `ember`), standing, hunting with the head down, striking, clattering with
   the head thrown back and flying; and the greylag goose, grey-brown (`bare_light`, `bare`,
   `mud`) with a pale breast, a white tail and an orange bill (`flame`), standing, grazing,
   walking and flying. Flying birds are seen from a little above: the far wing above the body,
   the near wing below it. No new colours. The roe deer and rabbits stay. Task 80 added the
   small ones (tools/art/animals.py): a grey-brown mouse (`mud`, a pale belly, pink ears, a
   bare `skin_shade` tail drawn over the outline so that it stays thin), sitting and
   scurrying, and an olive common frog (`dry_light` with `olive` blotches, a pale throat that
   puffs out), sitting and hopping; and a stork swallowing a frog. Still to do: a
   stork's nest on a ridge, lapwings, seals on the sandbanks, pigs. Task 79
   added dogs (a collie in brown with a white collar, a grey spitz with its tail curled over its
   back, a liver-and-white hunting dog with drop ears), cats (tabby, black with gold eyes,
   ginger) and horses: a heavy marsh horse about 32 px long in bay (black mane, tail and lower
   legs), black and dapple grey, and a dun pony; all of them gallop. The horse's neck and head
   rise ahead of its back, which stays free for a saddle and a rider. A bone item. No new
   colours. Task 81 added the saddle (leather in `rust`, `rust_dark` and `russet_deep`, a
   `stone_light` stirrup) as an item and on the horse, the player's layers sitting astride
   (from the side the near leg down the flank and the foot in the stirrup; from the front and
   behind both legs outside the horse) and the ridden horse seen from the side, the front (its
   head in front of the rider) and behind, standing, walking and trotting on diagonal pairs.
   From the front and behind the horse is 14 px wide (the pony 12), broad enough under the
   rider's legs not to read as a pole. No new colours. Task 82 added a cat on the hunt, in
   every look: crouched with the belly near the ground, the head level with the back, the ears
   laid back and the tail flat behind (its tip flicking); creeping low on bent legs; and the
   pounce, from the crouch to a leap stretched out two pixels off the ground and a landing with
   the head down on the mouse. No new colours. Task 114 drew the farm animals anew at 32 px
   per tile, after the mockup (review/resolution-mockup-2026-11-08), every action and frame
   kept: rounded forms shaded from the top left with `tools/art/forms.py` (as the people), the
   body and the neck with the head shaded as one form with more light on top, legs as limbs
   through their joints (a horse's forearm, knee, cannon, fetlock and hoof, its hind leg with
   the hock pointing back), the far legs a step darker, an eye with a glint, nostrils, ears,
   manes and tails in strands; each look's marks (pied patches shaded with the body, dapple
   rings, the dun's dark stripe, a bay's black points and white blaze, tabby stripes, wool
   curls, the collie's white collar) on top. The cow's head is drawn by hand, one for looking
   ahead and one for grazing (turning the first one over mirrors it). Sizes against the
   61 px people: the horse 88 px long and 57 px to the withers (88×76 cell), the pony four
   fifths of it, the cow 40 px to its back (72×54), the sheep
   22 px (44×32), the dog 48×36; the hen (24×24), the cat (32×24) and the rabbit (24×20) a
   little larger than life. The outline is the darkest colour of the coat (ink for the black
   and dark ones) and goes round the legs too; every animal stands on a contact shadow. The
   saddle sits on a blue wool cloth (`water_deep`, `water`), so that the rider's brown
   breeches don't merge with a bay. From the front and behind the ridden horse is 28 px wide.
   Readable on summer grass, snow, at dusk and at night (checked in screenshots). No new
   colours.
9. ~~**Coast and flats**~~ done (task 61). The world had no sea. Now the Wadden coast lies
   in the west: a sea dyke, then the salt marsh (grey-green turf with silvery sea purslane and
   glasswort, drawn in logical colours that each look maps: red-purple in autumn, with thrift
   and sea lavender among the flowers), the tidal mud (grey-brown, ripple marks along one wave
   across the tiles, lugworm casts, shells, a mussel bed, wrack), tideways and the sea; a tide
   that floods the mud by a relief of its own (mud.gdshader); a Warft, a grass mound whose
   edges are lit and shaded slopes, with its Fething; and an Ewer on the mud (tools/art/
   coast.py): a tarred hull lying askew with a raised leeboard, the mast leaning, the brown
   sail furled; since task 111 in scale with the people, a picture three object cells wide.
   No new colours. Still to do: mussel beds and seals as objects, a Stackdeich
   and sluices, ice on the mud, the tide's water reaching up the tideways' banks, Halligen. Task 99 added the sea birds
   (tools/art/sea_birds.py): the oystercatcher, black above and white below (`ink` with an
   `ink` outline, `lime`) with a long orange-red bill (`flame`, `red_light`) and pink legs,
   about 20 px long at 32 px; the dunlin, small and grey (`stone`, `stone_light`, a `stone_dark`
   outline so it stands out from the grey-brown mud) with a white belly and a drooping black
   bill; both standing, looking round, probing, walking and flying with a white wing bar. The
   herring gull, white with a blue-grey back (`snow_shadow`, `snow_deep`), black wing tips and
   a yellow bill with its red spot (`gold`, `red_light`), about 26 px long: standing, calling,
   walking, pecking, swimming in a ring of `foam` and flying. The common tern, slender and pale
   (`lime`, `snow`) with a black cap and a red bill: flying, hovering with the head bent down,
   plunging, the splash (a crown of spray falling back to a ring, without an outline) and
   flying with a silver fish. No new colours.
10. **Post mill and draw well** (medium). Landmark props that date the world at a glance.
