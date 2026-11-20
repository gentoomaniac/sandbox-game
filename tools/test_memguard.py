"""Tests of memguard.py: the watchdog kills what grows too far, and full test runs take turns."""

import io
import sys
import tempfile
import threading
import time
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest import mock

import memguard

# Grows by 20 MB every 50 ms, up to a large size, so only a guard stops it.
GROWER = "import time\nchunks = []\nwhile len(chunks) < 400:\n    chunks.append(bytearray(20 * 2**20))\n    time.sleep(0.05)\n"
SLEEPER = "import time; time.sleep(30)"
PLENTY = 10**9  # MB: a limit nothing reaches


class WatchdogTest(unittest.TestCase):
    def setUp(self):
        # The scope's own MemoryMax could stop the grower before the watchdog does; that is the
        # backstop, and not what is tested here.
        patcher = mock.patch.object(memguard, "systemd_scope_works", return_value=False)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_kills_a_process_over_its_rss_limit_and_says_which(self):
        status, reason = memguard.run([sys.executable, "-c", GROWER], rss_limit_mb=200, floor_mb=0)
        self.assertEqual(status, 137)
        self.assertIn("over the limit of 200 MB", reason)
        # The command line is cut at 120 characters, so a long repo path can hide its "-c".
        self.assertRegex(reason, r"\(pid \d+\) uses \d+ MB")

    def test_kills_the_children_of_the_command_too(self):
        spawner = f"import subprocess, sys; subprocess.run([sys.executable, '-c', {GROWER!r}])"
        status, reason = memguard.run([sys.executable, "-c", spawner], rss_limit_mb=200, floor_mb=0)
        self.assertIn("over the limit of 200 MB", reason)

    def test_kills_when_the_machine_runs_short_of_memory(self):
        with mock.patch.object(memguard, "mem_available_mb", return_value=500):
            status, reason = memguard.run([sys.executable, "-c", SLEEPER], rss_limit_mb=PLENTY, floor_mb=1000)
        self.assertEqual(status, 137)
        self.assertIn("only 500 MB available (floor 1000 MB)", reason)

    def test_the_floor_stops_every_guard_of_a_run(self):
        guards = [memguard.Guarded([sys.executable, "-c", SLEEPER], PLENTY, 1000) for _ in range(3)]
        self.addCleanup(lambda: [g.kill() for g in guards])
        with mock.patch.object(memguard, "mem_available_mb", return_value=500):
            memguard.check_all(guards)
        for guarded in guards:
            guarded.wait()
        for guarded in guards:
            self.assertIn("only 500 MB available", guarded.killed_because)

    def test_the_probe_of_the_scope_uses_the_options_of_the_real_run(self):
        self.assertIn("MemorySwapMax=2G", memguard.scope_prefix(1000))
        self.assertIn(f"--slice={memguard.SLICE}", memguard.scope_prefix(1000))

    def test_leaves_a_command_within_its_limits_alone(self):
        status, reason = memguard.run([sys.executable, "-c", "raise SystemExit(3)"], rss_limit_mb=PLENTY, floor_mb=0)
        self.assertEqual((status, reason), (3, None))

    def test_the_command_line_exits_non_zero_with_one_line(self):
        argv = ["memguard", "--floor-mb=2", "--", sys.executable, "-c", SLEEPER]
        stderr = io.StringIO()
        with mock.patch("sys.argv", argv), mock.patch.object(memguard, "mem_available_mb", return_value=1):
            with redirect_stderr(stderr):
                self.assertEqual(memguard.main(), 1)
        lines = stderr.getvalue().splitlines()
        self.assertEqual(len(lines), 1)
        self.assertIn("memguard: killed", lines[0])

    def test_runs_the_command_in_a_scope_where_systemd_allows_it(self):
        with mock.patch.object(memguard, "systemd_scope_works", return_value=True):
            guarded = memguard.Guarded(["true"], 1000, 0)
            guarded.wait()
        self.assertEqual(guarded.process.args[:3], ["systemd-run", "--user", "--scope"])


class TestRunLockTest(unittest.TestCase):
    def test_two_runs_take_turns(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "lock"
            events = []

            def second_run():
                with memguard.test_run_lock(path):
                    events.append("second in")

            with memguard.test_run_lock(path):
                events.append("first in")
                waiter = threading.Thread(target=second_run)
                with redirect_stderr(io.StringIO()):
                    waiter.start()
                    time.sleep(0.3)
                self.assertEqual(events, ["first in"])  # the second one waits
                events.append("first out")
            waiter.join(5)
        self.assertEqual(events, ["first in", "first out", "second in"])


class AvailableMemoryTest(unittest.TestCase):
    MEMINFO = "MemTotal:       32559104 kB\nMemAvailable:    3145728 kB\n"

    @staticmethod
    def arcstats(size_mb, c_min_mb):
        return "".join(
            [
                "13 1 0x01 123 33456 1 2\n",
                "name                            type data\n",
                f"c_min                           4    {c_min_mb * 2**20}\n",
                f"size                            4    {size_mb * 2**20}\n",
            ]
        )

    def available_mb(self, arcstats):
        with tempfile.TemporaryDirectory() as folder:
            meminfo = Path(folder) / "meminfo"
            meminfo.write_text(self.MEMINFO)
            stats = Path(folder) / "arcstats"
            if arcstats is not None:
                stats.write_text(arcstats)
            return memguard.mem_available_mb(meminfo, stats)

    def test_half_the_zfs_cache_above_its_minimum_counts_as_available(self):
        self.assertEqual(self.available_mb(self.arcstats(12 * 1024, 1024)), 3072 + 11 * 512)

    def test_without_zfs_it_is_mem_available(self):
        self.assertEqual(self.available_mb(None), 3072)

    def test_a_cache_at_its_minimum_adds_nothing(self):
        self.assertEqual(self.available_mb(self.arcstats(512, 1024)), 3072)

    def test_arcstats_without_size_or_c_min_adds_nothing(self):
        self.assertEqual(self.available_mb("name type data\nhits 4 12\n"), 3072)


if __name__ == "__main__":
    unittest.main()
