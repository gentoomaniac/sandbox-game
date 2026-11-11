#!/usr/bin/env python3
"""Picks the tests a branch needs, from the files it changes (`make test-changed`).

Usage: select_tests.py [BASE] [--head REF]

Looks at the whole range BASE..HEAD (default BASE main): every file changed in any commit of the
branch, plus, when the head is HEAD, the uncommitted changes of the worktree. The report (changed
file, reason, tests) goes to stderr. Stdout is the plan, words separated by spaces, for the Makefile:
  full        run `make test`, the selector can't place something (or knows the change is wide)
  tools       run the tests of the Python tools
  art         run `make art` and check that art/generated stays as committed (also with full:
              `make test` does not draw the art)
  tests/x.gd  a GUT test file to run
and nothing at all when no test is needed (docs only).

How a GUT test is found for a changed script: the files are a graph. A file depends on another when
it uses its class_name, names its res:// path (a path ending in / or cut at a % counts as a
prefix: it may load any file under it) or, for scenes and `extends "path"`, names it so. A test
runs when it reaches a changed file through those dependencies. A data or art file is read by the
files that name its path, its file name, or, for art, its assets/ folder; a data file that names
the art is followed on to its readers.

Anything not placed runs everything. That is a tendency, not a promise: it follows only what the
code spells out (class names, res:// paths, paths relative to the file), so a path built at run time
without a literal prefix is missed; and what git ignores (addons/, assets/) is invisible to it.
"""

import argparse
import os
import posixpath
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TIMES = ROOT / "build" / "test-times"

SCANNED_SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc"}
CLASS_NAME = re.compile(r"^class_name\s+(\w+)", re.MULTILINE)
RES_PATH = re.compile(r"res://[^\"'\s)]*")
# A path relative to the file that names it (preload("sibling.gd"), extends "base.gd").
RELATIVE_PATH = re.compile(r"[\"']([^\"':\s]+\.(?:gd|tscn|tres|gdshader|gdshaderinc))[\"']")
IDENTIFIER = re.compile(r"[A-Za-z_]\w*")
BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
SHADER_SUFFIXES = {".gdshader", ".gdshaderinc"}
# Folders that hold no code and no data of the game: changing them changes no test result.
DOCS_FOLDERS = {"docs", "design", "review", ".claude"}
ART_GENERATORS = ("tools/art/", "tools/audio/", "tools/music/")


@dataclass
class Plan:
    full: bool = False
    tools: bool = False
    art: bool = False
    tests: set = field(default_factory=set)
    report: list = field(default_factory=list)

    def words(self):
        # `make test` does not draw the art, so a full plan keeps its art check.
        art = ["art"] if self.art else []
        if self.full:
            return ["full", *art]
        return [*(["tools"] if self.tools else []), *art, *sorted(self.tests)]


def strip_comments(text, suffix):
    """The text without GDScript (#) or shader (//, /* */) comments, whole-line or trailing; a marker
    inside a string ("Press #1", "res://x") is not one. A shader's #include stays: it is a dependency."""
    if suffix == ".gd":
        marker = "#"
    elif suffix in SHADER_SUFFIXES:
        marker = "//"
        text = BLOCK_COMMENT.sub("", text)
    else:
        return text
    lines = []
    for line in text.splitlines():
        quote = None
        for i, char in enumerate(line):
            if quote:
                if char == quote and line[i - 1] != "\\":
                    quote = None
            elif char in "\"'":
                quote = char
            elif line.startswith(marker, i):
                line = line[:i]
                break
        lines.append(line)
    return "\n".join(lines)


