class_name StorkRoofs
extends Node
## The storks' places on the roofs of the houses near the view: the storks that fly in to a roof,
## and the nests (see StorkNests) shown as StorkNestView. Where on a roof a stork can stand is read
## from the top edge of the house's picture. WildlifeView owns it and has it follow the view.

## A stork flying to a roof comes from this far beside the view, in pixels.
const ARRIVAL_MARGIN := 96.0
## A stork on a roof stands this many pixels into the top of the roof, among the ridge sticks.
const ROOF_FOOTING := 4.0

## The nests shown, by the house they are on.
var nest_views: Dictionary[Building, StorkNestView] = {}
## For each picture of a house (a building type in a look), how far its top is above the bottom
## edge, for every column of pixels. Read the first time it is needed.
var _roof_heights: Dictionary[String, PackedInt32Array] = {}
var _wildlife: WildlifeView


func _init(wildlife: WildlifeView) -> void:
	_wildlife = wildlife


## Takes every nest away (the player went indoors).
func clear() -> void:
	for nest_view in nest_views.values():
		nest_view.queue_free()
	nest_views.clear()


## Has the nests that are shown look at who is home now (time has skipped).
func settle_nests() -> void:
	for nest_view in nest_views.values():
		nest_view.settle()


## Shows the nests that came near the view, drops those that are far from it or whose house is
## gone, and has each one look at who is in it. A nest that comes near has its pair on it at once.
func follow_nests() -> void:
	var view := _wildlife.view_rect()
	for building: Building in nest_views.keys():
		var nest_view := nest_views[building]
		if not is_standing(building) or _wildlife.rules.is_beyond_view(nest_view.position, view):
			nest_view.queue_free()
			nest_views.erase(building)
	var near := view.grow(_wildlife.rules.general("spawn_margin_tiles") * WildlifeRules.TILE_SIZE)
	for building in _wildlife.world_view.world.buildings():
		if nest_views.has(building) or not _wildlife.nests.has_nest(building):
			continue
		if not near.has_point(front_middle(building)):
			continue
		var nest_view := StorkNestView.new()
		nest_view.building = building
		nest_view.wildlife = _wildlife
		nest_views[building] = nest_view
		_wildlife.world_view.entities.add_child(nest_view)
		nest_view.update(true)
	for nest_view in nest_views.values():
		nest_view.update()


## Sends a stork to the roof of a house near the view that has none: it flies in from beside
## the view. One made by hand stands on the roof nearest to the player at once, and one that is
## `is_instant` (see WildlifeView `settle`) on a roof as it would have settled, not made by hand.
## Returns whether there was a roof for it.
func send_stork(is_debug: bool, is_instant := false) -> bool:
	var near := _wildlife.view_rect().grow(
		_wildlife.rules.general("spawn_margin_tiles") * WildlifeRules.TILE_SIZE
	)
	var houses: Array[Building] = []
	for building in _wildlife.world_view.world.buildings():
		var is_taken := (
			_wildlife.has_stork_on(building)
			or (not is_debug and _wildlife.nests.has_nest(building))
		)
		if near.has_point(front_middle(building)) and not is_taken:
			houses.append(building)
	if houses.is_empty():
		return false
	var house := houses[_wildlife.rng.randi() % houses.size()]
	if is_debug:
		var nearest := INF
		for building in houses:
			var distance := front_middle(building).distance_to(_wildlife.world_view.player_feet)
			if distance < nearest:
				nearest = distance
				house = building
	var stork := Stork.new(WildlifeRules.ROOF_STORK)
	# On the ridge: the middle third of the picture, away from the hips.
	var footprint: Vector2i = BuildingTypes.TYPES[house.type]["footprint"]
	var width := footprint.x * WildlifeRules.TILE_SIZE
	var column := _wildlife.rng.randi_range(width / 3, width * 2 / 3)
	if is_debug or is_instant:
		stork.stand_on(house, column, in_front_of(house, column))
	else:
		stork.position = arrival_point(house)
		stork.fly_to(house, column, in_front_of(house, column))
	_wildlife.add_animal(stork, is_debug)
	return true


## Where a stork flying to a roof of a house starts: beyond the left or right edge of the view,
## where it can't be seen high up as it is.
func arrival_point(house: Building) -> Vector2:
	var view := _wildlife.view_rect()
	var side := (
		view.position.x - ARRIVAL_MARGIN
		if _wildlife.rng.randf() < 0.5
		else view.end.x + ARRIVAL_MARGIN
	)
	return Vector2(
		side, in_front_of(house, 0).y + _wildlife.rng.randf_range(-0.3, 0.3) * view.size.y
	)


## How high above the point in front of a house (see `in_front_of`) a stork stands on a column
## of the house's picture as it is shown now: its feet among the ridge sticks, ROOF_FOOTING pixels
## into the top of the roof. Under snow the roof is a little higher.
func roof_lift(building: Building, column: int) -> float:
	var heights := _roof_heights_of(_wildlife.world_view.building_picture(building))
	var feet := BuildingViews.footprint_bottom(building) - heights[column] + ROOF_FOOTING
	return in_front_of(building, column).y - feet


## Whether a house still stands in the world.
func is_standing(building: Building) -> bool:
	return _wildlife.world_view.world.building_at(building.origin) == building


## The point of the ground just in front of a house, below a column of its picture: an animal
## there sorts right after the house.
func in_front_of(building: Building, column: int) -> Vector2:
	return BuildingViews.sort_position(building) + Vector2(column, 1.0)


func front_middle(building: Building) -> Vector2:
	var footprint: Vector2i = BuildingTypes.TYPES[building.type]["footprint"]
	return in_front_of(building, footprint.x * WildlifeRules.TILE_SIZE / 2)


## For every column of pixels of a house's picture, how far its top is above the bottom edge.
func _roof_heights_of(picture: String) -> PackedInt32Array:
	if _roof_heights.has(picture):
		return _roof_heights[picture]
	var image: Image = load(picture).get_image()
	var heights := PackedInt32Array()
	heights.resize(image.get_width())
	for x in image.get_width():
		for y in image.get_height():
			if image.get_pixel(x, y).a > 0.5:
				heights[x] = image.get_height() - y
				break
	_roof_heights[picture] = heights
	return heights
