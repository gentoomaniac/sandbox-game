class_name DecorationView
extends Node2D
## The flowers, pebbles and the like scattered on the ground of a World, and the hints of its
## clay spots: two TileMapLayers on the plain tile grid. They are only looks, not world
## objects, and never under an object. WorldView owns it and tells it which tiles to draw.
##
## A decoration comes from a tile's layer and the decoration noise (see TerrainTileset), and
## a plant's decoration is there only in the days of its Vegetation kind. Meadow flowers grow in
## drifts (see FlowerRules) and, while one of them is in bloom, show instead of the tile's other
## decoration. The picture is the look of its tile (the season, snow, frost). The wildlife asks
## it where flowers bloom.

## Visual-only noise, seeded from the world seed with an offset far from the generator's:
## decoration clusters, a few tiles across.
const DECORATION_SEED_OFFSET := 104729
const DECORATION_FREQUENCY := 0.12
## The flowers' drift and mix noises (see data/flowers.cfg), each with a seed of its own.
const DRIFT_SEED_OFFSET := 104743
const MIX_SEED_OFFSET := 104759
## Keeps a tile's flower rolls apart from its decoration roll.
const FLOWER_ROLL_SALT := 7
const DRIFT_TILE_ROLL_SALT := 8
## The habitat of the flowers (a section of data/flowers.cfg) on each layer; the other layers
## (water, tilled soil) have none. Grass in a forest is the habitat "woods".
const FLOWER_HABITATS := {
	TerrainTileset.Layer.GRASS: "grass",
	TerrainTileset.Layer.LUSH_GRASS: "lush_grass",
	TerrainTileset.Layer.DRY_GRASS: "dry_grass",
	TerrainTileset.Layer.FLOODPLAIN: "floodplain",
	TerrainTileset.Layer.WETLAND: "wetland",
	TerrainTileset.Layer.SALT_MARSH: "salt_marsh",
	TerrainTileset.Layer.WARFT: "grass",
}
const GRASS_LAYERS: Array[TerrainTileset.Layer] = [
	TerrainTileset.Layer.GRASS, TerrainTileset.Layer.LUSH_GRASS, TerrainTileset.Layer.DRY_GRASS
]


## A place where a decoration or flowers could grow: its decoration (NO_DECORATION for none)
## with its Vegetation kind and fixed threshold, its flowers with theirs, and what is drawn now
## and in which look.
class DecorationSpot:
	extends RefCounted
	var atlas_cell := TerrainTileset.NO_DECORATION
	var kind: StringName
	var threshold: float
	## The species of FlowerRules.flowers_at, and the threshold of each.
	var flowers: Array[StringName] = []
	var flower_thresholds := PackedFloat32Array()
	## Which tile of its flowers it shows: a few plants, or the thick of a drift.
	var flower_variant := TerrainTileset.FlowerVariant.FEW
	## The atlas cell drawn now, NO_DECORATION for none.
	var shown_cell := TerrainTileset.NO_DECORATION
	## The terrain layer of its tile, which decides how its look shows.
	var layer := 0
	var look := SeasonBlend.Look.SUMMER


## The day the decorations are drawn for. WorldView sets it.
var day := 0
var _world: World
var _tileset: TerrainTileset
var _flower_rules := FlowerRules.default_rules()
var _decoration_noise := FastNoiseLite.new()
var _drift_noise := FastNoiseLite.new()
var _mix_noise := FastNoiseLite.new()
var _decorations := TileMapLayer.new()
## The hints of clay spots.
var _clay_hints := TileMapLayer.new()
## Where a decoration or flowers could grow, shown or not, so a new day only revisits these
## tiles.
var _spots: Dictionary[Vector2i, DecorationSpot] = {}


func _init(tileset: TerrainTileset) -> void:
	_tileset = tileset
	_decoration_noise.frequency = DECORATION_FREQUENCY
	_drift_noise.frequency = _flower_rules.value("drifts", "frequency")
	_mix_noise.frequency = _flower_rules.value("drifts", "mix_frequency")
	_decorations.name = "Decorations"
	_decorations.tile_set = tileset.tile_set
	add_child(_decorations)
	_clay_hints.name = "ClayHints"
	_clay_hints.tile_set = tileset.tile_set
	add_child(_clay_hints)


