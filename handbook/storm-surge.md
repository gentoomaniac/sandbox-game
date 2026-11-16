# The sea dyke and the storm surge

In autumn and winter a heavy storm at high water can drive the North Sea over the dykes. This page
says what the signs are, what the water does and what you can do about it. (Numbers and the reasons
behind them are in the [design](../design/world/storm-surge.md).)

## The dykes

Every stretch of the sea dyke has a height (in metres over the mean high water) and a strength (how
well it is turfed and packed). Point at a dyke and the hover says it: "Dyke, 2.1 m, well turfed", or
"Dyke, low, 1.2 m, bare". A stretch of about 60 tiles shares one value, and some stretches are low:
those are the places where a surge comes through. The sea dyke is about 2.4 m high, give or take 0.8
(the river's dykes are lower and the sea never reaches them). A dyke the sea runs over breaks
down to 0.3 m; one that holds but was nearly overtopped is damaged, a weak one more than a strong
one. The villagers mend a damaged dyke after six days.

You can't build or raise a dyke yet: that comes with terraforming
([#59](https://github.com/gentoomaniac/sandbox-game/issues/59)), and with it clay for height and sods
for strength.

## When it comes

A surge needs a high water, a heavy storm and the season (day 71 to 140 of the year; winter has half
the chance). At the first values it comes about once a game year, with the water rising 1.6 to 3.2 m.
You are warned six hours ahead:

- a line at the top of the screen, "Storm surge: the sea will run over the dykes at 18:40 (2.8 m)";
- the sky turns to a storm, with wind and rain, and the waves of the shore roar;
- the villagers speak of it, and those who stand on low land walk inland to higher ground.

The church bell that is to ring the alarm has no sound yet.

## The flood

Where the sea runs over a dyke the water fills the land behind it, the low land first, and stops where
the ground rises: the Koog (the first 36 tiles behind the dyke) is the lowest land, the Geest further
inland and the Warften are never reached. It stands a day or two and then drains, the shallowest
ground first. Water deeper than a third of a metre can't be walked on: you can only wade into it, as
into the flooded mud. Farm animals in the water walk out to dry ground, and the villagers keep to
higher ground until it has drained.

## What it leaves

- **Crops:** a seedling under the water dies at once, any other crop when it has stood deeper than
  10 cm for a day.
- **Salt:** the sea leaves salt on the land for 40 days (a day less each day, and each hour of rain
  takes one more off). Nothing can be planted on it, and the hover says "Salt: 31 days". Tilled soil
  stays tilled.
- **Mud:** the ground is muddy for three days: footprints, and a slower walk.
- **Items:** things lying on the ground under more than half a metre of water drift up to three
  tiles inland, or are lost (three in ten). Chests, fences, walls and houses stand.

## Trying it

The console's `surge <metres>` starts one at once (`surge 3.4` breaks every dyke), `surge` shows what
is expected and `surge off` ends it ([the console](console.md)).
