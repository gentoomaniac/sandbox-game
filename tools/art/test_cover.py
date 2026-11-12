"""Tests of cover.py (`make test` runs them): the textures of the seasonal overlays."""

import unittest

import numpy as np
from PIL import Image

import cover
import palette
import seasons


class GroundNoiseTest(unittest.TestCase):
    def test_every_channel_is_spread_evenly(self):
        noise = np.array(cover.ground_noise(16))
        for channel in range(3):
            share_below_a_third = (noise[:, :, channel] < 255 / 3).mean()
            self.assertAlmostEqual(share_below_a_third, 1 / 3, delta=0.02)

    def test_the_channels_differ_and_the_texture_is_opaque(self):
        noise = np.array(cover.ground_noise(16))
        self.assertTrue((noise[:, :, 3] == 255).all())
        self.assertLess((noise[:, :, 0] == noise[:, :, 1]).mean(), 0.1)

    def test_it_repeats_without_a_seam(self):
        # Neighbouring pixels differ by the grain, but not across the edge more than inside.
        red = np.array(cover.ground_noise(16), dtype=int)[:, :, 0]
        for axis in (0, 1):
            inside = np.abs(np.diff(red, axis=axis)).mean()
            across = np.abs(np.take(red, 0, axis=axis) - np.take(red, -1, axis=axis)).mean()
            self.assertLess(across, inside * 1.5, f"axis {axis}")


class LeafLitterTest(unittest.TestCase):
    def test_the_leaves_are_palette_colours_with_a_rank(self):
        picture = cover.leaf_litter(32)
        self.assertEqual(picture.width, cover.LEAF_TILES * 32)
        allowed = {bytes.fromhex(colour) for colour in palette.PALETTE.values()}
        pixels = np.array(picture).reshape(-1, 4)
        drawn = pixels[pixels[:, 3] > 0]
        self.assertGreater(len(drawn), 0)
        self.assertTrue(all(bytes(colour[:3]) in allowed for colour in drawn))

    def test_it_is_a_light_scatter(self):
        for tile_size in (32, 16):
            alpha = np.array(cover.leaf_litter(tile_size))[:, :, 3]
            self.assertTrue(0.02 < (alpha > 0).mean() < 0.12, tile_size)

    def test_it_is_the_same_every_time(self):
        self.assertEqual(cover.leaf_litter(16).tobytes(), cover.leaf_litter(16).tobytes())


class ObjectCoverTest(unittest.TestCase):
    def test_a_cover_cell_holds_only_what_the_look_adds(self):
        base = [["green", None], ["green", "green"]]
        snowy = [["snow", None], ["green", "snow"]]
        self.assertEqual(cover.cover_cells(snowy, base), [["snow", None], [None, "snow"]])

    def test_the_cover_is_what_snow_and_frost_add_to_the_bare_picture(self):
        summer = [[[["green", "green"]]]]
        looks = {look: summer for look in ("summer", "bare")}
        looks["snow"] = [[[["snow", "green"]]]]
        looks["frost"] = [[[["green", "green"]]]]
        covered = cover.object_cover_looks(looks)
        self.assertEqual(covered["snow_cover"], [[[["snow", None]]]])
        self.assertEqual(covered["frost_cover"], [[[[None, None]]]])

    def test_the_cover_looks_are_no_season_looks(self):
        self.assertEqual(cover.COVER_LOOKS, ("snow_cover", "frost_cover"))
        self.assertFalse(set(cover.COVER_LOOKS) & set(seasons.LOOKS))


class RankedTest(unittest.TestCase):
    def sheet(self):
        image = Image.new("RGBA", (4, 8), (0, 0, 0, 0))
        for y in range(2, 8):
            for x in range(4):
                image.putpixel((x, y), (255, 255, 255, 255))
        return image

    def test_snow_is_ranked_from_the_top_down(self):
        ranked = np.array(cover.ranked(self.sheet(), 4, 8, True))[:, :, 3].astype(int)
        self.assertTrue((ranked[:2] == 0).all(), "clear pixels stay clear")
        self.assertTrue((ranked[2:] >= 1).all())
        self.assertLess(ranked[2].mean() + 20, ranked[7].mean())

    def test_frost_is_ranked_by_noise_alone(self):
        ranked = np.array(cover.ranked(self.sheet(), 4, 8, False))[:, :, 3].astype(int)
        self.assertLess(abs(ranked[2].mean() - ranked[7].mean()), 120)

    def test_the_ranks_are_the_same_every_time_and_a_cell_does_not_depend_on_the_others(self):
        first = cover.ranked(self.sheet(), 4, 8, False)
        self.assertEqual(first.tobytes(), cover.ranked(self.sheet(), 4, 8, False).tobytes())
        wide = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        wide.paste(self.sheet(), (0, 0))
        self.assertEqual(cover.ranked(wide, 4, 8, False).crop((0, 0, 4, 8)).tobytes(), first.tobytes())

    def test_colours_are_kept(self):
        ranked = np.array(cover.ranked(self.sheet(), 4, 8, True))
        self.assertTrue((ranked[2:, :, :3] == 255).all())


if __name__ == "__main__":
    unittest.main()
