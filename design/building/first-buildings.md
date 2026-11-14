# First buildings

- **First buildings** (decided 2026-11-05), in the style of the Danish and North German
  countryside, each with its own inside:
  - **Shack:** a small wooden hut, the cheapest shelter. Footprint 3×2, door on the middle
    tile.
  - **Fisherman's hut** (*Fischerkate*, task 103, 2026-11-08, from the art review of that
    day): the shack's kin at a landing, the Ketels' home: 4×2, door on the second tile, tarred
    boards under a reed thatch with a turf ridge, one small window. Costs 25 logs, 5 stone,
    15 reeds. Its landing is made of world objects, not part of the building (see **The
    landing** below).
  - **Kate:** a small cottage, 5×3, door on the middle tile. It replaces the old small
    house (old saves map to it). Two more styles (task 120, 2026-11-09, from
    review/art-review-2026-11-08): the **brick Kate** (red brick in sand joints on the
    fieldstones, white frames, green door and shutters, a brick chimney; 30 clay instead of
    15), as Kerrin Paulsen's house at the dyke foot, the mill house or the sexton's; and the
    **Geest Kate** (the lime wash over a foot tarred black instead of the fieldstones, a turf
    ridge; 35 logs, 5 stone). Same rooms inside.
  - **Longhouse:** a larger farmhouse, a Geesthardenhaus entered on its long side by a big
    arched door like the hall house's Grote Door; 7×3, door on the middle tile.
  - **Hall house** (task 59, 2026-11-06, from docs/art-style.md): the Low German hall house
    (*Niederdeutsches Hallenhaus*, Niedersachsenhaus) of Holstein, the biggest and dearest
    building: 7×5, its gable end to the front with the door (the Grote Door) on the middle
    tile. Costs 100 logs, 40 stone, 50 clay, 80 reeds (kept for now, the user 2026-11-14; tuning
    comes later). A Haubarg (the giant of the marsh under a pyramid of thatch) comes later.
  - **Barn:** a work and storage building, no hearth or bed; 6×3, door on the third tile
    from the left, no windows. Costs 30 logs, 15 stone, 5 clay, 25 reeds. The longhouse
    costs 60 logs, 30 stone, 30 clay, 50 reeds.
  - **Church and bell frame** (task 102, 2026-11-08, from review/art-review-2026-11-08): the
    parish church of a marsh village, 6×4, door in the porch on the third tile. A nave of
    grey-brown tuff ashlar with the lower chancel to the east, steep roofs of red pantiles
    (village churches here were tiled, not thatched), small round-arched windows of leaded
    glass in brick arches, a low lime-washed porch on the south side with its gable to the
    front, iron crosses on the west gable and the porch. Costs 70 logs, 35 stone, 45 clay
    (the pantiles are fired clay). The small marsh parishes had no tower: the **bell frame**
    (*Glockenstapel*), 2×2, is an open oak frame on a brick base under a pyramid of oak
    shingles, the bronze bell in it; 25 logs, 5 stone, 10 clay. It has no inside: its
    `interior_map` is empty, none of its tiles can be walked on and nobody goes in. It can be rung (task 180,
    2026-11-11): E or a click on it within one tile rings the bell (see
    `design/presentation/sound.md`), with no effect on the game yet. The
    **churchyard**: the fieldstone wall of the fields, and **grave markers** made at the
    workbench (woodworking 15: 2 planks, 2 stone) and placed outdoors only, which stand as an
    oak cross (always: the user, 2026-11-10; headstones may come later as their own crafted
    item); the pickaxe takes them up. The world generator places no church yet: there is no
    village in the world to put it in (the Warften on the salt marsh are empty); `--churchyard=<x>,<y>` puts one in
    view for screenshots.
  - **Chicken coop** (task 122, 2026-11-10; behaviour in design/farming/livestock.md): 2×2, low
    and boarded, door on the bottom left tile: upright tarred boards on a footing of field stones
    under a low shed roof of grey boards, a ramp with cleats up to the hens' hatch, a nest box
    with its lid propped open; no window (so no lit picture of its own and no snow-time light), no
    bed. Costs 12 logs and 4 stone. Its inside is 6×6 (clay floor, one window, two hay piles for
    nests, sacks and a crate); it is made when the coop is first needed (`Building.inside`: the
    first time someone goes in, or a hen lays an egg in it), not only when entered.
  - **Insides** (decided 2026-11-05): each is a Tiled map, `maps/interiors/<id>.tmx`, a little
    larger than the footprint: shack 6×6 (straw sleeping mat, crate, stool), fisherman's hut
    7×6 (the shack's room a tile wider: sleeping mat, stool, barrel, sacks), Kate 9×8 (hearth,
    bed, table, stools, chest), longhouse 15×8 (living end with hearth, box bed, table and
    bench; a stall partition divides it from the animal end with stalls, hay and sacks), barn
    13×8 (four hay stalls, crates, barrels, sacks), church 12×9 (a nave with six pews either
    side of the aisle and a table for the altar under two windows), hall house 15×13: the Diele, a long
    threshing floor of clay from the door up the middle, rows of oak posts with rails (the
    stall partitions) on both sides and hay, barrels, a crate and sacks in the stalls; at its
    far end the Flett in brick across the whole width, with the open hearth on the back wall
    straight behind the door (a cooking station like every hearth), a box bed in each corner,
    the wall bench, a chest, table, bench and stool, a plate rack and three windows. The room
    is taller than the screen at zoom 1, so the camera follows the player through it as
    outside. Sleep fills: mat 80, bed and box bed 100.
    The barn and the church have no bed, so they can't be slept in.
  - **Items on the floor** (task 200, 2026-11-11): an interior has its own piles of items, like
    the world's (`GameMap.ground_items`), saved with the interior. Dropping works inside
    (the drop key, a stack dragged out of a window); the piles lie on free floor only (never on a
    wall, on furniture that blocks or on the doormat), within the room, show on the floor in
    both arts, are picked up as outside and stay when the player leaves and comes back. Piles have no
    wind, rot, animal or rain behaviour anywhere, so nothing is left out indoors; the settle after a
    drop and the auto pickup work indoors as outside.
  - **Furnished in the period** (task 57, 2026-11-06, from docs/art-style.md): the rooms look
    like 18th-century North Frisian and Danish farmhouses. Floors: red brick in a herringbone
    in the living rooms (the Kate, the longhouse's living end), beaten clay in the work rooms
    (the byre, the barn, the shack); clay is a terrain of its own (`CLAY_FLOOR`) and sounds
    like soil underfoot, while clogs clack on brick as on wood. The hearth is an open hearth
    of buff brick under a lime-washed smoke hood on an oak mantel, with an iron pot, Dutch
    tiles (blue-and-white Delft) on the wall under the hood and soot behind the fire; the
    hood stands on the back wall above the hearth's footprint, and its fire burns as before
    (same shader, light and sound). Plate racks with Delft and pewter plates hang on the back
    wall of the Kate and the longhouse's living end (wall pieces, like the window); the Kate
    has a spindle-backed bench against the back wall. The Kate's bed is boxed in like a Durk
    under a canopy with red curtains, the longhouse's box bed a panelled cupboard (an
    Alkoven) open onto the bed, reaching up the wall to just under the window; both under a
    checked indigo blanket. All furniture blocks walking as before; footprints, beds, doors
    and every free floor tile stay reachable (tested). A save from before (version 11) takes
    today's floors and the wall pieces its rooms lack; the furniture on the floor stays as
    the player left it. The jamb stove (*Bilegger*) of the best room is left for later.
  - The look (from the user's reference photos, 2026-11-05): the roof is the hero, a huge,
    thick reed thatch, weathered grey-brown with moss, hipped at both ends with heavy rounded
    eaves, and eyebrow dormers (the thatch swells in a wave over a half-round window). The
    roof is steep planes, not a dome (task 55): a lit left hip, the front slope and a shaded
    right hip with a straight ridge; the reed lies in courses 7 px high (at 32 px per tile)
    with wavy edges, lit along their top in broken runs, with reed ends of mixed length
    hanging below over a ragged shadow line, and moss and weathering in patches. Under snow the planes show but no stripes. The Kate has lime-washed walls (`lime`), a
    teal door and shutters (`paint_teal`), white window frames, crossed sticks on its ridge
    and a small white chimney; its door is a split door (Klöntür) and its shutters are
    braced, on iron hinges. The longhouse has buff brick on a fieldstone base, crossed sticks
    on its ridge, two brick chimneys, white windows in dark green frames, climbing roses, and
    the big arched green barn door of the hall house as its door (the middle tile), the
    thatch sweeping up over it. The barn is half-timbered (dark oak beams, red brick) with big
    plank doors and no windows. The shack (task 58) is a fisherman's or herdsman's hut, not a
    frontier cabin: upright boards tarred near-black with battens over the joints (the tar's
    blue-grey sheen on their edge), on a sill beam and a low fieldstone base, a ledged door
    and a shutter in ox-blood red, a white window; a turf roof on birch bark, grass in
    clumps with dry patches and a few flowers, a ragged crest and a thick lip of turf at the
    eaves with blades hanging over the pale bark edge. Under snow the turf is lumpy snow with
    the lip and the bark showing under it.
    The hall house (task 59) shows its gable: oak framing with red brick, laid in herringbone
    between the gable's posts and in slanting courses beside them, the top of the gable
    boarded in oak with the owl hole (*Uhlenloch*) under a little hip, the green Grote Door
    under a flat white arch and a carved door beam, small stable windows in green frames to
    either side and short braces in the corner bays. Its half-hipped thatch runs back up the
    picture: seen from the gable, the eaves run along the sides, so the courses run up the
    picture on its two planes (the left lit, the right in shade), with rolled eaves along
    both sides, the reed cut along the rakes, a roll of reed as the ridge (lying along the
    roof, narrowing as it runs back and ending short of its back) and moss low on the shaded
    plane. White bargeboards lie along the rakes and cross over the hip in a pair
    of carved horse heads (*Pferdeköpfe*); under snow the boards and the heads stay clear.
    Every building has lit windows and a look per season of the grass on its tile (task 58,
    SeasonalArt.HOUSE_LOOKS): the grass on a roof (the shack's turf, a turf ridge) is fresh
    in spring, then darker green in autumn and winter like the grass of the ground, its dark
    base and the moss on a thatch green all year; the snow builds up on the roof from the ridge
    to the eaves by shader (task 185, `<house>_snow_cover.png`). Frost leaves a roof in its
    season's look; the build ghost always shows the summer look.
    Windows have small panes (task 52): 2×2 px panes in 1 px white glazing bars, 3×3 panes
    in a house window, 2×3 in the shack's, and the dormers' half-round windows divided
    the same way; a lit pane glows in one colour. The window inside is the same, with
    wooden bars and daylight.
- **The landing** (task 103, 2026-11-08): what stands by the fisherman's hut, placed with
  items like a chest: a **jetty**, laid a piece (1×1) at a time and joined to its neighbours
  like a Knick, on water, the sea, mud or the salt marsh at the edge; it is walked on over
  the water (the `deck` of WorldObjectTypes) and has mooring posts at its head. A flat
  **rowing boat** (2×1) lies on water or mud, only to look at, like the Ewer. A **net frame**
  (2×1, a tarred net hung on a pole between forked posts) and **eel traps** (1×1, wicker)
  stand on the land. The jetty piece (3 planks, 1 log, woodworking 20) and the boat (10
  planks, 4 fibre, woodworking 35) are made at the workbench, the net frame (2 logs, 8 fibre)
  and the eel traps (4 reeds, 1 fibre) by hand. The axe takes the jetty, the boat and the
  frame down for their items; the traps are picked up by hand, but not the jetty the
  player stands on ("Step off it first.", for the axe and the hammer alike), and a player
  who stands where they don't fit can always step onto a deck, so nobody is left in the
  water. A deck is walkable for everyone: animals, villagers and a ridden horse can go out
  on a jetty too, and getting off a horse there puts the player on the jetty, never in the
  water (getting off looks for a tile they can stand on). No fishing yet.
