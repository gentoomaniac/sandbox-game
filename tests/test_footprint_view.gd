extends GutTest
## The drawing of footprints (#64): one MultiMesh for each chunk that has prints, made with its
## first print and dropped with the chunk.

const TILE := Vector2i(5, 5)

var _world: World
var _view: FootprintView


func before_each() -> void:
	_world = World.new(1)
	_world.add_chunk(Chunk.new(Vector2i.ZERO))
	_view = add_child_autofree(FootprintView.new())
	_view.show_world(_world, func(_tile: Vector2i) -> bool: return true)


func _step_along(count: int) -> void:
	var step := FootprintRules.default_rules().step_tiles()
	var stride := Footprints.Stride.new()
	for x in count:
		var from := Vector2(TILE) + Vector2(x % 4 * step, 0.5)
		_world.footprints.walk(_world, stride, from, from + Vector2.RIGHT * step * 1.01)


func test_a_chunk_gets_one_multimesh_however_many_prints() -> void:
	assert_eq(_view.get_child_count(), 0, "no prints, no node")
	_step_along(10)
	assert_eq(_view.get_child_count(), 1)
	var multimesh := (_view.get_child(0) as MultiMeshInstance2D).multimesh
	assert_eq(multimesh.visible_instance_count, 10)


func test_the_multimesh_never_outgrows_the_cap() -> void:
	var cap := FootprintRules.default_rules().per_chunk()
	_step_along(cap * 2)
	var multimesh := (_view.get_child(0) as MultiMeshInstance2D).multimesh
	assert_eq(multimesh.instance_count, cap)
	assert_eq(multimesh.visible_instance_count, cap)


func test_forgetting_a_chunk_frees_its_multimesh_and_prints() -> void:
	_step_along(3)
	_view.forget_chunk(Vector2i.ZERO)
	await wait_process_frames(1)
	assert_eq(_view.get_child_count(), 0)
	assert_null(_world.footprints.ring_of(Vector2i.ZERO))