func show_world(world: World) -> void:
	_world = world
	_decoration_noise.seed = world.world_seed + DECORATION_SEED_OFFSET
	_drift_noise.seed = world.world_seed + DRIFT_SEED_OFFSET
	_mix_noise.seed = world.world_seed + MIX_SEED_OFFSET


## Draws the decoration and the clay hint of a tile of a chunk that was just drawn, unless an
## object covers it. `code` is the tile's (see TerrainTileset.tile_code).
func place(world_pos: Vector2i, code: int, is_covered: bool) -> void:
	_set_clay_hint(world_pos, is_covered)
	_decorations.erase_cell(world_pos)
	_spots.erase(world_pos)
	if is_covered or _is_sea(world_pos):
		return
	var spot := DecorationSpot.new()
	spot.layer = TerrainTileset.layer_of(code)
	var cluster := _decoration_noise.get_noise_2dv(Vector2(world_pos))
	spot.atlas_cell = _tileset.decoration_cell(spot.layer, world_pos, cluster)
	if spot.atlas_cell != TerrainTileset.NO_DECORATION:
		spot.kind = TerrainTileset.decoration_kind(spot.atlas_cell)
		if spot.kind != &"":
			spot.threshold = _world.vegetation.threshold(spot.kind, _world.world_seed, world_pos)
	_sow_flowers(spot, world_pos)
	if spot.atlas_cell == TerrainTileset.NO_DECORATION and spot.flowers.is_empty():
		return
	_spots[world_pos] = spot
	_update(world_pos, spot, code)


## Draws a tile again after something on it changed: whether an object covers it now.
func redraw(world_pos: Vector2i, code: int) -> void:
	place(world_pos, code, _world.object_at(world_pos) != null)


## Brings the decoration of a tile up to date with the day and the look of the tile.
func refresh(world_pos: Vector2i, code: int) -> void:
	var spot: DecorationSpot = _spots.get(world_pos)
	if spot != null:
		_update(world_pos, spot, code)


## Forgets a tile whose chunk unloads.
func forget(world_pos: Vector2i) -> void:
	_decorations.erase_cell(world_pos)
	_clay_hints.erase_cell(world_pos)
	_spots.erase(world_pos)


## Whether a flower is in bloom on a tile today and not under snow (wildlife visits those).
func has_flower(world_pos: Vector2i) -> bool:
	var spot: DecorationSpot = _spots.get(world_pos)
	return (
		spot != null
		and spot.shown_cell.y == TerrainTileset.FLOWER_ROW
		and spot.look != SeasonBlend.Look.SNOW
	)


## The tiles within a rectangle (in world pixels) where a flower is in bloom today, or on game
## day `on_day` if given, with `is_snowed` (a Callable taking a tile) telling where snow lies on
## it: worked out from the flowers, not read from what is drawn, which may not have caught up
## with the date yet.
func flower_tiles_within(
	area: Rect2, on_day := 0, is_snowed := func(_pos: Vector2i) -> bool: return false
) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var first := Vector2i((area.position / TerrainTileset.TILE_SIZE).floor())
	var last := Vector2i((area.end / TerrainTileset.TILE_SIZE).floor())
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var is_in_bloom := (
				has_flower(Vector2i(x, y))
				if on_day == 0
				else _has_flower_on(Vector2i(x, y), on_day, is_snowed)
			)
			if is_in_bloom:
				tiles.append(Vector2i(x, y))
	return tiles


## Whether a tile is the sea's, which is drawn as water but has no lily pads.
func _is_sea(world_pos: Vector2i) -> bool:
	var tile := _world.tile_at(world_pos)
	return tile != null and tile.terrain == Tile.Terrain.SEA


## Shows the hint of a clay spot that still holds clay, unless an object stands on it.
func _set_clay_hint(world_pos: Vector2i, is_covered: bool) -> void:
	if is_covered or not _world.has_clay(world_pos):
		_clay_hints.erase_cell(world_pos)
	else:
		_clay_hints.set_cell(world_pos, TerrainTileset.CLAY_HINT_SOURCE_ID, Vector2i.ZERO)


