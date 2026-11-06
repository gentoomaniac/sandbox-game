class_name BuildingViews
extends Node
## The sprites of the buildings of a World and the lights in their windows. WorldView owns it
## and gives it the looks of the day.
##
## The sprites stand in the y-sorted `entities` node of WorldView, so they sort with the
## objects and the player. They belong to the world, not to a chunk, so they stay when chunks
## unload. A building is a SeeThroughSprite: it fades inside a circle around the player while
## it hides them (see Occlusion).

## The windows of buildings are lit (and shine) once the light strength is at least this.
const WINDOW_LIT_STRENGTH := 0.3

var _entities: Node2D
var _blend: SeasonBlend
var _conditions: SeasonBlend.Conditions
var _light_strength := 1.0
var _sprites: Dictionary[Building, SeeThroughSprite] = {}
## The lights in the windows of each building.
var _window_lights: Dictionary[Building, Array] = {}


func _init(entities: Node2D) -> void:
	_entities = entities


## Sets the looks the roofs and windows are drawn for (see SeasonBlend) and redraws the ones
## already there.
func set_looks(blend: SeasonBlend, conditions: SeasonBlend.Conditions) -> void:
	_blend = blend
	_conditions = conditions
	for building in _sprites:
		_show_windows(building)


## Sets how brightly the windows shine (see ObjectLight.strength).
func set_light_strength(strength: float) -> void:
	_light_strength = strength
	for building in _sprites:
		_show_windows(building)


func add(building: Building) -> void:
	var building_type: Dictionary = BuildingTypes.TYPES[building.type]
	var sprite := SeeThroughSprite.new()
	_sprites[building] = sprite
	sprite.texture = load(SeasonalArt.house_path(building_type["sprite"], _is_snowy(building)))
	sprite.centered = false
	# The sprite is sorted by its position: the middle of its bottom footprint row, like an
	# object standing on that row. Its bottom edge is the footprint's bottom edge.
	var half_tile := TerrainTileset.TILE_SIZE / 2
	var footprint_bottom: int = (
		(building.origin.y + building_type["footprint"].y) * TerrainTileset.TILE_SIZE
	)
	sprite.position = Vector2(
		building.origin.x * TerrainTileset.TILE_SIZE, footprint_bottom - half_tile
	)
	sprite.offset = Vector2(0, half_tile - sprite.texture.get_height())
	_entities.add_child(sprite)
	_add_window_lights(building, sprite)


## Fades the buildings in `occluding` and puts back the others.
func update_see_through(delta: float, player_feet: Vector2, occluding: Array[Building]) -> void:
	for building in _sprites:
		_sprites[building].is_occluding = building in occluding
		_sprites[building].update(delta, player_feet)


## Building windows: a lit sprite variant and a small warm light in each window, on at night.
func _add_window_lights(building: Building, sprite: Sprite2D) -> void:
	var building_type: Dictionary = BuildingTypes.TYPES[building.type]
	var lights: Array[ObjectLight] = []
	for window_centre: Vector2i in building_type["window_lights"]:
		var light := ObjectLight.new(building_type["window_light"], building.origin)
		# On the window pane. The sprite's top left is its position plus its offset.
		light.position = sprite.position + sprite.offset + Vector2(window_centre)
		lights.append(light)
		add_child(light)
	_window_lights[building] = lights
	_show_windows(building)


func _show_windows(building: Building) -> void:
	var building_type: Dictionary = BuildingTypes.TYPES[building.type]
	var is_lit := _light_strength >= WINDOW_LIT_STRENGTH
	var sprite := _sprites[building]
	var texture_path := SeasonalArt.house_path(
		building_type["sprite_lit"] if is_lit else building_type["sprite"], _is_snowy(building)
	)
	# The strength changes every frame while the tint does; the picture only at dusk and dawn.
	if sprite.texture.resource_path != texture_path:
		sprite.texture = load(texture_path)
	for light: ObjectLight in _window_lights[building]:
		light.strength = _light_strength if is_lit else 0.0


## Whether a house has snow on its roof: when the snow cover is above its tile's threshold.
func _is_snowy(building: Building) -> bool:
	return _conditions.snow_cover > _blend.thresholds(building.origin).y
