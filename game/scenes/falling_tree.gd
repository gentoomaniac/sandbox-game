class_name FallingTree
extends Sprite2D
## The picture of a felled tree toppling over its base: it speeds up, lands, rebounds a little
## and settles. WorldView drives it with `advance` and puts the trunk object in its place when
## it is finished. The sprite's position is the pivot, the foot of the tree.

signal landed
signal finished

const FALL_SECONDS := 0.5
const SETTLE_SECONDS := 0.1
const TOTAL_SECONDS := FALL_SECONDS + SETTLE_SECONDS
## Lying flat; the tree rotates onto the ground this far.
const LYING_ANGLE := PI / 2.0
## How far the landing bounces back up, in radians.
const REBOUND_ANGLE := 0.12
## The fall speeds up: the angle grows with the time to this power.
const EASE_POWER := 2.4

## Where a toppled tree bursts on landing, as a share of its picture's height from its foot (the
## middle of its crown), and how high above the ground, in pixels.
const IMPACT_REACH_SHARE := 0.55
const IMPACT_HEIGHT := 12.0 * TerrainTileset.ART_16_SCALE

## What fell: the tree object, where it stood.
var tree: WorldObject
## The trunk it leaves, or null if there is no room for one.
var trunk: WorldObject
## What flies off when it lands.
var impact_effect := HitEffect.Kind.NONE
## 1 falls to the right, -1 to the left.
var direction := 1
var _age := 0.0
var _has_landed := false
var _has_finished := false


## A fall of `tree`, which was just replaced by its stump in `world`: towards the trunk beside
## the stump (see TrunkPlacement), or away from the player standing at `player_x` (world pixels)
## if there is none. A trunk above or below the stump gives no side; the tree then falls to the
## right, as the trunk lies.
static func beside_trunk_of(felled: WorldObject, world: World, player_x: float) -> FallingTree:
	var fall := FallingTree.new()
	fall.tree = felled
	var trunk_types: Array[StringName] = [
		WorldObjectTypes.trunk_type(felled.type, false),
		WorldObjectTypes.trunk_type(felled.type, true)
	]
	for side: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var object := world.object_at(felled.pos + side)
		if object != null and trunk_types.has(object.type):
			fall.trunk = object
			break
	var tree_x := felled.pos.x + 0.5
	if fall.trunk != null:
		var trunk_width: int = fall.trunk.type_data()["footprint"].x
		fall.direction = -1 if fall.trunk.pos.x + trunk_width / 2.0 < tree_x else 1
	else:
		fall.direction = 1 if player_x <= tree_x * TerrainTileset.TILE_SIZE else -1
	return fall


## The rotation of a tree `age` seconds into the fall, falling to the right.
static func angle_at(age: float) -> float:
	if age < FALL_SECONDS:
		return LYING_ANGLE * pow(age / FALL_SECONDS, EASE_POWER)
	var settling := clampf((age - FALL_SECONDS) / SETTLE_SECONDS, 0.0, 1.0)
	return LYING_ANGLE - REBOUND_ANGLE * sin(PI * settling)


## Where it bursts when it lands, in world pixels.
func impact_point() -> Vector2:
	var reach: float = IMPACT_REACH_SHARE * tree.type_data()["sprite_height"]
	return position + Vector2(direction * reach, -IMPACT_HEIGHT)


func has_landed() -> bool:
	return _has_landed


func advance(delta: float) -> void:
	_age += delta
	rotation = direction * angle_at(_age)
	# The crown fades while it settles, so the trunk that takes its place does not pop in.
	modulate.a = 1.0 - clampf((_age - FALL_SECONDS) / SETTLE_SECONDS, 0.0, 1.0)
	if not _has_landed and _age >= FALL_SECONDS:
		_has_landed = true
		landed.emit()
	if not _has_finished and _age >= TOTAL_SECONDS:
		_has_finished = true
		finished.emit()
