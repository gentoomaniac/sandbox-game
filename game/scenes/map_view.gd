class_name MapView
extends Control
## The picture of the world map (see MapScreen): the chunks MapBuilder has built, scaled up a tile
## to a block, the village by name, the villagers as dots (their names in a box when the pointer is
## on them), and the player as an arrow facing their way.
## It pans (drag, arrow keys) and zooms (wheel, about the pointer), and tells where a click fell.

## A click, not a drag: the tile it fell on, and where on the view.
signal tile_clicked(tile: Vector2i, at: Vector2)
## The pointer is over another tile.
signal tile_hovered(tile: Vector2i)

## Pixels a tile: how far the map is zoomed.
const START_SCALE := 6.0
const MIN_SCALE := 2.0
const MAX_SCALE := 24.0
const ZOOM_STEP := 1.25
## How fast the arrow keys pan, in screen pixels a second.
const KEY_PAN_SPEED := 500.0
## A press that moves less than this many pixels is a click.
const CLICK_SLOP := 5.0
## What the builder may spend on a frame (see MapBuilder `update`).
const BUILD_BUDGET_USEC := 3000
const BACKGROUND := Color("1d1b26")
const PLAYER_FILL := Color("fff176")
const PLAYER_OUTLINE := Color("1d1b26")
const VILLAGER_FILL := Color("ffffff")
const LABEL_SIZE := 11
const PLAYER_ARROW_SIZE := 9.0
const VILLAGER_DOT_RADIUS := 3.5
## How near the pointer must be to a villager's dot, in screen pixels, for their name to show.
const HOVER_RADIUS := 10.0
## The box behind a name: its fill, its edge, and the room round the text.
const TAG_FILL := Color(0.11, 0.105, 0.15, 0.92)
const TAG_EDGE := Color("8a7560")
const TAG_PADDING := Vector2(6, 3)
## Where the box of the names under the pointer sits from the pointer.
const TAG_OFFSET := Vector2(14, 6)
## Nowhere on the view: the pointer is not on the map.
const NO_POINTER := Vector2(-INF, -INF)

var _state: GameState
var _builder: MapBuilder
## The tile at the middle of the view, as a point: tile (x, y) spans x..x+1 and y..y+1.
var _centre := Vector2.ZERO
var _scale := START_SCALE
var _press_at := Vector2.ZERO
var _is_pressed := false
var _is_dragging := false
var _pointer := NO_POINTER


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	mouse_exited.connect(func() -> void: _pointer = NO_POINTER)


## The map of `state`, built by `builder`.
func show_state(state: GameState, builder: MapBuilder) -> void:
	_state = state
	_builder = builder


## The map shows what has changed in the world since it was built (see MapBuilder `refresh`).
func refresh() -> void:
	_builder.refresh()


## Puts the player in the middle of the view.
func centre_on_player() -> void:
	_centre = Vector2(_state.outdoor_tile()) + Vector2(0.5, 0.5)


## The pixels a tile takes now.
func tile_pixels() -> float:
	return _scale


## The tile under a point of the view.
func tile_at(point: Vector2) -> Vector2i:
	return Vector2(_centre + (point - size / 2.0) / _scale).floor()


## Where the middle of a tile is on the view.
func point_of(tile_position: Vector2) -> Vector2:
	return (tile_position - _centre) * _scale + size / 2.0


## The chunks in view that are in the world, the nearest the middle first.
func visible_chunks() -> Array[Vector2i]:
	var first := Chunk.world_to_chunk(tile_at(Vector2.ZERO))
	var last := Chunk.world_to_chunk(tile_at(size))
	var middle := Vector2(Chunk.world_to_chunk(tile_at(size / 2.0)))
	var chunks: Array[Vector2i] = []
	for chunk_y in range(first.y, last.y + 1):
		for chunk_x in range(first.x, last.x + 1):
			var coords := Vector2i(chunk_x, chunk_y)
			if World.is_chunk_in_bounds(coords):
				chunks.append(coords)
	chunks.sort_custom(
		func(one: Vector2i, other: Vector2i) -> bool:
			return (
				Vector2(one).distance_squared_to(middle)
				< Vector2(other).distance_squared_to(middle)
			)
	)
	return chunks


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _builder == null:
		return
	var keys := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	_centre += keys * KEY_PAN_SPEED / _scale * delta
	_builder.update(visible_chunks(), BUILD_BUDGET_USEC)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_pointer = event.position
		tile_hovered.emit(tile_at(event.position))
		if _is_pressed:
			_on_mouse_drag(event)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_zoom(ZOOM_STEP, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / ZOOM_STEP, event.position)
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_pressed = true
				_is_dragging = false
				_press_at = event.position
			else:
				if _is_pressed and not _is_dragging:
					tile_clicked.emit(tile_at(event.position), event.position)
				_is_pressed = false