class Graph:
    """What the files of game/ and tests/ depend on, and the readers of the data and art files."""

    def __init__(self, root):
        self.root = root
        self.texts = {}  # path -> text, of every scanned file in game/ and tests/ and data/
        for folder in ("game", "tests", "data", "maps"):
            for file in sorted((root / folder).rglob("*")):
                if file.is_file() and (file.suffix in SCANNED_SUFFIXES or file.suffix == ".cfg"):
                    self.texts[file.relative_to(root).as_posix()] = file.read_text(errors="replace")
        # A scene, resource or script under data/ is code too: tests reach shaders through it.
        self.code = {p for p in self.texts if Path(p).suffix in SCANNED_SUFFIXES}
        # A name or a path in a comment is no reference (comments are full of "see Foo").
        self.stripped = {p: strip_comments(self.texts[p], Path(p).suffix) for p in self.code}
        self.class_files = {}  # class_name -> file
        for path in self.code:
            for name in class_names(self.texts[path]):
                self.class_files[name] = path
        self.dependents = {path: set() for path in self.code}  # file -> files that depend on it
        for path in self.code:
            for dependency in self._dependencies(path):
                self.dependents[dependency].add(path)

    def _dependencies(self, path):
        text = self.stripped[path]
        found = {self.class_files[name] for name in set(IDENTIFIER.findall(text)) & self.class_files.keys()}
        for literal in RES_PATH.findall(text):
            found |= self.code_named_by(literal.removeprefix("res://"))
        for literal in RELATIVE_PATH.findall(text):
            found |= {posixpath.normpath(posixpath.join(posixpath.dirname(path), literal))} & self.code
        found.discard(path)
        return found

    def code_named_by(self, literal):
        """The scripts, scenes and shaders a path in a file may name."""
        stem, cut, _ = literal.partition("%")
        if cut or stem.endswith("/"):
            return {p for p in self.code if p.startswith(stem)}
        return {stem} & self.code

    def tests_reaching(self, seeds):
        """The test files that depend on one of the files, directly or through others."""
        reached = set()
        todo = list(seeds)
        while todo:
            path = todo.pop()
            if path not in reached:
                reached.add(path)
                todo.extend(self.dependents.get(path, ()))
        return {p for p in reached if is_test(p)}

    def tests_using(self, files):
        """The test files that are one of the files or depend directly on one."""
        return {p for f in files for p in {f, *self.dependents[f]} if is_test(p)}

    def readers_of(self, path, by_name=True):
        """The files of game/ and tests/ that name a data or art file (by its res:// path, or, with
        by_name, by its file name too), and the ones that only name a folder above an art file (a
        loader of everything under assets/)."""
        names = self._names_of(path)
        readers = set()
        loaders = set()
        for code_path in self.code:
            text = self.stripped[code_path]
            if by_name and any(name in text for name in names["text"]):
                readers.add(code_path)
            for literal in RES_PATH.findall(text):
                stem, cut, _ = literal.removeprefix("res://").partition("%")
                folder = names["folder"]
                if stem in names["paths"] or stem.startswith(tuple(names["prefixes"])):
                    readers.add(code_path)
                elif folder:
                    if stem.startswith(folder + "/"):
                        readers.add(code_path)
                    elif (folder + "/").startswith(stem):
                        loaders.add(code_path)
                elif (cut or stem.endswith("/")) and any(p.startswith(stem) for p in names["paths"]):
                    readers.add(code_path)
        return readers, loaders - readers

    def data_files_naming(self, path):
        """The data files that name a data, map or art file (data/crops.cfg names assets/crops/x.png)."""
        names = self._names_of(path)
        return {p for p, text in self.texts.items() if p.startswith("data/") and any(n in text for n in names["text"])}

    def readers_through_data(self, path):
        """The files that read a map or data file through the data files that name it: buildings.cfg
        names maps/interiors/kate.tmx, and what reads buildings.cfg reads the map."""
        readers = set()
        seen = {path}
        todo = [path]
        while todo:
            for data_file in self.data_files_naming(todo.pop()) - seen:
                seen.add(data_file)
                todo.append(data_file)
                readers |= self.readers_of(data_file)[0]
        return readers

    def _names_of(self, path):
        base = Path(path).name
        names = {"text": {path, base}, "paths": {path}, "folder": None, "prefixes": set()}
        if path.startswith(("art/generated/", "art/hand/")):
            # make assets scales and packs these into assets/, without the size in the name, so
            # the readers name that.
            relative = re.sub(r"_(16x16|32x32)(\.\w+)$", r"\2", path.split("/", 2)[2])
            folder = relative.rpartition("/")[0]
            names["text"] = {base, "assets/" + relative}
            names["paths"] = {"assets/" + relative}
            names["folder"] = "assets/" + folder if folder else None
            # The sheets of a folder with an atlas manifest are packed into assets/<folder>.png (one
            # per look, and objects_rows.txt beside it), which no file of the folder is named like.
            if folder and any((self.root / "art/generated" / folder).glob("atlas_*.txt")):
                names["prefixes"] = {"assets/" + folder, "assets/classic/" + folder}
        return names