## Gives a spot the flowers that grow on its tile, if any: by the habitat of its layer and the
## drift and mix noises there.
func _sow_flowers(spot: DecorationSpot, world_pos: Vector2i) -> void:
	var habitat: String = FLOWER_HABITATS.get(spot.layer, "")
	if habitat == "":
		return  # Fields, water and the like grow no flowers.
	if spot.layer in GRASS_LAYERS and _world.is_in_woods(world_pos):
		habitat = "woods"
	var drift := _drift_noise.get_noise_2dv(Vector2(world_pos))
	var mix := _mix_noise.get_noise_2dv(Vector2(world_pos))
	var roll := PositionHash.of(world_pos, FLOWER_ROLL_SALT) % 10000 / 10000.0
	spot.flowers = _flower_rules.flowers_at(habitat, drift, mix, roll)
	for species in spot.flowers:
		spot.flower_thresholds.append(
			_world.vegetation.threshold(species, _world.world_seed, world_pos)
		)
	if _flower_rules.drift_depth(drift) >= _flower_rules.value("drifts", "thick_from"):
		# Two tiles of the thick of a drift, so that a carpet of them shows no grid.
		var is_other := PositionHash.of(world_pos, DRIFT_TILE_ROLL_SALT) % 2 == 1
		spot.flower_variant = (
			TerrainTileset.FlowerVariant.OTHER_DRIFT
			if is_other
			else TerrainTileset.FlowerVariant.DRIFT
		)


## Whether a flower is in bloom on a tile on game day `on_day` and not under snow (`is_snowed`).
func _has_flower_on(world_pos: Vector2i, on_day: int, is_snowed: Callable) -> bool:
	var spot: DecorationSpot = _spots.get(world_pos)
	if spot == null or _cell_for(spot, on_day).y != TerrainTileset.FLOWER_ROW:
		return false
	var snow := SeasonBlend.Look.SNOW if is_snowed.call(world_pos) else SeasonBlend.Look.SUMMER
	return TerrainTileset.shown_weather_look(spot.layer, snow) != SeasonBlend.Look.SNOW


## The atlas cell a spot shows today: of its flowers in bloom the one furthest into its bloom
## (its density furthest above the spot's threshold), so the species in bloom mix within a
## drift, as a small plant while it is only just in bloom; else its decoration while its kind
## is present; else none.
func _cell_for_today(spot: DecorationSpot) -> Vector2i:
	return _cell_for(spot, day)


func _cell_for(spot: DecorationSpot, on_day: int) -> Vector2i:
	var flower := &""
	var best_margin := 0.0
	for index in spot.flowers.size():
		var species := spot.flowers[index]
		var margin := _world.vegetation.density(species, on_day) - spot.flower_thresholds[index]
		if margin > best_margin:
			flower = species
			best_margin = margin
	if best_margin >= _flower_rules.value("drifts", "small_margin"):
		return TerrainTileset.flower_cell(flower, spot.flower_variant)
	if flower != &"":
		return TerrainTileset.flower_cell(flower, TerrainTileset.FlowerVariant.SMALL)
	if spot.kind == &"" or _world.vegetation.shows(spot.kind, spot.threshold, on_day):
		return spot.atlas_cell
	return TerrainTileset.NO_DECORATION


## Draws, erases or redraws the decoration of a spot, as it is today and as the look of its tile
## is now.
func _update(world_pos: Vector2i, spot: DecorationSpot, code: int) -> void:
	var cell := _cell_for_today(spot)
	var look := TerrainTileset.shown_look(
		spot.layer, TerrainTileset.season_of(code), TerrainTileset.weather_of(code)
	)
	if cell == spot.shown_cell and look == spot.look:
		return
	spot.shown_cell = cell
	spot.look = look
	if cell == TerrainTileset.NO_DECORATION:
		_decorations.erase_cell(world_pos)
	else:
		_decorations.set_cell(world_pos, TerrainTileset.decoration_source_id(look), cell)
