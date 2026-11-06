class_name GroundItemView
extends Node
## Draws the items lying on the ground of a World: a small icon each, standing among the
## world's objects (see WorldView `entities`) so it sorts with them. Positions are rounded to
## whole art pixels, so the sprites stay put on the world as the camera moves. Piles a harvest
## drops hop out of their source (see ItemHop); the state has them where they land at once, so
## a pile that is pulled towards the player or collected during its hop just ends the hop.

## From the sprite's position (the pile's spot on the ground) to its top left corner.
const SPRITE_OFFSET := Vector2(-4, -7)
## Between the hops of the piles of one drop.
const STAGGER_SECONDS := 0.05

var _entities: Node2D
var _sprites: Dictionary[GroundItem, Sprite2D] = {}
var _hops: Dictionary[GroundItem, ItemHop] = {}


## The items that are on the ground now are not dropped: they appear where they lie.
func show_items(world: World, entities: Node2D) -> void:
	_entities = entities
	world.ground_items.added.connect(_add_sprite)
	world.ground_items.removed.connect(_remove_sprite)
	world.ground_items.dropped.connect(_start_hops)
	for ground_item in world.ground_items.all():
		_add_sprite(ground_item)


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


func _add_sprite(ground_item: GroundItem) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(ItemTypes.ground_icon_path(ground_item.item))
	sprite.centered = false
	sprite.offset = SPRITE_OFFSET
	sprite.position = _pixel_position(ground_item)
	_entities.add_child(sprite)
	_sprites[ground_item] = sprite


func _remove_sprite(ground_item: GroundItem) -> void:
	_sprites[ground_item].queue_free()
	_sprites.erase(ground_item)
	_hops.erase(ground_item)


func _start_hops(source: Vector2i, piles: Array[GroundItem]) -> void:
	for index in piles.size():
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
