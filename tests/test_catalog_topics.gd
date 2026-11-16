extends GutTest
## CatalogTopics: the definitions of the topic scripts are gathered in path order, and an id two
## topics define is a problem that names both, found before either is merged.

const CLASHING := "res://tests/catalog_topics/clashing"
const ODD := "res://tests/catalog_topics/odd"


func test_the_topics_of_a_folder_are_read_in_path_order() -> void:
	var problems: Array[String] = []
	var by_path := CatalogTopics.read_folder(CLASHING, problems)
	assert_eq(by_path.keys(), [CLASHING + "/a_kiln.gd", CLASHING + "/b_oven.gd"])
	assert_eq(by_path[CLASHING + "/b_oven.gd"][&"only_b"], {"hp": 3})
	assert_eq(problems, [] as Array[String])


func test_a_topic_without_types_is_a_problem() -> void:
	var problems: Array[String] = []
	assert_eq(CatalogTopics.read_folder(ODD, problems), {})
	assert_eq(problems, [ODD + "/no_types.gd has no TYPES"] as Array[String])


func test_an_id_two_topics_define_names_both_and_keeps_the_first() -> void:
	var problems: Array[String] = []
	var by_path := CatalogTopics.read_folder(CLASHING, problems)
	var all_types := CatalogTopics.merged("object", by_path, problems)
	var expected := "object shared: defined in %s/a_kiln.gd and in %s/b_oven.gd"
	assert_eq(problems, [expected % [CLASHING, CLASHING]] as Array[String])
	assert_eq(all_types.keys(), [&"shared", &"only_a", &"only_b"])
	assert_eq(all_types[&"shared"], {"hp": 1})
