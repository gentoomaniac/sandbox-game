"""Tests of what run_tests.py says about a shard that was killed."""

import unittest
from unittest import mock

import memguard

import run_tests

LOG = """\
---  GUT  ---
res://tests/test_bag_key.gd
* test_tab_is_bound_to_no_action
* test_second

res://tests/test_cart.gd
* test_cart_rolls
* test_cart_brakes_while_the_world_is_streaming
"""


class WhereItWasTest(unittest.TestCase):
    def test_names_the_last_file_and_test(self):
        self.assertEqual(
            run_tests.where_it_was(LOG), "tests/test_cart.gd: test_cart_brakes_while_the_world_is_streaming"
        )

    def test_a_file_without_a_test_yet(self):
        self.assertEqual(
            run_tests.where_it_was(LOG + "res://tests/test_x.gd\n"), "tests/test_x.gd, before its first test"
        )

    def test_a_log_without_a_file(self):
        self.assertEqual(run_tests.where_it_was("Godot Engine\n"), "before its first test file")


class AffordableJobsTest(unittest.TestCase):
    def jobs_with(self, available_mb, asked=8):
        with mock.patch.object(memguard, "mem_available_mb", return_value=available_mb):
            return run_tests.affordable_jobs(asked)

    def test_asks_no_more_than_the_free_memory_above_the_floor_carries(self):
        # 3000 MB floor, 3000 MB per shard
        self.assertEqual(self.jobs_with(3000 + 3 * 3000 + 100), 3)

    def test_never_more_than_asked(self):
        self.assertEqual(self.jobs_with(100_000, asked=4), 4)

    def test_at_least_one(self):
        self.assertEqual(self.jobs_with(3100), 1)

    def test_exits_when_the_machine_is_below_the_floor_already(self):
        with self.assertRaisesRegex(SystemExit, "below the floor"):
            self.jobs_with(500)


if __name__ == "__main__":
    unittest.main()
