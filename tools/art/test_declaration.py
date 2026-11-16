"""Tests of the art declaration (declaration.py; `make test` runs them): a name that two sources
draw is refused naming both, and the pictures come out in the declared order or not at all."""

import unittest

import declaration


class MergeTest(unittest.TestCase):
    def test_the_sources_are_merged_in_order(self):
        merged = declaration.merge({"a.py": {"x": 1}, "b.py": {"y": 2, "z": 3}})
        self.assertEqual(list(merged.items()), [("x", 1), ("y", 2), ("z", 3)])

    def test_a_name_drawn_twice_is_refused_naming_both_sources(self):
        with self.assertRaises(declaration.DuplicateContribution) as error:
            declaration.merge({"a.py": {"x": 1}, "b.py": {"y": 2}, "c.py": {"x": 3}})
        self.assertIn("'x'", str(error.exception))
        self.assertIn("a.py", str(error.exception))
        self.assertIn("c.py", str(error.exception))


class InDeclaredOrderTest(unittest.TestCase):
    def test_the_pictures_follow_the_declaration(self):
        self.assertEqual(declaration.in_declared_order(("b", "a"), {"a": 1, "b": 2}, "test"), [("b", 2), ("a", 1)])

    def test_a_declared_name_that_is_not_drawn_is_refused(self):
        with self.assertRaisesRegex(ValueError, r"declared but not drawn: \['b'\]"):
            declaration.in_declared_order(("a", "b"), {"a": 1}, "test")

    def test_a_drawn_name_that_is_not_declared_is_refused(self):
        with self.assertRaisesRegex(ValueError, r"drawn but not declared: \['b'\]"):
            declaration.in_declared_order(("a",), {"a": 1, "b": 2}, "test")


class DeclaredNamesTest(unittest.TestCase):
    def test_every_object_kind_is_declared_once(self):
        self.assertEqual(len(declaration.OBJECT_KINDS), len(set(declaration.OBJECT_KINDS)))

    def test_every_piece_of_furniture_is_declared_once(self):
        self.assertEqual(len(declaration.FURNITURE), len(set(declaration.FURNITURE)))
