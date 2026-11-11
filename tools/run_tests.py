#!/usr/bin/env python3
"""Runs the GUT tests of tests/ in parallel: one headless Godot process per shard.

Usage: run_tests.py JOBS [FILE...]   (called by `make test` and `make test-changed`, which import the
project first)

Without files every tests/test_*.gd runs; with files (like tests/test_x.gd) only those do.

The test files are spread over the shards by their duration in the last run
(build/test-times), or by their size when a file has no time yet. Each shard has its own
user:// folder (build/user-data-<i>), emptied at the start of a run, so parallel runs never touch
each other's files, no save of an earlier run (another commit's) is found and no test can reach the
real save. build/test.log is the shard logs joined, ending with a summary
in GUT's own words (Passing Tests, Failing Tests, ...), so greps for them keep working.
The exit status is non-zero when any shard or any check fails, or a shard runs longer than
TEST_TIMEOUT seconds (default 600).
"""

import os
import re
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
TIMES = BUILD / "test-times"
GODOT = os.environ.get("GODOT", "godot")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
SUMMARY_LABELS = [
    "Scripts", "Tests", "Passing Tests", "Failing Tests", "Asserts", "Warnings", "Orphans",
]  # fmt: skip
# Seconds a whole run may take before its shards are killed (a hung Godot must not hang make).
TIMEOUT = float(os.environ.get("TEST_TIMEOUT", 600))


def read_times():
    """Seconds per test file (named like tests/test_x.gd) from earlier runs."""
    if not TIMES.exists():
        return {}
    pairs = (line.split("\t") for line in TIMES.read_text().splitlines())
    return {name: float(seconds) for name, seconds in pairs}


def make_shards(files, jobs, times):
    """Longest file first, each into the shard that has the least work so far."""
    # A file without a time is guessed from its size, in the unit of the files that have one.
    timed_size = sum((ROOT / f).stat().st_size for f in files if f in times)
    seconds_per_byte = sum(times[f] for f in files if f in times) / timed_size if timed_size else 1.0
    cost = {f: times.get(f, (ROOT / f).stat().st_size * seconds_per_byte) for f in files}
    shards = [[] for _ in range(jobs)]
    loads = [0.0] * jobs
    for f in sorted(files, key=lambda f: -cost[f]):
        i = loads.index(min(loads))
        shards[i].append(f)
        loads[i] += cost[f]
    return [shard for shard in shards if shard]


def start_shard(i, shard):
    user_data = BUILD / f"user-data-{i}"
    # Nothing of an earlier run stays: a save left by the tests of another commit (a newer version)
    # is refused by the game that a test starts, which then waits for an answer for good.
    shutil.rmtree(user_data, ignore_errors=True)
    user_data.mkdir(parents=True)
    command = [
        GODOT, "--headless", "--path", str(ROOT), "-s", "addons/gut/gut_cmdln.gd",
        "-gtest=" + ",".join(f"res://{f}" for f in shard),
        "-gexit", f"-gjunit_xml_file={BUILD / f'test-{i}.xml'}",
    ]  # fmt: skip
    env = {**os.environ, "XDG_DATA_HOME": str(user_data)}
    with (BUILD / f"test-{i}.log").open("w") as log:
        return subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=env, cwd=ROOT)


def count(text, label):
    """A number of GUT's summary; GUT leaves a count out when it is 0."""
    found = re.findall(rf"^{label} +(\d+)$", text, re.MULTILINE)
    return int(found[-1]) if found else 0


def main():
    jobs = int(sys.argv[1])
    started = time.monotonic()
    all_files = sorted(str(f.relative_to(ROOT)) for f in (ROOT / "tests").glob("test_*.gd"))
    files = sorted(set(sys.argv[2:])) or all_files
    unknown = [f for f in files if f not in all_files]
    if jobs < 1 or not files or unknown:
        sys.exit(f"make test: needs TEST_JOBS >= 1 and test files (jobs {jobs}, {len(files)} files, unknown {unknown})")
    # Output of an earlier run must never stand in for a shard that died before writing its own.
    for stale in [*BUILD.glob("test-*.xml"), *BUILD.glob("test-*.log")]:
        stale.unlink()
    times = read_times()
    shards = make_shards(files, jobs, times)
    problems = []
    processes = []
    try:
        processes = [start_shard(i, shard) for i, shard in enumerate(shards)]
        statuses = []
        for i, process in enumerate(processes):
            try:
                statuses.append(process.wait(max(0.0, started + TIMEOUT - time.monotonic())))
            except subprocess.TimeoutExpired:
                process.kill()
                statuses.append(process.wait())
                problems.append(f"shard {i}: timed out after {TIMEOUT:.0f} s")
    finally:
        # Ctrl-C, a signal or an error must not leave Godot processes behind.
        for process in processes:
            if process.poll() is None:
                process.kill()
                process.wait()

    totals = dict.fromkeys(SUMMARY_LABELS, 0)
    failed = []
    combined = []
    for i, (shard, status) in enumerate(zip(shards, statuses)):
        text = ANSI.sub("", (BUILD / f"test-{i}.log").read_text(errors="replace"))
        combined.append(f"===== shard {i}: {len(shard)} files =====\n{text}")
        for label in totals:
            totals[label] += count(text, label)
        # A broken script must fail the run, never just drop its tests: one that doesn't load (a
        # parse error), and a test file GUT skips because it doesn't extend GutTest.
        not_loaded = set(re.findall(r'Failed to load script "res://((?:game|tests)/[^"]+)"', text))
        for path in sorted(not_loaded):
            problems.append(f"shard {i}: {path} failed to load (see build/test-{i}.log)")
        skipped = set(re.findall(r"Ignoring script res://(tests/\S+) because", text))
        for path in sorted(skipped - not_loaded):
            problems.append(f"shard {i}: {path} was skipped: it does not extend GutTest")
        if count(text, "Tests") == 0:
            problems.append(f"shard {i}: GUT ran no tests")
        if "leaked at exit" in text:
            problems.append(f"shard {i}: leaked at exit")
        # Failing tests make GUT exit non-zero too; they are reported below, from the junit file.
        if status != 0 and count(text, "Failing Tests") == 0:
            problems.append(f"shard {i}: Godot exited with status {status}")
        xml = BUILD / f"test-{i}.xml"
        if xml.exists():
            for suite in ET.parse(xml).getroot().iter("testsuite"):
                times[suite.get("name")] = float(suite.get("time", 0))
                for case in suite.iter("testcase"):
                    if case.get("status") == "fail":
                        failed.append(f"{suite.get('name')}: {case.get('name')}")
    TIMES.write_text("".join(f"{name}\t{seconds}\n" for name, seconds in sorted(times.items()) if name in all_files))

    summary = ["", "Totals", "------"]
    summary += [f"{label:<18}{n}" for label, n in totals.items() if n or label == "Tests"]
    summary.append(f"{'Time':<18}{time.monotonic() - started:.3f}s ({len(shards)} shards)")
    summary += [f"[Failed] {line}" for line in failed]
    if totals["Failing Tests"] == 0 and not problems:
        summary.append("---- All tests passed! ----")
    summary += [f"make test: {problem}" for problem in problems]
    summary.append(f"make test: {totals['Warnings']} warnings, {totals['Orphans']} orphans")
    (BUILD / "test.log").write_text("\n".join(combined + summary) + "\n")
    print("\n".join(summary))
    # Any non-zero Godot status fails the run, even if the log shows no problem.
    return 1 if problems or any(statuses) else 0


if __name__ == "__main__":
    sys.exit(main())
