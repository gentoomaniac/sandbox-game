extends GutTest
## Every picture under assets/ is imported and loads (see AssetCheck).


func test_every_picture_under_assets_loads() -> void:
	assert_eq(AssetCheck.missing(), [] as Array[String])
