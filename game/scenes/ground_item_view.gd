class_name GroundItemView
extends Node
## Draws the items lying on the ground of a World: a small icon each, standing among the
## world's objects (see WorldView `entities`) so it sorts with them. Positions are rounded to
## whole art pixels, so the sprites stay put on the world as the camera moves.

## From the sprite's position (the pile's spot on the ground) to its top left corner.
const SPRITE_OFFSET := Vector2(-4, -7)

var _entities: Node2D
var _sprites: Dictionary[GroundItem, Sprite2D] = {}


func show_items(world: World, entities: Node2D) -> void:
	_entities = entities
	world.ground_item_added.connect(_add_sprite)
	world.ground_item_removed.connect(_remove_sprite)
	for ground_item in world.ground_items():
		_add_sprite(ground_item)


## Piles move while they are pulled to the player.
func _process(_delta: float) -> void:
	for ground_item in _sprites:
		_sprites[ground_item].position = _pixel_position(ground_item)


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


func _pixel_position(ground_item: GroundItem) -> Vector2:
	return (ground_item.position * TerrainTileset.TILE_SIZE).round()
