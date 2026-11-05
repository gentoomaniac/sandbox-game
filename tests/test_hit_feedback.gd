extends ResourceCase
## Hit feedback: which effect a hit on each object type and look gives, how the particles
## live, and that every hit, the finishing one too, shakes and emits.

const LOOKS := SeasonBlend.Look
const KINDS := HitEffect.Kind

var _view: WorldView


func _show_world_in_view() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_view.show_world(_world)
	_view._load_chunk(Chunk.world_to_chunk(_tile))


func test_a_tree_with_foliage_drops_leaves_of_its_look() -> void:
	assert_eq(HitEffect.kind_for(WorldObjectTypes.OAK, LOOKS.SPRING), KINDS.LEAVES_GREEN)
	assert_eq(HitEffect.kind_for(WorldObjectTypes.OAK, LOOKS.SUMMER), KINDS.LEAVES_GREEN)
	assert_eq(HitEffect.kind_for(WorldObjectTypes.OAK, LOOKS.AUTUMN), KINDS.LEAVES_AUTUMN)


func test_spruce_and_pine_drop_needles_all_year_unless_snowy() -> void:
	for type in [WorldObjectTypes.SPRUCE, WorldObjectTypes.PINE]:
		for look in [LOOKS.SPRING, LOOKS.SUMMER, LOOKS.AUTUMN, LOOKS.BARE, LOOKS.FROST]:
			assert_eq(HitEffect.kind_for(type, look), KINDS.NEEDLES, "%s %s" % [type, look])
		assert_eq(HitEffect.kind_for(type, LOOKS.SNOW), KINDS.SNOW)
		assert_eq(HitEffect.kind_for(type, LOOKS.DUSTING), KINDS.SNOW)


func test_a_snowy_oak_drops_snow() -> void:
	assert_eq(HitEffect.kind_for(WorldObjectTypes.OAK, LOOKS.SNOW), KINDS.SNOW)
	assert_eq(HitEffect.kind_for(WorldObjectTypes.OAK, LOOKS.DUSTING), KINDS.SNOW)


func test_bare_trees_drop_nothing() -> void:
	assert_eq(HitEffect.kind_for(WorldObjectTypes.OAK, LOOKS.BARE), KINDS.NONE)
	for look in LOOKS.values():
		assert_ne(HitEffect.kind_for(WorldObjectTypes.DEAD_TREE, look), KINDS.LEAVES_GREEN)
	assert_eq(HitEffect.kind_for(WorldObjectTypes.DEAD_TREE, LOOKS.SUMMER), KINDS.NONE)


func test_stone_and_boulder_throw_splinters_in_every_look() -> void:
	for type in [WorldObjectTypes.STONE, WorldObjectTypes.BOULDER]:
		for look in LOOKS.values():
			assert_eq(HitEffect.kind_for(type, look), KINDS.SPLINTERS)


func test_stumps_and_bushes_drop_nothing() -> void:
	for type in [WorldObjectTypes.STUMP, WorldObjectTypes.SHRUB, WorldObjectTypes.BERRY_BUSH]:
		assert_eq(HitEffect.kind_for(type, LOOKS.SUMMER), KINDS.NONE)


func test_particles_are_few_and_gone_in_about_a_second() -> void:
	var particles: HitParticles = autofree(HitParticles.new())
	for kind in HitParticles.SPECS:
		particles.emit(kind, Vector2.ZERO)
		var count := particles.particle_count()
		assert_between(count, 2, 12, "count of %s" % kind)
		particles.advance(1.2)
		assert_eq(particles.particle_count(), 0, "%s gone" % kind)
		assert_lt(HitParticles.SPECS[kind]["life"], 1.2)


func test_no_effect_emits_no_particles() -> void:
	var particles: HitParticles = autofree(HitParticles.new())
	particles.emit(KINDS.NONE, Vector2.ZERO)
	assert_eq(particles.particle_count(), 0)


func test_a_hit_that_leaves_the_tree_standing_shakes_it_and_drops_leaves() -> void:
	var tree := _place(WorldObjectTypes.OAK)
	_set_midsummer()
	_show_world_in_view()
	_hold(ItemTypes.AXE)
	_state.use_tile(_tile)
	assert_same(_world.object_at(_tile), tree)
	assert_false(_view._object_sprites[_tile].is_plain(), "shaking")
	assert_gt(_view._hit_particles.particle_count(), 0)


func test_the_finishing_hit_shakes_the_stump_and_drops_leaves() -> void:
	_place(WorldObjectTypes.OAK)
	_set_midsummer()
	_show_world_in_view()
	_hold(ItemTypes.AXE)
	_hit(ItemTypes.AXE, 5)
	var stump := _world.object_at(_tile)
	assert_eq(stump.type, WorldObjectTypes.STUMP)
	assert_false(_view._object_sprites[_tile].is_plain(), "the stump shakes")
	assert_gt(_view._hit_particles.particle_count(), 0)


func test_the_finishing_hit_on_stone_removes_it_and_throws_splinters() -> void:
	_place(WorldObjectTypes.STONE)
	_hit(ItemTypes.PICKAXE, 2)
	_show_world_in_view()
	_hit(ItemTypes.PICKAXE, 1)
	assert_null(_world.object_at(_tile))
	assert_between(_view._hit_particles.particle_count(), 6, 9, "4 to 6 splinters and some dust")