func _on_mouse_drag(event: InputEventMouseMotion) -> void:
	if not _is_dragging and event.position.distance_to(_press_at) < CLICK_SLOP:
		return
	_is_dragging = true
	_centre -= event.relative / _scale
	queue_redraw()


## Zooms so that the point of the map under `at` stays there.
func _zoom(factor: float, at: Vector2) -> void:
	var tile_under := _centre + (at - size / 2.0) / _scale
	_scale = clampf(_scale * factor, MIN_SCALE, MAX_SCALE)
	_centre = tile_under - (at - size / 2.0) / _scale
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if _builder == null:
		return
	var chunk_pixels := Vector2.ONE * Chunk.CHUNK_SIZE * _scale
	for coords in visible_chunks():
		var texture := _builder.texture_of(coords)
		if texture != null:
			var top_left := point_of(Vector2(coords * Chunk.CHUNK_SIZE))
			draw_texture_rect(texture, Rect2(top_left, chunk_pixels), false)
	_draw_village()
	_draw_villagers()
	_draw_player()


func _draw_village() -> void:
	var village := _state.world.village
	if village == null:
		return
	var area := Rect2(village.area)
	var above := point_of(Vector2(area.get_center().x, area.position.y))
	_draw_tag([village.village_name], above + Vector2(0, -8), true)


## The villagers as dots, and the names of those under the pointer in one box beside it.
func _draw_villagers() -> void:
	for npc in _state.npcs.all():
		var at := _point_of_villager(npc)
		draw_circle(at, VILLAGER_DOT_RADIUS + 1.0, PLAYER_OUTLINE)
		draw_circle(at, VILLAGER_DOT_RADIUS, VILLAGER_FILL)
	var names: Array[String] = []
	for npc in villagers_at(_pointer):
		names.append(npc.name)
	if not names.is_empty():
		_draw_tag(names, _pointer + TAG_OFFSET)


## The villagers whose dots are within HOVER_RADIUS of `point`, the nearest first.
func villagers_at(point: Vector2) -> Array[Npc]:
	var near: Array[Npc] = []
	if point == NO_POINTER:
		return near
	for npc in _state.npcs.all():
		if _point_of_villager(npc).distance_to(point) <= HOVER_RADIUS:
			near.append(npc)
	near.sort_custom(
		func(a: Npc, b: Npc) -> bool:
			return (
				_point_of_villager(a).distance_squared_to(point)
				< _point_of_villager(b).distance_squared_to(point)
			)
	)
	return near


func _point_of_villager(npc: Npc) -> Vector2:
	var tile := npc.inside.door_tile() if npc.inside != null else npc.tile()
	return point_of(Vector2(tile) + Vector2(0.5, 0.5))


## The player as an arrow pointing the way they face.
func _draw_player() -> void:
	var at := point_of(Vector2(_state.outdoor_tile()) + Vector2(0.5, 0.5))
	var facing := Vector2(_state.player.facing)
	var side := facing.orthogonal()
	var arrow := PackedVector2Array(
		[
			at + facing * PLAYER_ARROW_SIZE,
			at - facing * PLAYER_ARROW_SIZE * 0.7 + side * PLAYER_ARROW_SIZE * 0.7,
			at - facing * PLAYER_ARROW_SIZE * 0.3,
			at - facing * PLAYER_ARROW_SIZE * 0.7 - side * PLAYER_ARROW_SIZE * 0.7,
		]
	)
	draw_colored_polygon(arrow, PLAYER_FILL)
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), PLAYER_OUTLINE, 1.5)


## A box of lines on a dark fill with an edge, its top left at `at` (or its bottom middle, when
## `is_centred`), kept inside the view.
func _draw_tag(lines: Array[String], at: Vector2, is_centred := false) -> void:
	var font := get_theme_default_font()
	var line_height := font.get_height(LABEL_SIZE)
	var width := 0.0
	for line in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x)
	var box_size := Vector2(width, line_height * lines.size()) + TAG_PADDING * 2.0
	var top_left := at - Vector2(box_size.x / 2.0, box_size.y) if is_centred else at
	top_left = top_left.clamp(Vector2.ZERO, (size - box_size).max(Vector2.ZERO))
	var box := Rect2(top_left, box_size)
	draw_rect(box, TAG_FILL)
	draw_rect(box, TAG_EDGE, false, 1.0)
	for index in lines.size():
		var baseline := (
			top_left + TAG_PADDING + Vector2(0, line_height * index + font.get_ascent(LABEL_SIZE))
		)
		draw_string(
			font, baseline, lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, VILLAGER_FILL
		)
