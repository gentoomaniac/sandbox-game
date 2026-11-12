# Run `make` (or `make help`) to list the targets and variables.
.DEFAULT_GOAL := help

GODOT ?= godot
GODOT_VERSION := $(shell cat .godot-version)

GUT_VERSION := 9.7.1

VENV := .venv
GDLINT := $(VENV)/bin/gdlint
GDFORMAT := $(VENV)/bin/gdformat
PYTHON := $(VENV)/bin/python
# Written once the packages are installed, so an interrupted install is not taken for a venv.
VENV_READY := $(VENV)/.installed
GDSCRIPT_DIRS := game tests

# Godot only finds addon classes (GUT) and new class_name scripts after an import
# pass. It takes about 2 s, so setup, run and test simply run it every time instead of
# tracking when the cache is stale.
IMPORT := $(GODOT) --headless --quiet --import

# Downloaded addons are NOT committed: the pinned versions above make `make setup`
# reproducible, and it keeps third-party code out of our history and diffs.
# The cost is that a fresh clone needs `make setup` (and network) before it runs.

.PHONY: help setup venv art classic-art assets contrast-sheet run screenshot test test-changed test-tools bench bench-music music-check lint format export clean llm-up llm-down llm-check \
	llm-pull llm-models llm-rm llm-eval llm-gpu-setup

help:
	@echo "Targets:"
	@echo "  help        This list (the default)."
	@echo "  setup       Check the tools, download GUT, create the Python venv, build assets/, import the project."
	@echo "  venv        Create the Python venv with the packages of tools/requirements.txt."
	@echo "  run         Start the game."
	@echo "  screenshot  Save one frame as PNG (a new game, muted, no focus, its own save)."
	@echo "  test        Run the GUT tests headless, in TEST_JOBS parallel processes, and the tests of the Python tools."
	@echo "  test-changed  Run only the tests the files changed since BASE need: GUT files, tools tests, make art (see tools/select_tests.py)."
	@echo "  test-tools  Run only the tests of the Python tools (tools/ and its art, llm and music folders, test_*.py)."
	@echo "  bench       Time a heavy save headless (start-up, nodes, frame times standing and walking, pile pick-up, save); see tools/README.md."
	@echo "  bench-music Time the prototype music renderer: renders on their own, then frame times in the game while it renders (headless, muted)."
	@echo "  music-check Render every piece with the game's prototype music renderer and compare it with libmodplug's (headless, silent)."
	@echo "  lint        Run gdlint and gdformat --check, and check no API key is in the repo."
	@echo "  format      Format the GDScript."
	@echo "  art         Draw all art, sounds and music into art/generated/, then check them (minutes; needs no Godot)."
	@echo "  classic-art Draw only the classic art (the 16 px art of groups now drawn at 32 px)."
	@echo "  assets      Build assets/ (what Godot reads; not tracked) from art/generated/ and art/hand/ (seconds, only when stale; needs no Godot)."
	@echo "  contrast-sheet  Draw plants over the ground of every look into build/contrast_sheet.png."
	@echo "  llm-up      Start the local test LLM (Ollama in a container) and pull its model; see tools/README.md."
	@echo "  llm-down    Stop and remove the test LLM container (the model stays; PURGE=1 deletes it too)."
	@echo "  llm-check   Send one chat request to the test LLM and print the reply."
	@echo "  llm-pull    Fetch another model into the running test LLM, e.g. LLM_MODEL=qwen2.5:7b-instruct."
	@echo "  llm-models  List the models the test LLM has."
	@echo "  llm-eval    Try the villagers' prompts on LLM_MODEL (LLM_RUNS replies each); report in build/llm-eval/."
	@echo "  llm-rm      Delete the model LLM_MODEL (required) from the test LLM."
	@echo "  llm-gpu-setup  Prepare the GPU for llm-up: NVIDIA writes its CDI spec (sudo, again after driver updates); AMD checks the devices and groups."
	@echo "  clean       Delete build/ (test log, screenshots, the screenshot save); nothing is lost."
	@echo "  export      Not set up yet: no export presets exist."
	@echo
	@echo "Variables (make <target> NAME=value):"
	@echo "  GODOT       Path of the Godot binary (default: godot)."
	@echo "  VENV        Directory of the Python venv (default: .venv)."
	@echo "  TEST_JOBS   test: parallel test processes (default: 8; 1 runs the tests in one process)."
	@echo "  BASE        test-changed: the branch point to compare with (default: main); BASE..HEAD and uncommitted changes count."
	@echo "  TEST_TIMEOUT test: seconds before a hung run is stopped (default: 600)."
	@echo "  AT          screenshot: world tile to put the player on, e.g. AT=40,-20 (default: the camp)."
	@echo "  TIME        screenshot: time of day, e.g. TIME=21:00 (default: the game start)."
	@echo "  ZOOM        screenshot: camera zoom, 0.5 (the widest, 40x22 tiles, as the game starts) to 2 (the closest); 1 is 20x11 tiles."
	@echo "  SIZE        screenshot: picture size in pixels, e.g. SIZE=1000x1040 (default: the window as it is)."
	@echo "  OUT         screenshot: file to write (default: build/screenshot.png)."
	@echo "  SCREENSHOT_TIMEOUT  screenshot: seconds before a hung Godot is killed (default: 30)."
	@echo "  KEEP_SAVE   screenshot: KEEP_SAVE=1 loads the real save instead of a new game."
	@echo "  SOUND       screenshot: SOUND=1 keeps the sound on."
	@echo "  CONTAINER   llm-*: container tool, podman or docker (default: podman if present)."
	@echo "  LLM_MODEL   llm-*: Ollama model tag (default: qwen2.5:7b-instruct)."
	@echo "  LLM_RUNS    llm-eval: replies per scenario (default: 3)."
	@echo "  LLM_GPU     llm-up: auto (NVIDIA via CDI spec, else AMD via ROCm, else CPU), nvidia, amd, 1 (any GPU or fail), 0 (CPU)."
	@echo "  LLM_HSA_OVERRIDE  llm-up on AMD: HSA_OVERRIDE_GFX_VERSION for cards ROCm does not list, e.g. 10.3.0."
	@echo "  ARGS        screenshot, run: more debug flags, e.g. ARGS=\"--weather=rain\" (see game/scenes/startup_options.gd)."

