class_name SaveContext
extends RefCounted
## What the checks of a save (see SaveValidator and the domain checks beside this file) share: where
## their findings go, the primitive shape and range checks, and the buildings of the world that
## the references of other domains point at.

enum Kind { TEXT, NUMBER, WHOLE, BOOL, LIST, DICT, VECTOR, RECT, POINT }

const KIND_NAMES := {
	Kind.TEXT: "text",
	Kind.NUMBER: "a number",
	Kind.WHOLE: "a whole number",
	Kind.BOOL: "true or false",
	Kind.LIST: "a list",
	Kind.DICT: "a dictionary",
	Kind.VECTOR: "two whole numbers",
	Kind.RECT: "four whole numbers",
	Kind.POINT: "two numbers",
}

## What is damaged in the save, each as "where: what", e.g. "player inventory slot 3: count -7 is
## not between 1 and 99".
var problems: Array[String] = []
## What the game no longer has, each as "what in where".
var missing: Array[String] = []

## What takes one missing thing out of the data, in the order found.
var _removals: Array[Callable] = []
## Whether the building at an origin has an inside; its keys are the origins of all the buildings
## the world checks have seen.
var _has_interior_by_origin: Dictionary[Vector2i, bool] = {}


## Takes what the game no longer has out of the data that was checked: an item leaves its slot,
## an object, animal or pile goes.
func drop_missing() -> void:
	for remove in _removals:
		remove.call()
	_removals.clear()
	missing.clear()


func report(path: String, message: String) -> void:
	problems.append(message if path == "" else "%s: %s" % [path, message])


func add_missing(what: String, path: String, remove: Callable) -> void:
	missing.append("%s in %s" % [what, path])
	_removals.append(remove)


func add_building(origin: Vector2i, has_interior: bool) -> void:
	_has_interior_by_origin[origin] = has_interior


func has_building_at(origin: Vector2i) -> bool:
	return _has_interior_by_origin.has(origin)


func has_interior_at(origin: Vector2i) -> bool:
	return _has_interior_by_origin.get(origin, false)


## Reports a number that is there (`value` is not null) and outside `low` to `high`.
func check_between(value: Variant, low: Variant, high: Variant, path: String, key: String) -> void:
	if value != null and (value < low or value > high):
		report(path, "%s %s is not between %s and %s" % [key, value, low, high])


## The value of `owner[key]` if it is there and of `kind`; else null, with a problem reported
## at `path`.
func field(owner: Dictionary, key: String, kind: Kind, path: String) -> Variant:
	if not owner.has(key):
		report(path, "no %s" % key)
		return null
	if not is_kind(owner[key], kind):
		report(join(path, key), "should be %s" % KIND_NAMES[kind])
		return null
	return owner[key]


func is_kind(value: Variant, kind: Kind) -> bool:
	var is_of_kind := false
	match kind:
		Kind.TEXT:
			is_of_kind = value is String
		Kind.NUMBER:
			is_of_kind = value is float or value is int
		Kind.WHOLE:
			is_of_kind = value is int or (value is float and value == floorf(value))
		Kind.BOOL:
			is_of_kind = value is bool
		Kind.LIST:
			is_of_kind = value is Array
		Kind.DICT:
			is_of_kind = value is Dictionary
		Kind.VECTOR:
			is_of_kind = _is_list_of(value, 2, Kind.WHOLE)
		Kind.RECT:
			is_of_kind = _is_list_of(value, 4, Kind.WHOLE)
		Kind.POINT:
			is_of_kind = _is_list_of(value, 2, Kind.NUMBER)
	return is_of_kind


func is_vector(value: Variant) -> bool:
	return is_kind(value, Kind.VECTOR)


func join(path: String, key: String) -> String:
	return key if path == "" else "%s %s" % [path, key]


## A list of `[x, y, value]` of the world, the value of the kind `value_kind`.
func check_entries(owner: Dictionary, key: String, value_kind: Kind) -> void:
	var entries: Variant = field(owner, key, Kind.LIST, "world")
	if entries == null:
		return
	for index in entries.size():
		var entry: Variant = entries[index]
		var path := "world %s %d" % [key, index]
		if not (entry is Array and entry.size() == 3):
			report(path, "should be [x, y, value]")
		elif not (is_kind(entry.slice(0, 2), Kind.VECTOR) and is_kind(entry[2], value_kind)):
			report(path, "should be [x, y, %s]" % KIND_NAMES[value_kind])


## The look of a person: layers, each with a slot and a variant.
func check_appearance(appearance: Dictionary, path: String) -> void:
	var layers: Variant = field(appearance, "layers", Kind.LIST, path)
	if layers == null:
		return
	for index in layers.size():
		var layer: Variant = layers[index]
		var is_layer: bool = (
			layer is Dictionary and layer.get("slot") is String and layer.get("variant") is String
		)
		if not is_layer:
			report("%s layers %d" % [path, index], "should have a slot and a variant")


## Takes `entry` out of `list` (the very one, not an equal one).
func removing(list: Array, entry: Variant) -> Callable:
	return func() -> void:
		list.assign(list.filter(func(other: Variant) -> bool: return not is_same(other, entry)))


func _is_list_of(value: Variant, size: int, part_kind: Kind) -> bool:
	return (
		value is Array
		and value.size() == size
		and value.all(func(part: Variant) -> bool: return is_kind(part, part_kind))
	)
