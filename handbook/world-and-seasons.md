# The world: seasons, land, weather and light

How the land looks and changes through the year.

## A world that changes with the seasons

There are four seasons of 30 days each. The ground, the trees, the bushes and the buildings each
have a look for every season: fresh green in spring, full summer foliage, autumn colours of the
North Sea, and snow in winter. The woods are those of the region: grey beeches under broad domes
that turn copper, white birches that turn yellow, dark alders on wet ground that stay green late and
hang with cones in winter, and oaks in brown, ochre and copper. The grass itself stays grass and
only shifts its colour gently and evenly through the year, fresh green in spring and darker green in
autumn and winter; fallen leaves, frost and snow come over it as overlays that build up and melt
gradually, a few more leaves under the oaks, a rime on a cold morning, a thin snow that thickens and
thaws first on the paths and in the open, with soft edges that never follow the tiles, and the snow
settles on the trees, bushes and stones from the top down and on the roofs from the ridge to the
eaves. The trees follow their season over its first three days, tree by tree: in spring the trees
and bushes leaf out in steps, from bare twigs to a haze of buds, thin young leaves and then the full
crown. Scots pines, tall with a loose flat crown, and spruces stay green all year; they are rare, in
clumps on the dry Geest. Ground cover thins and fills over the year, ferns die back in winter, and
berry bushes only bear fruit in their season.

![A wood of oak, alder and birch by a meadow and a pollard willow: on the second day of spring, in summer, on the third day of autumn and in the first snow](../docs/screenshots/seasons.png)

The meadows flower from spring to late summer, in drifts and patches rather than sprinkled evenly:
the first daisies, dandelions and, in the beech woods, wood anemones in early spring, cuckooflower
on the wet meadows, then buttercups, red campion and red and white clover, and in high summer
yarrow, knapweed, meadowsweet by the water and the heather on the Geest. Each drift has its few
species that take over from each other, so a patch changes colour with the weeks; the first and the
last flowers of a species are small ones, and autumn sees them fade. Fields, water and the woods
have none or few. Bees keep to the flowers: they come only where something blooms, more where more
does, and their quiet buzz comes from where they are. Where the flowers grow is in
[data/flowers.cfg](../data/flowers.cfg), when they bloom in
[data/vegetation.cfg](../data/vegetation.cfg).

![The same meadow on the 8th and the 25th day of spring and the 15th and the 27th day of summer](../docs/screenshots/meadows.png)

Where you walk often, the grass wears: first it is trodden, thin and flattened with the earth
showing through, then a path of bare earth with grass creeping in at its edges, and the flowers and
tufts on it are gone. Walk the same line a few times a day and a path forms in a few days; leave it
and it grows back over a week or two. Paths fade softly into the grass around them, change with the
seasons, lie dark in a winter without snow and show as a faint trodden track under snow. Cows and
the other farm animals wear the ground too where they keep walking, and so do the villagers on their
rounds. A path is only a look: it walks, tills and builds like grass. Where many feet have worn a
whole yard, the trodden and path ground joins into one calm patch of earth with no repeating shapes,
and its edge follows at once as tiles wear or grow back. The numbers are in
[data/paths.cfg](../data/paths.cfg).

![A desire path through a meadow after three days, after eight days, five days after it was last walked, and under snow](../docs/screenshots/desire-paths.png)

![A yard worn by many feet: one joined patch of trodden and bare earth](../docs/screenshots/worn-ground.png)

## Knicks, ditches and dykes

The land is worked, as in Schleswig-Holstein around 1700–1800. On the dry Geest the fields are
bounded by Knicks, hedges of hazel and hawthorn on earth banks that blossom in spring, turn yellow
and brown in autumn and stand bare in winter, and here and there by a fieldstone wall or a wattle
fence. Down in the marsh along the river the fields are cut by straight ditches of water lined with
reeds and pollard willows, and turfed dykes run along the floodplain, long green banks with a sheep
track along the crest that bend round their corners and wind along where the river runs on the
slant. Every boundary has a gap or a crossing, so no field is shut in. The axe cuts a Knick down for
logs and fibre, the pickaxe takes a wall apart for stone, and willows are felled like the other
trees.

![The marsh with its dykes, ditches, reeds and pollard willows by a wood, in summer, on a rainy autumn evening and in the first snow](../docs/screenshots/landscape.png)