setup:
	@missing=0; \
	check() { \
		if ! command -v "$$1" >/dev/null 2>&1; then \
			echo "MISSING: $$2"; echo "  install: $$3"; missing=1; \
		fi; \
	}; \
	check "$(GODOT)" "Godot $(GODOT_VERSION) ('$(GODOT)' not found)" \
		"Gentoo: emerge dev-games/godot; or download $(GODOT_VERSION) from godotengine.org and run make GODOT=/path/to/godot ..."; \
	check python3 "Python 3" "Gentoo: emerge dev-lang/python; or your package manager's python3"; \
	check git "git" "Gentoo: emerge dev-vcs/git; or your package manager's git"; \
	check curl "curl (downloads addons)" "Gentoo: emerge net-misc/curl; or your package manager's curl"; \
	if ! command -v tiled >/dev/null 2>&1; then \
		echo "Tiled: not found (optional: only to edit interiors)"; \
		echo "  install: Gentoo: emerge games-util/tiled; or download from mapeditor.org"; \
	fi; \
	if command -v "$(GODOT)" >/dev/null 2>&1; then \
		found=$$("$(GODOT)" --version | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+'); \
		if [ "$$found" != "$(GODOT_VERSION)" ]; then \
			echo "WRONG VERSION: Godot $$found found, $(GODOT_VERSION) required (.godot-version)"; missing=1; \
		fi; \
	fi; \
	if command -v python3 >/dev/null 2>&1; then \
		$(MAKE) --no-print-directory venv || missing=1; \
	fi; \
	if [ ! -d addons/gut ] && command -v curl >/dev/null 2>&1; then \
		echo "Downloading GUT $(GUT_VERSION)"; \
		curl -fsSL https://github.com/bitwes/Gut/archive/refs/tags/v$(GUT_VERSION).tar.gz \
			| tar xz --strip-components=1 "Gut-$(GUT_VERSION)/addons/gut" || missing=1; \
	fi; \
	if [ $$missing -eq 0 ]; then $(MAKE) --no-print-directory assets || missing=1; fi; \
	if [ -d addons/gut ] && command -v "$(GODOT)" >/dev/null 2>&1; then \
		$(IMPORT) || missing=1; \
	fi; \
	if [ $$missing -ne 0 ]; then echo "Setup incomplete, see above."; exit 1; fi; \
	echo "Setup complete."

# The Python tools (art, sound and lint) run in a venv of their own with pinned packages, see
# tools/requirements.txt. The venv counts as ready only once its packages are installed (a
# marker file), so a broken or interrupted install is redone on the next run, and so is one
# whose pins changed since.
venv: $(VENV_READY)

$(VENV_READY): tools/requirements.txt
	python3 -m venv $(VENV)
	$(VENV)/bin/pip install --quiet --disable-pip-version-check -r tools/requirements.txt
	touch $(VENV_READY)

# Draws every PNG into art/generated/ and checks that they use only palette colours, then every
# sound into art/generated/sounds/ and checks their levels and loops, then every piece of music
# into art/generated/music/ and checks it with an independent player. The classic art comes
# first, so the palette check covers it too. This is the slow part; `make assets` packs it.
art: classic-art
	$(PYTHON) tools/art/generate.py
	$(PYTHON) tools/audio/generate.py
	$(PYTHON) tools/audio/check.py
	$(PYTHON) tools/music/generate.py
	$(PYTHON) tools/music/check.py

# The classic art: the _16x16 files of art/generated/ (see tools/art/classic/generate.py).
classic-art: $(VENV_READY)
	$(PYTHON) tools/art/classic/generate.py

# Builds assets/ out of art/generated/ (see tools/art/pack.py): packs the atlases, scales the
# classic art up, copies the rest. Draws nothing.
# assets/ is build output, not tracked: a fresh clone builds it, and so does every target that
# needs it once its sources (art/, a folder's own time changes when a file is removed) or the
# packing code are newer than the stamp.
ASSETS_STAMP := assets/.packed
ASSET_SOURCES := $(shell find art -mindepth 1 -type f -o -type d) $(wildcard tools/art/pack.py tools/art/atlas.py tools/art/palette.py tools/art/classic/scaling.py)

assets: $(ASSETS_STAMP)

$(ASSETS_STAMP): $(VENV_READY) $(ASSET_SOURCES)
	$(PYTHON) tools/art/pack.py
	touch $@

# Plants over the ground of every look, to check their contrast by eye (needs the assets):
# make contrast-sheet, or make contrast-sheet KINDS="willow shrub" (atlas row names).
KINDS ?=
contrast-sheet: $(VENV_READY)
	$(PYTHON) tools/art/contrast_sheet.py $(KINDS)

run: assets
	$(IMPORT)
	$(GODOT) --path . $(if $(ARGS),-- $(ARGS))

# Saves one frame of the game as PNG, e.g. make screenshot AT=40,-20 OUT=/tmp/shot.png
# (AT is a world tile to put the player on; default: the camp). TIME=hh:mm sets the time of
# day (default: game start). The picture is the whole window, as the player sees it.
AT ?=
TIME ?=
# Camera zoom, 0.5 (the widest, 40x22 tiles, as the game starts) to 2 (the closest).
ZOOM ?=
# The picture's size in pixels, e.g. SIZE=1000x1040. Without it the picture is the window as the
# window manager sized it, which is not what was asked for on Wayland; with it the game runs in a
# viewport of that size and the picture shows what a window of that size shows.
SIZE ?=
# Further debug flags, e.g. ARGS="--ghost=3,-5" (see game/scenes/startup_options.gd).
ARGS ?=
OUT ?= $(CURDIR)/build/screenshot.png
# Screenshots start a new game, so they never show the real save; KEEP_SAVE=1 loads it
# (e.g. with ARGS="--save-path=..."). They read build/settings.cfg instead of the player's
# settings (a missing file means defaults), so stored keys or display mode don't apply.
KEEP_SAVE ?=
# Test runs stay out of the way: no sound (SOUND=1 keeps it) and a window that doesn't take the
# focus (--background makes it unfocusable). On Wayland the native driver is used as well, since
# Wayland compositors are stricter than X11 about new windows grabbing the focus. A Godot build
# without the Wayland driver needs QUIET_WINDOW= on the command line.
# The game itself runs on X11 (XWayland under Wayland; project.godot sets the driver), because
# Godot 4.7.2's Wayland driver sometimes never finishes quitting. Screenshots keep Wayland for
# the focus and live with that hang through SCREENSHOT_TIMEOUT below.
QUIET_WINDOW := $(if $(WAYLAND_DISPLAY),--display-driver wayland)

# Godot's Wayland driver sometimes hangs for good while it shuts down, after the PNG is written
# (an empty project does it too: about 1 quit in 20). Such a run is killed after
# SCREENSHOT_TIMEOUT seconds (exit status 137, killed) and counts as done when the PNG is there.
# A long --screenshot-delay needs a larger SCREENSHOT_TIMEOUT, or the run is killed before the PNG
# exists and fails.
SCREENSHOT_TIMEOUT ?= 30
# The window is named so that window rules (KWin, a tiling script) can keep test windows out of
# the way (see tools/README.md). `make run` doesn't name its window so: add the flag with
# ARGS=--with-working-window-title if a run is a check.

screenshot: assets
	$(IMPORT)
	mkdir -p $(dir $(OUT))
	rm -f $(OUT)
	timeout -s KILL $(SCREENSHOT_TIMEOUT) $(GODOT) $(QUIET_WINDOW) --path . $(if $(SIZE),res://game/scenes/screenshot_frame.tscn) -- $(if $(SOUND),,--mute) --background --with-working-window-title $(if $(KEEP_SAVE),,--new-game --save-path=$(CURDIR)/build/screenshot.save) $(if $(AT),--at=$(AT)) --settings-path=$(CURDIR)/build/settings.cfg --screenshot=$(OUT) $(if $(TIME),--time=$(TIME)) $(if $(ZOOM),--zoom=$(ZOOM)) $(if $(SIZE),--screenshot-size=$(SIZE)) $(ARGS); status=$$?; \
	if [ $$status -eq 137 ] && [ -s $(OUT) ]; then echo "make screenshot: Godot hung on quit, after the screenshot"; exit 0; fi; \
	exit $$status

# On Godot builds without navigation (e.g. some Gentoo builds) GUT prints a harmless
# 'Identifier "NavigationMeshGenerator" not declared' parse error. Tests still run.
# tools/run_tests.py spreads the test files over TEST_JOBS headless Godot processes (1 = one
# process, like a plain GUT run) and checks every shard: a script that failed to load and a test
# file that doesn't extend GutTest (GUT skips both without failing the run; each is named), no
# test run at all, failing tests, "leaked at exit". It ends with the warning and orphan counts of
# GUT's summary and leaves the joined logs in build/test.log.
# user:// of each shard points into build/ (Godot finds it under XDG_DATA_HOME on Linux): runs
# in two worktrees at once don't delete each other's test files, and no test can reach the
# real save.
TEST_JOBS ?= 8

# The tests of the Python tools (tools/art/, tools/llm/, tools/music/ and tools/ test_*.py), part of `make test`.
test-tools: $(VENV_READY)
	$(PYTHON) -m unittest discover -s tools/art -p "test_*.py"
	$(PYTHON) -m unittest discover -s tools/llm -p "test_*.py"
	$(PYTHON) -m unittest discover -s tools/music -p "test_*.py"
	$(PYTHON) -m unittest discover -s tools -p "test_*.py"

test: assets test-tools
	@mkdir -p build/user-data
	XDG_DATA_HOME=$(CURDIR)/build/user-data $(IMPORT)
	@GODOT=$(GODOT) python3 tools/run_tests.py $(TEST_JOBS)

# Only what the files changed since BASE need: the whole range BASE..HEAD and the uncommitted
# changes, not just the last commit. tools/select_tests.py says what it picked and why (on stderr)
# and answers on stdout with the words `full` (the same as make test), `tools`, `art` (`make art`
# and art/ left as committed; kept with `full` too, which does not draw it) and test files to
# run, or nothing when only docs changed. `make test` stays the check before reporting.
BASE ?= main

test-changed: $(VENV_READY)
	@set -e; \
	plan="$$($(PYTHON) tools/select_tests.py $(BASE))"; \
	if [ -z "$$plan" ]; then echo "make test-changed: no tests needed."; exit 0; fi; \
	case " $$plan " in *" art "*) \
		$(MAKE) art; \
		drawn="$$(git status --porcelain art/)"; \
		if [ -n "$$drawn" ]; then \
			echo "make test-changed: make art changed art/ (commit the drawn art first):" >&2; echo "$$drawn" >&2; exit 1; \
		fi;; \
	esac; \
	case " $$plan " in *" full "*) exec $(MAKE) test;; esac; \
	case " $$plan " in *" tools "*) $(MAKE) test-tools;; esac; \
	gut_files=$$(printf '%s\n' $$plan | grep '^tests/' || true); \
	if [ -n "$$gut_files" ]; then \
		$(MAKE) assets; \
		mkdir -p build/user-data; \
		XDG_DATA_HOME=$(CURDIR)/build/user-data $(IMPORT); \
		GODOT=$(GODOT) python3 tools/run_tests.py $(TEST_JOBS) $$gut_files; \
	fi

