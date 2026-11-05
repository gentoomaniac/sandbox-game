GODOT ?= godot
GODOT_VERSION := $(shell cat .godot-version)

GUT_VERSION := 9.7.1
# Pinned. Bump only to a release that ships a GDScript build (some are C#-only).
YATI_VERSION := 2.2.9
GDTOOLKIT_VERSION := 4.5.0

VENV := .venv
GDLINT := $(VENV)/bin/gdlint
GDFORMAT := $(VENV)/bin/gdformat
GDSCRIPT_DIRS := game tests

# Godot only finds addon classes (GUT) and new class_name scripts after an import
# pass. It takes about 2 s, so setup, run and test simply run it every time instead of
# tracking when the cache is stale.
IMPORT := $(GODOT) --headless --quiet --import

# Downloaded addons are NOT committed: the pinned versions above make `make setup`
# reproducible, and it keeps third-party code out of our history and diffs.
# The cost is that a fresh clone needs `make setup` (and network) before it runs.

.PHONY: setup run test lint format export

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
	check unzip "unzip (unpacks addons)" "Gentoo: emerge app-arch/unzip; or your package manager's unzip"; \
	check curl "curl (downloads addons)" "Gentoo: emerge net-misc/curl; or your package manager's curl"; \
	if command -v "$(GODOT)" >/dev/null 2>&1; then \
		found=$$("$(GODOT)" --version | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+'); \
		if [ "$$found" != "$(GODOT_VERSION)" ]; then \
			echo "WRONG VERSION: Godot $$found found, $(GODOT_VERSION) required (.godot-version)"; missing=1; \
		fi; \
	fi; \
	if command -v python3 >/dev/null 2>&1 && [ ! -x $(GDLINT) ]; then \
		python3 -m venv $(VENV) && $(VENV)/bin/pip install --quiet gdtoolkit==$(GDTOOLKIT_VERSION) || missing=1; \
	fi; \
	if [ ! -d addons/gut ] && command -v curl >/dev/null 2>&1; then \
		echo "Downloading GUT $(GUT_VERSION)"; \
		curl -fsSL https://github.com/bitwes/Gut/archive/refs/tags/v$(GUT_VERSION).tar.gz \
			| tar xz --strip-components=1 "Gut-$(GUT_VERSION)/addons/gut" || missing=1; \
	fi; \
	if [ ! -d addons/YATI ] && command -v curl >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then \
		echo "Downloading YATI $(YATI_VERSION)"; \
		curl -fsSL -o yati.zip \
			https://github.com/Kiamo2/YATI/releases/download/v$(YATI_VERSION)/v$(YATI_VERSION)-gdscript.zip \
			&& unzip -q -o yati.zip 'addons/YATI/*' || missing=1; \
		rm -f yati.zip; \
	fi; \
	if [ -d addons/gut ] && command -v "$(GODOT)" >/dev/null 2>&1; then \
		$(IMPORT) || missing=1; \
	fi; \
	if [ $$missing -ne 0 ]; then echo "Setup incomplete, see above."; exit 1; fi; \
	echo "Setup complete."

run:
	$(IMPORT)
	$(GODOT) --path .

# On Godot builds without navigation (e.g. some Gentoo builds) GUT prints a harmless
# 'Identifier "NavigationMeshGenerator" not declared' parse error. Tests still run.
test:
	$(IMPORT)
	$(GODOT) --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

lint:
	$(GDLINT) $(GDSCRIPT_DIRS)
	$(GDFORMAT) --check $(GDSCRIPT_DIRS)

format:
	$(GDFORMAT) $(GDSCRIPT_DIRS)

export:
	@echo "No export presets exist yet."
	@exit 1
