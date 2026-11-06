# Run `make` (or `make help`) to list the targets and variables.
.DEFAULT_GOAL := help

GODOT ?= godot
GODOT_VERSION := $(shell cat .godot-version)

GUT_VERSION := 9.7.1
GDTOOLKIT_VERSION := 4.5.0
PILLOW_VERSION := 12.0.0
NUMPY_VERSION := 2.3.4

VENV := .venv
GDLINT := $(VENV)/bin/gdlint
GDFORMAT := $(VENV)/bin/gdformat
PYTHON := $(VENV)/bin/python
GDSCRIPT_DIRS := game tests

# Godot only finds addon classes (GUT) and new class_name scripts after an import
# pass. It takes about 2 s, so setup, run and test simply run it every time instead of
# tracking when the cache is stale.
IMPORT := $(GODOT) --headless --quiet --import

# Downloaded addons are NOT committed: the pinned versions above make `make setup`
# reproducible, and it keeps third-party code out of our history and diffs.
# The cost is that a fresh clone needs `make setup` (and network) before it runs.

.PHONY: help setup assets run screenshot test lint format export

help:
	@echo "Targets:"
	@echo "  help        This list (the default)."
	@echo "  setup       Check the tools, download GUT, create the Python venv, import the project."
	@echo "  run         Start the game."
	@echo "  screenshot  Save one frame as PNG (a new game, muted, no focus, its own save)."
	@echo "  test        Run the GUT tests headless."
	@echo "  lint        Run gdlint and gdformat --check."
	@echo "  format      Format the GDScript."
	@echo "  assets      Regenerate all art and sounds, then check them."
	@echo "  export      Not set up yet: no export presets exist."
	@echo
	@echo "Variables (make <target> NAME=value):"
	@echo "  GODOT       Path of the Godot binary (default: godot)."
	@echo "  VENV        Directory of the Python venv (default: .venv)."
	@echo "  AT          screenshot: world tile to put the player on, e.g. AT=40,-20 (default: the camp)."
	@echo "  TIME        screenshot: time of day, e.g. TIME=21:00 (default: the game start)."
	@echo "  ZOOM        screenshot: camera zoom, 0.5 to 2 (default 1)."
	@echo "  OUT         screenshot: file to write (default: build/screenshot.png)."
	@echo "  KEEP_SAVE   screenshot: KEEP_SAVE=1 loads the real save instead of a new game."
	@echo "  SOUND       screenshot: SOUND=1 keeps the sound on."
	@echo "  ARGS        screenshot: more debug flags, e.g. ARGS=\"--weather=rain\" (see game/scenes/main.gd)."

