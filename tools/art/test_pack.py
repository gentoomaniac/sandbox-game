"""Tests of pack.py (`make test` runs them): the atlases packed from sheets, and the hand-drawn art
laid over the generated art. They build a tiny art/ tree in a temporary folder."""

import tempfile
import unittest
from io import BytesIO
from pathlib import Path
from unittest import mock

from PIL import Image

import pack
from palette import PALETTE

FIRST_COLOUR = (*bytes.fromhex(next(iter(PALETTE.values()))), 255)
SECOND_COLOUR = (*bytes.fromhex(list(PALETTE.values())[1]), 255)
NOT_IN_PALETTE = (1, 2, 3, 255)
CELL = 2


def pixel(content):
    """The top left pixel of an output, a picture or the bytes of a PNG file."""
    image = Image.open(BytesIO(content)) if isinstance(content, bytes) else content
    return image.convert("RGBA").getpixel((0, 0))


def solid(width, height, colour):
    return Image.new("RGBA", (width, height), colour)


class PackTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.generated, self.hand, self.assets = root / "generated", root / "hand", root / "assets"
        for name, folder in (("GENERATED", self.generated), ("HAND", self.hand), ("ASSETS", self.assets), ("ROOT", root)):
            patcher = mock.patch.object(pack, name, folder if name != "ROOT" else root)
            patcher.start()
            self.addCleanup(patcher.stop)
        # An atlas of objects with two looks: oak has two variants, stone one.
        self.write_text("objects/atlas.txt", "cell 2 2\nlooks spring summer\noak 2\nstone 1\n")
        self.write_text("cell_sizes.txt", "objects/oak.png 2 2\nobjects/stone.png 2 2\n")
        self.save(solid(2 * CELL, 2 * CELL, FIRST_COLOUR), self.generated / "objects/oak.png")
        self.save(solid(CELL, 2 * CELL, FIRST_COLOUR), self.generated / "objects/stone.png")
        self.save(solid(CELL, CELL, FIRST_COLOUR), self.generated / "items/axe.png")
        self.save(solid(CELL, CELL, FIRST_COLOUR), self.generated / "classic/items/axe.png")
        (self.generated / "sounds").mkdir()
        (self.generated / "sounds/chop_1.wav").write_bytes(b"generated sound")

    def write_text(self, relative, text):
        path = self.generated / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def save(self, image, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path)

    def build(self):
        sources = pack.Sources()
        return sources, pack.build_outputs(sources)

    def test_packs_one_atlas_per_look_with_a_row_per_entity(self):
        _, outputs = self.build()
        summer = outputs["objects.png"]
        spring = outputs["objects_spring.png"]
        self.assertEqual(summer.size, (2 * CELL, 2 * CELL))
        self.assertEqual(spring.getpixel((0, 0)), FIRST_COLOUR)
        self.assertEqual(outputs["objects_rows.txt"], b"0 oak 2\n1 stone 1\n")

    def test_a_missing_atlas_manifest_says_what_to_do(self):
        (self.generated / "objects/atlas.txt").unlink()
        with self.assertRaises(SystemExit) as raised:
            self.build()
        self.assertIn("make art", str(raised.exception))

    def test_a_missing_source_image_names_the_entity(self):
        (self.generated / "objects/stone.png").unlink()
        sources, _ = self.build()
        self.assertEqual(len(sources.errors), 1)
        self.assertIn("objects/stone", sources.errors[0])

    def test_hand_art_replaces_the_cells_it_draws_and_the_rest_stays_generated(self):
        hand = Image.new("RGBA", (2 * CELL, 2 * CELL))
        hand.paste(solid(CELL, CELL, SECOND_COLOUR), (CELL, CELL))
        self.save(hand, self.hand / "objects/oak_32x32.png")
        sources, outputs = self.build()
        summer, spring = outputs["objects.png"], outputs["objects_spring.png"]
        self.assertEqual(sources.errors, [])
        self.assertEqual(summer.getpixel((CELL, 0)), SECOND_COLOUR)
        self.assertEqual(summer.getpixel((0, 0)), FIRST_COLOUR)
        self.assertEqual(spring.getpixel((CELL, 0)), FIRST_COLOUR)
        self.assertEqual(len(sources.used), 1)
        self.assertIn("1 of 4 cells", sources.used[0])

    def test_a_postfix_replaces_only_its_art_set(self):
        self.save(solid(CELL, CELL, SECOND_COLOUR), self.hand / "items/axe_16x16.png")
        sources, outputs = self.build()
        self.assertEqual(sources.errors, [])
        self.assertEqual(pixel(outputs["items/axe.png"]), FIRST_COLOUR)
        self.assertEqual(pixel(outputs["classic/items/axe.png"]), SECOND_COLOUR)

    def test_hand_art_of_another_size_is_an_error(self):
        self.save(solid(CELL + 1, CELL, SECOND_COLOUR), self.hand / "items/axe_32x32.png")
        sources, _ = self.build()
        self.assertEqual(len(sources.errors), 1)
        self.assertIn("size exactly", sources.errors[0])

    def test_a_hand_file_that_replaces_nothing_is_an_error(self):
        self.save(solid(CELL, CELL, FIRST_COLOUR), self.hand / "items/axee_32x32.png")
        self.save(solid(CELL, CELL, FIRST_COLOUR), self.hand / "items/axe.png")
        sources, _ = self.build()
        self.assertEqual(len(sources.errors), 2)
        self.assertTrue(any("matches no generated file" in error for error in sources.errors))
        self.assertTrue(any("neither _32x32.png nor _16x16.png" in error for error in sources.errors))

    def test_hand_art_outside_the_palette_is_only_a_warning(self):
        self.save(solid(CELL, CELL, NOT_IN_PALETTE), self.hand / "items/axe_32x32.png")
        sources, outputs = self.build()
        self.assertEqual(sources.errors, [])
        self.assertEqual(len(sources.warnings), 1)
        self.assertEqual(pixel(outputs["items/axe.png"]), NOT_IN_PALETTE)

    def test_a_hand_sound_replaces_the_generated_one(self):
        (self.hand / "sounds").mkdir(parents=True)
        (self.hand / "sounds/chop_1.wav").write_bytes(b"recorded sound")
        sources, outputs = self.build()
        self.assertEqual(sources.errors, [])
        self.assertEqual(outputs["sounds/chop_1.wav"], b"recorded sound")

    def test_a_readme_in_the_hand_folder_is_no_art(self):
        self.hand.mkdir()
        (self.hand / "README.md").write_text("notes")
        sources, _ = self.build()
        self.assertEqual(sources.errors, [])


if __name__ == "__main__":
    unittest.main()
