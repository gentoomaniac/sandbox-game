class_name ReadOnly
extends RefCounted
## Makes a table of data safe to hand out: whoever gets a dictionary or array of it can read it
## but not change it (the change is an error), however deep it looks.


## `value` with every dictionary and array in it (itself too) made read-only; returns `value`.
static func deep(value: Variant) -> Variant:
	if value is Dictionary:
		for key: Variant in value:
			deep(value[key])
		value.make_read_only()
	elif value is Array:
		for element: Variant in value:
			deep(element)
		value.make_read_only()
	return value
