class_name ArtSet
extends RefCounted
## Which art the world is drawn in: the new art, drawn at 32 px per tile, or the classic art, the
## 16 px art doubled as it was before its group was drawn anew. The classic art is generated
## into assets/classic/ under the new art's names (tools/art/classic/); the player picks the set
## under Settings → Display or with F7 (GameSettings `is_classic_art`).
##
## Every picture of a group that has classic art is loaded by its `path`. A picture with no
## classic version (one drawn after its group went native, such as the tricorne) is the new one
## in both sets. A view that keeps a loaded picture joins the group VIEWS and loads it anew in
## its `show_art_set()`; a view that loads its pictures as it shows them needs nothing more.

const VIEWS := &"art_set_views"
const ASSETS_DIR := "res://assets/"
const CLASSIC_DIR := "res://assets/classic/"

## Not saved here: Main sets it from the settings at start and on every change.
static var is_classic := false
## The classic picture of each picture asked for, or the picture itself where it has none.
## PlayerView asks every frame, so the files are looked up only once.
static var _classic_paths := {}


## The picture to load for the picture `asset_path` under assets/ in the chosen set.
static func path(asset_path: String) -> String:
	if not is_classic:
		return asset_path
	if not _classic_paths.has(asset_path):
		var classic := CLASSIC_DIR + asset_path.trim_prefix(ASSETS_DIR)
		_classic_paths[asset_path] = classic if ResourceLoader.exists(classic) else asset_path
	return _classic_paths[asset_path]


## Shows the classic art or the new: the views of `tree` that keep pictures load them anew.
static func show(classic: bool, tree: SceneTree) -> void:
	is_classic = classic
	tree.call_group(VIEWS, &"show_art_set")
