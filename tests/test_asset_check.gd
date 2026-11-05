extends GutTest
## Every picture the data refers to is in the repo and imported (see AssetCheck).


func test_every_picture_the_data_refers_to_loads() -> void:
	assert_eq(AssetCheck.missing(), [] as Array[String])
