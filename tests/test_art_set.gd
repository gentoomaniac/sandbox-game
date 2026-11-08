extends GutTest
## The art sets: which picture is loaded in each, and the switch of the views that keep theirs.

const BODY := "res://assets/character/body_0.png"
## Drawn after the people went native, so it has no classic picture.
const TRICORNE := "res://assets/character/head_tricorne.png"


func after_each() -> void:
	ArtSet.is_classic = false


func test_the_new_art_is_the_picture_itself() -> void:
	assert_eq(ArtSet.path(BODY), BODY)


func test_the_classic_art_is_the_picture_under_classic() -> void:
	ArtSet.is_classic = true
	assert_eq(ArtSet.path(BODY), "res://assets/classic/character/body_0.png")


func test_a_picture_without_classic_art_is_the_new_one_in_both_sets() -> void:
	ArtSet.is_classic = true
	assert_eq(ArtSet.path(TRICORNE), TRICORNE)


func test_the_classic_art_has_the_cells_of_the_new() -> void:
	ArtSet.is_classic = true
	for path in [BODY, "res://assets/character/collapse/body_0.png"]:
		var classic: Texture2D = load(ArtSet.path(path))
		assert_eq(classic.get_size(), load(path).get_size(), path)


func test_a_villager_shown_switches_its_sheets_with_the_art() -> void:
	var look := Appearance.new()
	look.wear(Appearance.HEAD, "tricorne")
	var view := NpcView.new(Npc.new("Hinnerk", &"male", look, Vector2.ZERO))
	add_child_autofree(view)
	ArtSet.show(true, get_tree())
	var sheets := view.get_children().map(
		func(sprite: Sprite2D) -> String: return sprite.texture.resource_path
	)
	assert_eq(
		sheets,
		[
			"res://assets/classic/character/body_0.png",
			"res://assets/classic/character/hair_0.png",
			TRICORNE,
		]
	)
	ArtSet.show(false, get_tree())
	assert_eq(view.get_child(0).texture.resource_path, BODY)