# The fixture save is written once (again when its script changes); each run plays a copy, since
# the game saves over the file it loaded. user:// points into build/, so the real save and
# settings are never touched.
BENCH_DIR := $(CURDIR)/build/bench
# The bench runs uncapped: the default 60 fps cap would floor its frame times.
BENCH_GODOT := XDG_DATA_HOME=$(CURDIR)/build/user-data $(GODOT) --headless --path .

$(BENCH_DIR)/fixture.save: tools/bench/make_fixture.gd
	mkdir -p $(BENCH_DIR)
	$(BENCH_GODOT) -s tools/bench/make_fixture.gd -- $@

bench: assets
	@mkdir -p build/user-data
	XDG_DATA_HOME=$(CURDIR)/build/user-data $(IMPORT)
	$(MAKE) $(BENCH_DIR)/fixture.save
	cp $(BENCH_DIR)/fixture.save $(BENCH_DIR)/run.save
	$(BENCH_GODOT) -s tools/bench/frames.gd -- --save-path=$(BENCH_DIR)/run.save --settings-path=$(BENCH_DIR)/settings.cfg --mute --max-fps=0
	$(BENCH_GODOT) -s tools/bench/pickup.gd -- $(BENCH_DIR)/fixture.save
	$(BENCH_GODOT) -s tools/bench/save.gd -- $(BENCH_DIR)/fixture.save

