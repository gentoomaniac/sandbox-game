class_name WoodLayout
extends RefCounted
## Where the woods are, from data/landscape.cfg ([woods]): a pure function of the seed and the
## tile position, like the rest of the generator.
##
## A wood is where the forest noise, read at a position pushed about by a slow warp noise (so a
## wood's outline is no contour line of one noise), is above `above`. `depth_at` says how far
## inside: 0 at the edge, 1 where the noise reaches `core_above`, negative outside. A tile of a wood
## holds a trunk with a chance that rises from `edge_trees` to `core_trees` (see there) from the
## edge to the core. A clearing noise cuts holes into a wood where it is above `clearing_above`.

const FOREST_FREQUENCY := 0.012
const WARP_FREQUENCY := 0.04
const CLEARING_FREQUENCY := 0.12
## The warp and clearing noises need no fine detail: two octaves cost less than the default five.
const SMOOTH_OCTAVES := 2
## Where the noise barely rises above `above` the depth stays below this: a tuft of shrubs, too
## small for trees.
const MIN_TREE_DEPTH := 0.1

const FOREST_SEED_OFFSET := 2
const WARP_X_SEED_OFFSET := 19
const WARP_Y_SEED_OFFSET := 20
const CLEARING_SEED_OFFSET := 21
## The roll of a tile for a trunk.
const TREE_ROLL_SEED_OFFSET := 22

var _forest_noise := FastNoiseLite.new()
var _warp_x_noise := FastNoiseLite.new()
var _warp_y_noise := FastNoiseLite.new()
var _clearing_noise := FastNoiseLite.new()
var _tree_roll_seed: int
## The numbers of data/landscape.cfg (see there).
var _above: float
var _core_above: float
var _warp_tiles: float
var _clearing_above: float
var _edge_trees: float
var _core_trees: float


func _init(world_seed: int, landscape: LandscapeRules) -> void:
	_forest_noise.seed = world_seed + FOREST_SEED_OFFSET
	_forest_noise.frequency = FOREST_FREQUENCY
	_warp_x_noise.seed = world_seed + WARP_X_SEED_OFFSET
	_warp_x_noise.frequency = WARP_FREQUENCY
	_warp_x_noise.fractal_octaves = SMOOTH_OCTAVES
	_warp_y_noise.seed = world_seed + WARP_Y_SEED_OFFSET
	_warp_y_noise.frequency = WARP_FREQUENCY
	_warp_y_noise.fractal_octaves = SMOOTH_OCTAVES
	_clearing_noise.seed = world_seed + CLEARING_SEED_OFFSET
	_clearing_noise.frequency = CLEARING_FREQUENCY
	_clearing_noise.fractal_octaves = SMOOTH_OCTAVES
	_tree_roll_seed = world_seed + TREE_ROLL_SEED_OFFSET
	_above = landscape.value("woods", "above")
	_core_above = landscape.value("woods", "core_above")
	_warp_tiles = landscape.value("woods", "warp")
	_clearing_above = landscape.value("woods", "clearing_above")
	_edge_trees = landscape.value("woods", "edge_trees")
	_core_trees = landscape.value("woods", "core_trees")


## The forest noise at a tile, in -1 to 1: high where woods grow and low where the meadows are.
func noise_at(world_pos: Vector2i) -> float:
	return _forest_noise.get_noise_2dv(Vector2(world_pos))


## The tile whose wood a tile belongs to: the tile pushed by the warp noise. Ask `depth_at` of it.
func warped(world_pos: Vector2i) -> Vector2i:
	var pos := Vector2(world_pos)
	var push := Vector2(_warp_x_noise.get_noise_2dv(pos), _warp_y_noise.get_noise_2dv(pos))
	return world_pos + Vector2i((push * _warp_tiles).round())


## How far into a wood a (warped) tile lies: 0 at the edge, 1 in the core, negative outside.
func depth_at(warped_pos: Vector2i) -> float:
	return (noise_at(warped_pos) - _above) / (_core_above - _above)


func is_clearing_at(world_pos: Vector2i) -> bool:
	return _clearing_noise.get_noise_2dv(Vector2(world_pos)) > _clearing_above


## Whether a tile of a wood, `depth` inside it, holds a trunk.
func has_tree_at(world_pos: Vector2i, depth: float) -> bool:
	if depth < MIN_TREE_DEPTH or is_clearing_at(world_pos):
		return false
	var chance := lerpf(_edge_trees, _core_trees, clampf(depth, 0.0, 1.0))
	return PositionHash.of(world_pos, _tree_roll_seed) % 10000 / 10000.0 < chance
