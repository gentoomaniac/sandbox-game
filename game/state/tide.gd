class_name Tide
extends RefCounted
## The tide of the North Sea on the tidal mud: high water twice a day, a little later each day, as
## on the real coast. It is a look only (see mud.gdshader): the mud can be walked on at any tide,
## so nobody is ever cut off by the water.

## From one high water to the next, in game minutes: 12 hours 25 minutes.
const PERIOD_MINUTES := 745.0


## How high the water stands at a moment of the game clock (`GameClock.total_minutes`): 1 at
## high water, 0 at low water, rising and falling smoothly in between. The first high water is at
## midnight before day 1.
static func level(total_minutes: float) -> float:
	return 0.5 + 0.5 * cos(TAU * total_minutes / PERIOD_MINUTES)