def class_names(text):
    return set(CLASS_NAME.findall(text))


def is_test(path):
    return path.startswith("tests/test_") and path.endswith(".gd")


def names_of(paths, limit=6):
    paths = sorted(paths)
    shown = ", ".join(Path(p).name for p in paths[:limit])
    return shown + (f", ... ({len(paths)} in all)" if len(paths) > limit else "")


def select(root, changed, deleted=(), base_class_names=None):
    """The plan for the changed and deleted files (paths relative to root, with /).
    base_class_names: the class_names each changed script declared before the branch."""
    plan = Plan()
    base_class_names = base_class_names or {}
    graph = Graph(root)
    for path in sorted({*changed, *deleted}):
        parts = Path(path).parts
        name = Path(path).name
        line = f"{path}: "
        if path.endswith(".uid") or name == ".gitkeep":
            plan.report.append(line + "no effect on any test")
        elif path.endswith(".md") or parts[0] in DOCS_FOLDERS:
            plan.report.append(line + "docs, no tests")
        elif path == "tools/run_tests.py":
            plan.full = True
            plan.report.append(line + "the test runner itself: everything")
        elif parts[0] == "tools":
            plan.tools = True
            # Anything a generator reads counts, not only its code (tools/music/pieces/*.txt).
            is_python_test = name.startswith("test_") and name.endswith(".py")
            generator = path.startswith(ART_GENERATORS) and not is_python_test
            plan.art |= generator
            # A GUT test may read a tool's file too (test_shader_palette.gd reads tools/art/palette.py).
            readers = graph.readers_of(path, by_name=False)[0]
            tests = graph.tests_reaching(readers)
            plan.tests |= tests
            reason = "tool, the tests of the tools" + (" and make art" if generator else "")
            if tests:
                reason += f", read by {names_of(readers)} -> {len(tests)} tests ({names_of(tests)})"
            plan.report.append(line + reason)
        elif parts[0] in ("game", "tests") and Path(path).suffix in SCANNED_SUFFIXES:
            if path in deleted:
                if is_test(path):
                    plan.report.append(line + "deleted test, nothing to run")
                else:
                    plan.full = True
                    plan.report.append(line + "deleted, its users can't be followed: everything")
                continue
            lost = base_class_names.get(path, set()) - class_names(graph.texts[path])
            if lost:
                plan.full = True
                plan.report.append(line + f"class_name {', '.join(sorted(lost))} is gone: its users can't be followed: everything")
                continue
            tests = graph.tests_reaching({path})
            reason = "test, runs itself" if is_test(path) else "reached by"
            plan.tests |= tests
            plan.report.append(line + f"{reason} {len(tests)} tests ({names_of(tests)})")
        elif path.startswith(("data/", "maps/", "art/generated/", "art/hand/")):
            place_resource(plan, graph, path)
        else:
            plan.full = True
            plan.report.append(line + "unknown kind of path: everything")
    return plan


