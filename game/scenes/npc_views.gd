class_name NpcViews
extends Node
## Draws the villagers of the game: an NpcView for each one that is near the focus (the player), in
## the world view's entities, and stands on a chunk that is loaded: one on a chunk that is not has
## no ground to be drawn on. A villager far away has no view, but goes on in the state (see Npcs
## `update`, which walks its trip over chunks that are not loaded) and has one again when it is near
## and its chunk is loaded. One who is inside a building has none here: InteriorNpcViews shows them
## in its room.

## Villagers get a view within this many chunks of the focus, the ones the world view draws, and
## keep it until they are further than one chunk more, so one who strolls over a chunk border
## does not get a view and lose it again and again.
const NEAR_CHUNKS := ChunkResidency.LOAD_RADIUS
const KEPT_CHUNKS := NEAR_CHUNKS + 1

var _entities: Node2D
var _focus_chunk := Vector2i.ZERO
var _has_focus := false
var _views: Dictionary[Npc, NpcView] = {}
var _npcs: Npcs
var _world: World


## Shows the villagers of `npcs` that stand on loaded chunks of `world` as the focus gets near them
## (see `set_focus`).
func show_npcs(npcs: Npcs, entities: Node2D, world: World) -> void:
	_npcs = npcs
	_world = world
	_entities = entities
	npcs.added.connect(_update_view)
	npcs.removed.connect(_free_view)


## Follows the world tile the player is at.
func set_focus(world_pos: Vector2i) -> void:
	_focus_chunk = Chunk.world_to_chunk(world_pos)
	_has_focus = true


## Villagers walk between chunks, and the focus moves.
func _process(_delta: float) -> void:
	if _has_focus:
		for npc in _npcs.all():
			_update_view(npc)


func _update_view(npc: Npc) -> void:
	if not _has_focus:
		return
	if npc.inside != null:
		_free_view(npc)
		return
	var chunk := Chunk.world_to_chunk(Vector2i(npc.position.floor()))
	var offset := (chunk - _focus_chunk).abs()
	var chunks_away := maxi(offset.x, offset.y)
	var is_loaded := _world.is_chunk_loaded(chunk)
	if chunks_away <= NEAR_CHUNKS and is_loaded and not _views.has(npc):
		_views[npc] = NpcView.new(npc)
		_entities.add_child(_views[npc])
	elif (chunks_away > KEPT_CHUNKS or not is_loaded) and _views.has(npc):
		_views[npc].queue_free()
		_views.erase(npc)


func _free_view(npc: Npc) -> void:
	if _views.has(npc):
		_views[npc].queue_free()
		_views.erase(npc)