# The prototype music renderer of task 169: render times, memory, and the game's frames while it
# renders on a worker, also during a save, on a copy of the bench save.
bench-music: assets
	@mkdir -p build/user-data
	XDG_DATA_HOME=$(CURDIR)/build/user-data $(IMPORT)
	$(MAKE) $(BENCH_DIR)/fixture.save
	cp $(BENCH_DIR)/fixture.save $(BENCH_DIR)/run.save
	$(BENCH_GODOT) -s tools/bench/music.gd -- --save-path=$(BENCH_DIR)/run.save --settings-path=$(BENCH_DIR)/settings.cfg --mute --max-fps=0

# The game's prototype music renderer (task 169) against libmodplug, an independent player: the
# pieces rendered headless into build/music/, then compared by tools/music/check.py.
music-check: assets
	@mkdir -p build/user-data
	XDG_DATA_HOME=$(CURDIR)/build/user-data $(IMPORT)
	XDG_DATA_HOME=$(CURDIR)/build/user-data $(GODOT) --headless --path . -s tools/music/render.gd -- $(CURDIR)/build/music
	$(PYTHON) tools/music/check.py --against build/music

lint:
	$(GDLINT) $(GDSCRIPT_DIRS)
	$(GDFORMAT) --check $(GDSCRIPT_DIRS)
	tools/check_secrets.sh

