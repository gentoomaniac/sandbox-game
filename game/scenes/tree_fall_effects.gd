class_name TreeFallEffects
extends Node
## A tree that is felled topples as a FallingTree sprite while the state already has its stump and
## its trunk; the trunk's tile stays hidden (see WorldObjectView `hide_object`) until the fall
## ends. WorldView owns it, starts the falls and advances them every frame.

## A tree was felled and starts to fall, for `seconds` until it lands.
signal tree_felled(tile: Vector2i, seconds: float)
## A felled tree hit the ground (where the sound of it belongs). `tree` is the object it was.
signal tree_landed(tree: WorldObject)

## The falls going on, the oldest first.
var falls: Array[FallingTree] = []
var _world: World
var _entities: Node2D
var _objects: WorldObjectView
var _hit_particles: HitParticles


func _init(entities: Node2D, objects: WorldObjectView, hit_particles: HitParticles) -> void:
	_entities = entities
	_objects = objects
	_hit_particles = hit_particles


func show_world(world: World) -> void:
	_world = world


## Starts the fall of a tree that was just replaced by its stump, away from the player at
## `player_x`. Its trunk is already in the world; it stays hidden until the tree has landed.
## `impact_effect` is what flies off when it lands.
func start(tree: WorldObject, impact_effect: HitEffect.Kind, player_x: float) -> void:
	var fall := FallingTree.beside_trunk_of(tree, _world, player_x)
	fall.impact_effect = impact_effect
	_objects.place_sprite(fall, tree)
	fall.landed.connect(_on_landed.bind(fall))
	fall.finished.connect(_end.bind(fall))
	_entities.add_child(fall)
	falls.append(fall)
	if fall.trunk != null:
		_objects.hide_object(fall.trunk.pos)
	tree_felled.emit(tree.pos, FallingTree.FALL_SECONDS)


func advance(delta: float) -> void:
	if falls.is_empty():
		return
	for fall in falls.duplicate():
		fall.advance(delta)


## Ends the falls of the trees of a chunk that was dropped from the world.
func end_falls_in(coords: Vector2i) -> void:
	for fall in falls.duplicate():
		if Chunk.world_to_chunk(fall.tree.pos) == coords:
			_end(fall)


func _on_landed(fall: FallingTree) -> void:
	_hit_particles.emit(fall.impact_effect, fall.impact_point())
	var stump := _world.object_at(fall.tree.pos)
	if stump != null:
		_objects.shake(stump)
	tree_landed.emit(fall.tree)


## Takes the tree's sprite away and draws its trunk, if the chunk is still loaded.
func _end(fall: FallingTree) -> void:
	falls.erase(fall)
	fall.queue_free()
	if fall.trunk != null:
		_objects.reveal(fall.trunk.pos)
