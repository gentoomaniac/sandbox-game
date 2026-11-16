class_name SaveMigrations
extends RefCounted
## The upgrades of an old save, one script per version in game/state/save_migrations/:
## `v<N>_to_v<N+1>.gd` has `static func upgrade(game: Dictionary)`, which gives the data of a save
## of version N the shape of version N + 1. The scripts of the versions SaveFile still reads, from
## OLDEST_VERSION up to the one before VERSION, are all there and none else (a test checks it).

const DIRECTORY := "res://game/state/save_migrations"


## Brings the data of a save of `from_version` up to the current version, one step after the other.
static func upgrade(game: Dictionary, from_version: int) -> void:
	for version in range(from_version, SaveFile.VERSION):
		load(path_from(version)).call(&"upgrade", game)


## The script that upgrades a save of `version` to the next.
static func path_from(version: int) -> String:
	return "%s/v%d_to_v%d.gd" % [DIRECTORY, version, version + 1]