format:
	$(GDFORMAT) $(GDSCRIPT_DIRS)

export: assets
	@echo "No export presets exist yet."
	@exit 1

# A local LLM for trying NPC talk, in a container; no test needs it. See tools/README.md.
llm-up:
	tools/llm/llm.sh up

llm-down:
	tools/llm/llm.sh down $(if $(filter 1,$(PURGE)),--purge)

llm-check:
	tools/llm/llm.sh check

llm-pull:
	tools/llm/llm.sh pull

llm-models:
	tools/llm/llm.sh models

# Needs the test LLM running (llm-up) with the model pulled.
llm-eval: $(VENV_READY)
	$(PYTHON) tools/llm/eval_prompts.py --runs $(or $(LLM_RUNS),3)

# Never the default model by accident: the tag must be given.
llm-rm:
	@test -n "$(LLM_MODEL)" || { echo "llm-rm needs LLM_MODEL=<tag>, e.g. make llm-rm LLM_MODEL=qwen2.5:7b-instruct" >&2; exit 1; }
	tools/llm/llm.sh rm

# One-time host setup (and again after each driver update): the GPU for llm-up.
llm-gpu-setup:
	tools/llm/llm.sh gpu-setup

# Everything in build/ is made by the targets above, so deleting it loses nothing.
clean:
	rm -rf build
