extends RefCounted
## A topic for test_catalog_topics.gd with an id that is no StringName, a definition that is no
## table, a key that is no text, and one sound definition.

const TYPES := {
	"text_id": {"hp": 1},
	&"no_table": 5,
	&"odd_key": {3: "hp"},
	&"sound": {"hp": 4},
}
