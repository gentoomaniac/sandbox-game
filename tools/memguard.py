#!/usr/bin/env python3
"""Keeps a command from taking the machine's memory: a watchdog and a lock for test runs.

Usage: memguard.py [--proc-mem-mb N] [--floor-mb N] [--lock] -- COMMAND...

Runs COMMAND and, every 0.5 s, looks at it and all its child processes. It kills them all when the
machine's available memory (MemAvailable plus half the ZFS cache that gives way, see
arc_reclaimable_mb) drops below the floor or one process's RSS goes above the limit, and then
exits with status 1 and one line that says what it killed and why. Otherwise it exits with the
status of COMMAND. `make` runs the Godot import and the screenshot through it, and tools/run_tests.py
uses the same Guarded class for its shards (see docs/development.md, "Memory guard").

Three more protections, because one OOM kill of Godot has taken the editor down with it:
- The command runs in its own systemd user scope when `systemd-run --user` works (systemd stops
  the whole unit of a killed process, and a Godot started from the editor's terminal otherwise
  shares the editor's unit).
- Its processes get oom_score_adj 1000, so the kernel picks them before anything else.
- --lock (and test_run_lock) lets one full test run at a time go, machine-wide.

Knobs: TEST_MEM_FLOOR_MB (default 3000), TEST_PROC_MEM_MB (default 5000; the import raises it).
"""

import argparse
import contextlib
import fcntl
import functools
import os
import subprocess
import sys
import time
from pathlib import Path

POLL_SECONDS = 0.5
PAGE_MB = os.sysconf("SC_PAGE_SIZE") / 2**20
LOCK_PATH = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "sandbox-game-test.lock"
SLICE = "sandbox-tests.slice"
# A shard of the test suite peaked at 3.4 GB in a full run on 5 shards, so 5 GB is margin and still
# far from the 12-17 GB runaways that were measured.
DEFAULT_PROC_MEM_MB = 5000
DEFAULT_FLOOR_MB = 3000
ARCSTATS = Path("/proc/spl/kstat/zfs/arcstats")
# The share of the ZFS cache above its minimum that counts as free (see arc_reclaimable_mb).
ARC_SHARE = 0.5


def default_floor_mb():
    return int(os.environ.get("TEST_MEM_FLOOR_MB", DEFAULT_FLOOR_MB))


def default_proc_mem_mb():
    return int(os.environ.get("TEST_PROC_MEM_MB", DEFAULT_PROC_MEM_MB))


def mem_available_mb(meminfo=Path("/proc/meminfo"), arcstats=ARCSTATS):
    """MemAvailable plus the ZFS cache the kernel can take back (see `arc_reclaimable_mb`)."""
    for line in meminfo.read_text().splitlines():
        if line.startswith("MemAvailable:"):
            return int(line.split()[1]) / 1024 + arc_reclaimable_mb(arcstats)
    raise RuntimeError("no MemAvailable in /proc/meminfo")


def arc_reclaimable_mb(arcstats=ARCSTATS):
    """How much of the ZFS cache (the ARC) counts as free: half its size above its minimum.

    MemAvailable does not count the ARC, which can hold 11-15 GB on this machine and shrinks to
    `c_min` when programs need the memory, so without this the floor stops runs on a machine that
    has room. Only half counts: the ARC gives memory back lazily, and part of it is pinned, so a
    burst of shards starting at once could outrun it. 0 without ZFS.
    """
    try:
        lines = arcstats.read_text().splitlines()
    except OSError:
        return 0
    values = {}
    for line in lines:
        fields = line.split()
        if len(fields) == 3 and fields[0] in ("size", "c_min"):
            values[fields[0]] = int(fields[2])
    if len(values) < 2:
        return 0
    return ARC_SHARE * max(values["size"] - values["c_min"], 0) / 2**20


def process_table():
    """{pid: (parent pid, RSS in MB)} of every process that can be read."""
    table = {}
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            # The command name in stat is in parentheses and may hold spaces: split after the last ")".
            after_name = (entry / "stat").read_text().rsplit(")", 1)[1].split()
            rss_pages = int((entry / "statm").read_text().split()[1])
        except (OSError, IndexError, ValueError):
            continue  # the process ended while we looked
        table[int(entry.name)] = (int(after_name[1]), rss_pages * PAGE_MB)
    return table


def tree_of(root_pid, table):
    """root_pid and all its descendants (they may have left its process group, as `timeout` does)."""
    children = {}
    for pid, (parent, _) in table.items():
        children.setdefault(parent, []).append(pid)
    found, todo = [], [root_pid]
    while todo:
        pid = todo.pop()
        found.append(pid)
        todo += children.get(pid, [])
    return found


def command_line(pid):
    try:
        return Path(f"/proc/{pid}/cmdline").read_bytes().replace(b"\0", b" ").decode(errors="replace").strip()
    except OSError:
        return f"pid {pid}"


