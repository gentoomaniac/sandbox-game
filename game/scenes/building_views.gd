class_name BuildingViews
extends Node
## The sprites of the buildings of a World and the lights in their windows. WorldView owns it
## and gives it the looks of the day.
##
## The sprites stand in the y-sorted `entities` node of WorldView, so they sort with the
## objects and the player. They belong to the world, not to a chunk, so they stay when chunks
## unload. A building is a SeeThroughSprite: it fades inside a circle around the player while
## it hides them (see Occlusion). Its pictures are those of the chosen art set (see ArtSet), which
## WorldView shows anew by `show_art_set`.

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


## Where a building's picture is sorted with the objects and the player: the middle of its
## bottom row of tiles, like an object standing on that row. The x is the picture's left edge.
static func sort_position(building: Building) -> Vector2:
	return Vector2(
		building.origin.x * TerrainTileset.TILE_SIZE,
		footprint_bottom(building) - TerrainTileset.TILE_SIZE / 2.0
	)


## The bottom edge of a building's footprint, in pixels: the bottom edge of its picture.
static func footprint_bottom(building: Building) -> float:
	var footprint: Vector2i = BuildingTypes.TYPES[building.type]["footprint"]
	return (building.origin.y + footprint.y) * TerrainTileset.TILE_SIZE


## The picture a building is shown with now: its look (see `_house_look`), lit or not, in the
## chosen art set.
func picture_path(building: Building, is_lit := false) -> String:
	var building_type: Dictionary = BuildingTypes.TYPES[building.type]
	var summer_path: String = building_type["sprite_lit"] if is_lit else building_type["sprite"]
	return ArtSet.path(SeasonalArt.house_path(summer_path, _house_look(building)))


func add(building: Building) -> void:
	var sprite := SeeThroughSprite.new()
	_sprites[building] = sprite
	sprite.texture = load(picture_path(building))
	sprite.centered = false
	sprite.position = sort_position(building)
	# Its bottom edge is the footprint's bottom edge. The classic pictures are as big as the new.
	var bottom := footprint_bottom(building) - sprite.position.y
	sprite.offset = Vector2(0, bottom - sprite.texture.get_height())
	_entities.add_child(sprite)
	_add_window_lights(building, sprite)


## Shows every building in the chosen art set (see ArtSet).
func show_art_set() -> void:
	for building in _sprites:
		_show_windows(building)


## Takes down the sprite and the window lights of a building.
func remove(building: Building) -> void:
	_sprites[building].queue_free()
	_sprites.erase(building)
	for light: ObjectLight in _window_lights[building]:
		light.queue_free()
	_window_lights.erase(building)


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
	var is_lit := _light_strength >= WINDOW_LIT_STRENGTH
	var sprite := _sprites[building]
	var texture_path := picture_path(building, is_lit)
	# The strength changes every frame while the tint does; the picture only at dusk and dawn.
	if sprite.texture.resource_path != texture_path:
		sprite.texture = load(texture_path)
	for light: ObjectLight in _window_lights[building]:
		light.strength = _light_strength if is_lit else 0.0


## The look of a house (see SeasonalArt.HOUSE_LOOKS): snow on its roof when the snow cover is
## above its tile's threshold, else the season's look of the grass on its tile.
func _house_look(building: Building) -> SeasonBlend.Look:
	var thresholds := _blend.thresholds(building.origin)
	if _conditions.snow_cover > thresholds.y:
		return SeasonBlend.Look.SNOW
	return _conditions.ground_season_look(thresholds.x)
