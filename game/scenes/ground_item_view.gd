class_name GroundItemView
extends Node
## Draws the items lying on the ground of a World: a small picture each on a contact shadow,
## standing among the world's objects (see WorldView `entities`) so it sorts with them.
## Positions are rounded to whole art pixels, so the sprites stay put on the world as the camera
## moves. Piles a harvest drops hop out of their source (see ItemHop); the state has them where
## they land at once, so a pile that is pulled towards the player or collected during its hop
## just ends the hop.
##
## Only the piles near the focus (the player) have a sprite: the others stay in the state and
## get theirs when the focus comes near (see `set_focus`).

## From the sprite's position (the pile's spot on the ground) to the top left corner of its
## 16x16 picture.
const SPRITE_OFFSET := Vector2(-8, -14)
## The contact shadow under a pile (see Animal `draw_contact_shadow`), in world pixels.
const SHADOW_HALF_WIDTH := 6
## Between the hops of the piles of one drop.
const STAGGER_SECONDS := 0.05
## Piles get a sprite within this many chunks of the focus, the ones the world view draws. They
## keep it until they are further than one chunk more, so a focus on a chunk border does not
## make and free the sprites of a row of chunks again and again.
const NEAR_CHUNKS := ChunkResidency.LOAD_RADIUS
const KEPT_CHUNKS := NEAR_CHUNKS + 1

var _world: World
var _entities: Node2D
var _focus_chunk: Vector2i
var _has_focus := false
var _sprites: Dictionary[GroundItem, Sprite2D] = {}
var _hops: Dictionary[GroundItem, ItemHop] = {}


## Shows the items of the world as the focus gets near them (see `set_focus`). Showing the world
## it shows again does nothing; another world is refused, as the sprites and hops of the first
## would stay: make a new view.
func show_items(world: World, entities: Node2D) -> void:
	if _world == world:
		return
	if _world != null:
		push_error("GroundItemView already shows the items of another world")
		return
	_world = world
	_entities = entities
	add_to_group(ArtSet.VIEWS)
	world.ground_items.added.connect(_show_new_pile)
	world.ground_items.removed.connect(_remove_sprite)
	world.ground_items.dropped.connect(_start_hops)


## Follows the world tile the player is at: piles that are near it appear where they lie (not
## dropped, so without a hop), piles that are far lose their sprite.
func set_focus(world_pos: Vector2i) -> void:
	var chunk := Chunk.world_to_chunk(world_pos)
	if _has_focus and chunk == _focus_chunk:
		return
	_has_focus = true
	_focus_chunk = chunk
	for ground_item in _sprites.keys():
		if _chunks_from_focus(ground_item) > KEPT_CHUNKS:
			_remove_sprite(ground_item)
	for ground_item in _world.ground_items.in_chunks_around(chunk, NEAR_CHUNKS):
		if not _sprites.has(ground_item):
			_add_sprite(ground_item)


func show_art_set() -> void:
	for ground_item in _sprites:
		var path := ItemTypes.ground_icon_path(ground_item.item)
		_sprites[ground_item].texture = load(ArtSet.path(path))


## Makes the hops from `source` that were just dropped wait `seconds` longer: a felled tree's seed
## comes out when the tree lands, not when it is cut.
func hold_hops_from(source: Vector2i, seconds: float) -> void:
	for ground_item in _hops.keys():
		var hop := _hops[ground_item]
		if hop.source == source and hop.just_dropped:
			hop.delay += seconds
			_update_sprite(ground_item)


## Piles move while they hop and while they are pulled to the player.
func _process(delta: float) -> void:
	for ground_item in _hops.keys():
		_hops[ground_item].advance(delta)
	for ground_item in _sprites:
		_update_sprite(ground_item)


func _show_new_pile(ground_item: GroundItem) -> void:
	if _has_focus and _chunks_from_focus(ground_item) <= NEAR_CHUNKS:
		_add_sprite(ground_item)


func _chunks_from_focus(ground_item: GroundItem) -> int:
	var offset := (
		(Chunk.world_to_chunk(Vector2i(ground_item.position.floor())) - _focus_chunk).abs()
	)
	return maxi(offset.x, offset.y)


func _add_sprite(ground_item: GroundItem) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(ArtSet.path(ItemTypes.ground_icon_path(ground_item.item)))
	sprite.centered = false
	sprite.offset = SPRITE_OFFSET
	sprite.position = _pixel_position(ground_item)
	# The sprite's position stays on the ground while it hops (the lift is in its offset), so
	# the shadow under it stays there too.
	var shadow := Node2D.new()
	shadow.show_behind_parent = true
	shadow.draw.connect(Animal.draw_contact_shadow.bind(shadow, SHADOW_HALF_WIDTH))
	sprite.add_child(shadow)
	_entities.add_child(sprite)
	_sprites[ground_item] = sprite


func _remove_sprite(ground_item: GroundItem) -> void:
	if not _sprites.has(ground_item):
		return
	_sprites[ground_item].queue_free()
	_sprites.erase(ground_item)
	_hops.erase(ground_item)


func _start_hops(source: Vector2i, piles: Array[GroundItem]) -> void:
	for index in piles.size():
		if not _sprites.has(piles[index]):
			continue
		var landing := piles[index].position * TerrainTileset.TILE_SIZE
		_hops[piles[index]] = ItemHop.new(source, landing, index * STAGGER_SECONDS)
		_update_sprite(piles[index])


func _update_sprite(ground_item: GroundItem) -> void:
	var sprite := _sprites[ground_item]
	var hop: ItemHop = _hops.get(ground_item)
	# A pile that is not where the hop lands was pulled: the player takes it from here.
	if (
		hop != null
		and (hop.is_done() or hop.landing() != ground_item.position * TerrainTileset.TILE_SIZE)
	):
		_hops.erase(ground_item)
		hop = null
	if hop == null:
		sprite.visible = true
		sprite.offset = SPRITE_OFFSET
		sprite.position = _pixel_position(ground_item)
		return
	sprite.visible = not hop.is_waiting()
	sprite.offset = SPRITE_OFFSET - Vector2(0, roundf(hop.lift()))
	sprite.position = hop.ground_position().round()


func _pixel_position(ground_item: GroundItem) -> Vector2:
	return (ground_item.position * TerrainTileset.TILE_SIZE).round()
