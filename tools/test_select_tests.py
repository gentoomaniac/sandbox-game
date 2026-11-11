"""Tests of select_tests.py on a small fake game, and on a fake repo for the branch range."""

import subprocess
import tempfile
import unittest
from pathlib import Path

import select_tests

GAME = {
    "game/state/foo.gd": "class_name Foo\n",
    "game/state/bar.gd": "class_name Bar\nvar foo := Foo.new()\n",
    "game/state/lonely.gd": "class_name Lonely\n",
    "game/state/orphan.gd": "class_name Orphan\n",
    "game/scenes/scene.tscn": '[ext_resource type="Script" path="res://game/state/bar.gd" id="1"]\n',
    "game/scenes/view.gd": 'var scene := preload("res://game/scenes/scene.tscn")\n',
    "game/state/crop_data.gd": 'class_name CropData\nconst PATH := "res://data/crops.cfg"\n',
    "data/crops.cfg": "[turnip]\n",
    "data/unread.cfg": "[nothing]\n",
    "tests/case_base.gd": "class_name CaseBase\nextends GutTest\n",
    "tests/test_foo.gd": "extends GutTest\nvar foo := Foo.new()\n",
    "tests/test_bar_through_class_name.gd": "extends CaseBase\nvar bar := Bar.new()\n",
    "tests/test_view.gd": 'extends GutTest\nvar view = load("res://game/scenes/view.gd")\n',
    "tests/test_crops.gd": "extends GutTest\nvar data := CropData.new()\n",
    "tests/test_unrelated.gd": "extends GutTest\n",
    "game/scenes/hud.tscn": '[ext_resource type="Resource" path="res://data/hud.cfg" id="1"]\n',
    "data/hud.cfg": "[hud]\n",
    "tests/test_hud.gd": 'extends GutTest\nvar hud = preload("res://game/scenes/hud.tscn")\n',
    "game/scenes/glow.gdshader": "shader_type canvas_item;\n",
    "tests/test_glow.gd": 'extends GutTest\nvar glow = load("res://game/scenes/glow.gdshader")\n',
    "game/scenes/art_loader.gd": 'class_name ArtLoader\nconst SHEET := "res://assets/crops/%s.png"\n',
    "game/scenes/crop_user.gd": "class_name CropUser\nvar loader := ArtLoader.new()\n",
    "game/scenes/art_set.gd": 'class_name ArtSet\nconst DIR := "res://assets/"\n',
    "art/generated/crops/turnip_32x32.png": "",
    "art/generated/lonely_32x32.png": "",
    "tests/test_art_loader.gd": "extends GutTest\nvar loader := ArtLoader.new()\n",
    "tests/test_crop_user.gd": "extends GutTest\nvar user := CropUser.new()\n",
    "tests/test_art_set.gd": "extends GutTest\nvar art := ArtSet.new()\n",
    "game/state/sheet_loader.gd": 'class_name SheetLoader\nconst PATH := "res://data/sheets/%s.cfg"\n',
    "data/sheets/a.cfg": "[a]\n",
    "tests/test_sheet_loader.gd": "extends GutTest\nvar loader := SheetLoader.new()\n",
    "game/state/map_loader.gd": 'class_name MapLoader\nconst DIR := "res://maps/other/"\n',
    "maps/other/hall.tmx": "<map/>\n",
    "maps/interiors/den.tmx": "<map/>\n",
    "data/rooms.cfg": '[den]\ninterior="res://maps/interiors/den.tmx"\n',
    "game/state/room_types.gd": 'class_name RoomTypes\nconst PATH := "res://data/rooms.cfg"\n',
    "tests/test_rooms.gd": "extends GutTest\nvar rooms := RoomTypes.new()\n",
    "game/scenes/hash.gdshaderinc": "float hash(float x) { return x; }\n",
    "game/scenes/sway.gdshader": '#include "res://game/scenes/hash.gdshaderinc"\n// a comment\n',
    "tests/test_sway.gd": 'extends GutTest\nvar sway = load("res://game/scenes/sway.gdshader")\n',
    "game/scenes/tint.gdshader": "shader_type canvas_item;\n",
    "game/scenes/theme.tres": '[ext_resource type="Shader" path="res://game/scenes/tint.gdshader" id="1"]\n',
    "game/scenes/theme_user.gd": 'class_name ThemeUser\nvar theme := preload("res://game/scenes/theme.tres")\n',
    "tests/test_theme.gd": "extends GutTest\nvar user := ThemeUser.new()\n",
    "game/state/base_rel.gd": "var x := 1\n",
    "game/state/child_rel.gd": 'class_name ChildRel\nextends "base_rel.gd"\nvar sibling := preload("base_rel.gd")\n',
    "tests/test_child_rel.gd": "extends GutTest\nvar child := ChildRel.new()\n",
    "art/generated/objects/oak_32x32.png": "",
    "art/generated/objects/atlas_32x32.txt": "32 32\n",
    "art/hand/objects/oak_32x32.png": "",
    "game/scenes/object_atlas.gd": 'class_name ObjectAtlas\nconst ATLAS := "res://assets/objects.png"\n',
    "tests/test_object_atlas.gd": "extends GutTest\nvar atlas := ObjectAtlas.new()\n",
    "tools/music/pieces/morning.txt": "",
    "tools/music/pieces/test_reel.txt": "",
    "game/scenes/skin.gdshader": "shader_type canvas_item;\n",
    "data/skin.tres": '[ext_resource type="Shader" path="res://game/scenes/skin.gdshader" id="1"]\n',
    "game/state/skin_user.gd": 'class_name SkinUser\nvar skin := preload("res://data/skin.tres")\n',
    "tests/test_skin.gd": "extends GutTest\nvar user := SkinUser.new()\n",
    "tests/test_map_loader.gd": "extends GutTest\nvar loader := MapLoader.new()\n",
    "tests/test_palette.gd": "extends GutTest\nvar t := FileAccess.get_file_as_string(\"res://tools/art/palette.py\")\n",
    "tools/art/palette.py": "",
    "tests/test_hash.gd": 'extends GutTest\nvar s := "Press #1"; var hashed := Hashed.new()\n',
    "game/state/hashed.gd": "class_name Hashed\n",
    "game/scenes/note.gdshader": "// Hashed is not used here\n",
    "tests/test_note.gd": 'extends GutTest\nvar note = load("res://game/scenes/note.gdshader")\n',
    "README.md": "readme\n",
    "docs/a.md": "doc\n",
    "tools/art/test_pack.py": "",
    "tools/art/trees.py": "",
    "tools/llm/llm.sh": "",
}


