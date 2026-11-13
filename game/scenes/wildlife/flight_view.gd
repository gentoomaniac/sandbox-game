class_name FlightView
extends RefCounted
## The three views of a bird in flight: side on (flipped when it flies left), from the front while
## it flies down the screen and from behind while it flies up it. Each is an action of the
## sheets of the sparrow and the goose (the others have the side view only).

const SIDE := &"fly"
const FRONT := &"fly_down"
const BACK := &"fly_up"
## A bird whose heading is less than this many degrees from the screen's vertical is seen from
## the front or from behind, one further from it side on. Migrating flocks stray at most
## `migration_spread_degrees` (data/wildlife.cfg) from it, so they are always seen head on.
const HEAD_ON_DEGREES := 45.0


## The view of a bird flying along `heading`: SIDE, FRONT or BACK.
static func of(heading: Vector2) -> StringName:
	var from_vertical := rad_to_deg(absf(heading.angle_to(Vector2.DOWN)))
	if from_vertical < HEAD_ON_DEGREES:
		return FRONT
	if from_vertical > 180.0 - HEAD_ON_DEGREES:
		return BACK
	return SIDE
