extends GutTest
## The upgrade scripts of old saves are one per supported version, with none missing and none left
## over from a version that is no longer read (see SaveMigrations).


func test_the_migrations_are_one_for_each_version_from_the_oldest_to_the_one_before_the_current(
) -> void:
	var expected: Array[String] = []
	for version in range(SaveFile.OLDEST_VERSION, SaveFile.VERSION):
		expected.append(SaveMigrations.path_from(version))

	assert_eq(ScriptFolder.paths(SaveMigrations.DIRECTORY), expected)


func test_every_migration_has_an_upgrade_that_takes_the_data_of_a_game() -> void:
	for version in range(SaveFile.OLDEST_VERSION, SaveFile.VERSION):
		var script: GDScript = load(SaveMigrations.path_from(version))
		var upgrades := script.get_script_method_list().filter(
			func(method: Dictionary) -> bool: return method["name"] == "upgrade"
		)

		assert_eq(upgrades.size(), 1, "version %d has one upgrade" % version)
		assert_eq(upgrades[0]["args"].size(), 1, "version %d upgrades the game" % version)