setup:
	@missing=0; \
	check() { \
		if ! command -v "$$1" >/dev/null 2>&1; then \
			echo "MISSING: $$2"; echo "  install: $$3"; missing=1; \
		fi; \
	}; \
	check "$(GODOT)" "Godot $(GODOT_VERSION) ('$(GODOT)' not found)" \
		"Gentoo: emerge dev-games/godot; or download $(GODOT_VERSION) from godotengine.org and run make GODOT=/path/to/godot ..."; \
	check tiled "Tiled" \
		"Gentoo: emerge games-util/tiled; or download from mapeditor.org"; \
	check python3 "Python 3" "Gentoo: emerge dev-lang/python; or your package manager's python3"; \
	check git "git" "Gentoo: emerge dev-vcs/git; or your package manager's git"; \
	check curl "curl (downloads addons)" "Gentoo: emerge net-misc/curl; or your package manager's curl"; \
	if command -v "$(GODOT)" >/dev/null 2>&1; then \
		found=$$("$(GODOT)" --version | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+'); \
		if [ "$$found" != "$(GODOT_VERSION)" ]; then \
			echo "WRONG VERSION: Godot $$found found, $(GODOT_VERSION) required (.godot-version)"; missing=1; \
		fi; \
	fi; \
	if command -v python3 >/dev/null 2>&1 \
		&& { [ ! -x $(GDLINT) ] || ! $(PYTHON) -c 'import PIL, numpy' 2>/dev/null; }; then \
		python3 -m venv $(VENV) && $(VENV)/bin/pip install --quiet \
			gdtoolkit==$(GDTOOLKIT_VERSION) pillow==$(PILLOW_VERSION) numpy==$(NUMPY_VERSION) \
			|| missing=1; \
	fi; \
	if [ ! -d addons/gut ] && command -v curl >/dev/null 2>&1; then \
		echo "Downloading GUT $(GUT_VERSION)"; \
		curl -fsSL https://github.com/bitwes/Gut/archive/refs/tags/v$(GUT_VERSION).tar.gz \
			| tar xz --strip-components=1 "Gut-$(GUT_VERSION)/addons/gut" || missing=1; \
	fi; \
	if [ -d addons/gut ] && command -v "$(GODOT)" >/dev/null 2>&1; then \
		$(IMPORT) || missing=1; \
	fi; \
	if [ $$missing -ne 0 ]; then echo "Setup incomplete, see above."; exit 1; fi; \
	echo "Setup complete."

# Regenerates every PNG under assets/ and checks that they use only palette colours, then
# every sound under assets/sounds/ and checks their levels and loops.
assets:
	$(PYTHON) tools/art/generate.py
	$(PYTHON) tools/audio/generate.py
	$(PYTHON) tools/audio/check.py

run:
	$(IMPORT)
	$(GODOT) --path .

# Saves one frame of the game as PNG, e.g. make screenshot AT=40,-20 OUT=/tmp/shot.png
# (AT is a world tile to put the player on; default: the camp). TIME=hh:mm sets the time of
# day (default: game start). The picture is the whole window, as the player sees it.
AT ?=
TIME ?=
# Camera zoom, 0.5 to 2 (default 1).
ZOOM ?=
# Further debug flags, e.g. ARGS="--ghost=3,-5" (see game/scenes/build_mode.gd).
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
QUIET_WINDOW := $(if $(WAYLAND_DISPLAY),--display-driver wayland)

screenshot:
	$(IMPORT)
	mkdir -p $(dir $(OUT))
	$(GODOT) $(QUIET_WINDOW) --path . -- $(if $(SOUND),,--mute) --background $(if $(KEEP_SAVE),,--new-game --save-path=$(CURDIR)/build/screenshot.save) $(if $(AT),--at=$(AT)) --settings-path=$(CURDIR)/build/settings.cfg --screenshot=$(OUT) $(if $(TIME),--time=$(TIME)) $(if $(ZOOM),--zoom=$(ZOOM)) $(ARGS)

# On Godot builds without navigation (e.g. some Gentoo builds) GUT prints a harmless
# 'Identifier "NavigationMeshGenerator" not declared' parse error. Tests still run.
# A script that fails to load (e.g. a parse error) is skipped by GUT without failing the run,
# so the log is checked for our own scripts that failed to load (the GUT addon has one known
# harmless failure, under addons/).
# It also fails when GUT ran no test (a broken selection must not pass silently), and ends with
# the warning and orphan counts of GUT's summary (it leaves a count out when it is 0).
test:
	$(IMPORT)
	@mkdir -p build
	@$(GODOT) --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit \
		> build/test.log 2>&1; status=$$?; cat build/test.log; \
	if grep -Eq 'Failed to load script "res://(game|tests)/' build/test.log; then \
		echo "make test: a script in game/ or tests/ failed to load (see above)"; exit 1; fi; \
	count() { sed -En "s/^$$1 +([0-9]+)\$$/\1/p" build/test.log | tail -n 1; }; \
	tests=$$(count Tests); \
	if [ "$${tests:-0}" -eq 0 ]; then echo "make test: GUT ran no tests"; exit 1; fi; \
	echo "make test: $$(count Warnings | grep . || echo 0) warnings, $$(count Orphans | grep . || echo 0) orphans"; \
	exit $$status

lint:
	$(GDLINT) $(GDSCRIPT_DIRS)
	$(GDFORMAT) --check $(GDSCRIPT_DIRS)

format:
	$(GDFORMAT) $(GDSCRIPT_DIRS)

export:
	@echo "No export presets exist yet."
	@exit 1