def place_resource(plan, graph, path):
    """A data, map or art file runs the tests of the files that read it."""
    is_art = path.startswith("art/")
    make_art = path.startswith("art/generated/")
    plan.art |= make_art
    readers, loaders = graph.readers_of(path)
    if is_art:
        # A data file names the pictures too (crops.cfg names assets/crops/turnip.png): the tests
        # that read that file check its pictures.
        for data_file in graph.data_files_naming(path):
            readers |= {r for r in graph.readers_of(data_file)[0] if is_test(r)}
    else:
        readers |= graph.readers_through_data(path)
    if not readers and not loaders:
        plan.full = True
        plan.report.append(f"{path}: no file reads it that I can find: everything")
        return
    if is_art:
        # A picture changes what its readers draw, not what the code built on them does: their own
        # tests (and those of the loaders of all art) are the asset tests. The full run covers the rest.
        tests = graph.tests_using(readers | loaders)
    else:
        tests = graph.tests_reaching(readers)
    plan.tests |= tests
    reason = f"read by {names_of(readers | loaders)}" + (", make art" if make_art else "")
    plan.report.append(f"{path}: {reason} -> {len(tests)} tests ({names_of(tests)})")


def clean_git_env():
    """The environment for a git run in `root`, without the GIT_* variables of whoever called us:
    a `git rebase --exec` exports GIT_DIR and GIT_WORK_TREE, and with them git would act on that
    repository instead of the one in `root` (the selector's own tests once ran `git init` and
    commits against the real repository that way)."""
    return {name: value for name, value in os.environ.items() if not name.startswith("GIT_")}


def git(root, *args):
    result = subprocess.run(
        ["git", *args], cwd=root, capture_output=True, text=True, check=True, env=clean_git_env()
    )
    return result.stdout.split("\0" if "-z" in args else "\n")


def fork_point(root, base, head="HEAD"):
    return git(root, "merge-base", base, head)[0]


def class_names_at(root, revision, paths):
    """The class_names the scripts among `paths` declared at the revision (none for a new file)."""
    names = {}
    for path in paths:
        if path.endswith(".gd"):
            shown = subprocess.run(
                ["git", "show", f"{revision}:{path}"], cwd=root, capture_output=True, text=True, env=clean_git_env()
            )
            names[path] = class_names(shown.stdout) if shown.returncode == 0 else set()
    return names


def changed_files(root, base, head="HEAD"):
    """(changed, deleted): every file changed from where the branch left BASE to the head, plus the
    uncommitted and new files of the worktree when the head is HEAD."""
    paths = set(git(root, "diff", "-z", "--name-only", "--no-renames", fork_point(root, base, head), head))
    if head == "HEAD":
        paths |= set(git(root, "diff", "-z", "--name-only", "--no-renames", "HEAD"))
        paths |= set(git(root, "ls-files", "-z", "--others", "--exclude-standard"))
    paths.discard("")
    existing = {p for p in paths if (root / p).is_file()}
    return existing, paths - existing


def read_times(root):
    times_file = root / "build" / "test-times"
    if not times_file.exists():
        return {}
    return {name: float(sec) for name, sec in (line.split("\t") for line in times_file.read_text().splitlines())}


def summary(root, plan):
    if plan.full:
        return "Plan: everything (make test)" + (", and make art with a clean git status art/." if plan.art else ".")
    parts = []
    if plan.tools:
        parts.append("the tests of the tools")
    if plan.art:
        parts.append("make art and a clean git status art/")
    all_tests = sorted(p.relative_to(root).as_posix() for p in (root / "tests").glob("test_*.gd"))
    if plan.tests:
        times = read_times(root)
        seconds = ""
        if times:
            selected, total = sum(times.get(t, 0) for t in plan.tests), sum(times.values())
            seconds = f", about {selected:.0f} of {total:.0f} s of test time"
        parts.append(f"{len(plan.tests)} of {len(all_tests)} GUT test files{seconds}")
    return "Plan: " + (", ".join(parts) if parts else "no tests needed.")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("base", nargs="?", default="main")
    parser.add_argument("--head", default="HEAD")
    args = parser.parse_args()
    changed, deleted = changed_files(ROOT, args.base, args.head)
    base_class_names = class_names_at(ROOT, fork_point(ROOT, args.base, args.head), changed)
    plan = select(ROOT, changed, deleted, base_class_names)
    if not changed and not deleted:
        plan.report.append(f"Nothing changed between {args.base} and {args.head}.")
    print("\n".join([*plan.report, summary(ROOT, plan)]), file=sys.stderr)
    print(" ".join(plan.words()))


if __name__ == "__main__":
    main()