def write_files(root, files):
    for path, text in files.items():
        (root / path).parent.mkdir(parents=True, exist_ok=True)
        (root / path).write_text(text)


class SelectTestsTest(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.root = Path(folder.name)
        write_files(self.root, GAME)

    def select(self, *changed, deleted=()):
        return select_tests.select(self.root, changed, deleted)

    def test_docs_only_needs_no_tests(self):
        plan = self.select("README.md", "docs/a.md", "design/x/y.md", "TASKS.md")
        self.assertEqual(plan.words(), [])
        self.assertIn("docs, no tests", plan.report[0])

    def test_tools_only_runs_the_tool_tests(self):
        plan = self.select("tools/llm/llm.sh", "tools/art/test_pack.py")
        self.assertEqual(plan.words(), ["tools"])

    def test_art_generator_also_runs_make_art(self):
        plan = self.select("tools/art/trees.py")
        self.assertEqual(plan.words(), ["tools", "art"])

    def test_a_data_file_runs_the_tests_reaching_the_code_that_reads_it(self):
        plan = self.select("data/crops.cfg")
        self.assertEqual(plan.words(), ["tests/test_crops.gd"])

    def test_a_data_file_nothing_reads_runs_everything(self):
        self.assertEqual(self.select("data/unread.cfg").words(), ["full"])

    def test_a_script_runs_the_tests_that_use_its_class_name(self):
        self.assertEqual(self.select("game/state/foo.gd").tests, {
            "tests/test_foo.gd",
            "tests/test_bar_through_class_name.gd",
            "tests/test_view.gd",
        })

    def test_a_script_reaches_tests_through_scenes_and_load_paths(self):
        plan = self.select("game/state/bar.gd")
        self.assertEqual(plan.tests, {"tests/test_bar_through_class_name.gd", "tests/test_view.gd"})

    def test_a_class_named_only_in_a_comment_is_no_dependency(self):
        write_files(self.root, {"tests/test_comment.gd": "extends GutTest\n## see Orphan\nvar x := 1 # and Orphan\n"})
        self.assertEqual(self.select("game/state/orphan.gd").words(), [])

    def test_a_hash_inside_a_string_does_not_hide_the_rest_of_the_line(self):
        self.assertEqual(self.select("game/state/hashed.gd").words(), ["tests/test_hash.gd"])

    def test_a_shader_comment_is_no_dependency(self):
        self.assertEqual(self.select("game/scenes/note.gdshader").words(), ["tests/test_note.gd"])
        self.assertNotIn("tests/test_note.gd", self.select("game/state/hashed.gd").tests)

    def test_a_scene_reads_a_data_file(self):
        self.assertEqual(self.select("data/hud.cfg").words(), ["tests/test_hud.gd"])

    def test_a_shader_is_reached_through_the_load_path(self):
        self.assertEqual(self.select("game/scenes/glow.gdshader").words(), ["tests/test_glow.gd"])

    def test_a_percent_path_reads_every_file_it_may_name(self):
        self.assertEqual(self.select("data/sheets/a.cfg").words(), ["tests/test_sheet_loader.gd"])

    def test_a_folder_path_reads_every_file_below_it(self):
        self.assertEqual(self.select("maps/other/hall.tmx").words(), ["tests/test_map_loader.gd"])

    def test_a_map_named_in_a_data_file_runs_the_tests_of_that_data_files_readers(self):
        self.assertEqual(self.select("maps/interiors/den.tmx").words(), ["tests/test_rooms.gd"])

    def test_a_shader_include_is_a_dependency_and_its_comments_are_not(self):
        self.assertEqual(self.select("game/scenes/hash.gdshaderinc").words(), ["tests/test_sway.gd"])

    def test_a_resource_chain_is_followed(self):
        self.assertEqual(self.select("game/scenes/tint.gdshader").words(), ["tests/test_theme.gd"])

    def test_a_path_relative_to_the_file_is_a_dependency(self):
        self.assertEqual(self.select("game/state/base_rel.gd").words(), ["tests/test_child_rel.gd"])

    def test_a_picture_packed_into_an_atlas_runs_the_atlas_tests(self):
        for path in ["art/hand/objects/oak_32x32.png", "art/generated/objects/oak_32x32.png"]:
            with self.subTest(path=path):
                self.assertIn("tests/test_object_atlas.gd", self.select(path).tests)

    def test_a_generator_input_that_is_no_python_needs_make_art(self):
        self.assertEqual(self.select("tools/music/pieces/morning.txt").words(), ["tools", "art"])

    def test_a_generator_input_named_like_a_test_still_needs_make_art(self):
        self.assertEqual(self.select("tools/music/pieces/test_reel.txt").words(), ["tools", "art"])

    def test_a_resource_under_data_is_in_the_chain(self):
        self.assertEqual(self.select("game/scenes/skin.gdshader").words(), ["tests/test_skin.gd"])
        self.assertEqual(self.select("data/skin.tres").words(), ["tests/test_skin.gd"])

    def test_a_full_plan_keeps_the_art_check(self):
        self.assertEqual(self.select("Makefile", "art/generated/crops/turnip_32x32.png").words(), ["full", "art"])

    def test_a_generated_picture_nothing_reads_runs_everything_and_make_art(self):
        (self.root / "game/scenes/art_set.gd").unlink()
        self.assertEqual(self.select("art/generated/lonely_32x32.png").words(), ["full", "art"])

    def test_a_picture_runs_the_asset_tests_only(self):
        plan = self.select("art/generated/crops/turnip_32x32.png")
        # The tests of the reader and of the loader of all art, not of what uses the reader.
        self.assertEqual(plan.words(), ["art", "tests/test_art_loader.gd", "tests/test_art_set.gd"])

    def test_a_top_level_picture_is_read_by_the_loader_of_all_art(self):
        self.assertEqual(self.select("art/generated/lonely_32x32.png").words(), ["art", "tests/test_art_set.gd"])

    def test_a_tool_file_a_test_reads_runs_that_test_too(self):
        plan = self.select("tools/art/palette.py")
        self.assertEqual(plan.words(), ["tools", "art", "tests/test_palette.gd"])

    def test_a_script_no_test_reaches_selects_nothing(self):
        self.assertEqual(self.select("game/state/lonely.gd").words(), [])

    def test_a_changed_test_runs_itself(self):
        self.assertEqual(self.select("tests/test_unrelated.gd").words(), ["tests/test_unrelated.gd"])

    def test_a_changed_test_helper_runs_its_users(self):
        self.assertEqual(self.select("tests/case_base.gd").words(), ["tests/test_bar_through_class_name.gd"])

    def test_an_unknown_path_runs_everything(self):
        for path in ["project.godot", "Makefile", "addons/gut/plugin.cfg", "tools/run_tests.py", "new_folder/x.bin"]:
            with self.subTest(path=path):
                self.assertEqual(self.select(path).words(), ["full"])

    def test_a_deleted_script_runs_everything_and_a_deleted_test_nothing(self):
        self.assertEqual(self.select(deleted=["game/state/old.gd"]).words(), ["full"])
        self.assertEqual(self.select(deleted=["tests/test_old.gd"]).words(), [])


class BranchRangeTest(unittest.TestCase):
    """The range BASE..HEAD, on a real repo: main, and a branch off it."""

    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.root = Path(folder.name)
        write_files(self.root, GAME)
        self.git("init", "-q", "-b", "main")
        self.commit("start")
        self.git("checkout", "-q", "-b", "feature")

    def git(self, *args):
        subprocess.run(
            ["git", "-c", "user.name=t", "-c", "user.email=t@t", *args], cwd=self.root, check=True, capture_output=True
        )

    def commit(self, message):
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message)

    def planned_words(self):
        changed, deleted = select_tests.changed_files(self.root, "main")
        base_class_names = select_tests.class_names_at(self.root, select_tests.fork_point(self.root, "main"), changed)
        return select_tests.select(self.root, changed, deleted, base_class_names).words()

    def test_a_docs_only_tip_still_selects_the_tests_of_the_earlier_commits(self):
        write_files(self.root, {"game/state/lonely.gd": "class_name Lonely\n# 2\n", "tests/test_foo.gd": "# 2\n"})
        self.commit("code")
        write_files(self.root, {"README.md": "more\n"})
        self.commit("docs")
        self.assertEqual(self.planned_words(), ["tests/test_foo.gd"])

    def test_a_branch_of_docs_only_selects_nothing(self):
        write_files(self.root, {"README.md": "more\n"})
        self.commit("docs")
        self.assertEqual(self.planned_words(), [])

    def test_uncommitted_and_new_files_count(self):
        write_files(self.root, {"tests/test_unrelated.gd": "# edited, not committed\n"})
        self.assertEqual(self.planned_words(), ["tests/test_unrelated.gd"])
        write_files(self.root, {"tests/test_new.gd": "extends GutTest\n"})
        self.assertEqual(self.planned_words(), ["tests/test_new.gd", "tests/test_unrelated.gd"])

    def test_a_renamed_class_runs_everything(self):
        write_files(self.root, {"game/state/foo.gd": "class_name FooRenamed\n"})
        self.commit("rename")
        self.assertEqual(self.planned_words(), ["full"])

    def test_a_removed_class_runs_everything(self):
        write_files(self.root, {"game/state/foo.gd": "var x := 1\n"})
        self.commit("remove the class")
        self.assertEqual(self.planned_words(), ["full"])

    def test_a_file_deleted_on_the_branch_is_followed(self):
        (self.root / "game/state/foo.gd").unlink()
        self.commit("remove")
        self.assertEqual(self.planned_words(), ["full"])


if __name__ == "__main__":
    unittest.main()