Tall grass, ferns and reeds have a ground shadow and a dark, dense foot that is rimmed in the
darkest green of their own ramp, so they stand out from the ground in every season, and so does the
pollard willow's dense crown with its dark edge:

![Tall grass, fern and reeds over grass, lush grass, dry grass and floodplain in spring, summer, autumn, bare winter, frost, snow and at night](../docs/screenshots/outlines.png)

## The coast and the tidal flats

In the west the land ends at the North Sea. A sea dyke runs along the coast, and beyond it lie the
salt marsh, grey-green with sea purslane and glasswort, pink with thrift in early summer, lilac with
sea lavender later and red-purple in autumn; then the tidal mud of the Wadden Sea, with ripple
marks, lugworm casts and shells, cut by tideways that widen towards the open sea. The tide comes in
and goes out twice a day: the water fills the hollows first, then the flats are under, and at low
water the mud dries again. Mud under water can't be walked on, like the sea, so the flats open and
close with the tide: whoever the rising water catches can still wade out to the shore, and the
villagers and farm animals keep to the same rule. Out on the salt marsh a Warft rises here and
there, a dwelling mound with a pond on top, and now and then an Ewer, a flat-bottomed sailing barge,
lies on the mud. Storks and geese come to the salt marsh, and oystercatchers, dunlin, gulls and
terns to the mud and the sea (see [Wildlife](animals.md#wildlife)).

![The coast: a Warft with its Fething on the salt marsh on a summer morning, the salt marsh red around the green Warft in autumn, the tidal flats with their ripple marks at low water and the tide coming in, and the Warft under snow](../docs/screenshots/coast.png)

![An Ewer lying on the mud at low water, seven tiles long, the player beside it](../docs/screenshots/ewer.png)

## Weather

The weather is simulated from humidity, wind, temperature and sunlight. It brings rain, snow,
drifting fog, wind, storms and thunderstorms with lightning (a close strike draws a forking bolt in
the sky, now and then the lightning runs across it). The climate is mild: frost and snow only come
in winter, and late winter thaws quickly into spring. Rain comes as showers and passing fronts of a
few hours with dry hours between, seldom a whole day on end; autumn is the wettest season (as on the
North Frisian coast), spring the driest. The weather is worked out from the world seed and the time,
so the same world always has the same weather.

The world moves with the wind: trees, bushes, grass, reeds and crops sway, barely on a calm day and
hard in the gusts of a storm; the water ripples and glints, choppier in wind; the campfire and the
hearth burn, their flames licking up and falling back, and throw sparks; the campfire's flames lean
and stretch downwind, more in a strong wind; rain splashes on the ground; lily pads drift and bob.

In windy autumn weather, and a little in late summer and early winter, the trees near you shed
leaves in the colours of their season: some drop and sway down beside the tree, some are carried off
downwind, tumbling, more in a gust and none in calm. Spruces and pines only drop a rare needle. The
numbers are in `data/leaf_fall.cfg`.

![Rain in autumn, snow in winter, morning fog and a thunderstorm](../docs/screenshots/weather.png)

## Day, night and light

The days follow a Nordic year: about 16 hours of daylight in midsummer and 8 in midwinter, with dawn
and dusk following sunrise and sunset. The night is dark: away from a light you see little more than
shapes. When it gets dark, the campfire, the hearth and the lit windows glow, and clouds dim the
daylight. Under a partly clouded sky soft cloud shadows drift over the ground with the wind, more of
them the more cloud there is (a look only: plants and drying don't care). A setting lets you shrink
or switch off the change in day length. How dark the night gets and when dusk and dawn come is in
[data/lighting.cfg](../data/lighting.cfg).

![Cloud shadows drifting over the camp under a partly clouded sky](../docs/screenshots/cloud-shadows.png)

![Evening and dusk at the camp, houses after midnight and the interior by the hearth](../docs/screenshots/day-and-night.png)

To see in the dark, carry a lantern (for now from the console: `give lantern`). Select it and press
the use key (space) to light it or put it out; lit, it casts a warm, flickering circle of light
around you while you hold it. It needs no fuel.

![At night without a light, with the lantern lit, with the lantern by the campfire, and lit in the classic art](../docs/screenshots/lantern.png)