def scope_prefix(rss_limit_mb):
    """The systemd-run words that put a command into its own scope."""
    # MemoryMax is the backstop for growth between two polls; a scope kill by the kernel shows only
    # as status -9. A little swap is allowed so a moment's peak does not kill a run, a runaway is
    # still stopped.
    return ["systemd-run", "--user", "--scope", "--quiet", "--collect", f"--slice={SLICE}",
            "-p", f"MemoryMax={int(rss_limit_mb * 1.25)}M", "-p", "MemorySwapMax=2G"]  # fmt: skip


@functools.cache
def systemd_scope_works():
    """Whether systemd-run starts a command in a scope with the options we use; checked once per process."""
    try:
        probe = [*scope_prefix(DEFAULT_PROC_MEM_MB), "true"]
        return subprocess.run(probe, capture_output=True, timeout=10).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def make_most_killable():
    """Runs in the child before exec: the kernel's OOM killer takes it before anything else."""
    with open("/proc/self/oom_score_adj", "w") as adj:
        adj.write("1000")


class Guarded:
    """A command under watch. check() looks at it once; the caller polls it every POLL_SECONDS."""

    def __init__(self, command, rss_limit_mb, floor_mb, **popen_kwargs):
        self.rss_limit_mb = rss_limit_mb
        self.floor_mb = floor_mb
        self.killed_because = None
        if systemd_scope_works():
            command = [*scope_prefix(rss_limit_mb), *command]
        self.process = subprocess.Popen(command, start_new_session=True, preexec_fn=make_most_killable, **popen_kwargs)

    def check(self, table=None, available_mb=None):
        """Kills the whole tree if it is over a limit; returns the reason then, else None.

        table and available_mb are what process_table() and mem_available_mb() say now, to be read
        once for several guards."""
        if self.process.poll() is not None or self.killed_because:
            return self.killed_because
        table = table or process_table()
        available = mem_available_mb() if available_mb is None else available_mb
        pids = tree_of(self.process.pid, table)
        biggest = max((pid for pid in pids if pid in table), key=lambda pid: table[pid][1], default=None)
        if available < self.floor_mb:
            self.kill(pids, f"the machine has only {available:.0f} MB available (floor {self.floor_mb} MB)")
        elif biggest and table[biggest][1] > self.rss_limit_mb:
            self.kill(pids, f"`{command_line(biggest)[:120]}` (pid {biggest}) uses {table[biggest][1]:.0f} MB, "
                            f"over the limit of {self.rss_limit_mb} MB")  # fmt: skip
        return self.killed_because

    def kill(self, pids=None, reason="stopped"):
        if pids is None:
            pids = tree_of(self.process.pid, process_table())
        self.killed_because = self.killed_because or reason
        for pid in pids:
            with contextlib.suppress(OSError):
                os.kill(pid, 9)
        with contextlib.suppress(OSError):
            os.killpg(self.process.pid, 9)

    def wait(self):
        return self.process.wait()


def check_all(guardeds):
    """One poll of several guards of one run. All of them read the same memory figure, so the machine
    running short of memory stops every one of them, not just the first to look."""
    table = process_table()
    available = mem_available_mb()
    for guarded in guardeds:
        guarded.check(table, available)


@contextlib.contextmanager
def test_run_lock(path=LOCK_PATH):
    """One holder at a time on this machine; the others wait and say so once.

    A plain flock(1) on the same path takes part too.
    """
    with open(path, "a") as lock_file:
        try:
            fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print(f"memguard: another test run holds {path}; waiting for it", file=sys.stderr, flush=True)
            fcntl.flock(lock_file, fcntl.LOCK_EX)
        yield


def run(command, rss_limit_mb, floor_mb):
    """Runs command under watch; returns (exit status, reason it was killed or None)."""
    guarded = Guarded(command, rss_limit_mb, floor_mb)
    try:
        while guarded.process.poll() is None:
            guarded.check()
            time.sleep(POLL_SECONDS)
    finally:
        # Ctrl-C or an error must not leave the command's processes behind.
        if guarded.process.poll() is None:
            guarded.kill()
    status = guarded.wait()
    return (128 - status if status < 0 else status), guarded.killed_because


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--proc-mem-mb", type=int, default=default_proc_mem_mb())
    parser.add_argument("--floor-mb", type=int, default=default_floor_mb())
    parser.add_argument("--lock", action="store_true", help="wait for the machine-wide test lock first")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("no command given")
    with test_run_lock() if args.lock else contextlib.nullcontext():
        status, killed_because = run(command, args.proc_mem_mb, args.floor_mb)
    if killed_because:
        print(f"memguard: killed `{' '.join(command)[:100]}`: {killed_because}", file=sys.stderr)
        return 1
    return status


if __name__ == "__main__":
    sys.exit(main())
