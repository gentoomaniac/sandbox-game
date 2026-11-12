# The coast

- **The coast** (task 61, 2026-11-06): the North Sea lies in the west, the Wadden coast of North
  Frisia. Numbers in `data/landscape.cfg` ([coast], [tideways], [warften], [ewers]), first
  values, tune in play.
  - **Where:** a coast line runs north to south about 260 tiles west of the centre, wandering 40
    either way, so the farm and the camp lie far inland. The river runs out through it into the
    sea, widening.
  - **The sea dyke** stands on the first tiles of the land all along the coast (the floodplain
    too), without gaps but for the river: the dykes of the river (task 54) sit between the land
    and the marsh, this one between the land and the salt marsh, as real sea dykes do. The marsh
    with its ditches reaches 36 tiles inland from it as from the river.
  - **The foreshore**, west of the line, which nothing grows on: a band of **salt marsh** (about
    12 tiles, give or take 5), then the **tidal mud** (out to about 140 tiles, give or take a
    third), then the open **sea**. **Tideways** wind through the mud, one per 36 rows, from a tile
    wide at the salt marsh (or a little way out) to 7 wide towards the sea; they keep 3 tiles
    clear of the river, so no mud is cut off from the land. The water beyond the coast line is
    the sea's (`SEA`): water to walk and draw, without lily pads, frogs or reeds.
  - **Walking:** the salt marsh is walked on at any tide, the mud only where the tide does not
    cover it; the tideways and the sea are not walked on. Nothing is built on the foreshore but
    the Warft; nothing is tilled there, and nothing is dropped on flooded mud.
  - **The tide:** high water every 12 hours 25 minutes, a little later each day. The water rises
    over the mud by a relief of its own, filling the ripple troughs and hollows first, then pools
    that join, until the flats are under; a light line marks its edge. `Tide` ports that relief
    from the shader, and a tile of mud is flooded (`World.is_flooded`) when the water covers most
    of it, which is how the picture reads at the edges: a tile that looks mostly dry can be
    walked on. The dark troughs of the mud's pixels lie lower in the picture but not in the rule.
    Flooded mud is not walkable (`World.is_ground_walkable`, the one place that says so, for
    wading to change later): not for the player, the villagers or the farm animals, and the
    paths of the villagers go round it. Whoever stands in it (the water rose, or a game was
    saved there) can step off it, and on over any connected flooded mud (`GameMap.is_wadeable`),
    until wading is designed, so no one is cut off; a jetty over the mud stays walkable. Wading birds stay. Ice on the mud in winter: not
    done.
  - **Looks:** the mud keeps its look in every season and weather (the tide washes it). The salt
    marsh is grey-green turf with silvery sea purslane and green glasswort, fresher in spring,
    red-purple in autumn (the glasswort red), brown-grey in winter, rimed or white under frost
    and snow. Thrift flowers on it in late spring, sea lavender in late summer (task 75's flower
    habitat `salt_marsh`). Storks and geese come to it.
  - **A Warft** stands out on the salt marsh in one of every 150 rows of the coast (chance 0.7),
    never where the river runs out: an oval mound about 11 by 8 tiles with a pond (Fething) on
    top, in a ring of salt marsh. It is dry grass that can be walked and built on (not tilled), a
    spot for a later task to build on; nobody lives there yet.
  - **An Ewer** lies on the mud in one of every 70 rows (chance 0.6), 22 to 60 tiles out: a
    world object on 7x1 tiles, to look at; it blocks the way and no tool takes it. Its hull is
    about seven tiles long and its mast more than twice a person's height (task 111; it was held
    to one object cell, 3x1 tiles, before), still a little smaller than a real one.
  - **Old worlds:** saves from before the coast (version 17 and older) are no longer read (see
    [Saving](../tech/saving.md)); the upgrade that let the coast give way around an old home went
    with them.
