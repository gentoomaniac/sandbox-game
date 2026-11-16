class_name SavePlayerChecks
extends RefCounted
## The checks of the player: where they stand, their energy and health, the inventory, equipment,
## money, skills and attributes.

var _ctx: SaveContext
var _objects: SaveObjectChecks


func _init(context: SaveContext) -> void:
	_ctx = context
	_objects = SaveObjectChecks.new(context)


func check(game: Dictionary) -> void:
	var player: Variant = _ctx.field(game, "player", SaveContext.Kind.DICT, "")
	if player != null:
		_check_player(player)


func _check_player(player: Dictionary) -> void:
	_ctx.field(player, "position", SaveContext.Kind.POINT, "player")
	_ctx.field(player, "facing", SaveContext.Kind.VECTOR, "player")
	_ctx.field(player, "home_bed", SaveContext.Kind.VECTOR, "player")
	_ctx.field(player, "energy", SaveContext.Kind.NUMBER, "player")
	_ctx.field(player, "health", SaveContext.Kind.NUMBER, "player")
	_ctx.field(player, "is_debuffed", SaveContext.Kind.BOOL, "player")
	_ctx.field(player, "is_lantern_lit", SaveContext.Kind.BOOL, "player")
	var can_water: Variant = _ctx.field(player, "can_water", SaveContext.Kind.WHOLE, "player")
	_ctx.check_between(
		can_water, 0, EnergyRules.default_rules().can_capacity(), "player", "can_water"
	)
	var appearance: Variant = _ctx.field(player, "appearance", SaveContext.Kind.DICT, "player")
	if appearance != null:
		_ctx.check_appearance(appearance, "player appearance")
	var inventory: Variant = _ctx.field(player, "inventory", SaveContext.Kind.DICT, "player")
	if inventory != null:
		_check_inventory(inventory)
	var money: Variant = _ctx.field(player, "money", SaveContext.Kind.WHOLE, "player")
	if money != null and money < 0:
		_ctx.report("player", "money %d is below 0" % money)
	var equipment: Variant = _ctx.field(player, "equipment", SaveContext.Kind.DICT, "player")
	if equipment != null:
		_check_equipment(equipment)
	var skills: Variant = _ctx.field(player, "skills", SaveContext.Kind.DICT, "player")
	if skills != null:
		_check_skills(skills)
	var attributes: Variant = _ctx.field(player, "attributes", SaveContext.Kind.DICT, "player")
	if attributes != null:
		_check_attributes(attributes)


func _check_inventory(inventory: Dictionary) -> void:
	var path := "player inventory"
	_objects.check_stacks(inventory, "slots", Inventory.SLOT_COUNT, path)
	var selected: Variant = _ctx.field(inventory, "selected_slot", SaveContext.Kind.WHOLE, path)
	if selected != null and (selected < 0 or selected >= Inventory.HOTBAR_SIZE):
		_ctx.report(
			path,
			(
				"selected_slot %d is not a hotbar slot (0 to %d)"
				% [selected, Inventory.HOTBAR_SIZE - 1]
			)
		)


func _check_equipment(equipment: Dictionary) -> void:
	for slot: Variant in equipment:
		var path := "player equipment %s" % slot
		var item: Variant = equipment[slot]
		if not item is String:
			_ctx.report(path, "should be an item id")
		elif not Equipment.SLOTS.has(StringName(slot)):
			_ctx.report(path, "not an equipment slot")
		elif not ItemTypes.TYPES.has(StringName(item)):
			_ctx.add_missing("item %s" % item, path, func() -> void: equipment.erase(slot))
		elif not Equipment.fits(StringName(slot), StringName(item)):
			_ctx.report(path, "%s can't be worn there" % item)


func _check_skills(skills: Dictionary) -> void:
	var points: Variant = _ctx.field(skills, "points", SaveContext.Kind.DICT, "player skills")
	if points != null:
		for skill: Variant in points:
			if not _ctx.is_kind(points[skill], SaveContext.Kind.NUMBER):
				_ctx.report("player skills points %s" % skill, "should be a number")
	var fading: Variant = _ctx.field(skills, "fading", SaveContext.Kind.LIST, "player skills")
	if fading != null and not fading.all(func(skill: Variant) -> bool: return skill is String):
		_ctx.report("player skills fading", "should be a list of text")


func _check_attributes(attributes: Dictionary) -> void:
	var levels: Variant = _ctx.field(
		attributes, "levels", SaveContext.Kind.DICT, "player attributes"
	)
	if levels == null:
		return
	var rules := AttributeRules.default_rules()
	for attribute in rules.attribute_ids():
		var level: Variant = _ctx.field(
			levels, str(attribute), SaveContext.Kind.WHOLE, "player attributes levels"
		)
		_ctx.check_between(
			level, rules.min_level(), rules.max_level(), "player attributes levels", str(attribute)
		)
